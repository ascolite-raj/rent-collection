import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Central access point for the SQLite database. One instance, lazily opened.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String dbFileName = 'rentcollection.db';
  static const int dbVersion = 4;

  Database? _database;

  Future<Database> get database async {
    _database ??= await _open();
    return _database!;
  }

  Future<String> databasePath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    return join(documentsDir.path, dbFileName);
  }

  Future<Database> _open() async {
    final path = await databasePath();
    return openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_number TEXT NOT NULL UNIQUE,
        description TEXT,
        monthly_rent REAL NOT NULL DEFAULT 0,
        meter_number TEXT,
        current_meter_reading REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'vacant',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tenants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        mobile_number TEXT,
        family_members_count INTEGER NOT NULL DEFAULT 1,
        family_members_details TEXT,
        joining_date TEXT NOT NULL,
        current_room_id INTEGER REFERENCES rooms(id) ON DELETE SET NULL,
        monthly_rent REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE room_allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL REFERENCES rooms(id) ON DELETE RESTRICT,
        tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
        joining_date TEXT NOT NULL,
        leaving_date TEXT,
        monthly_rent REAL NOT NULL,
        initial_meter_reading REAL NOT NULL,
        final_meter_reading REAL,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE deposits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
        room_id INTEGER NOT NULL REFERENCES rooms(id) ON DELETE RESTRICT,
        allocation_id INTEGER NOT NULL REFERENCES room_allocations(id) ON DELETE RESTRICT,
        deposit_amount REAL NOT NULL DEFAULT 0,
        deposit_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'held',
        refund_amount REAL NOT NULL DEFAULT 0,
        adjustment_amount REAL NOT NULL DEFAULT 0,
        refund_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE rent_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
        room_id INTEGER NOT NULL REFERENCES rooms(id) ON DELETE RESTRICT,
        allocation_id INTEGER NOT NULL REFERENCES room_allocations(id) ON DELETE RESTRICT,
        billing_month TEXT NOT NULL,
        from_date TEXT NOT NULL,
        to_date TEXT NOT NULL,
        rent_amount REAL NOT NULL,
        due_date TEXT,
        paid_amount REAL NOT NULL DEFAULT 0,
        pending_amount REAL NOT NULL DEFAULT 0,
        payment_date TEXT,
        payment_status TEXT NOT NULL DEFAULT 'pending',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(allocation_id, billing_month)
      )
    ''');

    await db.execute('''
      CREATE TABLE meter_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL REFERENCES rooms(id) ON DELETE RESTRICT,
        tenant_id INTEGER REFERENCES tenants(id) ON DELETE SET NULL,
        allocation_id INTEGER REFERENCES room_allocations(id) ON DELETE SET NULL,
        reading_date TEXT NOT NULL,
        meter_reading REAL NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE electricity_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL REFERENCES rooms(id) ON DELETE RESTRICT,
        tenant_id INTEGER REFERENCES tenants(id) ON DELETE SET NULL,
        allocation_id INTEGER REFERENCES room_allocations(id) ON DELETE SET NULL,
        from_date TEXT NOT NULL,
        to_date TEXT NOT NULL,
        previous_reading REAL NOT NULL,
        current_reading REAL NOT NULL,
        total_units REAL NOT NULL,
        rate_per_unit REAL NOT NULL,
        bill_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0,
        pending_amount REAL NOT NULL DEFAULT 0,
        payment_status TEXT NOT NULL DEFAULT 'pending',
        payment_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenant_id INTEGER REFERENCES tenants(id) ON DELETE SET NULL,
        room_id INTEGER REFERENCES rooms(id) ON DELETE SET NULL,
        payment_type TEXT NOT NULL,
        reference_id INTEGER,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER REFERENCES rooms(id) ON DELETE SET NULL,
        category TEXT NOT NULL,
        expense_date TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settlements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        allocation_id INTEGER NOT NULL REFERENCES room_allocations(id) ON DELETE RESTRICT,
        tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
        room_id INTEGER NOT NULL REFERENCES rooms(id) ON DELETE RESTRICT,
        leaving_date TEXT NOT NULL,
        final_meter_reading REAL NOT NULL,
        pending_rent REAL NOT NULL DEFAULT 0,
        pending_electricity REAL NOT NULL DEFAULT 0,
        other_pending REAL NOT NULL DEFAULT 0,
        deposit_amount REAL NOT NULL DEFAULT 0,
        deposit_adjustment REAL NOT NULL DEFAULT 0,
        final_refund REAL NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
        room_id INTEGER REFERENCES rooms(id) ON DELETE SET NULL,
        text TEXT NOT NULL,
        image_path TEXT,
        kind TEXT,
        amount REAL,
        is_done INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.insert('settings', {'key': 'electricity_rate_per_unit', 'value': '10'});
    await db.insert('settings', {'key': 'rent_due_day', 'value': '5'});

    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX idx_tenants_current_room ON tenants(current_room_id)');
    await db.execute('CREATE INDEX idx_allocations_room ON room_allocations(room_id)');
    await db.execute('CREATE INDEX idx_allocations_tenant ON room_allocations(tenant_id)');
    await db.execute('CREATE INDEX idx_allocations_status ON room_allocations(status)');
    await db.execute('CREATE INDEX idx_deposits_allocation ON deposits(allocation_id)');
    await db.execute('CREATE INDEX idx_rent_allocation ON rent_transactions(allocation_id)');
    await db.execute('CREATE INDEX idx_rent_month ON rent_transactions(billing_month)');
    await db.execute('CREATE INDEX idx_rent_status ON rent_transactions(payment_status)');
    await db.execute('CREATE INDEX idx_meter_room ON meter_readings(room_id)');
    await db.execute('CREATE INDEX idx_meter_allocation ON meter_readings(allocation_id)');
    await db.execute('CREATE INDEX idx_bills_allocation ON electricity_bills(allocation_id)');
    await db.execute('CREATE INDEX idx_bills_room ON electricity_bills(room_id)');
    await db.execute('CREATE INDEX idx_payments_tenant ON payments(tenant_id)');
    await db.execute('CREATE INDEX idx_payments_room ON payments(room_id)');
    await db.execute('CREATE INDEX idx_payments_type ON payments(payment_type)');
    await db.execute('CREATE INDEX idx_payments_date ON payments(payment_date)');
    await db.execute('CREATE INDEX idx_expenses_room ON expenses(room_id)');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(expense_date)');
    await db.execute('CREATE INDEX idx_expenses_category ON expenses(category)');
    await db.execute('CREATE INDEX idx_notes_tenant ON notes(tenant_id)');
  }

  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
          room_id INTEGER REFERENCES rooms(id) ON DELETE SET NULL,
          text TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX idx_notes_tenant ON notes(tenant_id)');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE notes ADD COLUMN image_path TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE notes ADD COLUMN kind TEXT');
      await db.execute('ALTER TABLE notes ADD COLUMN amount REAL');
      await db.execute('ALTER TABLE notes ADD COLUMN is_done INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double> getElectricityRate() async {
    final value = await getSetting('electricity_rate_per_unit');
    return double.tryParse(value ?? '10') ?? 10;
  }

  /// Closes the current connection. Used before restoring a backup file.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Replaces the live database file with [backupFile], validating it first.
  Future<void> restoreFrom(File backupFile) async {
    await _validateBackup(backupFile);
    await close();
    final targetPath = await databasePath();
    await backupFile.copy(targetPath);
    _database = await _open();
  }

  Future<void> _validateBackup(File backupFile) async {
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found');
    }
    Database? testDb;
    try {
      testDb = await openDatabase(backupFile.path, readOnly: true);
      final tables = await testDb.query(
        'sqlite_master',
        where: "type = 'table' AND name = ?",
        whereArgs: ['rooms'],
      );
      if (tables.isEmpty) {
        throw Exception('Selected file is not a valid backup of this app');
      }
    } finally {
      await testDb?.close();
    }
  }
}
