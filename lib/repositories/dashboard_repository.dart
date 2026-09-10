import '../database/database_helper.dart';
import '../models/room.dart';
import '../utils/formatters.dart';

class DashboardSummary {
  final int totalRooms;
  final int occupiedRooms;
  final int vacantRooms;
  final int activeTenants;
  final double currentMonthRent;
  final double currentMonthElectricity;
  final double totalPending;
  final double currentMonthExpenses;
  final double netCollection;
  final int chatPendingCount;
  final double chatPendingAmount;
  final int chatDoneCount;
  final double chatDoneAmount;

  DashboardSummary({
    required this.totalRooms,
    required this.occupiedRooms,
    required this.vacantRooms,
    required this.activeTenants,
    required this.currentMonthRent,
    required this.currentMonthElectricity,
    required this.totalPending,
    required this.currentMonthExpenses,
    required this.netCollection,
    required this.chatPendingCount,
    required this.chatPendingAmount,
    required this.chatDoneCount,
    required this.chatDoneAmount,
  });
}

class RoomCardData {
  final Room room;
  final String? tenantName;
  final int? tenantId;
  final int familyMembers;
  final double monthlyRent;
  final double currentMonthElectricity;
  final double pending;
  final double currentMeterReading;

  RoomCardData({
    required this.room,
    this.tenantName,
    this.tenantId,
    this.familyMembers = 0,
    required this.monthlyRent,
    required this.currentMonthElectricity,
    required this.pending,
    required this.currentMeterReading,
  });
}

/// Read-only aggregation queries for the dashboard. Nothing here is cached or
/// hardcoded — every figure is computed from the current database state.
class DashboardRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<DashboardSummary> getSummary() async {
    final db = await _helper.database;
    final month = currentBillingMonth();

    final totalRooms = _firstInt(await db.rawQuery("SELECT COUNT(*) c FROM rooms WHERE status != 'inactive'"));
    final occupiedRooms = _firstInt(await db.rawQuery("SELECT COUNT(*) c FROM rooms WHERE status = 'occupied'"));
    final vacantRooms = _firstInt(await db.rawQuery("SELECT COUNT(*) c FROM rooms WHERE status = 'vacant'"));
    final activeTenants = _firstInt(await db.rawQuery("SELECT COUNT(*) c FROM tenants WHERE status = 'active'"));

    final currentMonthRent = _firstDouble(await db.rawQuery(
      'SELECT COALESCE(SUM(rent_amount),0) t FROM rent_transactions WHERE billing_month = ?',
      [month],
    ));
    final currentMonthElectricity = _firstDouble(await db.rawQuery(
      "SELECT COALESCE(SUM(bill_amount),0) t FROM electricity_bills WHERE to_date LIKE ?",
      ['$month%'],
    ));
    final pendingRent = _firstDouble(await db.rawQuery(
      "SELECT COALESCE(SUM(pending_amount),0) t FROM rent_transactions WHERE payment_status != 'paid'",
    ));
    final pendingElectricity = _firstDouble(await db.rawQuery(
      "SELECT COALESCE(SUM(pending_amount),0) t FROM electricity_bills WHERE payment_status != 'paid'",
    ));
    final currentMonthExpenses = _firstDouble(await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) t FROM expenses WHERE expense_date LIKE ?',
      ['$month%'],
    ));
    final currentMonthCollection = _firstDouble(await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) t FROM payments WHERE payment_date LIKE ? AND payment_type IN (?, ?)',
      ['$month%', 'rent', 'electricity'],
    ));

    final chatPendingRow = (await db.rawQuery(
      "SELECT COUNT(*) c, COALESCE(SUM(amount),0) t FROM notes WHERE kind IS NOT NULL AND is_done = 0",
    )).first;
    final chatDoneRow = (await db.rawQuery(
      "SELECT COUNT(*) c, COALESCE(SUM(amount),0) t FROM notes WHERE kind IS NOT NULL AND is_done = 1",
    )).first;

    return DashboardSummary(
      totalRooms: totalRooms,
      occupiedRooms: occupiedRooms,
      vacantRooms: vacantRooms,
      activeTenants: activeTenants,
      currentMonthRent: currentMonthRent,
      currentMonthElectricity: currentMonthElectricity,
      totalPending: pendingRent + pendingElectricity,
      currentMonthExpenses: currentMonthExpenses,
      netCollection: currentMonthCollection - currentMonthExpenses,
      chatPendingCount: (chatPendingRow['c'] as int?) ?? 0,
      chatPendingAmount: (chatPendingRow['t'] as num?)?.toDouble() ?? 0,
      chatDoneCount: (chatDoneRow['c'] as int?) ?? 0,
      chatDoneAmount: (chatDoneRow['t'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<RoomCardData>> getRoomCards() async {
    final db = await _helper.database;
    final rooms = (await db.query('rooms', where: "status != 'inactive'", orderBy: 'room_number ASC'))
        .map(Room.fromMap)
        .toList();

    final cards = <RoomCardData>[];
    for (final room in rooms) {
      if (room.status == RoomStatus.vacant) {
        cards.add(RoomCardData(
          room: room,
          monthlyRent: room.monthlyRent,
          currentMonthElectricity: 0,
          pending: 0,
          currentMeterReading: room.currentMeterReading,
        ));
        continue;
      }

      final allocationRows = await db.query(
        'room_allocations',
        where: "room_id = ? AND status = 'active'",
        whereArgs: [room.id],
        limit: 1,
      );
      if (allocationRows.isEmpty) {
        cards.add(RoomCardData(
          room: room,
          monthlyRent: room.monthlyRent,
          currentMonthElectricity: 0,
          pending: 0,
          currentMeterReading: room.currentMeterReading,
        ));
        continue;
      }
      final allocation = allocationRows.first;
      final allocationId = allocation['id'] as int;
      final tenantId = allocation['tenant_id'] as int;

      final tenantRows = await db.query('tenants', where: 'id = ?', whereArgs: [tenantId], limit: 1);
      final tenant = tenantRows.isNotEmpty ? tenantRows.first : null;

      final month = currentBillingMonth();
      final electricityThisMonth = _firstDouble(await db.rawQuery(
        "SELECT COALESCE(SUM(bill_amount),0) t FROM electricity_bills WHERE allocation_id = ? AND to_date LIKE ?",
        [allocationId, '$month%'],
      ));
      final pendingRent = _firstDouble(await db.rawQuery(
        'SELECT COALESCE(SUM(pending_amount),0) t FROM rent_transactions WHERE allocation_id = ?',
        [allocationId],
      ));
      final pendingElectricity = _firstDouble(await db.rawQuery(
        'SELECT COALESCE(SUM(pending_amount),0) t FROM electricity_bills WHERE allocation_id = ?',
        [allocationId],
      ));

      cards.add(RoomCardData(
        room: room,
        tenantId: tenantId,
        tenantName: tenant?['full_name'] as String?,
        familyMembers: (tenant?['family_members_count'] as int?) ?? 0,
        monthlyRent: (allocation['monthly_rent'] as num).toDouble(),
        currentMonthElectricity: electricityThisMonth,
        pending: pendingRent + pendingElectricity,
        currentMeterReading: room.currentMeterReading,
      ));
    }
    return cards;
  }

  int _firstInt(List<Map<String, Object?>> rows) => (rows.first['c'] as int?) ?? 0;
  double _firstDouble(List<Map<String, Object?>> rows) => (rows.first['t'] as num?)?.toDouble() ?? 0;
}
