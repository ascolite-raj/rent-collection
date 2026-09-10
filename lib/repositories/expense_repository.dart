import '../database/database_helper.dart';
import '../models/expense.dart';
import '../utils/formatters.dart';

class ExpenseRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<int> create(Expense expense) async {
    final db = await _helper.database;
    return db.insert(
      'expenses',
      Expense(
        roomId: expense.roomId,
        category: expense.category,
        expenseDate: expense.expenseDate,
        amount: expense.amount,
        description: expense.description,
        notes: expense.notes,
        createdAt: todayForStorage(),
      ).toMap(),
    );
  }

  Future<void> update(Expense expense) async {
    final db = await _helper.database;
    await db.update('expenses', expense.toMap(), where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<void> delete(int id) async {
    final db = await _helper.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Expense>> filter({
    int? roomId,
    String? category,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _helper.database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (roomId != null) {
      conditions.add('room_id = ?');
      args.add(roomId);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (fromDate != null) {
      conditions.add('expense_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add('expense_date <= ?');
      args.add(toDate);
    }
    final rows = await db.query(
      'expenses',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'expense_date DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<double> totalForMonth(String billingMonthPrefix) async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE expense_date LIKE ?",
      ['$billingMonthPrefix%'],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }
}
