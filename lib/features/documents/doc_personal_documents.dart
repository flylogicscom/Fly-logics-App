// lib/features/documents/doc_personal_documents.dart

import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/section_container.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/popwindow.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';
import 'package:fly_logicd_logbook_app/utils/country_data.dart' as cdata;

class DocPersonalDocuments extends StatefulWidget {
  final int? docId; // null = new, not null = edit

  const DocPersonalDocuments({super.key, this.docId});

  @override
  State<DocPersonalDocuments> createState() => _DocPersonalDocumentsState();
}

class _DocPersonalDocumentsState extends State<DocPersonalDocuments> {
  static const String _personalDocsTable = 'personal_documents';

  // Campos
  final _documentLabelCtrl =
      TextEditingController(); // "Etiqueta del documento"
  final _docTypeCtrl = TextEditingController(); // "Tipo"
  final _countryCtrl = TextEditingController(); // País + bandera
  cdata.CountryData? _selectedCountry;
  String? _countryFlag;

  final _issueDateCtrl = TextEditingController(); // Emisión
  final _expiryDateCtrl = TextEditingController(); // Caducidad
  DateTime? _issueDate;
  DateTime? _expiryDate;

  final _observationsCtrl = TextEditingController(); // Observaciones

  bool _loading = true;
  bool _saving = false;

  // ================== AUTO FORMATO ==================
  bool _formatting = false;

  static final RegExp _wordRe =
      RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ]+(?:[’'\-][A-Za-zÀ-ÖØ-öø-ÿ]+)*");
  static final RegExp _letterRe = RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ]");

  int _clampSel(int v, int len) {
    if (v < 0) return 0;
    if (v > len) return len;
    return v;
  }

  void _attachFormattedController(
    TextEditingController ctrl,
    String Function(String) formatter,
  ) {
    ctrl.addListener(() {
      if (_formatting) return;

      final oldText = ctrl.text;
      final newText = formatter(oldText);

      if (newText == oldText) return;

      _formatting = true;

      final sel = ctrl.selection;
      final base = _clampSel(sel.baseOffset, newText.length);
      final extent = _clampSel(sel.extentOffset, newText.length);

      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection(baseOffset: base, extentOffset: extent),
      );

      _formatting = false;
    });
  }

  bool _isAllLettersUpper(String w) {
    final letters = w.replaceAll(RegExp(r"[^A-Za-zÀ-ÖØ-öø-ÿ]"), "");
    if (letters.isEmpty) return false;
    return letters == letters.toUpperCase();
  }

  String _titleCaseWithDelims(String w) {
    final sb = StringBuffer();
    bool newSeg = true;

    for (int i = 0; i < w.length; i++) {
      final ch = w[i];

      if (ch == '-' || ch == '\'' || ch == '’') {
        sb.write(ch);
        newSeg = true;
        continue;
      }

      if (newSeg) {
        sb.write(ch.toUpperCase());
        newSeg = false;
      } else {
        sb.write(ch.toLowerCase());
      }
    }

    return sb.toString();
  }

  /// Primera letra de cada palabra en mayúscula (Title Case).
  /// Preserva acrónimos cortos tipo IFR/VFR/ICAO.
  String _toTitleCaseWordsPreservingAcronyms(String input) {
    return input.replaceAllMapped(_wordRe, (m) {
      final w = m.group(0) ?? '';
      if (_isAllLettersUpper(w) && w.length <= 5) return w;
      return _titleCaseWithDelims(w);
    });
  }

  /// Primera letra del texto en mayúscula (no toca el resto).
  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;

    final chars = s.split('');
    for (int i = 0; i < chars.length; i++) {
      final ch = chars[i];
      if (_letterRe.hasMatch(ch)) {
        chars[i] = ch.toUpperCase();
        break;
      }
    }
    return chars.join();
  }

  void _setupAutoFormat() {
    // ETIQUETA: MAYÚSCULA todo
    _attachFormattedController(_documentLabelCtrl, (s) => s.toUpperCase());

    // document_type: primera letra de cada palabra en mayúscula
    _attachFormattedController(
        _docTypeCtrl, _toTitleCaseWordsPreservingAcronyms);

    // observations: primera letra de la primera palabra en mayúscula
    _attachFormattedController(_observationsCtrl, _capitalizeFirst);
  }

  // ================== COUNTRY I18N ==================

  /// Convierte 🇨🇱 -> "CL"
  String? _iso2FromFlagEmoji(String flagEmoji) {
    final s = flagEmoji.trim();
    if (s.isEmpty) return null;

    final runes = s.runes.toList();
    if (runes.length < 2) return null;

    const int base = 0x1F1E6; // Regional Indicator Symbol Letter A
    const int asciiA = 0x41;

    final int r1 = runes[0];
    final int r2 = runes[1];

    if (r1 < base || r2 < base) return null;

    final int c1 = r1 - base + asciiA;
    final int c2 = r2 - base + asciiA;

    if (c1 < asciiA || c1 > 0x5A || c2 < asciiA || c2 > 0x5A) return null;

    return String.fromCharCode(c1) + String.fromCharCode(c2);
  }

  String _localizedCountryName({
    required String fallbackEnglishName,
    required String? flagEmoji,
  }) {
    final f = flagEmoji?.trim();
    if (f == null || f.isEmpty) return fallbackEnglishName;

    final iso2 = _iso2FromFlagEmoji(f);
    if (iso2 == null) return fallbackEnglishName;

    final l = AppLocalizations.of(context);
    final key = 'countries.$iso2';
    final t = l.t(key);

    // Si no existe traducción, t(key) devuelve el mismo key
    return (t == key) ? fallbackEnglishName : t;
  }

  String _displayCountryForData(cdata.CountryData c) {
    if (c.name == 'Simulator') return c.name;
    return _localizedCountryName(
      fallbackEnglishName: c.name,
      flagEmoji: c.flagEmoji,
    );
  }

  cdata.CountryData? _matchCountryFromText(String rawNameNoFlag) {
    final q = rawNameNoFlag.trim();
    if (q.isEmpty) return null;

    for (final c in cdata.allCountryData) {
      if (c.name == 'Simulator') continue;

      if (c.name.toLowerCase() == q.toLowerCase()) return c;

      final shown = _displayCountryForData(c);
      if (shown.toLowerCase() == q.toLowerCase()) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _setupAutoFormat();
    _init();
  }

  @override
  void dispose() {
    _documentLabelCtrl.dispose();
    _docTypeCtrl.dispose();
    _countryCtrl.dispose();
    _issueDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    _observationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _ensurePersonalDocsTableExists();
    if (widget.docId != null) {
      await _loadPersonalDoc();
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  // ================== DB / ESQUEMA ==================

  Future<void> _ensurePersonalDocsTableExists() async {
    final db = await DBHelper.getDB();

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_personalDocsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT
      )
    ''');

    final info = await db.rawQuery('PRAGMA table_info($_personalDocsTable)');
    final existing = <String>{
      for (final row in info)
        if (row['name'] is String) row['name'] as String,
    };

    Future<void> addColumn(String name, String type) async {
      if (!existing.contains(name)) {
        await db
            .execute('ALTER TABLE $_personalDocsTable ADD COLUMN $name $type');
      }
    }

    await addColumn('documentLabel', 'TEXT');
    await addColumn('docType', 'TEXT');
    await addColumn('country', 'TEXT');
    await addColumn('countryFlag', 'TEXT');
    await addColumn('issueDate', 'TEXT');
    await addColumn('expiryDate', 'TEXT');
    await addColumn('observations', 'TEXT');
    await addColumn('createdAt', 'TEXT');
  }

  Future<void> _loadPersonalDoc() async {
    final db = await DBHelper.getDB();
    final rows = await db.query(
      _personalDocsTable,
      where: 'id = ?',
      whereArgs: [widget.docId],
      limit: 1,
    );

    if (rows.isEmpty) return;
    final r = rows.first;

    _documentLabelCtrl.text = (r['documentLabel'] as String? ?? '').trim();
    _docTypeCtrl.text = (r['docType'] as String? ?? '').trim();

    final issueStr = (r['issueDate'] as String? ?? '').trim();
    if (issueStr.isNotEmpty) {
      try {
        _issueDate = DateTime.parse(issueStr);
        _issueDateCtrl.text = _formatDate(_issueDate!);
      } catch (_) {}
    }

    final expiryStr = (r['expiryDate'] as String? ?? '').trim();
    if (expiryStr.isNotEmpty) {
      try {
        _expiryDate = DateTime.parse(expiryStr);
        _expiryDateCtrl.text = _formatDate(_expiryDate!);
      } catch (_) {}
    }

    // country se guarda estable (inglés), pero se muestra traducido
    final countryNameEnglish = (r['country'] as String? ?? '').trim();
    final storedFlag = (r['countryFlag'] as String? ?? '').trim();
    if (countryNameEnglish.isNotEmpty) {
      cdata.CountryData? match;
      for (final c in cdata.allCountryData) {
        if (c.name == 'Simulator') continue;
        if (c.name == countryNameEnglish) {
          match = c;
          break;
        }
      }
      _selectedCountry = match;
      _countryFlag = storedFlag.isNotEmpty
          ? storedFlag
          : match?.flagEmoji.trim().isNotEmpty == true
              ? match!.flagEmoji.trim()
              : null;

      final shown = _localizedCountryName(
        fallbackEnglishName: countryNameEnglish,
        flagEmoji: _countryFlag,
      );

      final prefix = _countryFlag != null && _countryFlag!.isNotEmpty
          ? '${_countryFlag!} '
          : '';
      _countryCtrl.text = '$prefix$shown'.trim();
    }

    _observationsCtrl.text = (r['observations'] as String? ?? '').trim();
  }

  String? _nullIfEmpty(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  // ================== PICKERS ==================

  Future<void> _pickIssueDate() async {
    final now = DateTime.now();
    final initial = _issueDate ?? now;
    final first = DateTime(now.year - 70);
    final last = DateTime(now.year + 30);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        _issueDate = picked;
        _issueDateCtrl.text = _formatDate(picked);
      });
    }
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final initial = _expiryDate ?? now;
    final first = DateTime(now.year - 70);
    final last = DateTime(now.year + 50);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
        _expiryDateCtrl.text = _formatDate(picked);
      });
    }
  }

  Future<void> _pickCountry() async {
    final l = AppLocalizations.of(context);
    final searchCtrl = TextEditingController();
    List<cdata.CountryData> filtered =
        cdata.allCountryData.where((c) => c.name != 'Simulator').toList();
    cdata.CountryData? selected;

    await showPopWindow(
      context: context,
      title: l.t("select_country"),
      children: [
        StatefulBuilder(
          builder: (ctx, setSB) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    labelText: l.t("search"),
                  ),
                  onChanged: (txt) {
                    final q = txt.trim().toLowerCase();
                    setSB(() {
                      filtered = cdata.allCountryData
                          .where((c) => c.name != 'Simulator')
                          .where((c) {
                        final shown = _displayCountryForData(c).toLowerCase();
                        return c.name.toLowerCase().contains(q) ||
                            shown.contains(q) ||
                            c.flagEmoji.contains(q);
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final c = filtered[i];
                      final shownName = _displayCountryForData(c);

                      return ListTile(
                        leading: Text(
                          c.flagEmoji,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        title: Text(
                          shownName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        onTap: () {
                          selected = c;
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedCountry = selected;
        _countryFlag = selected!.flagEmoji.trim().isEmpty
            ? null
            : selected!.flagEmoji.trim();

        final shown = _displayCountryForData(selected!);
        _countryCtrl.text =
            '${_countryFlag != null ? '${_countryFlag!} ' : ''}$shown'.trim();
      });
    }
  }

  // ================== GUARDAR ==================

  Future<void> _savePersonalDoc() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final db = await DBHelper.getDB();
      await _ensurePersonalDocsTableExists();

      // Guardar país estable (inglés) si podemos resolverlo desde texto/selección
      String? countryNameEnglish;

      if (_selectedCountry != null) {
        countryNameEnglish = _selectedCountry!.name;
      } else {
        final raw = _countryCtrl.text.trim();
        if (raw.isNotEmpty) {
          // Si viene "🇨🇱 Chile", quitamos emoji inicial
          final parts = raw.split(' ');
          final hasFlag = parts.isNotEmpty &&
              parts.first.runes.length <= 4 &&
              parts.first.contains(RegExp(r'[\u2190-\u2BFF\u1F300-\u1F5FF]'));

          final nameNoFlag =
              (hasFlag && parts.length > 1) ? parts.sublist(1).join(' ') : raw;

          final match = _matchCountryFromText(nameNoFlag);
          countryNameEnglish = match?.name ?? nameNoFlag;
        }
      }

      final data = <String, Object?>{
        'documentLabel': _nullIfEmpty(_documentLabelCtrl.text),
        'docType': _nullIfEmpty(_docTypeCtrl.text),
        'country': _nullIfEmpty(countryNameEnglish),
        'countryFlag': _countryFlag,
        'issueDate': _issueDate?.toIso8601String(),
        'expiryDate': _expiryDate?.toIso8601String(),
        'observations': _nullIfEmpty(_observationsCtrl.text),
      };

      if (widget.docId == null) {
        data['createdAt'] = DateTime.now().toIso8601String();
        await db.insert(_personalDocsTable, data);
      } else {
        await db.update(
          _personalDocsTable,
          data,
          where: 'id = ?',
          whereArgs: [widget.docId],
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error saving personal document: $e');
      // ignore: avoid_print
      print(st);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("error_saving_data"))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ================== ELIMINAR ==================

  Future<void> _deletePersonalDoc() async {
    if (widget.docId == null) return;

    try {
      final db = await DBHelper.getDB();
      await db.delete(
        _personalDocsTable,
        where: 'id = ?',
        whereArgs: [widget.docId],
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error deleting personal document: $e');
      // ignore: avoid_print
      print(st);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("error_saving_data"))),
      );
    }
  }

  // ================== UI SECCIÓN ==================

  InputDecoration _fieldDecoration(BuildContext context, String key) {
    final l = AppLocalizations.of(context);
    return InputDecoration(
      labelText: l.t(key),
      labelStyle: AppTextStyles.headline2,
    );
  }

  Widget _buildPersonalDocDetailsSection(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SectionContainer(
      children: [
        SectionItemTitle(title: l.t("personal_documents")),
        const SizedBox(height: 8),

        // Etiqueta del documento
        TextField(
          controller: _documentLabelCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(context, "document_label"),
        ),
        const SizedBox(height: 12),

        // Tipo (Title Case por palabras)
        TextField(
          controller: _docTypeCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(context, "document_type"),
        ),
        const SizedBox(height: 12),

        // País
        GestureDetector(
          onTap: _pickCountry,
          child: AbsorbPointer(
            child: TextField(
              controller: _countryCtrl,
              decoration: _fieldDecoration(context, "country"),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Emisión
        GestureDetector(
          onTap: _pickIssueDate,
          child: AbsorbPointer(
            child: TextField(
              controller: _issueDateCtrl,
              decoration: _fieldDecoration(context, "issue"),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Caducidad
        GestureDetector(
          onTap: _pickExpiryDate,
          child: AbsorbPointer(
            child: TextField(
              controller: _expiryDateCtrl,
              decoration: _fieldDecoration(context, "expiry"),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Observaciones (Primera letra en mayúscula)
        TextField(
          controller: _observationsCtrl,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          decoration: _fieldDecoration(context, "observations"),
        ),
      ],
    );
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final String title = widget.docId == null
        ? l.t("new_personal_document")
        : l.t("edit_personal_document");

    return BaseScaffold(
      appBar: CustomAppBar(
        title: title,
        rightIconPath: 'assets/icons/logoback.svg',
        onRightIconTap: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context, false);
          }
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPersonalDocDetailsSection(context),
                  const SizedBox(height: 16),
                  ButtonStyles.pillCancelSave(
                    cancelLabel: l.t("cancel"),
                    saveLabel: _saving ? l.t("saving") : l.t("save"),
                    onCancel: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context, false);
                      }
                    },
                    onSave: () async {
                      if (!_saving) {
                        await _savePersonalDoc();
                      }
                    },
                    deleteLabel: widget.docId != null ? l.t("delete") : null,
                    onDelete: widget.docId != null
                        ? () async {
                            await _deletePersonalDoc();
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}
