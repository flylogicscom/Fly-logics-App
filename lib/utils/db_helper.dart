// lib/utils/db_helper.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'country_data.dart';
import 'package:fly_logicd_logbook_app/common/taglist_page.dart';

class DBHelper {
  DBHelper._();
  static Database? _db;

  static const String _dbName = 'app.db';
  // Subido a 11: flights schema mínimo (crew 1..3, aircraftItemId, time mode, notes)
  static const int _dbVersion = 12;

  static const String tableTagList = 'taglist';
  static const String tableCountries = 'countries';
  static const String tablePilot = 'pilot';
  static const String tableNotes = 'notes';

  // NUEVO
  static const String tableFlights = 'flights';
  static const String tableAircraftItems = 'aircraft_items';

  static const String tableExpenseSheets = 'expense_sheets';
  static const String tableExpenseCharges = 'expense_charges';
  static const String tableExpenseFxRates = 'expense_fx_rates';

  static String? databasePath;

  // ================== OPEN / CLOSE ==================

  static Future<Database> getDB() async {
    if (_db != null) {
      // Asegura migraciones/columnas incluso si la DB ya estaba abierta (hot reload / navegación).
      try {
        await _ensureFlightsColumns(_db!);
        await _migrateFlightsToV11(_db!);
      } catch (_) {}
      return _db!;
    }

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
        onOpen: _onOpen,
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

  static Future<void> _onOpen(Database db) async {
    // Mantener la DB en estado consistente incluso si no hubo bump de versión.
    // (Ej: emulador con app.db antigua, o hot reload)
    try {
      await _ensureFlightsColumns(db);
      await _migrateFlightsToV11(db);
    } catch (_) {}
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

    // v9: recrear flights para eliminar columnas (dataJson / makeAndModel)
    if (oldVersion < 10) {
      await db.execute('DROP TABLE IF EXISTS $tableFlights');
    }

    // flights: asegurar schema y migraciones
    await _createFlightsTable(db);
    await _ensureFlightsColumns(db);

    await _createIndexes(db);

    if (oldVersion < 11) {
      // V11: schema mínimo (crew 1..3, aircraftItemId, useUtcTime/timeStart/timeEnd, remarks/tags)
      // Incluye limpieza de columnas legacy en flights mediante rebuild seguro.
      await _migrateFlightsToV11(db);
    }
  }

  static Future<String?> getPilotDisplayName() async {
    final data = await getPilot();
    if (data == null) return null;

    final raw =
        ((data['displayName'] as String?) ?? (data['name'] as String?) ?? '')
            .trim();

    return raw.isEmpty ? null : raw;
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

        -- Sección 1
        startDate INTEGER NOT NULL,
        endDate INTEGER,

        -- Sección 2
        aircraftItemId INTEGER,

        -- Sección 3
        fromIcao TEXT,
        toIcao TEXT,

        -- Sección 4 (hasta 3 tripulantes)
        rangoPilot TEXT,
        pilotName TEXT,
        rangoPilot2 TEXT,
        pilotName2 TEXT,
        rangoPilot3 TEXT,
        pilotName3 TEXT,

        -- Sección 5 (modo tiempo + totales)
        blockTimeMinutes INTEGER,
        useUtcTime INTEGER NOT NULL DEFAULT 0,
        timeStartCtrl TEXT,
        timeEndCtrl TEXT,
        blockTimeText TEXT,
        totalFlightCenti INTEGER NOT NULL DEFAULT 0,

        -- Sección 6 (tipo aeronave) - derivado de aircraft_items.typeTitle
        singleEngineCenti INTEGER NOT NULL DEFAULT 0,
        multiEngineCenti  INTEGER NOT NULL DEFAULT 0,
        turbopropCenti    INTEGER NOT NULL DEFAULT 0,
        turbojetCenti     INTEGER NOT NULL DEFAULT 0,
        lsaCenti          INTEGER NOT NULL DEFAULT 0,
        helicopterCenti   INTEGER NOT NULL DEFAULT 0,
        gliderCenti       INTEGER NOT NULL DEFAULT 0,
        otherAircraftCenti INTEGER NOT NULL DEFAULT 0,

        -- Sección 7 (simulador) - derivado de aircraft_items.isSimulator
        simulatorCenti INTEGER NOT NULL DEFAULT 0,

        -- Sección 8
        condDayCenti   INTEGER NOT NULL DEFAULT 0,
        condNightCenti INTEGER NOT NULL DEFAULT 0,
        condIFRCenti   INTEGER NOT NULL DEFAULT 0,

        -- Sección 9
        timeCrossCountryCenti   INTEGER NOT NULL DEFAULT 0,
        timeSoloCenti           INTEGER NOT NULL DEFAULT 0,
        timePICCenti            INTEGER NOT NULL DEFAULT 0,
        timeSICCenti            INTEGER NOT NULL DEFAULT 0,
        timeInstructionRecCenti INTEGER NOT NULL DEFAULT 0,
        timeInstructorCenti     INTEGER NOT NULL DEFAULT 0,

        -- Sección 10
        takeoffsDay   INTEGER NOT NULL DEFAULT 0,
        takeoffsNight INTEGER NOT NULL DEFAULT 0,
        landingsDay   INTEGER NOT NULL DEFAULT 0,
        landingsNight INTEGER NOT NULL DEFAULT 0,

        -- Sección 11
        approachesNumber INTEGER NOT NULL DEFAULT 0,
        approachesType   TEXT,

        -- Sección 12
        remarks TEXT,
        tags TEXT,

        createdAt INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER
      )
    ''');
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_flights_start_created ON $tableFlights(startDate ASC, createdAt ASC)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_flights_fromIcao ON $tableFlights(fromIcao)',
      );
      // eliminado: idx_flights_aircraftReg (columna legacy removida en schema v11)
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_flights_aircraftItemId ON $tableFlights(aircraftItemId)',
      );
    } catch (_) {}
  }

  /// V11: Rebuild seguro de flights para:
  /// - eliminar columnas legacy (fromFlagEmoji/toFlagEmoji/aircraftRegistration/aircraftIdentifier/isSimulator/pic/dataJson/makeAndModel)
  /// - crear columnas nuevas (aircraftItemId, crew 1..3, useUtcTime/timeStartCtrl/timeEndCtrl, remarks/tags)
  /// Mantiene compatibilidad migrando datos desde columnas existentes y, si existía dataJson, extrae crew/time/notes.
  static Future<void> _migrateFlightsToV11(Database db) async {
    final exists = await _tableExists(db, tableFlights);
    if (!exists) {
      await _createFlightsTable(db);
      await _createIndexes(db);
      return;
    }

    final oldCols = await _columnsOf(db, tableFlights);

    // Si ya está en schema v11 (sin columnas legacy) no hacemos rebuild.
    const legacy = <String>{
      'fromFlagEmoji',
      'toFlagEmoji',
      'aircraftRegistration',
      'aircraftIdentifier',
      'isSimulator',
      'pic',
      'dataJson',
      'makeAndModel',
    };

    final bool hasLegacy = oldCols.any(legacy.contains);
    // Requiere columnas mínimas v11
    const requiredV11 = <String>{
      'aircraftItemId',
      'rangoPilot',
      'pilotName',
      'rangoPilot2',
      'pilotName2',
      'rangoPilot3',
      'pilotName3',
      'useUtcTime',
      'timeStartCtrl',
      'timeEndCtrl',
      'remarks',
      'tags',
      'singleEngineCenti',
      'multiEngineCenti',
      'turbopropCenti',
      'turbojetCenti',
      'lsaCenti',
      'helicopterCenti',
      'gliderCenti',
      'otherAircraftCenti',
      'simulatorCenti',
    };
    final bool missingRequired = requiredV11.any((c) => !oldCols.contains(c));

    if (!hasLegacy && !missingRequired) {
      // Asegura que existan todas las columnas por si faltó alguna en instalaciones viejas.
      await _ensureFlightsColumns(db);
      return;
    }

    await db.transaction((txn) async {
      const oldTable = 'flights__old_v11';

      // Si hubo un intento previo, limpiar
      try {
        await txn.execute('DROP TABLE IF EXISTS $oldTable');
      } catch (_) {}

      await txn.execute('ALTER TABLE $tableFlights RENAME TO $oldTable');

      // Crear tabla nueva (schema v11)
      await txn.execute('''CREATE TABLE $tableFlights(
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        -- Sección 1
        startDate INTEGER NOT NULL,
        endDate INTEGER,

        -- Sección 2
        aircraftItemId INTEGER,

        -- Sección 3
        fromIcao TEXT,
        toIcao TEXT,

        -- Sección 4 (hasta 3 tripulantes)
        rangoPilot TEXT,
        pilotName TEXT,
        rangoPilot2 TEXT,
        pilotName2 TEXT,
        rangoPilot3 TEXT,
        pilotName3 TEXT,

        -- Sección 5 (modo tiempo + totales)
        blockTimeMinutes INTEGER,
        useUtcTime INTEGER NOT NULL DEFAULT 0,
        timeStartCtrl TEXT,
        timeEndCtrl TEXT,
        blockTimeText TEXT,
        totalFlightCenti INTEGER NOT NULL DEFAULT 0,

        -- Sección 6 (tipo aeronave) - derivado de aircraft_items.typeTitle
        singleEngineCenti INTEGER NOT NULL DEFAULT 0,
        multiEngineCenti  INTEGER NOT NULL DEFAULT 0,
        turbopropCenti    INTEGER NOT NULL DEFAULT 0,
        turbojetCenti     INTEGER NOT NULL DEFAULT 0,
        lsaCenti          INTEGER NOT NULL DEFAULT 0,
        helicopterCenti   INTEGER NOT NULL DEFAULT 0,
        gliderCenti       INTEGER NOT NULL DEFAULT 0,
        otherAircraftCenti INTEGER NOT NULL DEFAULT 0,

        -- Sección 7 (simulador) - derivado de aircraft_items.isSimulator
        simulatorCenti INTEGER NOT NULL DEFAULT 0,

        -- Sección 8
        condDayCenti INTEGER NOT NULL DEFAULT 0,
        condNightCenti INTEGER NOT NULL DEFAULT 0,
        condIFRCenti INTEGER NOT NULL DEFAULT 0,

        -- Sección 9
        timeCrossCountryCenti INTEGER NOT NULL DEFAULT 0,
        timeSoloCenti INTEGER NOT NULL DEFAULT 0,
        timePICCenti INTEGER NOT NULL DEFAULT 0,
        timeSICCenti INTEGER NOT NULL DEFAULT 0,
        timeInstructionRecCenti INTEGER NOT NULL DEFAULT 0,
        timeInstructorCenti INTEGER NOT NULL DEFAULT 0,

        -- Sección 10
        takeoffsDay INTEGER NOT NULL DEFAULT 0,
        takeoffsNight INTEGER NOT NULL DEFAULT 0,
        landingsDay INTEGER NOT NULL DEFAULT 0,
        landingsNight INTEGER NOT NULL DEFAULT 0,

        -- Sección 11
        approachesNumber INTEGER NOT NULL DEFAULT 0,
        approachesType TEXT,

        -- Sección 12
        remarks TEXT,
        tags TEXT,

        createdAt INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER
      )''');

      // Helper para seleccionar columna si existe; si no, usar literal/default
      String colOr(String name, String fallbackSql) {
        return oldCols.contains(name) ? '$oldTable.$name' : fallbackSql;
      }

      // aircraftItemId: derivar desde aircraft_items si existen columnas legacy
      String aircraftIdSql = 'NULL';
      if (oldCols.contains('aircraftItemId')) {
        aircraftIdSql = '$oldTable.aircraftItemId';
      } else if (oldCols.contains('aircraftRegistration') ||
          oldCols.contains('aircraftIdentifier')) {
        final regSql = oldCols.contains('aircraftRegistration')
            ? '$oldTable.aircraftRegistration'
            : 'NULL';
        final identSql = oldCols.contains('aircraftIdentifier')
            ? '$oldTable.aircraftIdentifier'
            : 'NULL';
        aircraftIdSql = "(SELECT ai.id FROM $tableAircraftItems ai "
            "WHERE (ai.registration IS NOT NULL AND ai.registration = $regSql) "
            "OR (ai.identifier IS NOT NULL AND ai.identifier = $identSql) "
            "LIMIT 1)";
      }

      // rangoPilot: preferir rangoPilot si ya existe; si no, pic
      final String rangoPilotSql = oldCols.contains('rangoPilot')
          ? '$oldTable.rangoPilot'
          : (oldCols.contains('pic') ? '$oldTable.pic' : "NULL");

      await txn.execute('''INSERT INTO $tableFlights(
        id, startDate, endDate,
        aircraftItemId,
        fromIcao, toIcao,
        rangoPilot, pilotName,
        rangoPilot2, pilotName2,
        rangoPilot3, pilotName3,
        blockTimeMinutes, useUtcTime, timeStartCtrl, timeEndCtrl,
        blockTimeText, totalFlightCenti,
        singleEngineCenti, multiEngineCenti, turbopropCenti, turbojetCenti, lsaCenti, helicopterCenti, gliderCenti, otherAircraftCenti,
        simulatorCenti,
        condDayCenti, condNightCenti, condIFRCenti,
        timeCrossCountryCenti, timeSoloCenti, timePICCenti, timeSICCenti, timeInstructionRecCenti, timeInstructorCenti,
        takeoffsDay, takeoffsNight, landingsDay, landingsNight,
        approachesNumber, approachesType,
        remarks, tags,
        createdAt, updatedAt
      )
      SELECT
        $oldTable.id,
        $oldTable.startDate,
        $oldTable.endDate,
        $aircraftIdSql,
        ${colOr('fromIcao', "''")},
        ${colOr('toIcao', "''")},
        $rangoPilotSql,
        ${colOr('pilotName', "NULL")},
        ${colOr('rangoPilot2', "NULL")},
        ${colOr('pilotName2', "NULL")},
        ${colOr('rangoPilot3', "NULL")},
        ${colOr('pilotName3', "NULL")},
        ${colOr('blockTimeMinutes', "NULL")},
        ${colOr('useUtcTime', "0")},
        ${colOr('timeStartCtrl', "NULL")},
        ${colOr('timeEndCtrl', "NULL")},
        ${colOr('blockTimeText', "NULL")},
        ${colOr('totalFlightCenti', "0")},
        ${colOr('singleEngineCenti', "0")},
        ${colOr('multiEngineCenti', "0")},
        ${colOr('turbopropCenti', "0")},
        ${colOr('turbojetCenti', "0")},
        ${colOr('lsaCenti', "0")},
        ${colOr('helicopterCenti', "0")},
        ${colOr('gliderCenti', "0")},
        ${colOr('otherAircraftCenti', "0")},
        ${colOr('simulatorCenti', "0")},
        ${colOr('condDayCenti', "0")},
        ${colOr('condNightCenti', "0")},
        ${colOr('condIFRCenti', "0")},
        ${colOr('timeCrossCountryCenti', "0")},
        ${colOr('timeSoloCenti', "0")},
        ${colOr('timePICCenti', "0")},
        ${colOr('timeSICCenti', "0")},
        ${colOr('timeInstructionRecCenti', "0")},
        ${colOr('timeInstructorCenti', "0")},
        ${colOr('takeoffsDay', "0")},
        ${colOr('takeoffsNight', "0")},
        ${colOr('landingsDay', "0")},
        ${colOr('landingsNight', "0")},
        ${colOr('approachesNumber', "0")},
        ${colOr('approachesType', "NULL")},
        ${colOr('remarks', "NULL")},
        ${colOr('tags', "NULL")},
        $oldTable.createdAt,
        $oldTable.updatedAt
      FROM $oldTable''');

      // Si existía dataJson, extraer crew/time/remarks/tags y actualizar filas nuevas.
      if (oldCols.contains('dataJson')) {
        final rows = await txn.query(oldTable, columns: ['id', 'dataJson']);
        for (final r in rows) {
          final int id = (r['id'] as int?) ?? 0;
          if (id == 0) continue;

          final String raw = (r['dataJson'] ?? '').toString();
          if (raw.trim().isEmpty) continue;

          Map<String, dynamic>? snap;
          try {
            final dyn = jsonDecode(raw);
            if (dyn is Map<String, dynamic>) snap = dyn;
          } catch (_) {}

          if (snap == null) continue;

          // Crew
          try {
            final crew = snap['crew'];
            if (crew is List) {
              String? rp1, pn1, rp2, pn2, rp3, pn3;
              if (crew.isNotEmpty && crew[0] is Map) {
                final m = crew[0] as Map;
                rp1 = (m['role'] ?? '').toString();
                pn1 = (m['name'] ?? '').toString();
              }
              if (crew.length > 1 && crew[1] is Map) {
                final m = crew[1] as Map;
                rp2 = (m['role'] ?? '').toString();
                pn2 = (m['name'] ?? '').toString();
              }
              if (crew.length > 2 && crew[2] is Map) {
                final m = crew[2] as Map;
                rp3 = (m['role'] ?? '').toString();
                pn3 = (m['name'] ?? '').toString();
              }

              final update = <String, Object?>{};
              if (rp1 != null && rp1.trim().isNotEmpty) {
                update['rangoPilot'] = rp1.trim().toUpperCase();
              }
              if (pn1 != null && pn1.trim().isNotEmpty) {
                update['pilotName'] = pn1.trim();
              }
              if (rp2 != null && rp2.trim().isNotEmpty) {
                update['rangoPilot2'] = rp2.trim().toUpperCase();
              }
              if (pn2 != null && pn2.trim().isNotEmpty) {
                update['pilotName2'] = pn2.trim();
              }
              if (rp3 != null && rp3.trim().isNotEmpty) {
                update['rangoPilot3'] = rp3.trim().toUpperCase();
              }
              if (pn3 != null && pn3.trim().isNotEmpty) {
                update['pilotName3'] = pn3.trim();
              }

              if (update.isNotEmpty) {
                await txn.update(tableFlights, update,
                    where: 'id = ?', whereArgs: [id]);
              }
            }
          } catch (_) {}

          // Time
          try {
            final time = snap['time'];
            if (time is Map) {
              final useUtc = time['useUtc'];
              final start = (time['start'] ?? '').toString();
              final end = (time['end'] ?? '').toString();

              final update = <String, Object?>{};
              if (useUtc != null) {
                update['useUtcTime'] =
                    (useUtc == true || useUtc.toString() == '1') ? 1 : 0;
              }
              if (start.trim().isNotEmpty) {
                update['timeStartCtrl'] = start.trim();
              }
              if (end.trim().isNotEmpty) update['timeEndCtrl'] = end.trim();

              if (update.isNotEmpty) {
                await txn.update(tableFlights, update,
                    where: 'id = ?', whereArgs: [id]);
              }
            }
          } catch (_) {}

          // Notes
          try {
            final remarks = snap['remarks'];
            final tags = snap['tags'];
            final update = <String, Object?>{};
            if (remarks is String && remarks.trim().isNotEmpty) {
              update['remarks'] = remarks.trim();
            }
            if (tags is List) update['tags'] = jsonEncode(tags);
            if (update.isNotEmpty) {
              await txn.update(tableFlights, update,
                  where: 'id = ?', whereArgs: [id]);
            }
          } catch (_) {}
        }
      }

      // Recalcular Sección 6/7 a partir de aircraft_items
      try {
        final rows = await txn.query(tableFlights,
            columns: ['id', 'aircraftItemId', 'totalFlightCenti']);
        for (final r in rows) {
          final int id = (r['id'] as int?) ?? 0;
          final int? aid = r['aircraftItemId'] as int?;
          final int total = (r['totalFlightCenti'] as int?) ?? 0;
          if (id == 0 || aid == null || total <= 0) continue;

          final aiRows = await txn.query(tableAircraftItems,
              columns: ['typeTitle', 'isSimulator'],
              where: 'id = ?',
              whereArgs: [aid],
              limit: 1);
          if (aiRows.isEmpty) continue;

          final String typeTitle =
              (aiRows.first['typeTitle'] ?? '').toString().toUpperCase();
          final int isSim = (aiRows.first['isSimulator'] as int?) ?? 0;

          int singleEngineCenti = 0;
          int multiEngineCenti = 0;
          int turbopropCenti = 0;
          int turbojetCenti = 0;
          int lsaCenti = 0;
          int helicopterCenti = 0;
          int gliderCenti = 0;
          int otherAircraftCenti = 0;
          int simulatorCenti = 0;

          if (isSim == 1) {
            simulatorCenti = total;
          } else {
            if (typeTitle.contains('MULTI') || typeTitle.contains('ME')) {
              multiEngineCenti = total;
            } else if (typeTitle.contains('TURBOPROP') ||
                typeTitle.contains('TP')) {
              turbopropCenti = total;
            } else if (typeTitle.contains('TURBOJET') ||
                typeTitle.contains('JET') ||
                typeTitle.contains('TJ')) {
              turbojetCenti = total;
            } else if (typeTitle.contains('HELI')) {
              helicopterCenti = total;
            } else if (typeTitle.contains('GLIDER') ||
                typeTitle.contains('PLANADOR')) {
              gliderCenti = total;
            } else if (typeTitle.contains('SINGLE') ||
                typeTitle.contains('SE') ||
                typeTitle.contains('MONO')) {
              singleEngineCenti = total;
            } else {
              otherAircraftCenti = total;
            }
            if (typeTitle.contains('LSA')) {
              lsaCenti = total;
            }
          }

          await txn.update(
            tableFlights,
            {
              'singleEngineCenti': singleEngineCenti,
              'multiEngineCenti': multiEngineCenti,
              'turbopropCenti': turbopropCenti,
              'turbojetCenti': turbojetCenti,
              'lsaCenti': lsaCenti,
              'helicopterCenti': helicopterCenti,
              'gliderCenti': gliderCenti,
              'otherAircraftCenti': otherAircraftCenti,
              'simulatorCenti': simulatorCenti,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      } catch (_) {}

      // Drop old table
      try {
        await txn.execute('DROP TABLE IF EXISTS $oldTable');
      } catch (_) {}
    });

    // Post: asegurar columnas + indexes
    await _ensureFlightsColumns(db);
    await _createIndexes(db);
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

    // Normaliza columnas (flights schema v11)
    await addCol('endDate', 'INTEGER');
    await addCol('fromIcao', 'TEXT');
    await addCol('toIcao', 'TEXT');
    // ====== Schema v11 (mínimos esenciales) ======
    await addCol('aircraftItemId', 'INTEGER');

    await addCol('rangoPilot', 'TEXT');
    await addCol('pilotName', 'TEXT');
    await addCol('rangoPilot2', 'TEXT');
    await addCol('pilotName2', 'TEXT');
    await addCol('rangoPilot3', 'TEXT');
    await addCol('pilotName3', 'TEXT');

    await addCol('blockTimeMinutes', 'INTEGER');
    await addCol('useUtcTime', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('timeStartCtrl', 'TEXT');
    await addCol('timeEndCtrl', 'TEXT');
    await addCol('blockTimeText', 'TEXT');
    await addCol('updatedAt', 'INTEGER');

    await addCol('remarks', 'TEXT');
    await addCol('tags', 'TEXT');

    // ==== CAMPOS PLANOS PARA ESTADÍSTICAS (tipo Excel) ====

    await addCol('totalFlightCenti', 'INTEGER NOT NULL DEFAULT 0');

    await addCol('singleEngineCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('multiEngineCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('turbopropCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('turbojetCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('lsaCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('helicopterCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('gliderCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('otherAircraftCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('simulatorCenti', 'INTEGER NOT NULL DEFAULT 0');

    await addCol('condDayCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('condNightCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('condIFRCenti', 'INTEGER NOT NULL DEFAULT 0');

    await addCol('timeCrossCountryCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('timeSoloCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('timePICCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('timeSICCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('timeInstructionRecCenti', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('timeInstructorCenti', 'INTEGER NOT NULL DEFAULT 0');

    await addCol('takeoffsDay', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('takeoffsNight', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('landingsDay', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('landingsNight', 'INTEGER NOT NULL DEFAULT 0');

    await addCol('approachesNumber', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('approachesType', 'TEXT');
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

  static Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await getDB();
    return await db.insert(table, data);
  }

  static Future<int> update(
      String table, Map<String, dynamic> data, int id) async {
    final db = await getDB();
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
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
        'aircraftItemId',
        'fromIcao',
        'toIcao',
        'rangoPilot',
        'pilotName',
        'blockTimeMinutes',
        'blockTimeText',
        'totalFlightCenti',
        'createdAt',
        'updatedAt',
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
