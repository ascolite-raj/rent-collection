import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/deposit.dart';
import '../utils/formatters.dart';

class DepositRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<int> create(Deposit deposit, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final now = todayForStorage();
    return db.insert(
      'deposits',
      Deposit(
        tenantId: deposit.tenantId,
        roomId: deposit.roomId,
        allocationId: deposit.allocationId,
        depositAmount: deposit.depositAmount,
        depositDate: deposit.depositDate,
        status: deposit.status,
        notes: deposit.notes,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
  }

  Future<Deposit?> getByAllocation(int allocationId, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final rows = await db.query('deposits', where: 'allocation_id = ?', whereArgs: [allocationId], limit: 1);
    if (rows.isEmpty) return null;
    return Deposit.fromMap(rows.first);
  }

  Future<List<Deposit>> getByTenant(int tenantId) async {
    final db = await _helper.database;
    final rows = await db.query('deposits', where: 'tenant_id = ?', whereArgs: [tenantId], orderBy: 'deposit_date DESC');
    return rows.map(Deposit.fromMap).toList();
  }

  Future<List<Deposit>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query('deposits', orderBy: 'deposit_date DESC');
    return rows.map(Deposit.fromMap).toList();
  }

  Future<void> settleRefund({
    required int depositId,
    required double refundAmount,
    required double adjustmentAmount,
    required String refundDate,
    required String status,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _helper.database;
    await db.update(
      'deposits',
      {
        'status': status,
        'refund_amount': refundAmount,
        'adjustment_amount': adjustmentAmount,
        'refund_date': refundDate,
        'updated_at': todayForStorage(),
      },
      where: 'id = ?',
      whereArgs: [depositId],
    );
  }

  Future<double> totalHeldAmount() async {
    final db = await _helper.database;
    final result = await db.rawQuery("SELECT COALESCE(SUM(deposit_amount - refund_amount), 0) as total FROM deposits WHERE status != 'refunded'");
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }
}
