import '../database/database_helper.dart';
import '../models/electricity_bill.dart';
import '../models/meter_reading.dart';
import '../models/payment.dart';
import '../models/room.dart';
import '../repositories/allocation_repository.dart';
import '../repositories/electricity_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/room_repository.dart';
import '../utils/formatters.dart';

class NoActiveAllocationException implements Exception {
  final String message;
  NoActiveAllocationException(this.message);
  @override
  String toString() => message;
}

class MeterReadingTooLowException implements Exception {
  final String message;
  MeterReadingTooLowException(this.message);
  @override
  String toString() => message;
}

/// Records a new meter reading for an occupied room and automatically derives
/// the electricity bill for the period since the previous reading.
class ElectricityService {
  final DatabaseHelper _helper = DatabaseHelper.instance;
  final ElectricityRepository _electricityRepo = ElectricityRepository();
  final AllocationRepository _allocationRepo = AllocationRepository();
  final RoomRepository _roomRepo = RoomRepository();
  final PaymentRepository _paymentRepo = PaymentRepository();

  Future<ElectricityBill> recordReadingAndGenerateBill({
    required Room room,
    required String readingDate,
    required double meterReading,
    required double ratePerUnit,
    String? notes,
  }) async {
    final allocation = await _allocationRepo.getActiveForRoom(room.id!);
    if (allocation == null) {
      throw NoActiveAllocationException('${room.roomNumber} has no active tenant to bill.');
    }

    final db = await _helper.database;
    return db.transaction((txn) async {
      final lastReading = await _electricityRepo.getLastReadingForAllocation(allocation.id!, executor: txn);
      final previousReading = lastReading?.meterReading ?? allocation.initialMeterReading;
      final previousDate = lastReading?.readingDate ?? allocation.joiningDate;

      if (meterReading < previousReading) {
        throw MeterReadingTooLowException(
          'Current reading ($meterReading) cannot be lower than the previous reading ($previousReading).',
        );
      }

      await _electricityRepo.insertReading(
        MeterReading(
          roomId: room.id!,
          tenantId: allocation.tenantId,
          allocationId: allocation.id,
          readingDate: readingDate,
          meterReading: meterReading,
          notes: notes,
          createdAt: todayForStorage(),
        ),
        executor: txn,
      );

      final bill = ElectricityBill.calculate(
        roomId: room.id!,
        tenantId: allocation.tenantId,
        allocationId: allocation.id,
        fromDate: previousDate,
        toDate: readingDate,
        previousReading: previousReading,
        currentReading: meterReading,
        ratePerUnit: ratePerUnit,
        createdAt: todayForStorage(),
        updatedAt: todayForStorage(),
      );
      final billId = await _electricityRepo.insertBill(bill, executor: txn);
      await _roomRepo.updateMeterReading(room.id!, meterReading, executor: txn);

      final rows = await txn.query('electricity_bills', where: 'id = ?', whereArgs: [billId], limit: 1);
      return ElectricityBill.fromMap(rows.first);
    });
  }

  Future<void> recordPayment({
    required int billId,
    required int? tenantId,
    required int? roomId,
    required double amount,
    required String paymentDate,
    String paymentMethod = PaymentMethod.cash,
    String? notes,
  }) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      await _paymentRepo.create(
        Payment(
          tenantId: tenantId,
          roomId: roomId,
          paymentType: PaymentType.electricity,
          referenceId: billId,
          amount: amount,
          paymentDate: paymentDate,
          paymentMethod: paymentMethod,
          notes: notes,
          createdAt: todayForStorage(),
        ),
        executor: txn,
      );
      await _electricityRepo.applyPayment(billId, amount, paymentDate, executor: txn);
    });
  }
}
