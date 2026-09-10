import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/room.dart';
import '../utils/formatters.dart';

class RoomRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<List<Room>> getAll({bool includeInactive = true}) async {
    final db = await _helper.database;
    final rows = await db.query(
      'rooms',
      where: includeInactive ? null : "status != 'inactive'",
      orderBy: 'room_number ASC',
    );
    return rows.map(Room.fromMap).toList();
  }

  Future<Room?> getById(int id) async {
    final db = await _helper.database;
    final rows = await db.query('rooms', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Room.fromMap(rows.first);
  }

  Future<bool> roomNumberExists(String roomNumber, {int? excludeId}) async {
    final db = await _helper.database;
    final rows = await db.query(
      'rooms',
      where: excludeId == null ? 'room_number = ?' : 'room_number = ? AND id != ?',
      whereArgs: excludeId == null ? [roomNumber] : [roomNumber, excludeId],
    );
    return rows.isNotEmpty;
  }

  Future<int> create(Room room) async {
    final db = await _helper.database;
    final now = todayForStorage();
    return db.insert('rooms', room.copyWith(createdAt: now, updatedAt: now).toMap());
  }

  Future<void> update(Room room) async {
    final db = await _helper.database;
    await db.update(
      'rooms',
      room.copyWith(updatedAt: todayForStorage()).toMap(),
      where: 'id = ?',
      whereArgs: [room.id],
    );
  }

  Future<void> updateStatus(int roomId, String status, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    await db.update(
      'rooms',
      {'status': status, 'updated_at': todayForStorage()},
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }

  Future<void> updateMeterReading(int roomId, double reading, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _helper.database;
    await db.update(
      'rooms',
      {'current_meter_reading': reading, 'updated_at': todayForStorage()},
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }

  Future<bool> hasHistory(int roomId) async {
    final db = await _helper.database;
    final allocations = await db.query('room_allocations', where: 'room_id = ?', whereArgs: [roomId], limit: 1);
    return allocations.isNotEmpty;
  }

  /// Soft-deactivate only; rooms with history are never hard-deleted.
  Future<void> deactivate(int roomId) async {
    await updateStatus(roomId, RoomStatus.inactive);
  }

  Future<int> countByStatus(String status) async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM rooms WHERE status = ?',
      [status],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
