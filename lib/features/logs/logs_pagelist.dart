// lib/features/logs/logs_pagelist.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
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

  // Filtros
  int? _filterYear;
  int? _filterMonth; // 1..12
  final _filterRegCtrl = TextEditingController();
  final _filterIdCtrl = TextEditingController();
  final _filterPicCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
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
      if (!mounted) return;
      setState(() {
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
      final d = a.startDate.compareTo(b.startDate);
      if (d != 0) return d;
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

  Future<void> _openFilters() async {
    final years = _all.map((e) => e.year).toSet().toList()..sort();
    final l = AppLocalizations.of(context);

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
                          labelText: l.t("aircraft_registration"),
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: tempId,
                        decoration: InputDecoration(
                          labelText: l.t("aircraft_identifier"),
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: tempPic,
                        decoration: InputDecoration(
                          labelText: l.t("pilot_in_command"),
                          labelStyle: const TextStyle(color: Colors.white),
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

    tempReg.dispose();
    tempId.dispose();
    tempPic.dispose();
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

    return BaseScaffold(
      appBar: CustomAppBar(
        title: l.t("logs"),
        rightIconPath: 'assets/icons/logoback.svg',
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
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

                                      return Padding(
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
                                          bigValueFontSize: 15,
                                          orderFontSize: 15,
                                          flagFontSize: 10,
                                          aircraftFontSize: 12,

                                          onTap: () async {
                                            final Object? rawId = f.id;

                                            final int? flightId = rawId is int
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
                                                builder: (_) => NewFlightPage(
                                                    flightId: flightId),
                                              ),
                                            );

                                            if (changed == true) {
                                              await _reload();
                                            }
                                          },
                                        ),
                                      );
                                    },
                                    childCount: entry.value.length,
                                  ),
                                ),
                                const SliverToBoxAdapter(
                                    child: SizedBox(height: 8)),
                              ],
                            ],
                          ),
                        ),
                      ),
          ),
        ],
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

                const SizedBox(width: 5),

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

                const SizedBox(width: 4),

                // Separador
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.20)),
                const SizedBox(width: 10),

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

                const SizedBox(width: 10),
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

                const SizedBox(width: 10),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.20)),
                const SizedBox(width: 10),

                // (7-8) Desde
                Expanded(
                  flex: 3,
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
                            const SizedBox(width: 6),
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
