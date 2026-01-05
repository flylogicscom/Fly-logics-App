// lib/features/logs/logs_pagelist.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

// Abre la pantalla de edición del vuelo
import 'package:fly_logicd_logbook_app/features/newflight/newflight.dart';

/// Modelo “UI-friendly” para pintar el botón.
class LogbookFlight {
  final Object? id;

  final DateTime startDate;
  final DateTime? endDate;

  /// Formato "HH:MM" (ej: "02:35")
  final String blockTime;

  /// ICAO salida (ej: "SCEL")
  final String fromIcao;

  /// Emoji bandera (ej: "🇨🇱")
  final String fromFlagEmoji;

  /// Matrícula (ej: "PI-CUS-00")
  final String aircraftRegistration;

  /// Identificador aeronave (para filtro)
  final String aircraftIdentifier;

  /// Piloto al mando (para filtro)
  final String pic;

  /// Para ordenar en empate de fecha (más antiguo primero)
  final DateTime createdAt;

  /// Número visible "01", "02"...
  final String orderNumber;

  LogbookFlight({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.blockTime,
    required this.fromIcao,
    required this.fromFlagEmoji,
    required this.aircraftRegistration,
    required this.aircraftIdentifier,
    required this.pic,
    required this.createdAt,
    required this.orderNumber,
  });

  bool get isMultiDay {
    if (endDate == null) return false;
    return startDate.year != endDate!.year ||
        startDate.month != endDate!.month ||
        startDate.day != endDate!.day;
  }

  String get dayMonthText {
    final dd = startDate.day.toString().padLeft(2, '0');
    final mm = startDate.month.toString().padLeft(2, '0');
    return isMultiDay ? '$dd/$mm+' : '$dd/$mm';
  }

  int get year => startDate.year;
}

/// Pantalla lista de logs con:
/// - buscador
/// - filtros (mes/año, matrícula, identificador, PIC)
/// - año “sticky” al scrollear
/// - scrollbar lateral
class LogsPageList extends StatefulWidget {
  /// Si NO se provee loader, la pantalla carga desde DBHelper.getFlightsForLogsList().
  final Future<List<LogbookFlight>> Function()? loader;

  const LogsPageList({
    super.key,
    this.loader,
  });

  @override
  State<LogsPageList> createState() => _LogsPageListState();
}

class _LogsPageListState extends State<LogsPageList> {
  final _searchCtrl = TextEditingController();

  bool _loading = false;
  List<LogbookFlight> _all = <LogbookFlight>[];

  bool _flightsLocked = true;

  static const String _mainLogStateTable = 'mainlog_state';
  static const String _mainLogSortTable = 'mainlog_day_sort';

  Map<int, int> _sortIndexById = <int, int>{};

  // === NUEVO (solo para mejorar drag preview) ===
  Map<int, int>? _sortIndexSnapshot;
  int? _lastPreviewDraggedId;
  int? _lastPreviewTargetId;

  // Filtros
  int? _filterYear;
  int? _filterMonth; // 1..12
  final _filterRegCtrl = TextEditingController();
  final _filterIdCtrl = TextEditingController();
  final _filterPicCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFlightsLockState();
    _loadBaselineTotalsFlightTime(); // <-- AÑADIR
    _reload();
  }

  int? _asIntId(Object? rawId) {
    if (rawId == null) return null;
    if (rawId is int) return rawId;
    if (rawId is num) return rawId.toInt();
    return int.tryParse(rawId.toString());
  }

  String _flightKey(LogbookFlight f) {
    final intId = _asIntId(f.id);
    if (intId != null) return 'id:$intId';

    final s = f.id?.toString();
    if (s != null && s.trim().isNotEmpty) return 'sid:${s.trim()}';

    return 'ts:${f.startDate.millisecondsSinceEpoch}_${f.createdAt.millisecondsSinceEpoch}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _ensureMainLogStateTable() async {
    final db = await DBHelper.getDB();
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $_mainLogStateTable (
      id INTEGER PRIMARY KEY,
      isLocked INTEGER
    )
  ''');
  }

  Future<void> _loadFlightsLockState() async {
    bool locked = _flightsLocked;
    try {
      final db = await DBHelper.getDB();
      await _ensureMainLogStateTable();
      final rows = await db.query(
        _mainLogStateTable,
        where: 'id = ?',
        whereArgs: const [1],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final v = rows.first['isLocked'];
        if (v is int) locked = v != 0;
        if (v is num) locked = v.toInt() != 0;
      }
    } catch (_) {
      // no-op
    }

    if (!mounted) return;
    setState(() => _flightsLocked = locked);
  }

  Future<void> _saveFlightsLockState() async {
    try {
      final db = await DBHelper.getDB();
      await _ensureMainLogStateTable();
      await db.rawInsert(
        'INSERT OR REPLACE INTO $_mainLogStateTable (id, isLocked) VALUES (1, ?)',
        [_flightsLocked ? 1 : 0],
      );
    } catch (_) {
      // no-op
    }
  }

  Future<void> _ensureSortTable() async {
    final db = await DBHelper.getDB();
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $_mainLogSortTable (
      flightId INTEGER PRIMARY KEY,
      sortIndex INTEGER
    )
  ''');
  }

  Future<Map<int, int>> _loadSortIndexes(List<LogbookFlight> flights) async {
    final ids = <int>[];
    for (final f in flights) {
      final id = _asIntId(f.id);
      if (id != null) ids.add(id);
    }
    if (ids.isEmpty) return <int, int>{};

    try {
      final db = await DBHelper.getDB();
      await _ensureSortTable();

      final placeholders = List.filled(ids.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT flightId, sortIndex FROM $_mainLogSortTable WHERE flightId IN ($placeholders)',
        ids,
      );

      final map = <int, int>{};
      for (final r in rows) {
        final fid = r['flightId'];
        final idx = r['sortIndex'];
        if (fid is int && idx is int) map[fid] = idx;
        if (fid is num && idx is num) map[fid.toInt()] = idx.toInt();
      }
      return map;
    } catch (_) {
      return <int, int>{};
    }
  }

  Future<void> _saveDaySortOrder(
      DateTime day, List<LogbookFlight> ordered) async {
    try {
      final db = await DBHelper.getDB();
      await _ensureSortTable();

      await db.transaction((txn) async {
        for (int i = 0; i < ordered.length; i++) {
          final id = _asIntId(ordered[i].id);
          if (id == null) continue;
          await txn.rawInsert(
            'INSERT OR REPLACE INTO $_mainLogSortTable (flightId, sortIndex) VALUES (?, ?)',
            [id, i],
          );
        }
      });
    } catch (_) {
      // no-op
    }
  }

  Map<String, Object?> _buildPopResult() {
    return <String, Object?>{
      'locked': _flightsLocked,
      'count': _all.length,
    };
  }

  // === CAMBIO: pop robusto (devuelve resultado y evita bloqueos por navigator anidado) ===
  Future<bool> _popWithResult() async {
    final result = _buildPopResult();

    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(result);
      return true;
    }

    final root = Navigator.of(context, rootNavigator: true);
    if (root.canPop()) {
      root.pop(result);
      return true;
    }

    return false;
  }

  Future<void> _openNewFlight() async {
    if (_flightsLocked) return;

    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewFlightPage()),
    );

    if (changed == true) {
      await _reload();
    }
  }

  Future<void> _reorderWithinSameDay(
      LogbookFlight dragged, LogbookFlight target) async {
    if (_flightsLocked) return;
    // si tú ya agregaste _isFilterActive, deja esta línea:
    // if (_isFilterActive) return;

    if (!_isSameDay(dragged.startDate, target.startDate)) return;

    final draggedKey = _flightKey(dragged);
    final targetKey = _flightKey(target);
    if (draggedKey == targetKey) return;

    final day = dragged.startDate;

    // lista del día en el orden actual visible
    final dayFlights = _all.where((f) => _isSameDay(f.startDate, day)).toList();
    final from = dayFlights.indexWhere((f) => _flightKey(f) == draggedKey);
    final to = dayFlights.indexWhere((f) => _flightKey(f) == targetKey);
    if (from < 0 || to < 0 || from == to) return;

    final moved = dayFlights.removeAt(from);
    dayFlights.insert(to, moved);

    // actualiza sortIndex en memoria (para que SE VEA el cambio)
    final newSort = Map<int, int>.from(_sortIndexById);
    for (int i = 0; i < dayFlights.length; i++) {
      final id = _asIntId(dayFlights[i].id);
      if (id != null) newSort[id] = i;
    }

    if (!mounted) return;
    setState(() {
      _sortIndexById = newSort;
      _all = _computeOrdering(_all);
    });

    // persiste (sin reload)
    await _saveDaySortOrder(day, dayFlights);

    // limpia estado de preview si lo estás usando
    _sortIndexSnapshot = null;
    _lastPreviewDraggedId = null;
    _lastPreviewTargetId = null;
  }

  // === SUBTOTALES (cada 10 vuelos) ===
  double _baselineTotalsFlightTime =
      0.0; // viene de TotalsPage (tabla previous_totals)

  Future<void> _loadBaselineTotalsFlightTime() async {
    try {
      final db = await DBHelper.getDB();
      // TotalsPage usa: table = 'previous_totals', col = 'totalFlightTime'
      final rows = await db.query('previous_totals',
          columns: ['totalFlightTime'], limit: 1);
      final v = rows.isEmpty ? null : rows.first['totalFlightTime'];
      _baselineTotalsFlightTime = _parseDecimalLikeTotals(v);
    } catch (_) {
      _baselineTotalsFlightTime = 0.0;
    }
    if (!mounted) return;
    setState(() {});
  }

  bool _isFilterActive = false;

  bool _hasAnyFilter() {
    return (_filterYear != null) ||
        (_filterMonth != null) ||
        _filterRegCtrl.text.trim().isNotEmpty ||
        _filterIdCtrl.text.trim().isNotEmpty ||
        _filterPicCtrl.text.trim().isNotEmpty;
  }

  double _parseDecimalLikeTotals(Object? value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final t = value.toString().trim();
    if (t.isEmpty) return 0.0;
    // igual lógica que TotalsPage: quita miles '.' y usa ',' como decimal
    final s = t.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  double _parseBlockTimeToHours(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0.0;

    // Soporta HH:MM
    if (t.contains(':')) {
      final parts = t.split(':');
      if (parts.length == 2) {
        final hh = int.tryParse(parts[0].trim()) ?? 0;
        final mm = int.tryParse(parts[1].trim()) ?? 0;
        return hh + (mm / 60.0);
      }
    }

    // Soporta formato decimal tipo "5,00"
    return _parseDecimalLikeTotals(t);
  }

  String _formatDecimalLikeTotals(double value) {
    final String s = value.toStringAsFixed(2);
    final parts = s.split('.');
    String intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      buffer.write(intPart[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }
    final withDots = buffer.toString().split('').reversed.join();
    return '$withDots,$decPart';
  }

  void _openSubtotalsPopup(int pageIndex) {
    // Todo: definir más tarde (por ahora no hace nada)
  }

  Widget _buildSubtotalsSeparator({
    required AppLocalizations l,
    required int pageIndex,
    required double pageTime,
    required double totalsTime,
  }) {
    final pageStr = pageIndex.toString().padLeft(2, '0');

    final lineColor = AppColors.teal4.withOpacity(0.65);
    final vLineColor = AppColors.teal4.withOpacity(0.50);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: () => _openSubtotalsPopup(pageIndex),
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Container(height: 1, color: lineColor)),
            const SizedBox(width: 10),
            IntrinsicWidth(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.teal1, AppColors.teal2],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: lineColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${l.t("page")} ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      pageStr,
                      style: TextStyle(
                        color: AppColors.teal4,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(width: 0.5, height: 18, color: vLineColor),
                    const SizedBox(width: 5),
                    Text(
                      '${l.t("time")} ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatDecimalLikeTotals(pageTime),
                      style: const TextStyle(
                        color: AppColors.teal4,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(width: 0.5, height: 18, color: vLineColor),
                    const SizedBox(width: 5),
                    Text(
                      '${l.t("totals")} ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatDecimalLikeTotals(totalsTime),
                      style: const TextStyle(
                        color: AppColors.teal4,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: lineColor)),
          ],
        ),
      ),
    );
  }

  // === NUEVO: preview en vivo mientras se arrastra (para que se mueva el que se desplaza) ===
  void _previewReorderWithinSameDay(
      LogbookFlight dragged, LogbookFlight target) {
    if (_flightsLocked) return;
    if (!_isSameDay(dragged.startDate, target.startDate)) return;

    final draggedId = _asIntId(dragged.id);
    final targetId = _asIntId(target.id);
    if (draggedId == null || targetId == null) return;
    if (draggedId == targetId) return;

    if (_lastPreviewDraggedId == draggedId &&
        _lastPreviewTargetId == targetId) {
      return;
    }
    _lastPreviewDraggedId = draggedId;
    _lastPreviewTargetId = targetId;

    final day = dragged.startDate;

    final dayFlights = _all.where((f) => _isSameDay(f.startDate, day)).toList();
    final from = dayFlights.indexWhere((f) => _asIntId(f.id) == draggedId);
    final to = dayFlights.indexWhere((f) => _asIntId(f.id) == targetId);
    if (from < 0 || to < 0 || from == to) return;

    final moved = dayFlights.removeAt(from);
    dayFlights.insert(to, moved);

    final newSort = Map<int, int>.from(_sortIndexById);
    for (int i = 0; i < dayFlights.length; i++) {
      final id = _asIntId(dayFlights[i].id);
      if (id != null) newSort[id] = i;
    }

    setState(() {
      _sortIndexById = newSort;
      _all = _computeOrdering(_all);
    });
  }

  // === NUEVO: restaurar si se cancela el drag ===
  void _restorePreviewIfNeeded() {
    final snap = _sortIndexSnapshot;
    if (snap == null) return;

    setState(() {
      _sortIndexById = snap;
      _all = _computeOrdering(_all);
    });

    _sortIndexSnapshot = null;
    _lastPreviewDraggedId = null;
    _lastPreviewTargetId = null;
  }

  Widget _wrapReorderableItem(
      BuildContext context, LogbookFlight flight, Widget child) {
    if (_flightsLocked || _isFilterActive) return child;

    String flightKey(LogbookFlight f) {
      final intId = _asIntId(f.id);
      if (intId != null) return 'id:$intId';

      final s = f.id?.toString();
      if (s != null && s.trim().isNotEmpty) return 'sid:${s.trim()}';

      // fallback estable si id no existe
      return 'ts:${f.startDate.millisecondsSinceEpoch}_${f.createdAt.millisecondsSinceEpoch}';
    }

    return DragTarget<LogbookFlight>(
      onWillAccept: (dragged) {
        if (dragged == null) return false;
        if (_flightsLocked) return false;
        return _isSameDay(dragged.startDate, flight.startDate) &&
            flightKey(dragged) != flightKey(flight);
      },

      // === NUEVO: preview mientras se mueve ===
      onMove: (details) => _previewReorderWithinSameDay(details.data, flight),
      onAccept: (dragged) => _reorderWithinSameDay(dragged, flight),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<LogbookFlight>(
          data: flight,
          // === NUEVO: snapshot para revertir si se cancela ===
          onDragStarted: () {
            _sortIndexSnapshot = Map<int, int>.from(_sortIndexById);
            _lastPreviewDraggedId = null;
            _lastPreviewTargetId = null;
          },
          onDragCompleted: () {
            _sortIndexSnapshot = null;
            _lastPreviewDraggedId = null;
            _lastPreviewTargetId = null;
          },
          onDraggableCanceled: (_, __) {
            _restorePreviewIfNeeded();
          },
          feedback: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(
                width: MediaQuery.of(context).size.width - 10,
              ),
              child: child,
            ),
          ),
          // === CAMBIO: no dejar “hueco invisible” durante drag (mejora percepción de desplazamiento) ===
          childWhenDragging: Opacity(opacity: 0.0, child: child),
          child: child,
        );
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _filterRegCtrl.dispose();
    _filterIdCtrl.dispose();
    _filterPicCtrl.dispose();
    super.dispose();
  }

  static String _formatBlockTime({String? text, int? minutes}) {
    final t = (text ?? '').trim();
    if (t.isNotEmpty) return t;
    final m = minutes ?? 0;
    final hh = (m ~/ 60).toString().padLeft(2, '0');
    final mm = (m % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static LogbookFlight _fromRow(Map<String, Object?> row) {
    final startMs = row['startDate'] as int? ?? 0;
    final endMs = row['endDate'] as int?;
    final createdMs = row['createdAt'] as int? ?? startMs;

    final fromIcao = (row['fromIcao'] as String?)?.trim() ?? '';
    final fromFlag = (row['fromFlagEmoji'] as String?)?.trim() ?? '';

    final reg = (row['aircraftRegistration'] as String?)?.trim() ?? '';
    final ident = (row['aircraftIdentifier'] as String?)?.trim() ?? '';
    final pic = (row['pic'] as String?)?.trim() ?? '';

    final bt = _formatBlockTime(
      text: row['blockTimeText'] as String?,
      minutes: row['blockTimeMinutes'] as int?,
    );

    return LogbookFlight(
      id: row['id'],
      startDate: DateTime.fromMillisecondsSinceEpoch(startMs),
      endDate:
          endMs == null ? null : DateTime.fromMillisecondsSinceEpoch(endMs),
      blockTime: bt,
      fromIcao: fromIcao,
      fromFlagEmoji: fromFlag,
      aircraftRegistration: reg,
      aircraftIdentifier: ident,
      pic: pic,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
      orderNumber: '00', // se calcula después
    );
  }

  Future<List<LogbookFlight>> _defaultLoader() async {
    final rows = await DBHelper.getFlightsForLogsList();
    return rows.map(_fromRow).toList();
  }

  Future<void> _reload() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final loaded = await (widget.loader ?? _defaultLoader).call();
      final sortMap = await _loadSortIndexes(loaded);
      if (!mounted) return;
      setState(() {
        _sortIndexById = sortMap;
        _all = _computeOrdering(loaded);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Orden:
  /// - fecha más antigua => orderNumber "01"
  /// - si misma fecha => createdAt más antiguo => número menor
  List<LogbookFlight> _computeOrdering(List<LogbookFlight> flights) {
    final copy = List<LogbookFlight>.from(flights);

    copy.sort((a, b) {
      final aDay =
          DateTime(a.startDate.year, a.startDate.month, a.startDate.day);
      final bDay =
          DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
      final d = aDay.compareTo(bDay);
      if (d != 0) return d;

      if (_isSameDay(a.startDate, b.startDate)) {
        final aId = _asIntId(a.id);
        final bId = _asIntId(b.id);
        final aIdx = aId == null ? null : _sortIndexById[aId];
        final bIdx = bId == null ? null : _sortIndexById[bId];

        if (aIdx != null || bIdx != null) {
          if (aIdx == null) return 1;
          if (bIdx == null) return -1;
          final c = aIdx.compareTo(bIdx);
          if (c != 0) return c;
        }
      }

      return a.createdAt.compareTo(b.createdAt);
    });

    return List<LogbookFlight>.generate(copy.length, (i) {
      final n = (i + 1).toString().padLeft(2, '0');
      final f = copy[i];
      return LogbookFlight(
        id: f.id,
        startDate: f.startDate,
        endDate: f.endDate,
        blockTime: f.blockTime,
        fromIcao: f.fromIcao,
        fromFlagEmoji: f.fromFlagEmoji,
        aircraftRegistration: f.aircraftRegistration,
        aircraftIdentifier: f.aircraftIdentifier,
        pic: f.pic,
        createdAt: f.createdAt,
        orderNumber: n,
      );
    });
  }

  List<LogbookFlight> _applyFilters(List<LogbookFlight> flights) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final regQ = _filterRegCtrl.text.trim().toLowerCase();
    final idQ = _filterIdCtrl.text.trim().toLowerCase();
    final picQ = _filterPicCtrl.text.trim().toLowerCase();

    bool matchesText(LogbookFlight f) {
      if (q.isEmpty) return true;
      final hay = <String>[
        f.fromIcao,
        f.aircraftRegistration,
        f.aircraftIdentifier,
        f.pic,
        f.blockTime,
        f.dayMonthText,
        f.year.toString(),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }

    bool matchesFilters(LogbookFlight f) {
      if (_filterYear != null && f.startDate.year != _filterYear) return false;
      if (_filterMonth != null && f.startDate.month != _filterMonth) {
        return false;
      }

      if (regQ.isNotEmpty &&
          !f.aircraftRegistration.toLowerCase().contains(regQ)) {
        return false;
      }

      if (idQ.isNotEmpty && !f.aircraftIdentifier.toLowerCase().contains(idQ)) {
        return false;
      }

      if (picQ.isNotEmpty && !f.pic.toLowerCase().contains(picQ)) return false;

      return true;
    }

    return flights.where((f) => matchesText(f) && matchesFilters(f)).toList();
  }

  Future<String?> _pickPilotFromUsedFlights(
      BuildContext context, List<String> pilots) async {
    final l = AppLocalizations.of(context);

    if (pilots.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t("no_results"))),
        );
      }
      return null;
    }

    final TextEditingController searchCtrl = TextEditingController();
    final String? picked = await showDialog<String>(
      context: context,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (dctx, setD) {
            final String q = searchCtrl.text.trim().toLowerCase();
            final List<String> filtered = q.isEmpty
                ? pilots
                : pilots.where((p) => p.toLowerCase().contains(q)).toList();

            return AlertDialog(
              backgroundColor: AppColors.teal2,
              title: Text(
                l.t("crew_role_pic_name"),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setD(() {}),
                      decoration: InputDecoration(
                        hintText: l.t("search"),
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                l.t("no_results"),
                                style: const TextStyle(color: Colors.white),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final String name = filtered[i];
                                return ListTile(
                                  title: Text(
                                    name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onTap: () => Navigator.of(dctx).pop(name),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dctx).pop(''),
                  child: Text(
                    l.t("clear"),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dctx).pop(null),
                  child: const Text(
                    "Cerrar",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    searchCtrl.dispose();
    return picked;
  }

  Future<void> _openFilters() async {
    final years = _all.map((e) => e.year).toSet().toList()..sort();
    final l = AppLocalizations.of(context);

    final List<String> pilotOptions = _all
        .map((e) => e.pic.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    int? tempYear = _filterYear;
    int? tempMonth = _filterMonth;
    final tempReg = TextEditingController(text: _filterRegCtrl.text);
    final tempId = TextEditingController(text: _filterIdCtrl.text);
    final tempPic = TextEditingController(text: _filterPicCtrl.text);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.teal1, AppColors.teal2],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (ctx, setSB) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 14,
                    bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.filter_alt_outlined,
                              color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            l.t("filters"),
                            style:
                                Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setSB(() {
                                tempYear = null;
                                tempMonth = null;
                                tempReg.clear();
                                tempId.clear();
                                tempPic.clear();
                              });
                            },
                            child: Text(
                              l.t("clear"),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              value: tempYear,
                              dropdownColor: AppColors.teal4,
                              decoration: InputDecoration(
                                labelText: l.t("year"),
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                              ),
                              items: <DropdownMenuItem<int?>>[
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(l.t("all")),
                                ),
                                ...years.map(
                                  (y) => DropdownMenuItem<int?>(
                                    value: y,
                                    child: Text(y.toString()),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setSB(() => tempYear = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              value: tempMonth,
                              dropdownColor: AppColors.teal4,
                              decoration: InputDecoration(
                                labelText: l.t("month"),
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                              ),
                              items: <DropdownMenuItem<int?>>[
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(l.t("all")),
                                ),
                                ...List<int>.generate(12, (i) => i + 1).map(
                                  (m) => DropdownMenuItem<int?>(
                                    value: m,
                                    child: Text(m.toString().padLeft(2, '0')),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setSB(() => tempMonth = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: tempReg,
                        decoration: InputDecoration(
                          labelText: l.t("aircraft_registration_label"),
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final upper = newValue.text.toUpperCase();
                            return newValue.text == upper
                                ? newValue
                                : newValue.copyWith(
                                    text: upper, selection: newValue.selection);
                          }),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: tempId,
                        decoration: InputDecoration(
                          labelText: l.t("aircraft_identifier_label"),
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]')),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final upper = newValue.text.toUpperCase();
                            return newValue.text == upper
                                ? newValue
                                : newValue.copyWith(
                                    text: upper, selection: newValue.selection);
                          }),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          if (_flightsLocked) return;
                          final String? picked =
                              await _pickPilotFromUsedFlights(
                                  ctx, pilotOptions);
                          if (picked == null) return;
                          setSB(() => tempPic.text = picked);
                        },
                        child: IgnorePointer(
                          child: TextField(
                            controller: tempPic,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: l.t("crew_role_pic_name"),
                              labelStyle: const TextStyle(color: Colors.white),
                              suffixIcon:
                                  const Icon(Icons.search, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _filterYear = tempYear;
                                  _filterMonth = tempMonth;
                                  _filterRegCtrl.text = tempReg.text;
                                  _filterIdCtrl.text = tempId.text;
                                  _filterPicCtrl.text = tempPic.text;
                                  _isFilterActive = _hasAnyFilter();
                                });
                                Navigator.pop(ctx);
                              },
                              child: Text(l.t("apply")),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      tempReg.dispose();
      tempId.dispose();
      tempPic.dispose();
    });
  }

  Map<int, List<LogbookFlight>> _groupByYear(List<LogbookFlight> flights) {
    final map = <int, List<LogbookFlight>>{};
    for (final f in flights) {
      map.putIfAbsent(f.year, () => <LogbookFlight>[]).add(f);
    }
    final keys = map.keys.toList()..sort(); // asc
    return {for (final k in keys) k: map[k]!};
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final filtered = _applyFilters(_all);
    final grouped = _groupByYear(filtered);
    final visible = filtered;

// clave estable para mapear posición visible (id si existe; fallback si no)
    int flightKey(LogbookFlight f) =>
        _asIntId(f.id) ??
        (f.startDate.millisecondsSinceEpoch ^
            f.createdAt.millisecondsSinceEpoch);

// índice visible por vuelo
    final indexByKey = <int, int>{};
    final times = <double>[];
    for (int i = 0; i < visible.length; i++) {
      indexByKey[flightKey(visible[i])] = i;
      times.add(_parseBlockTimeToHours(visible[i].blockTime));
    }

// prefix sum: prefix[i] = suma de 0..i-1
    final prefix = List<double>.filled(times.length + 1, 0.0);
    for (int i = 0; i < times.length; i++) {
      prefix[i + 1] = prefix[i] + times[i];
    }

    return WillPopScope(
      onWillPop: () async {
        final popped = await _popWithResult();
        return !popped; // si no pudo hacer pop, deja que el sistema lo intente
      },
      child: BaseScaffold(
        appBar: CustomAppBar(
          title: l.t("logs"),
          rightIconPath: 'assets/icons/logoback.svg',
          // === CAMBIO: usar pop con resultado (y fallback) ===
          onRightIconTap: () {
            _popWithResult();
          },
        ),
        body: Stack(children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          labelText: l.t("search"),
                          // ✅ el "título" pasa a ser "subtítulo" al enfocar/escribir (label flotante)
                          floatingLabelBehavior: FloatingLabelBehavior.auto,

                          prefixIcon: const Icon(Icons.search),

                          // ✅ borde 1px tipo "cuadro de texto"
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              width: 1,
                              color: AppColors.teal4.withOpacity(0.70),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              width: 1,
                              color: AppColors.teal4.withOpacity(0.70),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              width: 1,
                              color: AppColors.teal4,
                            ),
                          ),

                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _openFilters,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.teal1, AppColors.teal2],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.filter_alt_outlined,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () async {
                        setState(() => _flightsLocked = !_flightsLocked);
                        await _saveFlightsLockState();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.teal1, AppColors.teal2],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _flightsLocked ? Icons.lock : Icons.lock_open,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(child: Text(l.t("no_results")))
                        : Scrollbar(
                            thumbVisibility: true,
                            interactive: true,
                            child: RefreshIndicator(
                              onRefresh: _reload,
                              child: CustomScrollView(
                                slivers: [
                                  for (final entry in grouped.entries) ...[
                                    SliverPersistentHeader(
                                      pinned: true,
                                      delegate: _YearHeaderDelegate(
                                        yearText: entry.key.toString(),
                                      ),
                                    ),
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (ctx, i) {
                                          final f = entry.value[i];
                                          final int pos =
                                              indexByKey[flightKey(f)] ?? -1;
                                          final bool showSubtotals =
                                              !_isFilterActive &&
                                                  pos >= 0 &&
                                                  ((pos + 1) % 10 == 0);

                                          final int pageIndex = showSubtotals
                                              ? ((pos ~/ 10) + 1)
                                              : 0;
                                          final int pageStart = showSubtotals
                                              ? ((pageIndex - 1) * 10)
                                              : 0;
                                          final int pageEnd = showSubtotals
                                              ? (((pageStart + 10) <=
                                                      visible.length)
                                                  ? (pageStart + 10)
                                                  : visible.length)
                                              : 0;

                                          final double pageTime = showSubtotals
                                              ? (prefix[pageEnd] -
                                                  prefix[pageStart])
                                              : 0.0;
                                          final double totalsTime =
                                              showSubtotals
                                                  ? (_baselineTotalsFlightTime +
                                                      prefix[pageEnd])
                                                  : 0.0;

                                          final item = Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            child: LogbookInfoButton(
                                              orderNumber: f.orderNumber,
                                              dateTitle: l.t("date"),
                                              dateText: f.dayMonthText,
                                              blockTitle: l.t("time"),
                                              blockTimeText: f.blockTime,
                                              fromTitle: l.t("flight_from"),
                                              fromFlagEmoji: f.fromFlagEmoji,
                                              fromIcao: f.fromIcao,
                                              aircraftTitle: l.t("airplane"),
                                              aircraftRegistration:
                                                  f.aircraftRegistration,

                                              // Ajustes opcionales (si quieres activarlos aquí):
                                              titleFontSize: 10,
                                              valueFontSize: 12,
                                              bigValueFontSize: 14,
                                              orderFontSize: 14,
                                              flagFontSize: 11,
                                              aircraftFontSize: 12,

                                              onTap: () async {
                                                if (_flightsLocked) return;
                                                final Object? rawId = f.id;

                                                final int? flightId = rawId
                                                        is int
                                                    ? rawId
                                                    : (rawId is num
                                                        ? rawId.toInt()
                                                        : int.tryParse(
                                                            rawId?.toString() ??
                                                                ''));

                                                if (flightId == null) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          '${l.t("error")}: id inválido'),
                                                    ),
                                                  );

                                                  return;
                                                }

                                                final bool? changed =
                                                    await Navigator.push<bool>(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        NewFlightPage(
                                                            flightId: flightId),
                                                  ),
                                                );

                                                if (changed == true) {
                                                  await _reload();
                                                }
                                              },
                                            ),
                                          );
                                          final Widget itemWithSubtotal =
                                              Column(
                                            children: [
                                              item,
                                              if (showSubtotals)
                                                _buildSubtotalsSeparator(
                                                  l: l,
                                                  pageIndex: pageIndex,
                                                  pageTime: pageTime,
                                                  totalsTime: totalsTime,
                                                ),
                                            ],
                                          );

                                          final idStr = (f.id ??
                                                  f.startDate
                                                      .millisecondsSinceEpoch)
                                              .toString();
                                          return KeyedSubtree(
                                            key: ValueKey('flight_$idStr'),
                                            child: _wrapReorderableItem(
                                                context, f, itemWithSubtotal),
                                          );
                                        },
                                        childCount: entry.value.length,
                                      ),
                                    ),
                                    const SliverToBoxAdapter(
                                        child: SizedBox(height: 8)),
                                  ],
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 90),
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Opacity(
              opacity: _flightsLocked ? 0.45 : 1.0,
              child: AbsorbPointer(
                absorbing: _flightsLocked,
                child: ButtonStyles.squareAddButton(
                  context: context,
                  onTap: _openNewFlight,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _YearHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String yearText;

  _YearHeaderDelegate({required this.yearText});

  @override
  double get minExtent => 34;

  @override
  double get maxExtent => 34;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.teal5.withOpacity(0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.teal4, width: 1),
        ),
        child: Text(
          yearText,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _YearHeaderDelegate oldDelegate) {
    return oldDelegate.yearText != yearText;
  }
}

/// Botón barra horizontal (10 "espacios" conceptuales) con degradado teal1/teal2.
class LogbookInfoButton extends StatelessWidget {
  final String orderNumber;

  final String dateTitle;
  final String dateText;

  final String blockTitle;
  final String blockTimeText;

  final String fromTitle;
  final String fromFlagEmoji;
  final String fromIcao;

  final String aircraftTitle;
  final String aircraftRegistration;

  final VoidCallback onTap;

  // ===== NUEVO: tamaños opcionales =====
  final double? titleFontSize; // títulos: Date / Block / From / Airplane
  final double? valueFontSize; // valores normales (ej: fromIcao)
  final double? bigValueFontSize; // valores grandes (dateText, blockTimeText)
  final double? orderFontSize; // número de orden
  final double? flagFontSize; // emoji bandera
  final double? aircraftFontSize; // matrícula

  const LogbookInfoButton({
    super.key,
    required this.orderNumber,
    required this.dateTitle,
    required this.dateText,
    required this.blockTitle,
    required this.blockTimeText,
    required this.fromTitle,
    required this.fromFlagEmoji,
    required this.fromIcao,
    required this.aircraftTitle,
    required this.aircraftRegistration,
    required this.onTap,
    this.titleFontSize,
    this.valueFontSize,
    this.bigValueFontSize,
    this.orderFontSize,
    this.flagFontSize,
    this.aircraftFontSize,
  });

  TextStyle _safe(TextStyle? s, TextStyle fallback) => s ?? fallback;

  Widget _title(BuildContext context, String t) {
    final base = _safe(
      Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.teal5.withOpacity(0.85),
            fontWeight: FontWeight.w600,
          ),
      TextStyle(
        color: Colors.white.withOpacity(0.85),
        fontWeight: FontWeight.w600,
        fontSize: titleFontSize ?? 11,
      ),
    );

    return Text(
      t,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          titleFontSize == null ? base : base.copyWith(fontSize: titleFontSize),
    );
  }

  Widget _value(BuildContext context, Widget child) {
    final base = _safe(
      Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
      const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );

    final styled =
        valueFontSize == null ? base : base.copyWith(fontSize: valueFontSize);
    return DefaultTextStyle(style: styled, child: child);
  }

  TextStyle _bigValueStyle(BuildContext context) {
    final base = _safe(
      Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
      const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
    );
    return bigValueFontSize == null
        ? base
        : base.copyWith(fontSize: bigValueFontSize);
  }

  TextStyle _orderStyle(BuildContext context) {
    final base = _safe(
      Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.teal4,
            fontWeight: FontWeight.w900,
          ),
      const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
    );
    return orderFontSize == null
        ? base
        : base.copyWith(fontSize: orderFontSize);
  }

  TextStyle _aircraftStyle(BuildContext context) {
    final base = _safe(
      Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
      const TextStyle(
          color: AppColors.white, fontWeight: FontWeight.w900, fontSize: 14),
    );
    return aircraftFontSize == null
        ? base
        : base.copyWith(fontSize: aircraftFontSize);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.teal1, AppColors.teal2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.teal4.withOpacity(0.65),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: Row(
              children: [
                // (1) Número en plataforma
                Container(
                  width: 40,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.teal2.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.teal4, width: 1),
                  ),
                  child: Text(orderNumber, style: _orderStyle(context)),
                ),

                const SizedBox(width: 3),

                // (2) Logo
                SizedBox(
                  width: 15,
                  height: 15,
                  child: SvgPicture.asset(
                    'assets/icons/logo.svg',
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),

                const SizedBox(width: 3),

                // Separador
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.20)),
                const SizedBox(width: 7),

                // (3-4) Fecha
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(context, dateTitle),
                      const SizedBox(height: 2),
                      _value(
                        context,
                        Text(dateText, style: _bigValueStyle(context)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 2),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.20)),
                const SizedBox(width: 10),

                // (5-6) Tiempo de bloque
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(context, blockTitle),
                      const SizedBox(height: 2),
                      _value(
                        context,
                        Text(blockTimeText, style: _bigValueStyle(context)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.20)),
                const SizedBox(width: 10),

                // (7-8) Desde
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(context, fromTitle),
                      const SizedBox(height: 2),
                      _value(
                        context,
                        Row(
                          children: [
                            Text(
                              fromFlagEmoji.isEmpty ? '🏳️' : fromFlagEmoji,
                              style: TextStyle(fontSize: flagFontSize ?? 18),
                            ),
                            const SizedBox(width: 1),
                            Flexible(
                              child: Text(
                                fromIcao,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.20)),
                const SizedBox(width: 10),

                // (9-10) Aeronave
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(context, aircraftTitle),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.teal4.withOpacity(0.60),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          aircraftRegistration.isEmpty
                              ? '-'
                              : aircraftRegistration,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _aircraftStyle(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
