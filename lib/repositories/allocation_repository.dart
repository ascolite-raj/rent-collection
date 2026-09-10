import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/deposit.dart';
import '../models/meter_reading.dart';
import '../models/payment.dart';
import '../models/room.dart';
import '../models/room_allocation.dart';
import '../models/settlement.dart';
import '../models/tenant.dart';
import '../utils/formatters.dart';
import 'deposit_repository.dart';
import 'electricity_repository.dart';
import 'payment_repository.dart';
import 'rent_repository.dart';
import 'room_repository.dart';

class RoomAlreadyOccupiedException implements Exception {
  final String message;
  RoomAlreadyOccupiedException(this.message);
  @override
  String toString() => message;
}

class TenantAlreadyAllocatedException implements Exception {
  final String message;
  TenantAlreadyAllocatedException(this.message);
  @override
  String toString() => message;
}

class CheckoutResult {
  final Settlement settlement;
  CheckoutResult(this.settlement);
}

class AllocationRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;
  final RoomRepository _roomRepo = RoomRepository();
  final DepositRepository _depositRepo = DepositRepository();
  final RentRepository _rentRepo = RentRepository();
  final ElectricityRepository _electricityRepo = ElectricityRepository();
  final PaymentRepository _paymentRepo = PaymentRepository();

  Future<List<RoomAllocation>> getByRoom(int roomId) async {
    final db = await _helper.database;
    final rows = await db.query('room_allocations', where: 'room_id = ?', whereArgs: [roomId], orderBy: 'joining_date DESC');
    return rows.map(RoomAllocation.fromMap).toList();
  }

  Future<List<RoomAllocation>> getByTenant(int tenantId) async {
    final db = await _helper.database;
    final rows = await db.query('room_allocations', where: 'tenant_id = ?', whereArgs: [tenantId], orderBy: 'joining_date DESC');
    return rows.map(RoomAllocation.fromMap).toList();
  }

  Future<RoomAllocation?> getActiveForRoom(int roomId, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final rows = await db.query(
      'room_allocations',
      where: "room_id = ? AND status = 'active'",
      whereArgs: [roomId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RoomAllocation.fromMap(rows.first);
  }

  Future<RoomAllocation?> getActiveForTenant(int tenantId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'room_allocations',
      where: "tenant_id = ? AND status = 'active'",
      whereArgs: [tenantId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RoomAllocation.fromMap(rows.first);
  }

  Future<RoomAllocation?> getById(int id) async {
    final db = await _helper.database;
    final rows = await db.query('room_allocations', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return RoomAllocation.fromMap(rows.first);
  }

  /// Allocates [tenant] to [room]: validates no conflicting active allocation exists,
  /// opens a room_allocations record, records the opening deposit (if any) and the
  /// initial meter reading, and flips room/tenant status — all in one transaction.
  Future<int> allocateTenant({
    required Room room,
    required Tenant tenant,
    required String joiningDate,
    required double monthlyRent,
    required double initialMeterReading,
    double depositAmount = 0,
    String? depositDate,
    String? notes,
  }) async {
    final db = await _helper.database;
    return db.transaction((txn) async {
      final existingForRoom = await getActiveForRoom(room.id!, executor: txn);
      if (existingForRoom != null) {
        throw RoomAlreadyOccupiedException('${room.roomNumber} already has an active tenant.');
      }
      final existingForTenantRows = await txn.query(
        'room_allocations',
        where: "tenant_id = ? AND status = 'active'",
        whereArgs: [tenant.id],
        limit: 1,
      );
      if (existingForTenantRows.isNotEmpty) {
        throw TenantAlreadyAllocatedException('${tenant.fullName} is already allocated to a room.');
      }
      final now = todayForStorage();
      final allocationId = await txn.insert(
        'room_allocations',
        RoomAllocation(
          roomId: room.id!,
          tenantId: tenant.id!,
          joiningDate: joiningDate,
          monthlyRent: monthlyRent,
          initialMeterReading: initialMeterReading,
          notes: notes,
          createdAt: now,
          updatedAt: now,
        ).toMap(),
      );

      await _electricityRepo.insertReading(
        MeterReading(
          roomId: room.id!,
          tenantId: tenant.id,
          allocationId: allocationId,
          readingDate: joiningDate,
          meterReading: initialMeterReading,
          notes: 'Initial reading on allocation',
          createdAt: now,
        ),
        executor: txn,
      );

      int? depositId;
      if (depositAmount > 0) {
        depositId = await _depositRepo.create(
          Deposit(
            tenantId: tenant.id!,
            roomId: room.id!,
            allocationId: allocationId,
            depositAmount: depositAmount,
            depositDate: depositDate ?? joiningDate,
            createdAt: now,
            updatedAt: now,
          ),
          executor: txn,
        );
        await _paymentRepo.create(
          Payment(
            tenantId: tenant.id,
            roomId: room.id,
            paymentType: PaymentType.deposit,
            referenceId: depositId,
            amount: depositAmount,
            paymentDate: depositDate ?? joiningDate,
            notes: 'Security deposit received',
            createdAt: now,
          ),
          executor: txn,
        );
      }

      await _roomRepo.updateStatus(room.id!, RoomStatus.occupied, executor: txn);
      await _roomRepo.updateMeterReading(room.id!, initialMeterReading, executor: txn);
      await txn.update(
        'tenants',
        {
          'current_room_id': room.id,
          'monthly_rent': monthlyRent,
          'status': TenantStatus.active,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [tenant.id],
      );

      return allocationId;
    });
  }

  /// Closes out an allocation when a tenant leaves: generates the final electricity
  /// bill, totals all pending rent/electricity/other dues, adjusts the deposit, and
  /// records a permanent settlement. Room becomes vacant, tenant becomes inactive.
  Future<CheckoutResult> checkoutTenant({
    required RoomAllocation allocation,
    required String leavingDate,
    required double finalMeterReading,
    required double electricityRate,
    double otherPending = 0,
    String? notes,
  }) async {
    final db = await _helper.database;
    return db.transaction((txn) async {
      final lastReading = await _electricityRepo.getLastReadingForAllocation(allocation.id!, executor: txn);
      final previousReading = lastReading?.meterReading ?? allocation.initialMeterReading;
      final previousDate = lastReading?.readingDate ?? allocation.joiningDate;

      await _electricityRepo.insertReading(
        MeterReading(
          roomId: allocation.roomId,
          tenantId: allocation.tenantId,
          allocationId: allocation.id,
          readingDate: leavingDate,
          meterReading: finalMeterReading,
          notes: 'Final reading on checkout',
          createdAt: todayForStorage(),
        ),
        executor: txn,
      );

      if (finalMeterReading > previousReading) {
        final now = todayForStorage();
        await txn.insert(
          'electricity_bills',
          (() {
            final units = finalMeterReading - previousReading;
            final amount = units * electricityRate;
            return {
              'room_id': allocation.roomId,
              'tenant_id': allocation.tenantId,
              'allocation_id': allocation.id,
              'from_date': previousDate,
              'to_date': leavingDate,
              'previous_reading': previousReading,
              'current_reading': finalMeterReading,
              'total_units': units,
              'rate_per_unit': electricityRate,
              'bill_amount': amount,
              'paid_amount': 0,
              'pending_amount': amount,
              'payment_status': 'pending',
              'notes': 'Final bill on checkout',
              'created_at': now,
              'updated_at': now,
            };
          })(),
        );
      }

      final pendingRent = await _rentRepo.totalPendingForAllocation(allocation.id!, executor: txn);
      final pendingElectricity = await _electricityRepo.totalPendingForAllocation(allocation.id!, executor: txn);

      final deposit = await _depositRepo.getByAllocation(allocation.id!, executor: txn);
      final depositAmount = deposit?.depositAmount ?? 0;
      final totalDue = pendingRent + pendingElectricity + otherPending;
      final depositAdjustment = totalDue > depositAmount ? depositAmount : totalDue;
      final finalRefund = depositAmount - depositAdjustment;

      if (deposit != null) {
        final status = depositAdjustment <= 0
            ? DepositStatus.refunded
            : (finalRefund > 0 ? DepositStatus.partiallyRefunded : DepositStatus.refunded);
        await _depositRepo.settleRefund(
          depositId: deposit.id!,
          refundAmount: finalRefund,
          adjustmentAmount: depositAdjustment,
          refundDate: leavingDate,
          status: status,
          executor: txn,
        );
        if (finalRefund > 0) {
          await _paymentRepo.create(
            Payment(
              tenantId: allocation.tenantId,
              roomId: allocation.roomId,
              paymentType: PaymentType.depositRefund,
              referenceId: deposit.id,
              amount: finalRefund,
              paymentDate: leavingDate,
              notes: 'Deposit refund on checkout',
              createdAt: todayForStorage(),
            ),
            executor: txn,
          );
        }
      }

      final settlement = Settlement(
        allocationId: allocation.id!,
        tenantId: allocation.tenantId,
        roomId: allocation.roomId,
        leavingDate: leavingDate,
        finalMeterReading: finalMeterReading,
        pendingRent: pendingRent,
        pendingElectricity: pendingElectricity,
        otherPending: otherPending,
        depositAmount: depositAmount,
        depositAdjustment: depositAdjustment,
        finalRefund: finalRefund,
        notes: notes,
        createdAt: todayForStorage(),
      );
      final settlementId = await txn.insert('settlements', settlement.toMap());

      await txn.update(
        'room_allocations',
        {
          'leaving_date': leavingDate,
          'final_meter_reading': finalMeterReading,
          'status': 'closed',
          'updated_at': todayForStorage(),
        },
        where: 'id = ?',
        whereArgs: [allocation.id],
      );

      await _roomRepo.updateStatus(allocation.roomId, RoomStatus.vacant, executor: txn);
      await _roomRepo.updateMeterReading(allocation.roomId, finalMeterReading, executor: txn);

      await txn.update(
        'tenants',
        {'status': TenantStatus.inactive, 'current_room_id': null, 'updated_at': todayForStorage()},
        where: 'id = ?',
        whereArgs: [allocation.tenantId],
      );

      return CheckoutResult(Settlement.fromMap({...settlement.toMap(), 'id': settlementId}));
    });
  }

  Future<List<Settlement>> getSettlementsByTenant(int tenantId) async {
    final db = await _helper.database;
    final rows = await db.query('settlements', where: 'tenant_id = ?', whereArgs: [tenantId], orderBy: 'leaving_date DESC');
    return rows.map(Settlement.fromMap).toList();
  }

  Future<List<Settlement>> getAllSettlements() async {
    final db = await _helper.database;
    final rows = await db.query('settlements', orderBy: 'leaving_date DESC');
    return rows.map(Settlement.fromMap).toList();
  }
}
