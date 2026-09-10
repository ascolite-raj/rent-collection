import '../database/database_helper.dart';

class RoomMonthlyLine {
  final String roomNumber;
  final double rent;
  final double electricity;
  RoomMonthlyLine({required this.roomNumber, required this.rent, required this.electricity});
  double get total => rent + electricity;
}

class MonthlyReport {
  final String billingMonth;
  final List<RoomMonthlyLine> lines;
  final double totalExpenses;

  MonthlyReport({required this.billingMonth, required this.lines, required this.totalExpenses});

  double get totalRent => lines.fold(0, (sum, l) => sum + l.rent);
  double get totalElectricity => lines.fold(0, (sum, l) => sum + l.electricity);
  double get totalCollection => totalRent + totalElectricity;
  double get netCollection => totalCollection - totalExpenses;
}

/// Backing queries for the Reports module. Every report reads directly from the
/// transaction tables so historical months are always reproducible.
class ReportRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<MonthlyReport> getMonthlyReport(String billingMonth) async {
    final db = await _helper.database;
    final rooms = await db.query('rooms', where: "status != 'inactive'", orderBy: 'room_number ASC');

    final lines = <RoomMonthlyLine>[];
    for (final room in rooms) {
      final roomId = room['id'] as int;
      final rentRows = await db.rawQuery(
        'SELECT COALESCE(SUM(rent_amount),0) t FROM rent_transactions WHERE room_id = ? AND billing_month = ?',
        [roomId, billingMonth],
      );
      final elecRows = await db.rawQuery(
        "SELECT COALESCE(SUM(bill_amount),0) t FROM electricity_bills WHERE room_id = ? AND to_date LIKE ?",
        [roomId, '$billingMonth%'],
      );
      final rent = (rentRows.first['t'] as num).toDouble();
      final electricity = (elecRows.first['t'] as num).toDouble();
      lines.add(RoomMonthlyLine(roomNumber: room['room_number'] as String, rent: rent, electricity: electricity));
    }

    final expenseRows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) t FROM expenses WHERE expense_date LIKE ?',
      ['$billingMonth%'],
    );
    final totalExpenses = (expenseRows.first['t'] as num).toDouble();

    return MonthlyReport(billingMonth: billingMonth, lines: lines, totalExpenses: totalExpenses);
  }

  Future<List<Map<String, Object?>>> getRentReport({String? fromDate, String? toDate}) async {
    final db = await _helper.database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (fromDate != null) {
      conditions.add('r.from_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add('r.to_date <= ?');
      args.add(toDate);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return db.rawQuery('''
      SELECT r.*, t.full_name as tenant_name, rm.room_number as room_number
      FROM rent_transactions r
      JOIN tenants t ON t.id = r.tenant_id
      JOIN rooms rm ON rm.id = r.room_id
      $where
      ORDER BY r.billing_month DESC
    ''', args);
  }

  Future<List<Map<String, Object?>>> getElectricityReport({String? fromDate, String? toDate}) async {
    final db = await _helper.database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (fromDate != null) {
      conditions.add('e.from_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add('e.to_date <= ?');
      args.add(toDate);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return db.rawQuery('''
      SELECT e.*, t.full_name as tenant_name, rm.room_number as room_number
      FROM electricity_bills e
      LEFT JOIN tenants t ON t.id = e.tenant_id
      JOIN rooms rm ON rm.id = e.room_id
      $where
      ORDER BY e.to_date DESC
    ''', args);
  }

  Future<List<Map<String, Object?>>> getPendingPaymentsReport() async {
    final db = await _helper.database;
    final rentPending = await db.rawQuery('''
      SELECT 'Rent' as type, r.billing_month as period, t.full_name as tenant_name,
             rm.room_number as room_number, r.pending_amount as pending
      FROM rent_transactions r
      JOIN tenants t ON t.id = r.tenant_id
      JOIN rooms rm ON rm.id = r.room_id
      WHERE r.payment_status != 'paid'
    ''');
    final elecPending = await db.rawQuery('''
      SELECT 'Electricity' as type, e.to_date as period, t.full_name as tenant_name,
             rm.room_number as room_number, e.pending_amount as pending
      FROM electricity_bills e
      LEFT JOIN tenants t ON t.id = e.tenant_id
      JOIN rooms rm ON rm.id = e.room_id
      WHERE e.payment_status != 'paid'
    ''');
    return [...rentPending, ...elecPending];
  }

  Future<List<Map<String, Object?>>> getDepositReport() async {
    final db = await _helper.database;
    return db.rawQuery('''
      SELECT d.*, t.full_name as tenant_name, rm.room_number as room_number
      FROM deposits d
      JOIN tenants t ON t.id = d.tenant_id
      JOIN rooms rm ON rm.id = d.room_id
      ORDER BY d.deposit_date DESC
    ''');
  }

  Future<List<Map<String, Object?>>> getRoomHistoryReport(int roomId) async {
    final db = await _helper.database;
    return db.rawQuery('''
      SELECT a.*, t.full_name as tenant_name
      FROM room_allocations a
      JOIN tenants t ON t.id = a.tenant_id
      WHERE a.room_id = ?
      ORDER BY a.joining_date DESC
    ''', [roomId]);
  }

  Future<List<Map<String, Object?>>> getExpenseReport({int? roomId, String? category, String? fromDate, String? toDate}) async {
    final db = await _helper.database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (roomId != null) {
      conditions.add('e.room_id = ?');
      args.add(roomId);
    }
    if (category != null) {
      conditions.add('e.category = ?');
      args.add(category);
    }
    if (fromDate != null) {
      conditions.add('e.expense_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add('e.expense_date <= ?');
      args.add(toDate);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return db.rawQuery('''
      SELECT e.*, rm.room_number as room_number
      FROM expenses e
      LEFT JOIN rooms rm ON rm.id = e.room_id
      $where
      ORDER BY e.expense_date DESC
    ''', args);
  }

  Future<List<Map<String, Object?>>> getSettlementReport() async {
    final db = await _helper.database;
    return db.rawQuery('''
      SELECT s.*, t.full_name as tenant_name, rm.room_number as room_number
      FROM settlements s
      JOIN tenants t ON t.id = s.tenant_id
      JOIN rooms rm ON rm.id = s.room_id
      ORDER BY s.leaving_date DESC
    ''');
  }
}
