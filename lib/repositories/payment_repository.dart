import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/payment.dart';
import '../utils/formatters.dart';

class PaymentRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<int> create(Payment payment, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    return db.insert(
      'payments',
      Payment(
        tenantId: payment.tenantId,
        roomId: payment.roomId,
        paymentType: payment.paymentType,
        referenceId: payment.referenceId,
        amount: payment.amount,
        paymentDate: payment.paymentDate,
        paymentMethod: payment.paymentMethod,
        notes: payment.notes,
        createdAt: todayForStorage(),
      ).toMap(),
    );
  }

  Future<List<Payment>> getAll({int? limit}) async {
    final db = await _helper.database;
    final rows = await db.query('payments', orderBy: 'payment_date DESC, id DESC', limit: limit);
    return rows.map(Payment.fromMap).toList();
  }

  Future<List<Payment>> getByTenant(int tenantId) async {
    final db = await _helper.database;
    final rows = await db.query('payments', where: 'tenant_id = ?', whereArgs: [tenantId], orderBy: 'payment_date DESC');
    return rows.map(Payment.fromMap).toList();
  }

  Future<List<Payment>> getByRoom(int roomId) async {
    final db = await _helper.database;
    final rows = await db.query('payments', where: 'room_id = ?', whereArgs: [roomId], orderBy: 'payment_date DESC');
    return rows.map(Payment.fromMap).toList();
  }

  Future<List<Payment>> filter({
    String? fromDate,
    String? toDate,
    String? paymentType,
    int? roomId,
    int? tenantId,
  }) async {
    final db = await _helper.database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (fromDate != null) {
      conditions.add('payment_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add('payment_date <= ?');
      args.add(toDate);
    }
    if (paymentType != null) {
      conditions.add('payment_type = ?');
      args.add(paymentType);
    }
    if (roomId != null) {
      conditions.add('room_id = ?');
      args.add(roomId);
    }
    if (tenantId != null) {
      conditions.add('tenant_id = ?');
      args.add(tenantId);
    }
    final rows = await db.query(
      'payments',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'payment_date DESC, id DESC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  Future<double> totalForMonth(String billingMonthPrefix, {String? paymentType}) async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      paymentType == null
          ? "SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE payment_date LIKE ?"
          : "SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE payment_date LIKE ? AND payment_type = ?",
      paymentType == null ? ['$billingMonthPrefix%'] : ['$billingMonthPrefix%', paymentType],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }
}
