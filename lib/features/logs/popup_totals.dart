// lib/features/logs/popup_total.dart

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

/// Popup informativo (sin mecánica) que se abre desde el pill de subtotales
/// en logs_pagelist.dart (// === SUBTOTALES (cada 10 vuelos) ===).
///
/// IMPORTANTE:
/// - Por ahora, solo se “cablean” los 3 totales de la sección 05 (flight time)
///   con los valores que le pases desde logs_pagelist.
/// - Las secciones 06-11 soportan datos vía [data], pero si no los pasas,
///   se muestran en 0 con el formato del PDF.
class PopupTotalsDialog extends StatefulWidget {
  const PopupTotalsDialog({
    super.key,
    required this.pageIndex, // 1-based
    required this.totalPageFlightTime,
    required this.totalPreviousFlightTime,
    required this.totalToDateFlightTime,
    this.data = const PopupTotalsData(),
    this.pilotNameOverride,
    this.pageFlightIds = const <int>[],
    this.previousFlightIds = const <int>[],
  });

  final int pageIndex;
  final double totalPageFlightTime; // suma de los 10 vuelos (col H)
  final double
      totalPreviousFlightTime; // total anterior (logbook o página anterior)
  final double totalToDateFlightTime; // previous + page (col H acumulado)

  /// Datos opcionales para poblar secciones 06-11.
  /// Claves = “dataKey” internos (ver specs abajo).
  final PopupTotalsData data;

  /// Si lo pasas, se usa en el header en vez de leerlo desde DB.
  final String? pilotNameOverride;

  /// IDs de vuelos visibles para sumar por página (cada 10 vuelos).
  /// Si no los pasas, se mostrarán ceros en secciones 06-11.
  final List<int> pageFlightIds;

  /// IDs de vuelos anteriores (para “página anterior / bitácora anterior”).
  final List<int> previousFlightIds;

  static Future<void> show(
    BuildContext context, {
    required int pageIndex,
    required double totalPageFlightTime,
    required double totalPreviousFlightTime,
    required double totalToDateFlightTime,
    PopupTotalsData data = const PopupTotalsData(),
    String? pilotNameOverride,
    List<int> pageFlightIds = const <int>[],
    List<int> previousFlightIds = const <int>[],
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PopupTotalsDialog(
        pageIndex: pageIndex,
        totalPageFlightTime: totalPageFlightTime,
        totalPreviousFlightTime: totalPreviousFlightTime,
        totalToDateFlightTime: totalToDateFlightTime,
        data: data,
        pilotNameOverride: pilotNameOverride,
        pageFlightIds: pageFlightIds,
        previousFlightIds: previousFlightIds,
      ),
    );
  }

  @override
  State<PopupTotalsDialog> createState() => _PopupTotalsDialogState();
}

class PopupTotalsData {
  const PopupTotalsData({
    this.page = const {},
    this.previous = const {},
  });

  final Map<String, num> page;
  final Map<String, num> previous;

  num pageValue(String key) => page[key] ?? 0;
  num previousValue(String key) => previous[key] ?? 0;
  num totalsValue(String key) => pageValue(key) + previousValue(key);
}

class _PopupTotalsDialogState extends State<PopupTotalsDialog> {
  String? _pilotName;
  PopupTotalsData _data = const PopupTotalsData();

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _loadPilotName();
    _loadTotalsData();
  }

  Future<void> _loadPilotName() async {
    if (widget.pilotNameOverride != null &&
        widget.pilotNameOverride!.trim().isNotEmpty) {
      setState(() => _pilotName = widget.pilotNameOverride!.trim());
      return;
    }

    try {
      final db = await DBHelper.getDB();

      // Best-effort: intenta sacar first/last de una tabla de perfil.
      // Si tu schema usa otro nombre, dime el nombre de la tabla y columnas
      // y lo dejamos exacto.
      final candidates = <String>[
        'pilot_data',
        'pilotData',
        'pilot',
        'profile',
        'user_profile',
      ];

      for (final t in candidates) {
        final info = await db.rawQuery("PRAGMA table_info('$t')");
        if (info.isEmpty) continue;

        final cols = info
            .map((r) => (['name'] as Object?)?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toSet();

        String? firstCol;
        String? lastCol;

        if (cols.contains('firstName')) firstCol = 'firstName';
        if (cols.contains('lastName')) lastCol = 'lastName';

        firstCol ??= cols.contains('first_name') ? 'first_name' : null;
        lastCol ??= cols.contains('last_name') ? 'last_name' : null;

        // fallback si solo guardan "name"
        firstCol ??= cols.contains('name') ? 'name' : null;

        if (firstCol == null) continue;

        final rows = await db.query(t, limit: 1);
        if (rows.isEmpty) continue;

        final first = rows.first[firstCol]?.toString().trim() ?? '';
        final last = (lastCol != null)
            ? (rows.first[lastCol]?.toString().trim() ?? '')
            : '';

        final full = [first, last].where((s) => s.isNotEmpty).join(' ');
        if (full.isNotEmpty) {
          if (!mounted) return;
          setState(() => _pilotName = full);
          return;
        }
      }
    } catch (_) {
      // Si no se puede leer, no rompe el popup.
    }

    if (!mounted) return;
    setState(() => _pilotName = '');
  }

  Future<void> _loadTotalsData() async {
    // Si no recibimos IDs desde logs_pagelist, no intentamos sumar.
    if (widget.pageFlightIds.isEmpty && widget.previousFlightIds.isEmpty) {
      return;
    }

    final page = await _sumFlightsForTotals(widget.pageFlightIds);

    Map<String, num> prev;
    if (widget.pageIndex == 1) {
      // En la primera página, "Log. Ant" viene de TotalsPage (previous_totals)
      prev = await _readPreviousTotalsAsFlightKeys();
    } else {
      // En páginas >1, "Pag. Ant" viene de los vuelos anteriores (IDs)
      prev = await _sumFlightsForTotals(widget.previousFlightIds);
    }

    if (!mounted) return;
    setState(() => _data = PopupTotalsData(page: page, previous: prev));
  }

  Future<Map<String, num>> _sumFlightsForTotals(List<int> ids) async {
    final out = <String, num>{};
    if (ids.isEmpty) return out;

    final db = await DBHelper.getDB();
    final flightsTable = DBHelper.tableFlights; // normalmente "flights"

    // Detecta columnas reales (compatibilidad con DBs antiguas).
    final existingCols = <String>{};
    try {
      final info = await db.rawQuery('PRAGMA table_info($flightsTable)');
      for (final r in info) {
        final n = r['name']?.toString();
        if (n != null && n.isNotEmpty) existingCols.add(n);
      }
    } catch (_) {}

    final wanted = <String>[
      'id',
      'aircraftItemId',
      'totalFlightCenti',

      // Sec 6
      'singleEngineCenti',
      'multiEngineCenti',
      'turbopropCenti',
      'turbojetCenti',
      'lsaCenti',
      'helicopterCenti',
      'gliderCenti',
      'otherAircraftCenti',

      // Sec 7
      'simulatorCenti',

      // Sec 8
      'condDayCenti',
      'condNightCenti',
      'condIFRCenti',

      // Sec 9
      'timeCrossCountryCenti',
      'timeSoloCenti',
      'timePICCenti',
      'timeSICCenti',
      'timeInstructionRecCenti',
      'timeInstructorCenti',

      // Sec 10
      'takeoffsDay',
      'takeoffsNight',
      'landingsDay',
      'landingsNight',

      // Sec 11
      'approachesNumber',
      'approachesType',
    ];

    final cols = (existingCols.isEmpty)
        ? wanted
        : wanted.where((c) => existingCols.contains(c)).toList();

    // Helpers de suma
    int sumInt(String key, int add) => (out[key] ?? 0).toInt() + add;

    // Cache local aircraft_items (fallback Sec6/7).
    final aircraftCache = <int, Map<String, Object?>>{};
    Map<String, String> aircraftCols = {};
    bool aircraftColsLoaded = false;

    Future<Map<String, Object?>> getAircraft(int id) async {
      if (aircraftCache.containsKey(id)) return aircraftCache[id]!;
      Map<String, Object?> row = {};
      try {
        // Tabla literal: "aircraft_items" (no dependemos de constantes del helper).
        if (!aircraftColsLoaded) {
          aircraftColsLoaded = true;
          try {
            final aiInfo =
                await db.rawQuery("PRAGMA table_info('aircraft_items')");
            for (final r in aiInfo) {
              final n = r['name']?.toString();
              if (n != null) aircraftCols[n] = n;
            }
          } catch (_) {}
        }
        final aiCols = <String>[];
        if (aircraftCols.containsKey('typeTitle')) aiCols.add('typeTitle');
        if (aircraftCols.containsKey('isSimulator')) aiCols.add('isSimulator');
        if (aiCols.isEmpty) {
          aircraftCache[id] = {};
          return {};
        }
        final aiRows = await db.query(
          'aircraft_items',
          columns: aiCols,
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (aiRows.isNotEmpty) row = aiRows.first;
      } catch (_) {}
      aircraftCache[id] = row;
      return row;
    }

    const chunkSize = 450;

    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(
          i, (i + chunkSize > ids.length) ? ids.length : i + chunkSize);
      final placeholders = List.filled(chunk.length, '?').join(',');

      final rows = await db.query(
        flightsTable,
        columns: cols,
        where: 'id IN ($placeholders)',
        whereArgs: chunk,
      );

      for (final r in rows) {
        final totalFlightCenti = (r['totalFlightCenti'] as int?) ?? 0;

        // Sec 6/7 direct (si existen y tienen valores)
        final se = (r['singleEngineCenti'] as int?) ?? 0;
        final me = (r['multiEngineCenti'] as int?) ?? 0;
        final tp = (r['turbopropCenti'] as int?) ?? 0;
        final tj = (r['turbojetCenti'] as int?) ?? 0;
        final lsa = (r['lsaCenti'] as int?) ?? 0;
        final heli = (r['helicopterCenti'] as int?) ?? 0;
        final gl = (r['gliderCenti'] as int?) ?? 0;
        final oth = (r['otherAircraftCenti'] as int?) ?? 0;
        final sim = (r['simulatorCenti'] as int?) ?? 0;

        final any6 = (se + me + tp + tj + lsa + heli + gl + oth) > 0;
        final any7 = sim > 0;

        if (any6) {
          out['singleEngineCenti'] = sumInt('singleEngineCenti', se);
          out['multiEngineCenti'] = sumInt('multiEngineCenti', me);
          out['turbopropCenti'] = sumInt('turbopropCenti', tp);
          out['turbojetCenti'] = sumInt('turbojetCenti', tj);
          out['lsaCenti'] = sumInt('lsaCenti', lsa);
          out['helicopterCenti'] = sumInt('helicopterCenti', heli);
          out['gliderCenti'] = sumInt('gliderCenti', gl);
          out['otherAircraftCenti'] = sumInt('otherAircraftCenti', oth);
        }
        if (any7) {
          out['simulatorCenti'] = sumInt('simulatorCenti', sim);
        }

        // Fallback Sec 6/7 desde aircraft_items (si no guardaron esas columnas)
        if (!any6 && !any7 && totalFlightCenti > 0) {
          final aid = r['aircraftItemId'] as int?;
          if (aid != null) {
            final ai = await getAircraft(aid);
            final typeTitle =
                (ai['typeTitle'] ?? '').toString().trim().toUpperCase();
            final isSim = (ai['isSimulator'] as int?) ?? 0;

            if (isSim == 1) {
              out['simulatorCenti'] =
                  sumInt('simulatorCenti', totalFlightCenti);
            } else {
              if (typeTitle.contains('MULTI')) {
                out['multiEngineCenti'] =
                    sumInt('multiEngineCenti', totalFlightCenti);
              } else if (typeTitle.contains('TURBOPROP')) {
                out['turbopropCenti'] =
                    sumInt('turbopropCenti', totalFlightCenti);
              } else if (typeTitle.contains('TURBOJET') ||
                  typeTitle.contains('JET')) {
                out['turbojetCenti'] =
                    sumInt('turbojetCenti', totalFlightCenti);
              } else if (typeTitle.contains('HELIC')) {
                out['helicopterCenti'] =
                    sumInt('helicopterCenti', totalFlightCenti);
              } else if (typeTitle.contains('GLIDER')) {
                out['gliderCenti'] = sumInt('gliderCenti', totalFlightCenti);
              } else {
                out['singleEngineCenti'] =
                    sumInt('singleEngineCenti', totalFlightCenti);
              }
              if (typeTitle.contains('LSA')) {
                out['lsaCenti'] = sumInt('lsaCenti', totalFlightCenti);
              }
            }
          }
        }

        // Sec 8
        out['condDayCenti'] =
            sumInt('condDayCenti', (r['condDayCenti'] as int?) ?? 0);
        out['condNightCenti'] =
            sumInt('condNightCenti', (r['condNightCenti'] as int?) ?? 0);
        out['condIFRCenti'] =
            sumInt('condIFRCenti', (r['condIFRCenti'] as int?) ?? 0);

        // Sec 9
        out['timeCrossCountryCenti'] = sumInt(
            'timeCrossCountryCenti', (r['timeCrossCountryCenti'] as int?) ?? 0);
        out['timeSoloCenti'] =
            sumInt('timeSoloCenti', (r['timeSoloCenti'] as int?) ?? 0);
        out['timePICCenti'] =
            sumInt('timePICCenti', (r['timePICCenti'] as int?) ?? 0);
        out['timeSICCenti'] =
            sumInt('timeSICCenti', (r['timeSICCenti'] as int?) ?? 0);
        out['timeInstructionRecCenti'] = sumInt('timeInstructionRecCenti',
            (r['timeInstructionRecCenti'] as int?) ?? 0);
        out['timeInstructorCenti'] = sumInt(
            'timeInstructorCenti', (r['timeInstructorCenti'] as int?) ?? 0);

        // Sec 10
        out['takeoffsDay'] =
            sumInt('takeoffsDay', (r['takeoffsDay'] as int?) ?? 0);
        out['takeoffsNight'] =
            sumInt('takeoffsNight', (r['takeoffsNight'] as int?) ?? 0);
        out['landingsDay'] =
            sumInt('landingsDay', (r['landingsDay'] as int?) ?? 0);
        out['landingsNight'] =
            sumInt('landingsNight', (r['landingsNight'] as int?) ?? 0);

        // Sec 11
        final apprN = (r['approachesNumber'] as int?) ?? 0;
        out['approachesNumber'] = sumInt('approachesNumber', apprN);

        int vfr = (out['approach_vfr'] ?? 0).toInt();
        int vor = (out['approach_vor'] ?? 0).toInt();
        int ndb = (out['approach_ndb'] ?? 0).toInt();
        int cat1 = (out['approach_cat1'] ?? 0).toInt();
        int cat2 = (out['approach_cat2'] ?? 0).toInt();
        int cat3 = (out['approach_cat3'] ?? 0).toInt();

        _accumulateApproachBuckets(
          rawType: r['approachesType'],
          count: apprN,
          onVfr: (n) => vfr += n,
          onVor: (n) => vor += n,
          onNdb: (n) => ndb += n,
          onCat1: (n) => cat1 += n,
          onCat2: (n) => cat2 += n,
          onCat3: (n) => cat3 += n,
        );

        out['approach_vfr'] = vfr;
        out['approach_vor'] = vor;
        out['approach_ndb'] = ndb;
        out['approach_cat1'] = cat1;
        out['approach_cat2'] = cat2;
        out['approach_cat3'] = cat3;
      }
    }

    return out;
  }

  Future<Map<String, num>> _readPreviousTotalsAsFlightKeys() async {
    final db = await DBHelper.getDB();

    // tabla de TotalsPage
    const table = 'previous_totals';

    // si no existe o no hay fila, devuelve vacío
    final exists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    if (exists.isEmpty) return <String, num>{};

    final rows = await db.query(table, limit: 1);
    if (rows.isEmpty) return <String, num>{};

    final r = rows.first;

    int toCenti(Object? v) {
      final n = (v is num) ? v : num.tryParse(v?.toString() ?? '') ?? 0;
      return (n * 100).round();
    }

    int toInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return <String, num>{
      // Sec 06/07 (REAL -> centi)
      'singleEngineCenti': toCenti(r['singleEngine']),
      'multiEngineCenti': toCenti(r['multiEngine']),
      'turbopropCenti': toCenti(r['turboprop']),
      'turbojetCenti': toCenti(r['turbojet']),
      'lsaCenti': toCenti(r['lsa']),
      'helicopterCenti': toCenti(r['helicopter']),
      'gliderCenti': toCenti(r['glider']),
      'otherAircraftCenti': toCenti(r['otherAircraft']),
      'simulatorCenti': toCenti(r['simulator']),

      // Sec 08
      'condDayCenti': toCenti(r['condDay']),
      'condNightCenti': toCenti(r['condNight']),
      'condIFRCenti': toCenti(r['condIFR']),

      // Sec 09
      'timeCrossCountryCenti': toCenti(r['timeCrossCountry']),
      'timeSoloCenti': toCenti(r['timeSolo']),
      'timePICCenti': toCenti(r['timePIC']),
      'timeSICCenti': toCenti(r['timeCopilot']),
      'timeInstructionRecCenti': toCenti(r['timeInstruction']),
      'timeInstructorCenti': toCenti(r['timeInstructor']),

      // Sec 10 (enteros)
      'takeoffsDay': toInt(r['takeoffsDay']),
      'takeoffsNight': toInt(r['takeoffsNight']),
      'landingsDay': toInt(r['landingsDay']),
      'landingsNight': toInt(r['landingsNight']),

      // Sec 11 (enteros)
      'approachesNumber': toInt(r['approachesNumber']),
    };
  }

  void _accumulateApproachBuckets({
    required Object? rawType,
    required int count,
    required void Function(int) onVfr,
    required void Function(int) onVor,
    required void Function(int) onNdb,
    required void Function(int) onCat1,
    required void Function(int) onCat2,
    required void Function(int) onCat3,
  }) {
    if (count <= 0 || rawType == null) return;
    final s = rawType.toString().trim();
    if (s.isEmpty) return;

    // Compat: puede venir como JSON array
    if (s.startsWith('[') && s.endsWith(']')) {
      try {
        final decoded = json.decode(s);
        if (decoded is List) {
          for (final item in decoded) {
            _accumulateApproachBuckets(
              rawType: item,
              count: count,
              onVfr: onVfr,
              onVor: onVor,
              onNdb: onNdb,
              onCat1: onCat1,
              onCat2: onCat2,
              onCat3: onCat3,
            );
          }
          return;
        }
      } catch (_) {}
    }

    final up = s.toUpperCase();

    if (up == 'VFR') {
      onVfr(count);
      return;
    }
    if (up == 'VOR') {
      onVor(count);
      return;
    }
    if (up == 'NDB') {
      onNdb(count);
      return;
    }

    // ILS CAT I/II/III
    if (up.contains('ILS') && up.contains('CAT')) {
      if (up.contains('III')) {
        onCat3(count);
      } else if (up.contains('II')) {
        onCat2(count);
      } else {
        onCat1(count);
      }
      return;
    }

    // Si guardan "CAT I" sin ILS, lo interpretamos igual
    if (up.contains('CAT')) {
      if (up.contains('III')) {
        onCat3(count);
      } else if (up.contains('II')) {
        onCat2(count);
      } else if (up.contains('I')) {
        onCat1(count);
      }
    }
  }

  double _asHours(num v) {
    // Compat: si viene como int asumimos centi-horas (xx.xx * 100).
    if (v is int) return v / 100.0;
    return v.toDouble();
  }

  // FIX: sin recursión / sin errores
  String _t(BuildContext context, String key) {
    final l = AppLocalizations.of(context);
    final v = l.t(key);
    // fallback simple si la key no existe y devuelve la misma key
    return (v == key) ? key : v;
  }

  String _page2(int pageIndex) => pageIndex.toString().padLeft(2, '0');

  String _fmtDecimal(num v, {int decimals = 2}) {
    final isNeg = v < 0;
    final abs = v.abs().toDouble();
    final pow = _pow10(decimals);
    final scaled = (abs * pow).round();
    final intPart = scaled ~/ pow;
    final fracPart = scaled % pow;

    final intStr = _groupThousands(intPart);
    final fracStr = fracPart.toString().padLeft(decimals, '0');

    return '${isNeg ? '-' : ''}$intStr,$fracStr';
  }

  int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  String _groupThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final remaining = s.length - i;
      buf.write(s[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buf.write('.');
      }
    }
    return buf.toString();
  }

  String _fmtCount(num v, {required bool large}) {
    // Enteros (sin formato 0000.000)
    return v.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final previous05Key = (widget.pageIndex == 1)
        ? 'total_previous_logbook'
        : 'total_previous_page';

    final prevRowLine1Key =
        (widget.pageIndex == 1) ? 'total_log_ant' : 'total_pag_ant';
    final prevRowLine2Key = '';
    // evita duplicar "PÁG. ANT" en páginas > 1

    final pilotNameShown = (_pilotName == null)
        ? ''
        : (_pilotName!.isEmpty ? '' : _pilotName!.trim());

    final headerStyle = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w800,
    );

    final headerTealStyle = TextStyle(
      color: AppColors.teal4,
      fontSize: 18,
      fontWeight: FontWeight.w900,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.teal3, width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.teal1.withOpacity(0.90),
              AppColors.teal2.withOpacity(0.90),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // ===== HEADER (fijo) =====
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    Text(_t(context, 'logs_mainlog_title').toUpperCase(),
                        style: headerStyle),
                    const SizedBox(width: 8),
                    Text(_page2(widget.pageIndex), style: headerTealStyle),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        pilotNameShown.isEmpty ? '' : pilotNameShown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _divider(),

              // ===== SECCIÓN 05 (fija) =====
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: _section05FlightTime(
                  context,
                  titleKey: ('flight_section_05_flight_time'),
                  row1LabelKey: ('total_page'),
                  row1Color: AppColors.teal5,
                  row1Value: _fmtDecimal(widget.totalPageFlightTime),
                  row2LabelKey: (previous05Key),
                  row2Color: AppColors.teal4,
                  row2Value: _fmtDecimal(widget.totalPreviousFlightTime),
                  row3LabelKey: ('total_to_date'),
                  row3Color: AppColors.teal3,
                  row3Value: _fmtDecimal(widget.totalToDateFlightTime),
                ),
              ),

              // ===== CONTENIDO VERTICAL (scroll) =====
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  child: Column(
                    children: [
                      _divider(),
                      _scrollableTotalsSection(
                        context,
                        titleKey: _t(context,
                            'flight_section_06_07_aircraft_type_and_sim_time'),
                        prevRowLine1Key: prevRowLine1Key,
                        prevRowLine2Key: prevRowLine2Key,
                        columns: const [
                          _TotalsColSpec(
                            labelKey: 'totals_single_engine_airplane',
                            dataKey: 'singleEngineCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_multi_engine_airplane',
                            dataKey: 'multiEngineCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_turboprop_airplane',
                            dataKey: 'turbopropCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_turbojet_airplane',
                            dataKey: 'turbojetCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_lsa_airplane',
                            dataKey: 'lsaCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_helicopter',
                            dataKey: 'helicopterCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_glider',
                            dataKey: 'gliderCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_other_aircraft',
                            dataKey: 'otherAircraftCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_flight_simulator',
                            dataKey: 'simulatorCenti',
                            format: _ValueFormat.decimal2,
                          ),
                        ],
                      ),
                      _divider(),
                      _scrollableTotalsSection(
                        context,
                        titleKey: 'flight_section_08_flight_conditions',
                        prevRowLine1Key: prevRowLine1Key,
                        prevRowLine2Key: prevRowLine2Key,
                        columns: const [
                          _TotalsColSpec(
                            labelKey: 'totals_condition_day',
                            dataKey: 'condDayCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_condition_night',
                            dataKey: 'condNightCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_condition_ifr',
                            dataKey: 'condIFRCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_time_cross_country',
                            dataKey: 'timeCrossCountryCenti',
                            format: _ValueFormat.decimal2,
                            dividerBefore: true,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_time_solo',
                            dataKey: 'timeSoloCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'pic_card',
                            dataKey: 'timePICCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_time_copilot',
                            dataKey: 'timeSICCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_time_instruction_received',
                            dataKey: 'timeInstructionRecCenti',
                            format: _ValueFormat.decimal2,
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_time_as_instructor',
                            dataKey: 'timeInstructorCenti',
                            format: _ValueFormat.decimal2,
                          ),
                        ],
                        rightTitleKey: 'flight_section_09_flight_time_types',
                      ),
                      _divider(),
                      _scrollableTotalsSection(
                        context,
                        titleKey: 'flight_section_10_tkof_landings',
                        prevRowLine1Key: prevRowLine1Key,
                        prevRowLine2Key: prevRowLine2Key,
                        columns: const [
                          _TotalsColSpec(
                            labelKey: 'totals_takeoffs_day',
                            dataKey: 'takeoffsDay',
                            format: _ValueFormat.count,
                            headerTop: 'totals_takeoffs_section',
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_takeoffs_night',
                            dataKey: 'takeoffsNight',
                            format: _ValueFormat.count,
                            headerTop: 'totals_takeoffs_section',
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_landings_day',
                            dataKey: 'landingsDay',
                            format: _ValueFormat.count,
                            headerTop: 'totals_landings_section',
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_landings_night',
                            dataKey: 'landingsNight',
                            format: _ValueFormat.count,
                            headerTop: 'totals_landings_section',
                          ),
                          _TotalsColSpec(
                            labelKey: 'totals_approaches_number',
                            dataKey: 'approachesNumber',
                            format: _ValueFormat.count,
                            dividerBefore: true,
                          ),
                          _TotalsColSpec(
                            labelKey: 'VFR',
                            dataKey: 'approach_vfr',
                            format: _ValueFormat.count,
                            isRawLabel: true,
                          ),
                          _TotalsColSpec(
                            labelKey: 'VOR',
                            dataKey: 'approach_vor',
                            format: _ValueFormat.count,
                            isRawLabel: true,
                          ),
                          _TotalsColSpec(
                            labelKey: 'NDB',
                            dataKey: 'approach_ndb',
                            format: _ValueFormat.count,
                            isRawLabel: true,
                          ),
                          _TotalsColSpec(
                            labelKey: 'CAT I',
                            dataKey: 'approach_cat1',
                            format: _ValueFormat.count,
                            isRawLabel: true,
                            headerTop: 'ILS',
                          ),
                          _TotalsColSpec(
                            labelKey: 'CAT II',
                            dataKey: 'approach_cat2',
                            format: _ValueFormat.count,
                            isRawLabel: true,
                            headerTop: 'ILS',
                          ),
                          _TotalsColSpec(
                            labelKey: 'CAT III',
                            dataKey: 'approach_cat3',
                            format: _ValueFormat.count,
                            isRawLabel: true,
                            headerTop: 'ILS',
                          ),
                        ],
                        rightTitleKey: 'flight_section_11_approaches',
                      ),
                    ],
                  ),
                ),
              ),

              // ===== BOTÓN ACEPTAR (fijo) =====
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.teal4, width: 1),
                        color: Colors.black.withOpacity(0.10),
                      ),
                      child: Text(
                        (() {
                          final v = l.t('accept');
                          return (v == 'accept') ? 'ACEPTAR' : v.toUpperCase();
                        })(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() =>
      Container(height: 1, color: AppColors.teal3.withOpacity(0.8));

  Widget _section05FlightTime(
    BuildContext context, {
    required String titleKey,
    required String row1LabelKey,
    required Color row1Color,
    required String row1Value,
    required String row2LabelKey,
    required Color row2Color,
    required String row2Value,
    required String row3LabelKey,
    required Color row3Color,
    required String row3Value,
  }) {
    final title = _t(context, titleKey).toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.teal4,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _kvRow(
          context,
          color: row1Color,
          labelKey: row1LabelKey,
          value: row1Value,
          valueStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        _kvRow(
          context,
          color: row2Color,
          labelKey: row2LabelKey,
          value: row2Value,
          valueStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        _kvRow(
          context,
          color: row3Color,
          labelKey: row3LabelKey,
          value: row3Value,
          valueStyle: const TextStyle(
            color: AppColors.teal4,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _kvRow(
    BuildContext context, {
    required Color color,
    required String labelKey,
    required String value,
    required TextStyle valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Row(
        children: [
          Container(width: 10, height: 25, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t(context, labelKey).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }

  Widget _scrollableTotalsSection(
    BuildContext context, {
    required String titleKey,
    required String prevRowLine1Key,
    required String prevRowLine2Key,
    required List<_TotalsColSpec> columns,
    String? rightTitleKey,
  }) {
    final titleLeft = _t(context, titleKey).toUpperCase();
    final titleRight = (rightTitleKey == null)
        ? null
        : _t(context, rightTitleKey).toUpperCase();

    // Alturas (alineación con columna izquierda fija)
    const double groupTitleH =
        26; // título de sección dentro del scroll horizontal
    const double headerH = 40; // headers de columnas
    const double rowH = 24; // page / prev / totals
    const double leftW = 100;

    // Column width (constante como PDF)
    const double colW = 100;

    final totalHeaderH = groupTitleH + headerH;
    final totalHeight = totalHeaderH + rowH * 3;

    String labelFor(_TotalsColSpec c) {
      if (c.isRawLabel) return c.labelKey;
      return _t(context, c.labelKey).toUpperCase();
    }

    String? headerTopFor(_TotalsColSpec c) {
      if (c.headerTop == null) return null;
      // Heurística: si parece key (contiene '_'), la traducimos; si no, la usamos raw (ej: "ILS").
      final raw = c.headerTop!.trim();
      if (raw.isEmpty) return null;
      return raw.contains('_') ? _t(context, raw).toUpperCase() : raw;
    }

    String fmtRow(_TotalsColSpec c, _RowKind kind) {
      final pageV = _data.pageValue(c.dataKey);
      final prevV = _data.previousValue(c.dataKey);
      final totV = _data.totalsValue(c.dataKey);

      switch (c.format) {
        case _ValueFormat.decimal2:
          if (kind == _RowKind.page) return _fmtDecimal(_asHours(pageV));
          if (kind == _RowKind.previous) return _fmtDecimal(_asHours(prevV));
          return _fmtDecimal(_asHours(totV));
        case _ValueFormat.count:
          if (kind == _RowKind.page) return _fmtCount(pageV, large: false);
          if (kind == _RowKind.previous) return _fmtCount(prevV, large: true);
          return _fmtCount(totV, large: true);
      }
    }

    final prevLabel = (prevRowLine2Key.trim().isEmpty)
        ? _t(context, prevRowLine1Key)
        : '${_t(context, prevRowLine1Key)}\n${_t(context, prevRowLine2Key)}';

    // Split para dos títulos (08/09, 10/11): usamos el primer dividerBefore como frontera.
    int splitIndex = -1;
    if (titleRight != null) {
      splitIndex = columns.indexWhere((c) => c.dividerBefore);
      if (splitIndex <= 0) {
        // fallback: mitad
        splitIndex = columns.length ~/ 2;
      }
    }

    final group1Count = (titleRight == null) ? columns.length : splitIndex;
    final group2Count =
        (titleRight == null) ? 0 : (columns.length - splitIndex);
    final group1W = group1Count * colW;
    final group2W = group2Count * colW;

    final dividerColor = AppColors.teal4.withOpacity(0.65);

    // FIX: SOLO encabezados de sección alineados a la izquierda (06/07, 08, 09, 10, 11)
    Widget groupTitleRow() {
      const pad = EdgeInsets.symmetric(horizontal: 8);

      if (titleRight == null) {
        return SizedBox(
          height: groupTitleH,
          child: SizedBox(
            width: group1W,
            child: Padding(
              padding: pad,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  titleLeft,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: AppColors.teal4,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      }

      return SizedBox(
        height: groupTitleH,
        child: Row(
          children: [
            SizedBox(
              width: group1W,
              child: Padding(
                padding: pad,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    titleLeft,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: AppColors.teal4,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Container(width: 1, height: groupTitleH, color: dividerColor),
            SizedBox(
              width: group2W,
              child: Padding(
                padding: pad,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    titleRight,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: AppColors.teal4,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== columna izquierda fija =====
          SizedBox(
            width: leftW,
            height: totalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // barra vertical 3 colores alineada con filas
                Column(
                  children: [
                    SizedBox(height: totalHeaderH),
                    SizedBox(
                      width: 10,
                      height: rowH * 3,
                      child: Column(
                        children: [
                          SizedBox(
                              height: rowH,
                              child: Container(color: AppColors.teal5)),
                          SizedBox(
                              height: rowH,
                              child: Container(color: AppColors.teal4)),
                          SizedBox(
                              height: rowH,
                              child: Container(color: AppColors.teal3)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // textos
                SizedBox(
                  width: leftW - 18,
                  height: totalHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: totalHeaderH),
                      SizedBox(
                        height: rowH,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _t(context, 'page').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: rowH,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            prevLabel.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              height: 1.00,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: rowH,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _t(context, 'totals').toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.teal3,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ===== datos horizontales (títulos y columnas se mueven juntos) =====
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  groupTitleRow(),
                  Row(
                    children: [
                      for (int i = 0; i < columns.length; i++) ...[
                        if (columns[i].dividerBefore)
                          Container(
                            width: 0.5,
                            height: headerH + rowH * 3,
                            color: dividerColor,
                          ),
                        _totalsColumn(
                          width: colW,
                          headerHeight: headerH,
                          rowHeight: rowH,
                          headerTop: headerTopFor(columns[i]) ?? '',
                          header: labelFor(columns[i]),
                          pageValue: fmtRow(columns[i], _RowKind.page),
                          prevValue: fmtRow(columns[i], _RowKind.previous),
                          totalsValue: fmtRow(columns[i], _RowKind.totals),
                          drawRightBorder: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsColumn({
    required double width,
    required double headerHeight,
    required double rowHeight,
    required String headerTop,
    required String header,
    required String pageValue,
    required String prevValue,
    required String totalsValue,
    required bool drawRightBorder,
  }) {
    final borderColor = AppColors.teal3.withOpacity(0.7);

    Widget headerWidget() {
      if (headerTop.isEmpty) {
        return Text(
          header,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        );
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            headerTop,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.teal5,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 0),
          Text(
            header,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
              color: drawRightBorder ? borderColor : Colors.transparent,
              width: 0.5),
          left: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: headerHeight,
            child: Center(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: headerWidget())),
          ),
          SizedBox(
            height: rowHeight,
            child: Center(
              child: Text(
                pageValue,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          SizedBox(
            height: rowHeight,
            child: Center(
              child: Text(
                prevValue,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          SizedBox(
            height: rowHeight,
            child: Center(
              child: Text(
                totalsValue,
                style: TextStyle(
                  color: AppColors.teal4,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ValueFormat { decimal2, count }

enum _RowKind { page, previous, totals }

class _TotalsColSpec {
  const _TotalsColSpec({
    required this.labelKey,
    required this.dataKey,
    required this.format,
    this.isRawLabel = false,
    this.headerTop,
    this.dividerBefore = false,
  });

  final String labelKey; // key de l10n, o label crudo si isRawLabel=true
  final String dataKey; // key interna para [PopupTotalsData]
  final _ValueFormat format;

  final bool isRawLabel;

  /// Inserta divisor vertical (0.5) antes de esta columna.
  final bool dividerBefore;

  /// Para headers tipo ILS sobre CAT I/II/III.
  final String? headerTop;
}
