import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../utils/formatters.dart';

class BackupService {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<Directory> _backupsDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documentsDir.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies the live database to a timestamped file under app documents/backups
  /// and returns the resulting file, ready to be shared/exported by the caller.
  Future<File> createBackup() async {
    await _helper.database; // ensure it's opened/flushed
    final dbPath = await _helper.databasePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('No database found to back up yet.');
    }
    final backupsDir = await _backupsDirectory();
    final timestamp = todayForStorage().replaceAll('-', '') +
        '_' +
        DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final backupFile = File(p.join(backupsDir.path, 'rentcollection_backup_$timestamp.db'));
    return dbFile.copy(backupFile.path);
  }

  Future<List<File>> listBackups() async {
    final dir = await _backupsDirectory();
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.db'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// Restores from [backupFile]: the helper validates the file, snapshots the
  /// current database first (so a bad restore can be undone), then swaps it in.
  Future<void> restoreBackup(File backupFile) async {
    await createBackup(); // safety snapshot of current state before overwriting
    await _helper.restoreFrom(backupFile);
  }
}
