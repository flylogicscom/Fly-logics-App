// lib/features/documents/doc_flight_licenseslist.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';
import 'package:fly_logicd_logbook_app/utils/country_data.dart' as cdata;

// OJO: este es el archivo real de detalle
import 'package:fly_logicd_logbook_app/features/documents/doc_flight_licenses.dart';

/// Info calculada de caducidad (texto + color del semáforo)
class _ExpiryInfo {
  final String text;
  final Color color;
  const _ExpiryInfo(this.text, this.color);
}

class DocFlightLicensesList extends StatefulWidget {
  const DocFlightLicensesList({super.key});

  @override
  State<DocFlightLicensesList> createState() => _DocFlightLicensesListState();
}

class _DocFlightLicensesListState extends State<DocFlightLicensesList> {
  static const String _licensesTable = 'flight_licenses';

  final List<Map<String, dynamic>> _licenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLicensesFromDb();
  }

  // =============== DB helpers ===============

  Future<void> _ensureLicensesTableExists() async {
    final db = await DBHelper.getDB();

    // Esquema alineado con doc_flight_licenses.dart
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_licensesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        licenseCode   TEXT,
        licenseTitle  TEXT,
        nameOnLicense TEXT,
        licenseNumber TEXT,
        issueDate     TEXT,
        expiryDate    TEXT,
        country       TEXT,
        countryFlag   TEXT,
        authorityCode TEXT,
        authorityName TEXT,
        observations  TEXT,
        createdAt     TEXT
      )
    ''');
  }

  Future<void> _loadLicensesFromDb() async {
    final db = await DBHelper.getDB();
    await _ensureLicensesTableExists();

    final rows = await db.query(
      _licensesTable,
      orderBy: 'createdAt DESC',
    );

    setState(() {
      _licenses
        ..clear()
        ..addAll(rows.map((r) {
          // id puede venir como int o String
          final dynamic rawId = r['id'];
          int id;
          if (rawId is int) {
            id = rawId;
          } else if (rawId is String) {
            id = int.tryParse(rawId) ?? 0;
          } else {
            id = 0;
          }

          final String code =
              ((r['licenseCode'] as String?) ?? '').trim().isEmpty
                  ? '---'
                  : (r['licenseCode'] as String).trim();

          String countryName = (r['country'] as String? ?? '').trim();
          String flagEmoji = (r['countryFlag'] as String? ?? '').trim();
          String authorityCode =
              (r['authorityCode'] as String? ?? '').trim(); // acrónimo
          String authorityName =
              (r['authorityName'] as String? ?? '').trim(); // nombre largo

          // Completar desde CountryData si faltan datos
          if (countryName.isNotEmpty) {
            cdata.CountryData? match;
            for (final c in cdata.allCountryData) {
              if (c.name == countryName) {
                match = c;
                break;
              }
            }
            if (match != null) {
              if (authorityCode.isEmpty &&
                  match.authorityAcronym.trim().isNotEmpty) {
                authorityCode = match.authorityAcronym.trim();
              }
              if (authorityName.isEmpty &&
                  match.authorityOfficialName.trim().isNotEmpty) {
                authorityName = match.authorityOfficialName.trim();
              }
              if (flagEmoji.isEmpty && match.flagEmoji.trim().isNotEmpty) {
                flagEmoji = match.flagEmoji.trim();
              }
            }
          }

          final String authorityText =
              authorityCode.isNotEmpty ? authorityCode : authorityName;

          // Caducidad
          final expiryStr = (r['expiryDate'] as String? ?? '').trim();
          DateTime? expiryDate;
          if (expiryStr.isNotEmpty) {
            try {
              expiryDate = DateTime.parse(expiryStr);
            } catch (_) {}
          }
          final expiryInfo = _buildExpiryInfo(expiryDate);

          return {
            'id': id,
            'code': code,
            'authorityText': authorityText,
            'flagEmoji': flagEmoji,
            'expiryText': expiryInfo.text,
            'expiryColor': expiryInfo.color,
          };
        }));
      _loading = false;
    });
  }

  _ExpiryInfo _buildExpiryInfo(DateTime? expiryDate) {
    if (expiryDate == null) {
      return const _ExpiryInfo('-', Colors.white38);
    }

    final now = DateTime.now();
    var diff = expiryDate.difference(now);
    if (diff.isNegative) diff = Duration.zero;

    final days = diff.inDays;

    Color color;
    if (days > 30) {
      color = Colors.greenAccent;
    } else if (days >= 10) {
      color = Colors.yellowAccent;
    } else {
      color = Colors.redAccent;
    }

    if (days == 0) {
      return _ExpiryInfo('0 días', color);
    }

    String text;

    if (days >= 365) {
      final years = days ~/ 365;
      final remDays = days % 365;
      final months = remDays ~/ 30;
      if (months > 0) {
        text = '$years año${years > 1 ? "s" : ""}, '
            '$months mes${months > 1 ? "es" : ""}';
      } else {
        text = '$years año${years > 1 ? "s" : ""}';
      }
    } else if (days >= 30) {
      final months = days ~/ 30;
      final remDays = days % 30;
      if (remDays > 0) {
        text = '$months mes${months > 1 ? "es" : ""}, '
            '$remDays día${remDays > 1 ? "s" : ""}';
      } else {
        text = '$months mes${months > 1 ? "es" : ""}';
      }
    } else if (days >= 7) {
      final weeks = days ~/ 7;
      final remDays = days % 7;
      if (remDays > 0) {
        text = '$weeks semana${weeks > 1 ? "s" : ""}, '
            '$remDays día${remDays > 1 ? "s" : ""}';
      } else {
        text = '$weeks semana${weeks > 1 ? "s" : ""}';
      }
    } else {
      text = '$days día${days > 1 ? "s" : ""}';
    }

    return _ExpiryInfo(text, color);
  }

  // =============== Navegación ===============

  Future<void> _openLicenseFile({int? licenseId}) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DocFlightLicenses(licenseId: licenseId),
      ),
    );

    if (changed == true) {
      await _loadLicensesFromDb();
    }
  }

  // =============== UI principal ===============

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return BaseScaffold(
      appBar: CustomAppBar(
        title: t.t("flight_licenses"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _licenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/licenses.svg',
                          height: 45,
                          colorFilter: const ColorFilter.mode(
                            AppColors.teal5,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.t("no_flight_licenses_yet"),
                          style: AppTextStyles.subtitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.t("tap_the_+_button_to_add_a_new_flight_license"),
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _licenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final license = _licenses[i];
                      return _buildLicenseRow(context, license);
                    },
                  ),
      ),
      floatingActionButton: ButtonStyles.squareAddButton(
        context: context,
        onTap: () => _openLicenseFile(),
      ),
    );
  }

  // =============== Fila ===============

  Widget _buildLicenseRow(
    BuildContext context,
    Map<String, dynamic> license,
  ) {
    final l = AppLocalizations.of(context);

    final String code = license['code'] as String? ?? '---';
    final String authorityText = license['authorityText'] as String? ?? '';
    final String flagEmoji = license['flagEmoji'] as String? ?? '';
    final String expiryText = license['expiryText'] as String? ?? '-';
    final Color expiryColor =
        (license['expiryColor'] as Color?) ?? Colors.white38;
    final int id = license['id'] as int;

    return ButtonStyles.infoButtonTwo(
      context: context,
      code: code,
      onTap: () => _openLicenseFile(licenseId: id),
      authorityLabel: l.t("authority"),
      authorityValue: authorityText, // ACRÓNIMO (DGAC, FAA…)
      authorityFlagEmoji: flagEmoji, // Bandera del país
      expiryLabel: l.t("expiry"),
      expiryText: expiryText,
      expiryStatusColor: expiryColor,
    );
  }
}
