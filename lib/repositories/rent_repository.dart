import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/rent_transaction.dart';
import '../utils/formatters.dart';

class RentRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<List<RentTransaction>> getByAllocation(int allocationId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'rent_transactions',
      where: 'allocation_id = ?',
      whereArgs: [allocationId],
      orderBy: 'billing_month DESC',
    );
    return rows.map(RentTransaction.fromMap).toList();
  }

  Future<List<RentTransaction>> getByTenant(int tenantId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'rent_transactions',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'billing_month DESC',
    );
    return rows.map(RentTransaction.fromMap).toList();
  }

  Future<List<RentTransaction>> getByRoom(int roomId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'rent_transactions',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'billing_month DESC',
    );
    return rows.map(RentTransaction.fromMap).toList();
  }

  Future<List<RentTransaction>> getByMonth(String billingMonth) async {
    final db = await _helper.database;
    final rows = await db.query(
      'rent_transactions',
      where: 'billing_month = ?',
      whereArgs: [billingMonth],
    );
    return rows.map(RentTransaction.fromMap).toList();
  }

  /// Same as [getByMonth] but joined with tenant/room names for display.
  Future<List<Map<String, Object?>>> getByMonthDetailed(String billingMonth) async {
    final db = await _helper.database;
    return db.rawQuery('''
      SELECT r.*, t.full_name as tenant_name, rm.room_number as room_number
      FROM rent_transactions r
      JOIN tenants t ON t.id = r.tenant_id
      JOIN rooms rm ON rm.id = r.room_id
      WHERE r.billing_month = ?
      ORDER BY rm.room_number ASC
    ''', [billingMonth]);
  }

  Future<List<RentTransaction>> getPending() async {
    final db = await _helper.database;
    final rows = await db.query(
      'rent_transactions',
      where: "payment_status != 'paid'",
      orderBy: 'billing_month ASC',
    );
    return rows.map(RentTransaction.fromMap).toList();
  }

  Future<bool> existsForMonth(int allocationId, String billingMonth, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final rows = await db.query(
      'rent_transactions',
      where: 'allocation_id = ? AND billing_month = ?',
      whereArgs: [allocationId, billingMonth],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> create(RentTransaction rent, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final now = todayForStorage();
    return db.insert(
      'rent_transactions',
      RentTransaction(
        tenantId: rent.tenantId,
        roomId: rent.roomId,
        allocationId: rent.allocationId,
        billingMonth: rent.billingMonth,
        fromDate: rent.fromDate,
        toDate: rent.toDate,
        rentAmount: rent.rentAmount,
        dueDate: rent.dueDate,
        paidAmount: rent.paidAmount,
        notes: rent.notes,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
  }

  Future<void> applyPayment(int rentId, double paymentAmount, String paymentDate, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final rows = await db.query('rent_transactions', where: 'id = ?', whereArgs: [rentId], limit: 1);
    if (rows.isEmpty) return;
    final rent = RentTransaction.fromMap(rows.first);
    final newPaid = rent.paidAmount + paymentAmount;
    final updated = RentTransaction(
      id: rent.id,
      tenantId: rent.tenantId,
      roomId: rent.roomId,
      allocationId: rent.allocationId,
      billingMonth: rent.billingMonth,
      fromDate: rent.fromDate,
      toDate: rent.toDate,
      rentAmount: rent.rentAmount,
      dueDate: rent.dueDate,
      paidAmount: newPaid,
      paymentDate: paymentDate,
      notes: rent.notes,
      createdAt: rent.createdAt,
      updatedAt: todayForStorage(),
    );
    await db.update('rent_transactions', updated.toMap(), where: 'id = ?', whereArgs: [rentId]);
  }

  Future<double> totalPendingForAllocation(int allocationId, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(pending_amount), 0) as total FROM rent_transactions WHERE allocation_id = ?',
      [allocationId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> totalForMonth(String billingMonth) async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(rent_amount), 0) as total FROM rent_transactions WHERE billing_month = ?',
      [billingMonth],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> totalPendingOverall() async {
    final db = await _helper.database;
    final result = await db.rawQuery("SELECT COALESCE(SUM(pending_amount), 0) as total FROM rent_transactions WHERE payment_status != 'paid'");
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }
}
