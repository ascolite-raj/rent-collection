import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';

/// Exports SQLite tables to CSV files under app documents/exports.
class CsvService {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  static const _tables = [
    'rooms',
    'tenants',
    'room_allocations',
    'deposits',
    'rent_transactions',
    'meter_readings',
    'electricity_bills',
    'payments',
    'expenses',
    'settlements',
  ];

  Future<Directory> _exportsDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documentsDir.path, 'exports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> exportRowsToCsv(String fileName, List<String> headers, List<List<dynamic>> rows) async {
    final dir = await _exportsDirectory();
    final csv = const ListToCsvConverter().convert([headers, ...rows]);
    final file = File(p.join(dir.path, fileName));
    return file.writeAsString(csv);
  }

  /// Exports every data table to its own CSV file. Returns the created files.
  Future<List<File>> exportAllData() async {
    final db = await _helper.database;
    final files = <File>[];
    for (final table in _tables) {
      final rows = await db.query(table);
      if (rows.isEmpty) {
        files.add(await exportRowsToCsv('$table.csv', ['(no data)'], []));
        continue;
      }
      final headers = rows.first.keys.toList();
      final dataRows = rows.map((r) => headers.map((h) => r[h]).toList()).toList();
      files.add(await exportRowsToCsv('$table.csv', headers, dataRows));
    }
    return files;
  }

  Future<File> exportQueryResult(String fileName, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) {
      return exportRowsToCsv(fileName, ['(no data)'], []);
    }
    final headers = rows.first.keys.toList();
    final dataRows = rows.map((r) => headers.map((h) => r[h]).toList()).toList();
    return exportRowsToCsv(fileName, headers, dataRows);
  }
}
