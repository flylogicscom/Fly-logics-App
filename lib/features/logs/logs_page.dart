// lib/features/logs/logs_page.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
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
  int get _mainLogFlightsCount => 0;

  String? _totalsName;
  bool _totalsLocked = false;

  @override
  void initState() {
    super.initState();
    _loadTotalsMeta();
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
  void _openLogbooksList(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LogsPageList()),
    );
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
              label: '${t.t("logs_mainlog_title_01")} ($_mainLogFlightsCount)',
              onTap: () => _openLogbooksList(context),
              leftIconAsset: 'assets/icons/logbooks.svg',
              locked: false,
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
