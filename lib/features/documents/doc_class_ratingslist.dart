// lib/features/documents/doc_class_ratingslist.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

import 'package:fly_logicd_logbook_app/features/documents/doc_class_rating.dart';

class DocClassRatingsList extends StatefulWidget {
  const DocClassRatingsList({super.key});

  @override
  State<DocClassRatingsList> createState() => _DocClassRatingsListState();
}

class _DocClassRatingsListState extends State<DocClassRatingsList> {
  final List<Map<String, dynamic>> _classRatings = [];
  bool _loading = true;

  static const String _classRatingsTable = 'class_ratings';

  @override
  void initState() {
    super.initState();
    _loadClassRatingsFromDb();
  }

  // ================== DB HELPERS ==================

  Future<void> _ensureClassRatingsTableExists() async {
    final db = await DBHelper.getDB();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_classRatingsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        classCode TEXT,
        classTitle TEXT,
        number TEXT,
        country TEXT,
        countryFlag TEXT,
        authorityCode TEXT,
        authorityName TEXT,
        category TEXT,
        aircraftType TEXT,
        issueDate TEXT,
        expiryDate TEXT,
        observations TEXT,
        createdAt TEXT
      )
    ''');
  }

  Future<void> _loadClassRatingsFromDb() async {
    final db = await DBHelper.getDB();
    await _ensureClassRatingsTableExists();

    final rows = await db.query(
      _classRatingsTable,
      orderBy: 'createdAt DESC',
    );

    setState(() {
      _classRatings
        ..clear()
        ..addAll(rows.map((r) {
          final dynamic rawId = r['id'];
          final int id =
              rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

          final String code = (r['classCode'] as String? ?? '').trim();

          final String authorityCode =
              (r['authorityCode'] as String? ?? '').trim();
          final String authorityName =
              (r['authorityName'] as String? ?? '').trim();

          final String authorityToShow;
          if (authorityCode.isNotEmpty) {
            authorityToShow = authorityCode;
          } else if (authorityName.isNotEmpty) {
            // fallback simple: primera palabra del nombre largo
            authorityToShow = authorityName
                .split(' ')
                .firstWhere((e) => e.isNotEmpty, orElse: () => '');
          } else {
            authorityToShow = '';
          }

          final String countryFlag = (r['countryFlag'] as String? ?? '').trim();
          final String expiryDateStr =
              (r['expiryDate'] as String? ?? '').trim();

          return {
            'id': id,
            'code': code.isEmpty ? '---' : code,
            'authorityCode': authorityToShow,
            'authorityName': authorityName,
            'countryFlag': countryFlag,
            'expiryDate': expiryDateStr,
          };
        }));
      _loading = false;
    });
  }

  // ================== NAVEGACIÓN ==================

  Future<void> _openClassRatingFile({int? ratingId}) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DocClassRatings(ratingId: ratingId),
      ),
    );

    if (changed == true) {
      await _loadClassRatingsFromDb();
    }
  }

  // ================== UI PRINCIPAL ==================

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return BaseScaffold(
      appBar: CustomAppBar(
        title: t.t("class_ratings"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _classRatings.isEmpty
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
                          t.t("no_class_ratings_yet"),
                          style: AppTextStyles.subtitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.t(
                            "tap_the_+_button_to_add_a_new_class_rating",
                          ),
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _classRatings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final rating = _classRatings[i];
                      return _buildClassRatingRow(context, rating);
                    },
                  ),
      ),
      floatingActionButton: ButtonStyles.squareAddButton(
        context: context,
        onTap: () => _openClassRatingFile(),
      ),
    );
  }

  // ================== FILA ==================

  Widget _buildClassRatingRow(
    BuildContext context,
    Map<String, dynamic> rating,
  ) {
    final l = AppLocalizations.of(context);

    final String code = rating['code'] as String? ?? '---';
    final int id = rating['id'] as int? ?? 0;

    final String authorityCode = rating['authorityCode'] as String? ?? '';
    final String countryFlag = rating['countryFlag'] as String? ?? '';
    final String expiryIso = rating['expiryDate'] as String? ?? '';

    final _ExpiryInfo expiryInfo = _buildExpiryInfo(expiryIso, context);

    return ButtonStyles.infoButtonTwo(
      context: context,
      code: code,
      onTap: () => _openClassRatingFile(ratingId: id),
      authorityLabel: l.t("authority"),
      authorityValue: authorityCode,
      authorityFlagEmoji: countryFlag,
      expiryLabel: l.t("expiry"),
      expiryText: expiryInfo.text,
      expiryStatusColor: expiryInfo.color,
    );
  }

  // ================== CÁLCULO EXPIRY ==================

  _ExpiryInfo _buildExpiryInfo(String? expiryIso, BuildContext context) {
    if (expiryIso == null || expiryIso.trim().isEmpty) {
      return const _ExpiryInfo(text: '-', color: Colors.white38);
    }

    DateTime expiry;
    try {
      expiry = DateTime.parse(expiryIso);
    } catch (_) {
      return const _ExpiryInfo(text: '-', color: Colors.white38);
    }

    final now = DateTime.now();
    final diff = expiry.difference(now);
    int days = diff.inDays;

    if (days <= 0) {
      final lang = Localizations.localeOf(context).languageCode;
      String text;
      if (lang == 'es') {
        text = '0 días';
      } else if (lang == 'pt') {
        text = '0 dias';
      } else {
        text = '0 days';
      }
      return _ExpiryInfo(text: text, color: Colors.redAccent);
    }

    Color color;
    if (days > 30) {
      color = Colors.greenAccent.shade400;
    } else if (days >= 10) {
      color = Colors.amberAccent.shade200;
    } else {
      color = Colors.redAccent;
    }

    final text = _formatRemaining(expiry, context);
    return _ExpiryInfo(text: text, color: color);
  }

  String _formatRemaining(DateTime? expiry, BuildContext context) {
    if (expiry == null) return '-';

    final now = DateTime.now();
    var daysTotal = expiry.difference(now).inDays;
    if (daysTotal <= 0) {
      final lang = Localizations.localeOf(context).languageCode;
      if (lang == 'es') return '0 días';
      if (lang == 'pt') return '0 dias';
      return '0 days';
    }

    final lang = Localizations.localeOf(context).languageCode;

    int years = daysTotal ~/ 365;
    daysTotal %= 365;
    int months = daysTotal ~/ 30;
    daysTotal %= 30;
    int weeks = daysTotal ~/ 7;
    daysTotal %= 7;
    int days = daysTotal;

    String part(
      int value,
      String enSing,
      String enPl,
      String esSing,
      String esPl,
      String ptSing,
      String ptPl,
    ) {
      if (value <= 0) return '';
      final useSing = value == 1;
      switch (lang) {
        case 'es':
          return '$value ${useSing ? esSing : esPl}';
        case 'pt':
          return '$value ${useSing ? ptSing : ptPl}';
        default:
          return '$value ${useSing ? enSing : enPl}';
      }
    }

    String result;
    if (years > 0) {
      result = [
        part(years, 'year', 'years', 'año', 'años', 'ano', 'anos'),
        part(months, 'month', 'months', 'mes', 'meses', 'mês', 'meses'),
      ].where((s) => s.isNotEmpty).join(', ');
    } else if (months > 0) {
      result = [
        part(months, 'month', 'months', 'mes', 'meses', 'mês', 'meses'),
        part(days, 'day', 'days', 'día', 'días', 'dia', 'dias'),
      ].where((s) => s.isNotEmpty).join(', ');
    } else if (weeks > 0) {
      result = [
        part(weeks, 'week', 'weeks', 'semana', 'semanas', 'semana', 'semanas'),
        part(days, 'day', 'days', 'día', 'días', 'dia', 'dias'),
      ].where((s) => s.isNotEmpty).join(', ');
    } else {
      result = part(days, 'day', 'days', 'día', 'días', 'dia', 'dias');
    }

    return result.isEmpty ? '-' : result;
  }
}

// Pequeña clase para devolver texto + color
class _ExpiryInfo {
  final String text;
  final Color color;

  const _ExpiryInfo({
    required this.text,
    required this.color,
  });
}
