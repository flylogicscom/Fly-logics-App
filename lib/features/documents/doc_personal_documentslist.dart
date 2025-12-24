import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

import 'package:fly_logicd_logbook_app/features/documents/doc_personal_documents.dart';

class DocPersonalDocumentsList extends StatefulWidget {
  const DocPersonalDocumentsList({super.key});

  @override
  State<DocPersonalDocumentsList> createState() =>
      _DocPersonalDocumentsListState();
}

class _DocPersonalDocumentsListState extends State<DocPersonalDocumentsList> {
  final List<Map<String, dynamic>> _personalDocs = [];
  bool _loading = true;

  static const String _personalDocsTable = 'personal_documents';

  @override
  void initState() {
    super.initState();
    _loadPersonalDocsFromDb();
  }

  // ================== DB HELPERS ==================

  Future<void> _ensurePersonalDocsTableExists() async {
    final db = await DBHelper.getDB();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_personalDocsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        documentLabel TEXT,
        docType TEXT,
        country TEXT,
        countryFlag TEXT,
        issueDate TEXT,
        expiryDate TEXT,
        observations TEXT,
        createdAt TEXT
      )
    ''');
  }

  Future<void> _loadPersonalDocsFromDb() async {
    final db = await DBHelper.getDB();
    await _ensurePersonalDocsTableExists();

    final rows = await db.query(
      _personalDocsTable,
      orderBy: 'createdAt DESC',
    );

    setState(() {
      _personalDocs
        ..clear()
        ..addAll(rows.map((r) {
          final dynamic rawId = r['id'];
          final int id =
              rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

          final String documentLabel =
              (r['documentLabel'] as String? ?? '').trim();
          final String docType = (r['docType'] as String? ?? '').trim();

          // Lo que mostramos en el pill de la izquierda:
          // primero la etiqueta; si está vacía, usamos el tipo.
          String codeToShow = documentLabel.isNotEmpty
              ? documentLabel
              : (docType.isNotEmpty ? docType : '---');

          final String countryName =
              (r['country'] as String? ?? '').trim(); // para "authorityValue"
          final String countryFlag =
              (r['countryFlag'] as String? ?? '').trim(); // emoji
          final String expiryDateStr =
              (r['expiryDate'] as String? ?? '').trim();

          return {
            'id': id,
            'code': codeToShow,
            'countryName': countryName,
            'countryFlag': countryFlag,
            'expiryDate': expiryDateStr,
          };
        }));
      _loading = false;
    });
  }

  // ================== NAVEGACIÓN ==================

  Future<void> _openPersonalDocFile({int? docId}) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DocPersonalDocuments(docId: docId),
      ),
    );

    if (changed == true) {
      await _loadPersonalDocsFromDb();
    }
  }

  // ================== UI PRINCIPAL ==================

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return BaseScaffold(
      appBar: CustomAppBar(
        title: t.t("personal_documents"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _personalDocs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/licenses.svg', // reutilizado
                          height: 45,
                          colorFilter: const ColorFilter.mode(
                            AppColors.teal5,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.t("no_personal_documents_yet"),
                          style: AppTextStyles.subtitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.t(
                            "tap_the_+_button_to_add_a_new_personal_document",
                          ),
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _personalDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final doc = _personalDocs[i];
                      return _buildPersonalDocRow(context, doc);
                    },
                  ),
      ),
      floatingActionButton: ButtonStyles.squareAddButton(
        context: context,
        onTap: () => _openPersonalDocFile(),
      ),
    );
  }

  // ================== FILA ==================

  Widget _buildPersonalDocRow(
    BuildContext context,
    Map<String, dynamic> doc,
  ) {
    final l = AppLocalizations.of(context);

    final String code = doc['code'] as String? ?? '---';
    final int id = doc['id'] as int? ?? 0;

    final String countryName = doc['countryName'] as String? ?? '';
    final String countryFlag = doc['countryFlag'] as String? ?? '';
    final String expiryIso = doc['expiryDate'] as String? ?? '';

    final _ExpiryInfo expiryInfo = _buildExpiryInfo(expiryIso, context);

    // authorityLabel se mantiene como "Authority", pero mostramos país + bandera
    return ButtonStyles.infoButtonTwo(
      context: context,
      code: code,
      onTap: () => _openPersonalDocFile(docId: id),
      authorityLabel: l.t("authority"),
      authorityValue: countryName,
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
