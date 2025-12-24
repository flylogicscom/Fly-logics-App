// lib/utils/db_helper.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'country_data.dart';
import 'package:fly_logicd_logbook_app/common/taglist_page.dart';

class DBHelper {
  DBHelper._();
  static Database? _db;

  static const String _dbName = 'app.db';
  // Subido a 7 para agregar/migrar columna toFlagEmoji en flights
  static const int _dbVersion = 7;

  static const String tableTagList = 'taglist';
  static const String tableCountries = 'countries';
  static const String tablePilot = 'pilot';
  static const String tableNotes = 'notes';

  // NUEVO
  static const String tableFlights = 'flights';

  static const String tableExpenseSheets = 'expense_sheets';
  static const String tableExpenseCharges = 'expense_charges';
  static const String tableExpenseFxRates = 'expense_fx_rates';

  static String? databasePath;

  // ================== OPEN / CLOSE ==================

  static Future<Database> getDB() async {
    if (_db != null) return _db!;

    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    databasePath = path;

    try {
      _db = await openDatabase(
        path,
        version: _dbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (_) {
      // DB dañada: borrar y recrear
      await deleteDB();
      _db = await openDatabase(
        path,
        version: _dbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
      );
    }

    await _ensureCoreTablesExist(_db!);
    return _db!;
  }

  static Future<String> dbPath() async {
    if (databasePath != null) return databasePath!;
    final dir = await getDatabasesPath();
    databasePath = p.join(dir, _dbName);
    return databasePath!;
  }

  static Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _db = null;
  }

  // Para exportación consistente (NO TOCAR: mantiene WAL + checkpoint)
  static Future<void> checkpointAndCloseForExport() async {
    final db = await getDB();
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
    await close();
  }

  // Borrado físico
  static Future<void> deleteDB() async {
    final path = await dbPath();
    try {
      final file = File(path);
      final wal = File('$path-wal');
      final shm = File('$path-shm');
      if (await file.exists()) await file.delete();
      if (await wal.exists()) await wal.delete();
      if (await shm.exists()) await shm.delete();
    } catch (_) {}
    _db = null;
  }

  // ================== CONFIG ==================

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.rawQuery('PRAGMA journal_mode = WAL');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createSchemaV3(db);
    await _createExpensesTables(db);

    // flights
    await _createFlightsTable(db);

    await _seedInitialData(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createSchemaV2(db);

      final hasPilots = await _tableExists(db, 'pilots');
      final hasPilot = await _tableExists(db, tablePilot);
      if (hasPilots && !hasPilot) {
        await db.execute('ALTER TABLE pilots RENAME TO $tablePilot');
      }

      await _createIndexes(db);
    }

    if (oldVersion < 3) {
      final cols = await _columnsOf(db, tablePilot);
      if (!cols.contains('authUid')) {
        await db.execute('ALTER TABLE $tablePilot ADD COLUMN authUid TEXT');
      }
      if (!cols.contains('email')) {
        await db.execute('ALTER TABLE $tablePilot ADD COLUMN email TEXT');
      }
      if (!cols.contains('displayName')) {
        await db.execute('ALTER TABLE $tablePilot ADD COLUMN displayName TEXT');
      }
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_pilot_authUid ON $tablePilot(authUid)',
      );
    }

    if (oldVersion < 4) {
      await _createExpensesTables(db);
    }

    if (oldVersion < 5) {
      // Nuevas columnas de pilot
      final pilotCols = await _columnsOf(db, tablePilot);
      Future<void> addPilotCol(String name, String type) async {
        if (!pilotCols.contains(name)) {
          await db.execute('ALTER TABLE $tablePilot ADD COLUMN $name $type');
        }
      }

      await addPilotCol('city', 'TEXT');
      await addPilotCol('street', 'TEXT');
      await addPilotCol('idNumber', 'TEXT');
      await addPilotCol('airline', 'TEXT');
      await addPilotCol('employeeNumber', 'TEXT');
      await addPilotCol('phoneFlag', 'TEXT');
      await addPilotCol('photoPath', 'TEXT');

      // Columna ibanSwift en expense_sheets
      final expCols = await _columnsOf(db, tableExpenseSheets);
      if (!expCols.contains('ibanSwift')) {
        try {
          await db.execute(
            'ALTER TABLE $tableExpenseSheets ADD COLUMN ibanSwift TEXT',
          );
        } catch (_) {}
      }

      // Asegurar columnas extendidas en countries
      final countryCols = await _columnsOf(db, tableCountries);
      Future<void> addCountryCol(String name, String type) async {
        if (!countryCols.contains(name)) {
          await db.execute(
            'ALTER TABLE $tableCountries ADD COLUMN $name $type',
          );
        }
      }

      await addCountryCol('registration', 'TEXT');
      await addCountryCol('localCurrency', 'TEXT');
      await addCountryCol('currencyName', 'TEXT');
      await addCountryCol('currencyFlagEmoji', 'TEXT');
    }

    // flights (v6+) y asegurar columnas (incluye toFlagEmoji en v7)
    await _createFlightsTable(db);
    await _ensureFlightsColumns(db);

    await _createIndexes(db);
  }

  static Future<void> _ensureCoreTablesExist(Database db) async {
    // Tablas base
    final requiredBase = [
      tableCountries,
      tableTagList,
      tablePilot,
      tableNotes,
    ];

    var needSeed = false;
    for (final t in requiredBase) {
      final exists = await _tableExists(db, t);
      if (!exists) {
        needSeed = true;
        break;
      }
    }

    if (needSeed) {
      await _createSchemaV3(db);
      await _createExpensesTables(db);
      await _createFlightsTable(db);
      await _seedInitialData(db);
    }

    // Asegura tablas de expenses
    final hasSheets = await _tableExists(db, tableExpenseSheets);
    if (!hasSheets) {
      await _createExpensesTables(db);
    }

    // Asegura flights sin forzar reseed
    await _createFlightsTable(db);
    await _ensureFlightsColumns(db);
  }

  static Future<bool> _tableExists(Database db, String table) async {
    final res = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return res.isNotEmpty;
  }

  static Future<Set<String>> _columnsOf(Database db, String table) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.map((r) => r['name'] as String).toSet();
  }

  // ================== SCHEMAS ==================

  static Future<void> _createSchemaV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTagList(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT,
        title TEXT,
        explanation TEXT,
        labelColor INTEGER,
        isUserCreated INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCountries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        flagEmoji TEXT,
        phoneCode TEXT,
        icaoPrefixes TEXT,
        registration TEXT,
        localCurrency TEXT,
        currencyName TEXT,
        currencyFlagEmoji TEXT,
        authorityOfficialName TEXT,
        authorityAcronym TEXT
      )
    ''');

    await _createPilotTableV2(db);
    await _createNotesTable(db);
    await _createIndexes(db);
  }

  static Future<void> _createSchemaV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTagList(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT,
        title TEXT,
        explanation TEXT,
        labelColor INTEGER,
        isUserCreated INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCountries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        flagEmoji TEXT,
        phoneCode TEXT,
        icaoPrefixes TEXT,
        registration TEXT,
        localCurrency TEXT,
        currencyName TEXT,
        currencyFlagEmoji TEXT,
        authorityOfficialName TEXT,
        authorityAcronym TEXT
      )
    ''');

    // Incluye columnas extendidas desde el inicio en V3
    await _createPilotTableV3(db);
    await _createNotesTable(db);
    await _createIndexes(db);

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_pilot_authUid ON $tablePilot(authUid)',
    );
  }

  static Future<void> _createExpensesTables(Database db) async {
    // Cabecera de hoja de gastos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableExpenseSheets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sheetId INTEGER NOT NULL UNIQUE,
        title TEXT,
        personalData TEXT,
        bankName TEXT,
        accountType TEXT,
        accountNumber TEXT,
        ibanSwift TEXT,
        holderName TEXT,
        idNumber TEXT,
        email TEXT,
        localCurrencyText TEXT,
        localCurrencyCode TEXT,
        localCurrencyEmoji TEXT,
        createdAt INTEGER,
        beginDate INTEGER,
        endDate INTEGER,
        maxApprovedAmount REAL,
        maxApprovedCurrencyCode TEXT,
        maxApprovedCurrencyEmoji TEXT,
        extraApprovedAmount REAL,
        extraApprovedCurrencyCode TEXT,
        extraApprovedCurrencyEmoji TEXT
      )
    ''');

    // Detalle cargos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableExpenseCharges(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sheetId INTEGER NOT NULL,
        type TEXT,
        ticket TEXT,
        date INTEGER,
        detail TEXT,
        amount REAL,
        currencyCode TEXT,
        currencyEmoji TEXT,
        FOREIGN KEY(sheetId) REFERENCES $tableExpenseSheets(sheetId) ON DELETE CASCADE
      )
    ''');

    // Ratios FX
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableExpenseFxRates(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sheetId INTEGER NOT NULL,
        code TEXT NOT NULL,
        rate REAL NOT NULL,
        FOREIGN KEY(sheetId) REFERENCES $tableExpenseSheets(sheetId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_expense_fx_sheet_code
      ON $tableExpenseFxRates(sheetId, code)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expense_charges_sheet
      ON $tableExpenseCharges(sheetId)
    ''');
  }

  // ================== FLIGHTS TABLE ==================

  static Future<void> _createFlightsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFlights(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startDate INTEGER NOT NULL,
        endDate INTEGER,
        fromIcao TEXT,
        toIcao TEXT,
        fromFlagEmoji TEXT,
        toFlagEmoji TEXT,              -- <-- FIX: columna faltante
        aircraftRegistration TEXT,
        aircraftIdentifier TEXT,
        isSimulator INTEGER NOT NULL DEFAULT 0,
        blockTimeMinutes INTEGER,
        blockTimeText TEXT,
        pic TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER,
        dataJson TEXT NOT NULL
      )
    ''');

    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_flights_start_created ON $tableFlights(startDate ASC, createdAt ASC)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_flights_fromIcao ON $tableFlights(fromIcao)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_flights_aircraftReg ON $tableFlights(aircraftRegistration)',
      );
    } catch (_) {}
  }

  static Future<void> _ensureFlightsColumns(Database db) async {
    final exists = await _tableExists(db, tableFlights);
    if (!exists) {
      await _createFlightsTable(db);
      return;
    }

    final cols = await _columnsOf(db, tableFlights);
    Future<void> addCol(String name, String type) async {
      if (!cols.contains(name)) {
        try {
          await db.execute('ALTER TABLE $tableFlights ADD COLUMN $name $type');
        } catch (_) {}
      }
    }

    // Normaliza columnas (incluye toFlagEmoji)
    await addCol('endDate', 'INTEGER');
    await addCol('fromIcao', 'TEXT');
    await addCol('toIcao', 'TEXT');
    await addCol('fromFlagEmoji', 'TEXT');
    await addCol('toFlagEmoji', 'TEXT'); // <-- FIX: migración
    await addCol('aircraftRegistration', 'TEXT');
    await addCol('aircraftIdentifier', 'TEXT');
    await addCol('isSimulator', 'INTEGER');
    await addCol('blockTimeMinutes', 'INTEGER');
    await addCol('blockTimeText', 'TEXT');
    await addCol('pic', 'TEXT');
    await addCol('updatedAt', 'INTEGER');
    await addCol('dataJson', 'TEXT');
  }

  // ================== SEED ==================

  static Future<void> _seedInitialData(Database db) async {
    final batch = db.batch();
    for (final c in allCountryData) {
      batch.insert(
        tableCountries,
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // ================== SUB-TABLAS BASE ==================

  static Future<void> _createPilotTableV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePilot(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        birthDate TEXT,
        country TEXT,
        phone TEXT,
        passport TEXT
      )
    ''');
  }

  static Future<void> _createPilotTableV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePilot(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        birthDate TEXT,
        country TEXT,
        phone TEXT,
        passport TEXT,
        authUid TEXT,
        email TEXT,
        displayName TEXT,
        city TEXT,
        street TEXT,
        idNumber TEXT,
        airline TEXT,
        employeeNumber TEXT,
        phoneFlag TEXT,
        photoPath TEXT
      )
    ''');
  }

  static Future<void> _createNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableNotes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');
  }

  static Future<void> _createIndexes(Database db) async {
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_countries_name ON $tableCountries(name)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_taglist_label_title ON $tableTagList(label, title)',
      );
    } catch (_) {}
  }

  // ================== UTILIDADES ==================

  static Future<List<String>> getTables() async {
    final db = await getDB();
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name ASC",
    );
    return rows.map((e) => e['name'] as String).toList(growable: false);
  }

  static Future<int> countCountries() async {
    final db = await getDB();
    final n = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableCountries'),
    );
    return n ?? 0;
  }

  // ================== TAGLIST CRUD ==================

  static Future<int> insertTag(SectionItem item) async {
    final db = await getDB();
    return db.insert(
      tableTagList,
      {
        'label': item.label,
        'title': item.title,
        'explanation': item.explanation,
        'labelColor': item.labelColor.toARGB32(),
        'isUserCreated': item.isUserCreated ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<SectionItem>> getTags() async {
    final db = await getDB();
    final rows = await db.query(tableTagList, orderBy: 'id DESC');
    return rows
        .map(
          (e) => SectionItem(
            id: e['id'] as int?,
            label: e['label'] as String? ?? '',
            title: e['title'] as String? ?? '',
            explanation: e['explanation'] as String? ?? '',
            labelColor: Color((e['labelColor'] ?? 0xFF000000) as int),
            isUserCreated: (e['isUserCreated'] ?? 0) == 1,
          ),
        )
        .toList(growable: false);
  }

  static Future<int> updateTag(SectionItem item) async {
    if (item.id == null) {
      throw Exception('ID requerido');
    }
    final db = await getDB();
    return db.update(
      tableTagList,
      {
        'label': item.label,
        'title': item.title,
        'explanation': item.explanation,
        'labelColor': item.labelColor.toARGB32(),
        'isUserCreated': item.isUserCreated ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  static Future<int> deleteTag(int id) async {
    final db = await getDB();
    return db.delete(tableTagList, where: 'id = ?', whereArgs: [id]);
  }

  // ================== COUNTRIES ==================

  static Future<List<CountryData>> getCountries() async {
    final db = await getDB();
    final rows = await db.query(
      tableCountries,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map((e) => CountryData.fromMap(e)).toList(growable: false);
  }

  // ================== PILOT ==================

  static Future<Map<String, dynamic>?> getPilot() async {
    final db = await getDB();
    final result = await db.query(tablePilot, limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  static Future<void> upsertPilot(Map<String, dynamic> data) async {
    final db = await getDB();
    await db.transaction((txn) async {
      final result = await txn.query(tablePilot, limit: 1);
      if (result.isEmpty) {
        await txn.insert(
          tablePilot,
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        final id = result.first['id'] as int;
        final count = await txn.update(
          tablePilot,
          data,
          where: 'id = ?',
          whereArgs: [id],
        );
        if (count == 0) {
          await txn.insert(
            tablePilot,
            {...data, 'id': id},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  static Future<void> upsertPilotFromAuth({
    String? authUid,
    String? email,
    String? displayName,
    String? phone,
    String? country,
  }) async {
    final db = await getDB();
    final current = await db.query(tablePilot, limit: 1);

    final hasDisplay = displayName != null && displayName.trim().isNotEmpty;
    final data = <String, Object?>{
      'authUid': authUid,
      'email': email,
      'displayName': displayName,
      'name': hasDisplay ? displayName.trim() : email?.split('@').first,
      'phone': phone,
      'country': country,
    };

    if (current.isEmpty) {
      await db.insert(tablePilot, data);
    } else {
      await db.update(
        tablePilot,
        data,
        where: 'id = ?',
        whereArgs: [current.first['id']],
      );
    }
  }

  // ================== NOTES CRUD ==================

  static Future<int> insertNote({
    required String title,
    required String content,
  }) async {
    final db = await getDB();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert(
      tableNotes,
      {
        'title': title,
        'content': content,
        'created_at': now,
        'updated_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, Object?>>> getAllNotes() async {
    final db = await getDB();
    return db.query(tableNotes, orderBy: 'created_at DESC');
  }

  static Future<int> updateNote({
    required int id,
    required String title,
    required String content,
  }) async {
    final db = await getDB();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.update(
      tableNotes,
      {
        'title': title,
        'content': content,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> deleteNote(int id) async {
    final db = await getDB();
    return db.delete(tableNotes, where: 'id = ?', whereArgs: [id]);
  }

  // ================== FLIGHTS CRUD ==================

  static Future<int> insertFlight(Map<String, Object?> data) async {
    final db = await getDB();
    final now = DateTime.now().millisecondsSinceEpoch;

    final toInsert = Map<String, Object?>.from(data);
    toInsert['createdAt'] ??= now;
    toInsert['updatedAt'] ??= now;
    toInsert['dataJson'] ??= '{}';
    toInsert['startDate'] ??= now;

    return db.insert(
      tableFlights,
      toInsert,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> updateFlight(int id, Map<String, Object?> data) async {
    final db = await getDB();
    final now = DateTime.now().millisecondsSinceEpoch;

    final toUpdate = Map<String, Object?>.from(data);
    toUpdate.remove('id');

    // Siempre actualizar timestamp
    toUpdate['updatedAt'] = now;

    // FIX:
    // No pises dataJson si no viene en `data`.
    // Si no lo mandas, SQLite mantiene el que ya existe.
    if (toUpdate.containsKey('dataJson')) {
      toUpdate['dataJson'] ??= '{}';
    }

    final count = await db.update(
      tableFlights,
      toUpdate,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count > 0) return count;

    // UPSERT fallback
    final existing = await db.query(
      tableFlights,
      columns: const ['createdAt'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final createdAt =
        (existing.isNotEmpty ? (existing.first['createdAt'] as int?) : null) ??
            now;

    return db.insert(
      tableFlights,
      {
        ...toUpdate,
        'id': id,
        'createdAt': createdAt,
        'startDate': toUpdate['startDate'] ?? now,

        // dataJson es NOT NULL en tu tabla: asegurar valor si hacemos insert
        'dataJson': toUpdate.containsKey('dataJson')
            ? (toUpdate['dataJson'] ?? '{}')
            : '{}',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> deleteFlight(int id) async {
    final db = await getDB();
    return db.delete(
      tableFlights,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<Map<String, Object?>>> getFlightsForLogsList() async {
    final db = await getDB();
    return db.query(
      tableFlights,
      columns: const [
        'id',
        'startDate',
        'endDate',
        'fromIcao',
        'toIcao',
        'fromFlagEmoji',
        'toFlagEmoji', // <-- FIX: ahora existe
        'aircraftRegistration',
        'aircraftIdentifier',
        'isSimulator',
        'blockTimeMinutes',
        'blockTimeText',
        'pic',
        'createdAt',
        'updatedAt',
        'dataJson',
      ],
      orderBy: 'startDate ASC, createdAt ASC',
    );
  }

  /// Obtiene un vuelo por id (incluye dataJson) para precargar NewFlightPage.
  static Future<Map<String, Object?>?> getFlightById(int id) async {
    final db = await getDB();
    final rows = await db.query(
      tableFlights,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ================== EXPENSES API ==================

  static Future<Map<String, dynamic>?> getExpenseSheetHeader(
    int sheetId,
  ) async {
    final db = await getDB();
    final rows = await db.query(
      tableExpenseSheets,
      where: 'sheetId = ?',
      whereArgs: [sheetId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  static Future<void> upsertExpenseSheetHeader({
    required int sheetId,
    required String title,
    String? personalData,
    String? bankName,
    String? accountType,
    String? accountNumber,
    String? ibanSwift, // NUEVO
    String? holderName,
    String? idNumber,
    String? email,
    String? localCurrencyText,
    String? localCurrencyCode,
    String? localCurrencyEmoji,
    DateTime? createdAt,
    DateTime? beginDate,
    DateTime? endDate,
    double? maxApprovedAmount,
    String? maxApprovedCurrencyCode,
    String? maxApprovedCurrencyEmoji,
    double? extraApprovedAmount,
    String? extraApprovedCurrencyCode,
    String? extraApprovedCurrencyEmoji,
  }) async {
    final db = await getDB();
    final data = <String, Object?>{
      'sheetId': sheetId,
      'title': title,
      'personalData': personalData,
      'bankName': bankName,
      'accountType': accountType,
      'accountNumber': accountNumber,
      'ibanSwift': ibanSwift, // NUEVO
      'holderName': holderName,
      'idNumber': idNumber,
      'email': email,
      'localCurrencyText': localCurrencyText,
      'localCurrencyCode': localCurrencyCode,
      'localCurrencyEmoji': localCurrencyEmoji,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'beginDate': beginDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'maxApprovedAmount': maxApprovedAmount,
      'maxApprovedCurrencyCode': maxApprovedCurrencyCode,
      'maxApprovedCurrencyEmoji': maxApprovedCurrencyEmoji,
      'extraApprovedAmount': extraApprovedAmount,
      'extraApprovedCurrencyCode': extraApprovedCurrencyCode,
      'extraApprovedCurrencyEmoji': extraApprovedCurrencyEmoji,
    };

    final existing = await db.query(
      tableExpenseSheets,
      where: 'sheetId = ?',
      whereArgs: [sheetId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(
        tableExpenseSheets,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.update(
        tableExpenseSheets,
        data,
        where: 'sheetId = ?',
        whereArgs: [sheetId],
      );
    }
  }

  static Future<List<Map<String, Object?>>> getExpenseCharges(
    int sheetId,
  ) async {
    final db = await getDB();
    return db.query(
      tableExpenseCharges,
      where: 'sheetId = ?',
      whereArgs: [sheetId],
      orderBy: 'date ASC, id ASC',
    );
  }

  static Future<void> replaceExpenseCharges(
    int sheetId,
    List<Map<String, Object?>> charges,
  ) async {
    final db = await getDB();
    await db.transaction((txn) async {
      await txn.delete(
        tableExpenseCharges,
        where: 'sheetId = ?',
        whereArgs: [sheetId],
      );
      for (final c in charges) {
        final toInsert = Map<String, Object?>.from(c)..['sheetId'] = sheetId;
        await txn.insert(
          tableExpenseCharges,
          toInsert,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<Map<String, double>> getExpenseFxRates(
    int sheetId,
  ) async {
    final db = await getDB();
    final rows = await db.query(
      tableExpenseFxRates,
      where: 'sheetId = ?',
      whereArgs: [sheetId],
    );
    final out = <String, double>{};
    for (final r in rows) {
      final code = r['code'] as String?;
      final rateNum = r['rate'] as num?;
      if (code != null && rateNum != null) {
        out[code] = rateNum.toDouble();
      }
    }
    return out;
  }

  static Future<void> replaceExpenseFxRates(
    int sheetId,
    Map<String, double> fxRates,
  ) async {
    final db = await getDB();
    await db.transaction((txn) async {
      await txn.delete(
        tableExpenseFxRates,
        where: 'sheetId = ?',
        whereArgs: [sheetId],
      );
      for (final entry in fxRates.entries) {
        final code = entry.key;
        final rate = entry.value;
        if (code.isEmpty || rate <= 0) continue;
        await txn.insert(
          tableExpenseFxRates,
          {
            'sheetId': sheetId,
            'code': code,
            'rate': rate,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // ================== COUNTRIES SYNC ==================

  static Future<Map<String, int>> syncCountriesFromCodeReport({
    bool prune = false,
  }) async {
    final db = await getDB();
    final all = allCountryData;

    int inserted = 0;
    int updated = 0;
    int deleted = 0;

    final validNames = <String>[
      for (final c in all)
        if (c.name.trim().isNotEmpty) c.name.trim(),
    ];

    await db.transaction((txn) async {
      for (final c in all) {
        final name = c.name.trim();
        if (name.isEmpty) continue;

        final data = c.toMap()..remove('id');

        final u = await txn.update(
          tableCountries,
          data,
          where: 'name = ?',
          whereArgs: [name],
        );
        if (u > 0) {
          updated += u;
        } else {
          final i = await txn.insert(
            tableCountries,
            data,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (i > 0) inserted += 1;
        }
      }

      if (prune && validNames.isNotEmpty) {
        final placeholders = List.filled(validNames.length, '?').join(',');
        deleted = await txn.rawDelete(
          'DELETE FROM $tableCountries WHERE name NOT IN ($placeholders)',
          validNames,
        );
      }
    });

    return {'inserted': inserted, 'updated': updated, 'deleted': deleted};
  }

  static Future<void> syncCountriesFromCode({bool prune = true}) async {
    await syncCountriesFromCodeReport(prune: prune);
  }
}

// Utilidad para guardar Color como int ARGB
extension on Color {
  // ignore: deprecated_member_use, unused_element
  int toARGB32() => value;
}
