import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/tenant.dart';
import '../utils/formatters.dart';

class TenantRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<List<Tenant>> getAll({bool includeInactive = true}) async {
    final db = await _helper.database;
    final rows = await db.query(
      'tenants',
      where: includeInactive ? null : "status = 'active'",
      orderBy: 'full_name ASC',
    );
    return rows.map(Tenant.fromMap).toList();
  }

  Future<Tenant?> getById(int id) async {
    final db = await _helper.database;
    final rows = await db.query('tenants', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Tenant.fromMap(rows.first);
  }

  Future<List<Tenant>> search(String query) async {
    final db = await _helper.database;
    final like = '%$query%';
    final rows = await db.query(
      'tenants',
      where: 'full_name LIKE ? OR mobile_number LIKE ?',
      whereArgs: [like, like],
      orderBy: 'full_name ASC',
    );
    return rows.map(Tenant.fromMap).toList();
  }

  Future<int> create(Tenant tenant, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    final now = todayForStorage();
    return db.insert(
      'tenants',
      Tenant(
        fullName: tenant.fullName,
        mobileNumber: tenant.mobileNumber,
        familyMembersCount: tenant.familyMembersCount,
        familyMembersDetails: tenant.familyMembersDetails,
        joiningDate: tenant.joiningDate,
        currentRoomId: tenant.currentRoomId,
        monthlyRent: tenant.monthlyRent,
        status: tenant.status,
        notes: tenant.notes,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
  }

  Future<void> update(Tenant tenant) async {
    final db = await _helper.database;
    await db.update(
      'tenants',
      tenant.copyWith(updatedAt: todayForStorage()).toMap(),
      where: 'id = ?',
      whereArgs: [tenant.id],
    );
  }

  Future<void> setCurrentRoom(int tenantId, int? roomId, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    await db.update(
      'tenants',
      {'current_room_id': roomId, 'updated_at': todayForStorage()},
      where: 'id = ?',
      whereArgs: [tenantId],
    );
  }

  Future<void> setStatus(int tenantId, String status, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    await db.update(
      'tenants',
      {'status': status, 'updated_at': todayForStorage()},
      where: 'id = ?',
      whereArgs: [tenantId],
    );
  }

  Future<bool> hasActiveAllocation(int tenantId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'room_allocations',
      where: "tenant_id = ? AND status = 'active'",
      whereArgs: [tenantId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> countActive() async {
    final db = await _helper.database;
    final result = await db.rawQuery("SELECT COUNT(*) as count FROM tenants WHERE status = 'active'");
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
