// lib/features/logs/logs_page.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

// Estas dos páginas deben existir
import 'package:fly_logicd_logbook_app/features/logs/totalspage.dart';
import 'package:fly_logicd_logbook_app/features/logs/logs_pagelist.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  int _mainLogFlightsCount = 0;

  bool _mainLogLocked = true;

  static const String _mainLogStateTable = 'mainlog_state';

  String? _totalsName;
  bool _totalsLocked = false;

  @override
  void initState() {
    super.initState();
    _loadTotalsMeta();
    _loadMainLogMeta();
  }

  Future<void> _loadMainLogMeta() async {
    // 1) lee candado desde la MISMA tabla/columna que usa logs_pagelist en _saveFlightsLockState
    final db = await DBHelper.getDB();

    // Si ya tienes _mainLogStateTable definido, úsalo aquí para que NO quede “unused”
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $_mainLogStateTable (
      id INTEGER PRIMARY KEY,
      isLocked INTEGER
    )
  ''');

    bool locked = false;
    final stateRows = await db.query(
      _mainLogStateTable,
      where: 'id = ?',
      whereArgs: const [1],
      limit: 1,
    );
    if (stateRows.isNotEmpty) {
      final v = stateRows.first['isLocked'];
      if (v is int) locked = v != 0;
      if (v is num) locked = v.toInt() != 0;
    }

    // 2) conteo de vuelos (usa el mismo loader que LogsPageList)
    int count = 0;
    try {
      final flights = await DBHelper.getFlightsForLogsList();
      count = flights.length;
    } catch (_) {
      count = 0;
    }

    if (!mounted) return;
    setState(() {
      _mainLogLocked = locked;
      _mainLogFlightsCount = count;
    });
  }

  // Carga nombre y estado de candado desde previous_totals
  Future<void> _loadTotalsMeta() async {
    final db = await DBHelper.getDB();

    // Comprobar si existe la tabla
    final exists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      ['previous_totals'],
    );

    if (exists.isEmpty) {
      if (!mounted) return;
      setState(() {
        _totalsName = null;
        _totalsLocked = false;
      });
      return;
    }

    final rows = await db.query('previous_totals', limit: 1);
    if (!mounted) return;

    if (rows.isEmpty) {
      setState(() {
        _totalsName = null;
        _totalsLocked = false;
      });
    } else {
      final r = rows.first;
      final name = r['name'] as String?;
      final isLockedVal = r['isLocked'];
      bool locked = false;
      if (isLockedVal is int) {
        locked = isLockedVal != 0;
      } else if (isLockedVal is num) {
        locked = isLockedVal.toInt() != 0;
      }
      setState(() {
        _totalsName = name;
        _totalsLocked = locked;
      });
    }
  }

  // Navega al “Totals logbook”
  Future<void> _openTotalsLog(BuildContext context) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TotalsPage()),
    );
    if (saved == true) {
      await _loadTotalsMeta();
    }
  }

  // Navega a la lista de bitácoras
  Future<void> _openLogbooksList(BuildContext context) async {
    final result = await Navigator.of(context).push<Map<String, Object?>>(
      MaterialPageRoute(builder: (_) => const LogsPageList()),
    );

    if (!mounted) return;

    if (result != null) {
      final lockedVal = result['locked'];
      final countVal = result['count'];
      setState(() {
        if (lockedVal is bool) _mainLogLocked = lockedVal;
        if (countVal is int) _mainLogFlightsCount = countVal;
        if (countVal is num) _mainLogFlightsCount = countVal.toInt();
      });
    }

    await _loadMainLogMeta();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    // Nombre mostrado en el botón de totales
    final String totalsLabel;
    if (_totalsName != null && _totalsName!.trim().isNotEmpty) {
      totalsLabel = _totalsName!.trim();
    } else {
      totalsLabel = t.t("logs_totals_title_01");
    }

    // ignore: no_leading_underscores_for_local_identifiers
    final int _countDisplay =
        _mainLogFlightsCount > 999 ? 999 : _mainLogFlightsCount;
    // ignore: no_leading_underscores_for_local_identifiers
    final String _countText = _countDisplay.toString().padLeft(3, '0');
    return BaseScaffold(
      appBar: CustomAppBar(
        title: t.t("logs"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ====== BLOQUE 1: TOTALES DE TODA LA VIDA ======
            ButtonStyles.infoButtonOne(
              context: context,
              label: totalsLabel,
              onTap: () => _openTotalsLog(context),
              leftIconAsset: 'assets/icons/logbooks.svg',
              locked: _totalsLocked, // candado vinculado con TotalsPage
            ),

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Text(
                t.t("logs_totals_description"),
                style: AppTextStyles.body.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ====== BLOQUE 2: BITÁCORA PRINCIPAL ======
            ButtonStyles.infoButtonOne(
              context: context,
              label: t.t("logs_mainlog_title"),
              onTap: () => _openLogbooksList(context),
              leftIconAsset: 'assets/icons/logbooks.svg',
              locked: _mainLogLocked,
              rightIconWidget1: Text(
                _countText,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.teal2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Botón + como pill
            ButtonStyles.pillAdd(
              context: context,
              label: t.t("logs_mainlog_add"),
              onTap: () => _openLogbooksList(context),
            ),

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Text(
                t.t("logs_mainlog_description"),
                style: AppTextStyles.body.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
