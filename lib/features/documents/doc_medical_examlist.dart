// lib/features/documents/doc_medical_examlist.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

import 'package:fly_logicd_logbook_app/features/documents/doc_medical_exam.dart';

class DocMedicalExamList extends StatefulWidget {
  const DocMedicalExamList({super.key});

  @override
  State<DocMedicalExamList> createState() => _DocMedicalExamListState();
}

class _DocMedicalExamListState extends State<DocMedicalExamList> {
  final List<Map<String, dynamic>> _medicalExams = [];
  bool _loading = true;

  static const String _medicalExamsTable = 'medical_exams';

  @override
  void initState() {
    super.initState();
    _loadMedicalExamsFromDb();
  }

  // ================== DB HELPERS ==================

  Future<void> _ensureMedicalExamsTableExists() async {
    final db = await DBHelper.getDB();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_medicalExamsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        examLabel TEXT,
        examName TEXT,
        medicalDecisionDate TEXT,
        examDate TEXT,
        expiryDate TEXT,
        country TEXT,
        countryFlag TEXT,
        authorityCode TEXT,
        authorityName TEXT,
        medicalClass TEXT,
        observations TEXT,
        createdAt TEXT
      )
    ''');
  }

  Future<void> _loadMedicalExamsFromDb() async {
    final db = await DBHelper.getDB();
    await _ensureMedicalExamsTableExists();

    final rows = await db.query(
      _medicalExamsTable,
      orderBy: 'createdAt DESC',
    );

    setState(() {
      _medicalExams
        ..clear()
        ..addAll(rows.map((r) {
          final dynamic rawId = r['id'];
          final int id =
              rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

          final String label = (r['examLabel'] as String? ?? '').trim();

          final String authorityCode =
              (r['authorityCode'] as String? ?? '').trim();
          final String authorityName =
              (r['authorityName'] as String? ?? '').trim();

          final String authorityToShow;
          if (authorityCode.isNotEmpty) {
            authorityToShow = authorityCode;
          } else if (authorityName.isNotEmpty) {
            // simple fallback: first non-empty word
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
            'label': label.isEmpty ? 'Medical exam' : label,
            'authorityCode': authorityToShow,
            'authorityName': authorityName,
            'countryFlag': countryFlag,
            'expiryDate': expiryDateStr,
          };
        }));
      _loading = false;
    });
  }

  // ================== NAVIGATION ==================

  Future<void> _openMedicalExamFile({int? examId}) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DocMedicalExam(examId: examId),
      ),
    );

    if (changed == true) {
      await _loadMedicalExamsFromDb();
    }
  }

  // ================== MAIN UI ==================

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BaseScaffold(
      appBar: CustomAppBar(
        title: t.t("medical_exams"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _medicalExams.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/licenses.svg',
                          height: 45,
                          colorFilter: ColorFilter.mode(
                            isDark ? AppColors.teal5 : AppColors.teal1,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.t("no_medical_exams_yet"),
                          style: AppTextStyles.subtitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.t(
                            "tap_the_+_button_to_add_a_new_medical_exam",
                          ),
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _medicalExams.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final exam = _medicalExams[i];
                      return _buildMedicalExamRow(context, exam);
                    },
                  ),
      ),
      floatingActionButton: ButtonStyles.squareAddButton(
        context: context,
        onTap: () => _openMedicalExamFile(),
      ),
    );
  }

  // ================== ROW ==================

  Widget _buildMedicalExamRow(
    BuildContext context,
    Map<String, dynamic> exam,
  ) {
    final l = AppLocalizations.of(context);

    final String label = exam['label'] as String? ?? 'Medical exam';
    final int id = exam['id'] as int? ?? 0;

    final String authorityCode = exam['authorityCode'] as String? ?? '';
    final String countryFlag = exam['countryFlag'] as String? ?? '';
    final String expiryIso = exam['expiryDate'] as String? ?? '';

    final _ExpiryInfo expiryInfo = _buildExpiryInfo(expiryIso, context);

    return ButtonStyles.infoButtonTwo(
      context: context,
      code: label,
      onTap: () => _openMedicalExamFile(examId: id),
      authorityLabel: l.t("authority"),
      authorityValue: authorityCode,
      authorityFlagEmoji: countryFlag,
      expiryLabel: l.t("expiry"),
      expiryText: expiryInfo.text,
      expiryStatusColor: expiryInfo.color,
    );
  }

  // ================== EXPIRY CALCULATION ==================

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

// Small holder for text + color
class _ExpiryInfo {
  final String text;
  final Color color;

  const _ExpiryInfo({
    required this.text,
    required this.color,
  });
}
