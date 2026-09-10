import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/electricity_bill.dart';
import '../models/meter_reading.dart';
import '../utils/formatters.dart';

class ElectricityRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<List<MeterReading>> getReadingsByRoom(int roomId) async {
    final db = await _helper.database;
    final rows = await db.query('meter_readings', where: 'room_id = ?', whereArgs: [roomId], orderBy: 'reading_date DESC');
    return rows.map(MeterReading.fromMap).toList();
  }

  Future<MeterReading?> getLastReadingForAllocation(int allocationId, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final rows = await db.query(
      'meter_readings',
      where: 'allocation_id = ?',
      whereArgs: [allocationId],
      orderBy: 'reading_date DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeterReading.fromMap(rows.first);
  }

  Future<int> insertReading(MeterReading reading, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    return db.insert(
      'meter_readings',
      MeterReading(
        roomId: reading.roomId,
        tenantId: reading.tenantId,
        allocationId: reading.allocationId,
        readingDate: reading.readingDate,
        meterReading: reading.meterReading,
        notes: reading.notes,
        createdAt: todayForStorage(),
      ).toMap(),
    );
  }

  Future<List<ElectricityBill>> getBillsByAllocation(int allocationId) async {
    final db = await _helper.database;
    final rows = await db.query('electricity_bills', where: 'allocation_id = ?', whereArgs: [allocationId], orderBy: 'to_date DESC');
    return rows.map(ElectricityBill.fromMap).toList();
  }

  Future<List<ElectricityBill>> getBillsByRoom(int roomId) async {
    final db = await _helper.database;
    final rows = await db.query('electricity_bills', where: 'room_id = ?', whereArgs: [roomId], orderBy: 'to_date DESC');
    return rows.map(ElectricityBill.fromMap).toList();
  }

  Future<List<ElectricityBill>> getByTenant(int tenantId) async {
    final db = await _helper.database;
    final rows = await db.query('electricity_bills', where: 'tenant_id = ?', whereArgs: [tenantId], orderBy: 'to_date DESC');
    return rows.map(ElectricityBill.fromMap).toList();
  }

  Future<List<ElectricityBill>> getPending() async {
    final db = await _helper.database;
    final rows = await db.query('electricity_bills', where: "payment_status != 'paid'", orderBy: 'to_date ASC');
    return rows.map(ElectricityBill.fromMap).toList();
  }

  Future<int> insertBill(ElectricityBill bill, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final now = todayForStorage();
    return db.insert(
      'electricity_bills',
      ElectricityBill(
        roomId: bill.roomId,
        tenantId: bill.tenantId,
        allocationId: bill.allocationId,
        fromDate: bill.fromDate,
        toDate: bill.toDate,
        previousReading: bill.previousReading,
        currentReading: bill.currentReading,
        totalUnits: bill.totalUnits,
        ratePerUnit: bill.ratePerUnit,
        billAmount: bill.billAmount,
        paidAmount: bill.paidAmount,
        pendingAmount: bill.pendingAmount,
        paymentStatus: bill.paymentStatus,
        notes: bill.notes,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
  }

  Future<void> applyPayment(int billId, double paymentAmount, String paymentDate, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final rows = await db.query('electricity_bills', where: 'id = ?', whereArgs: [billId], limit: 1);
    if (rows.isEmpty) return;
    final bill = ElectricityBill.fromMap(rows.first);
    final newPaid = bill.paidAmount + paymentAmount;
    final updated = ElectricityBill.calculate(
      id: bill.id,
      roomId: bill.roomId,
      tenantId: bill.tenantId,
      allocationId: bill.allocationId,
      fromDate: bill.fromDate,
      toDate: bill.toDate,
      previousReading: bill.previousReading,
      currentReading: bill.currentReading,
      ratePerUnit: bill.ratePerUnit,
      paidAmount: newPaid,
      paymentDate: paymentDate,
      notes: bill.notes,
      createdAt: bill.createdAt,
      updatedAt: todayForStorage(),
    );
    await db.update('electricity_bills', updated.toMap(), where: 'id = ?', whereArgs: [billId]);
  }

  Future<double> totalPendingForAllocation(int allocationId, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(pending_amount), 0) as total FROM electricity_bills WHERE allocation_id = ?',
      [allocationId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> totalForMonth(String billingMonthPrefix) async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(bill_amount), 0) as total FROM electricity_bills WHERE to_date LIKE ?",
      ['$billingMonthPrefix%'],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> totalPendingOverall() async {
    final db = await _helper.database;
    final result = await db.rawQuery("SELECT COALESCE(SUM(pending_amount), 0) as total FROM electricity_bills WHERE payment_status != 'paid'");
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }
}
