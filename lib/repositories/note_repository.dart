import '../database/database_helper.dart';
import '../models/note.dart';
import '../utils/formatters.dart';

class NoteRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<int> create({
    required int tenantId,
    int? roomId,
    required String text,
    String? imagePath,
    String? kind,
    double? amount,
    bool isDone = false,
  }) async {
    final db = await _helper.database;
    return db.insert(
      'notes',
      Note(
        tenantId: tenantId,
        roomId: roomId,
        text: text,
        imagePath: imagePath,
        kind: kind,
        amount: amount,
        isDone: isDone,
        createdAt: nowIsoForStorage(),
      ).toMap(),
    );
  }

  Future<List<Note>> getByTenant(int tenantId) async {
    final db = await _helper.database;
    final rows = await db.query('notes', where: 'tenant_id = ?', whereArgs: [tenantId], orderBy: 'created_at ASC');
    return rows.map(Note.fromMap).toList();
  }

  Future<void> setDone(int noteId, bool isDone) async {
    final db = await _helper.database;
    await db.update('notes', {'is_done': isDone ? 1 : 0}, where: 'id = ?', whereArgs: [noteId]);
  }
}
