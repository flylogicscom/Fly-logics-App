// lib/features/documents/doc_medical_exam.dart

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

class DocMedicalExam extends StatefulWidget {
  final int? examId; // null = new, non-null = edit existing

  const DocMedicalExam({super.key, this.examId});

  @override
  State<DocMedicalExam> createState() => _DocMedicalExamState();
}

class _DocMedicalExamState extends State<DocMedicalExam> {
  static const String _medicalExamsTable = 'medical_exams';

  // Label of exam
  final _examLabelCtrl = TextEditingController(); // medical_exam_label

  // Medical exam name / type
  final _examNameCtrl = TextEditingController(); // medical_exam_name

  // Dates
  final _medicalDecisionDateCtrl = TextEditingController(); // medical decision
  final _examDateCtrl = TextEditingController(); // date of exam
  final _expiryDateCtrl = TextEditingController(); // expiry date
  DateTime? _medicalDecisionDate;
  DateTime? _examDate;
  DateTime? _expiryDate;

  // Country / authority
  final _countryCtrl = TextEditingController();
  final _authorityCodeCtrl = TextEditingController(); // acronym (DGAC, EASA…)
  final _authorityNameCtrl = TextEditingController(); // long name
  cdata.CountryData? _selectedCountry;
  String? _countryFlag;

  // Class
  final _classCtrl = TextEditingController(); // medical_class

  // Observations
  final _observationsCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  // ================== AUTO FORMATO ==================
  bool _formatting = false;

  static final RegExp _wordRe =
      RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ]+(?:[’'\-][A-Za-zÀ-ÖØ-öø-ÿ]+)*");

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

  String _upperAll(String s) => s.toUpperCase();

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

  /// Title Case por palabras, preservando acrónimos cortos tipo ICAO/IFR/VFR.
  String _toTitleCaseWordsPreservingAcronyms(String input) {
    return input.replaceAllMapped(_wordRe, (m) {
      final w = m.group(0) ?? '';
      if (_isAllLettersUpper(w) && w.length <= 5) return w;
      return _titleCaseWithDelims(w);
    });
  }

  void _setupAutoFormat() {
    // medical_exam_label: MAYÚSCULA todo
    _attachFormattedController(_examLabelCtrl, _upperAll);

    // medical_exam_name: Primera letra de cada palabra
    _attachFormattedController(
      _examNameCtrl,
      _toTitleCaseWordsPreservingAcronyms,
    );

    // medical_class: MAYÚSCULA todo
    _attachFormattedController(_classCtrl, _upperAll);

    // country / authority / authority_name / observations: nada automático
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

  @override
  void initState() {
    super.initState();
    _setupAutoFormat();
    _init();
  }

  @override
  void dispose() {
    _examLabelCtrl.dispose();
    _examNameCtrl.dispose();
    _medicalDecisionDateCtrl.dispose();
    _examDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    _countryCtrl.dispose();
    _authorityCodeCtrl.dispose();
    _authorityNameCtrl.dispose();
    _classCtrl.dispose();
    _observationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _ensureMedicalExamsTableExists();
    if (widget.examId != null) {
      await _loadMedicalExam();
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  // ================== DB / SCHEMA ==================

  Future<void> _ensureMedicalExamsTableExists() async {
    final db = await DBHelper.getDB();

    // Minimal table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_medicalExamsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT
      )
    ''');

    // Add missing columns if needed
    final info = await db.rawQuery('PRAGMA table_info($_medicalExamsTable)');
    final existing = <String>{
      for (final row in info)
        if (row['name'] is String) row['name'] as String,
    };

    Future<void> addColumn(String name, String type) async {
      if (!existing.contains(name)) {
        await db
            .execute('ALTER TABLE $_medicalExamsTable ADD COLUMN $name $type');
      }
    }

    await addColumn('examLabel', 'TEXT');
    await addColumn('examName', 'TEXT');
    await addColumn('medicalDecisionDate', 'TEXT');
    await addColumn('examDate', 'TEXT');
    await addColumn('expiryDate', 'TEXT');
    await addColumn('country', 'TEXT');
    await addColumn('countryFlag', 'TEXT');
    await addColumn('authorityCode', 'TEXT');
    await addColumn('authorityName', 'TEXT');
    await addColumn('medicalClass', 'TEXT');
    await addColumn('observations', 'TEXT');
    await addColumn('createdAt', 'TEXT');
  }

  Future<void> _loadMedicalExam() async {
    final db = await DBHelper.getDB();
    final rows = await db.query(
      _medicalExamsTable,
      where: 'id = ?',
      whereArgs: [widget.examId],
      limit: 1,
    );

    if (rows.isEmpty) return;
    final r = rows.first;

    _examLabelCtrl.text = (r['examLabel'] as String? ?? '').trim();
    _examNameCtrl.text = (r['examName'] as String? ?? '').trim();

    final medicalDecisionStr =
        (r['medicalDecisionDate'] as String? ?? '').trim();
    if (medicalDecisionStr.isNotEmpty) {
      try {
        _medicalDecisionDate = DateTime.parse(medicalDecisionStr);
        _medicalDecisionDateCtrl.text = _formatDate(_medicalDecisionDate!);
      } catch (_) {}
    }

    final examDateStr = (r['examDate'] as String? ?? '').trim();
    if (examDateStr.isNotEmpty) {
      try {
        _examDate = DateTime.parse(examDateStr);
        _examDateCtrl.text = _formatDate(_examDate!);
      } catch (_) {}
    }

    final expiryStr = (r['expiryDate'] as String? ?? '').trim();
    if (expiryStr.isNotEmpty) {
      try {
        _expiryDate = DateTime.parse(expiryStr);
        _expiryDateCtrl.text = _formatDate(_expiryDate!);
      } catch (_) {}
    }

    // country en DB se guarda estable (inglés), pero se muestra traducido
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

    _authorityCodeCtrl.text = (r['authorityCode'] as String? ?? '').trim();
    _authorityNameCtrl.text = (r['authorityName'] as String? ?? '').trim();
    _classCtrl.text = (r['medicalClass'] as String? ?? '').trim();
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

  Future<void> _pickMedicalDecisionDate() async {
    final now = DateTime.now();
    final initial = _medicalDecisionDate ?? now;
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
        _medicalDecisionDate = picked;
        _medicalDecisionDateCtrl.text = _formatDate(picked);
      });
    }
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final initial = _examDate ?? now;
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
        _examDate = picked;
        _examDateCtrl.text = _formatDate(picked);
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

        _authorityCodeCtrl.text = selected!.authorityAcronym;
        _authorityNameCtrl.text = selected!.authorityOfficialName;
      });
    }
  }

  // ================== SAVE ==================

  Future<void> _saveMedicalExam() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final db = await DBHelper.getDB();
      await _ensureMedicalExamsTableExists();

      // IMPORTANTE: se guarda el país en inglés (estable) para no romper el match al cargar
      String? countryNameEnglish;
      if (_selectedCountry != null) {
        countryNameEnglish = _selectedCountry!.name;
      } else {
        final raw = _countryCtrl.text.trim();
        if (raw.isNotEmpty) {
          // If text comes as "🇨🇱 Chile", remove emoji
          final parts = raw.split(' ');
          if (parts.length > 1 &&
              parts.first.runes.length <= 4 &&
              parts.first.contains(RegExp(r'[\u2190-\u2BFF\u1F300-\u1F5FF]'))) {
            countryNameEnglish = parts.sublist(1).join(' ');
          } else {
            countryNameEnglish = raw;
          }
        }
      }

      final data = <String, Object?>{
        'examLabel': _nullIfEmpty(_examLabelCtrl.text),
        'examName': _nullIfEmpty(_examNameCtrl.text),
        'medicalDecisionDate': _medicalDecisionDate?.toIso8601String(),
        'examDate': _examDate?.toIso8601String(),
        'expiryDate': _expiryDate?.toIso8601String(),
        'country': _nullIfEmpty(countryNameEnglish),
        'countryFlag': _countryFlag,
        'authorityCode': _nullIfEmpty(_authorityCodeCtrl.text),
        'authorityName': _nullIfEmpty(_authorityNameCtrl.text),
        'medicalClass': _nullIfEmpty(_classCtrl.text),
        'observations': _nullIfEmpty(_observationsCtrl.text),
      };

      if (widget.examId == null) {
        data['createdAt'] = DateTime.now().toIso8601String();
        await db.insert(_medicalExamsTable, data);
      } else {
        await db.update(
          _medicalExamsTable,
          data,
          where: 'id = ?',
          whereArgs: [widget.examId],
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error saving medical exam: $e');
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

  // ================== DELETE ==================

  Future<void> _deleteMedicalExam() async {
    if (widget.examId == null) return;

    try {
      final db = await DBHelper.getDB();
      await db.delete(
        _medicalExamsTable,
        where: 'id = ?',
        whereArgs: [widget.examId],
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error deleting medical exam: $e');
      // ignore: avoid_print
      print(st);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("error_saving_data"))),
      );
    }
  }

  // ================== UI SECTION ==================

  InputDecoration _fieldDecoration(BuildContext context, String key) {
    final l = AppLocalizations.of(context);
    return InputDecoration(
      labelText: l.t(key),
      labelStyle: AppTextStyles.headline2,
    );
  }

  Widget _buildMedicalExamDetailsSection(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SectionContainer(
      children: [
        SectionItemTitle(title: l.t("medical_exams")),
        const SizedBox(height: 8),

        // medical_exam_label (MAYÚSCULA todo)
        TextField(
          controller: _examLabelCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(context, "medical_exam_label"),
        ),
        const SizedBox(height: 12),

        // medical_exam_name (Primera letra de cada palabra)
        TextField(
          controller: _examNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(context, "medical_exam_name"),
        ),
        const SizedBox(height: 12),

        // Medical decision date
        GestureDetector(
          onTap: _pickMedicalDecisionDate,
          child: AbsorbPointer(
            child: TextField(
              controller: _medicalDecisionDateCtrl,
              decoration: _fieldDecoration(context, "medical_decision_date"),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Exam date
        GestureDetector(
          onTap: _pickExamDate,
          child: AbsorbPointer(
            child: TextField(
              controller: _examDateCtrl,
              decoration: _fieldDecoration(context, "exam_date"),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Expiry date
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

        // Country / Authority (acronym)
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickCountry,
                child: AbsorbPointer(
                  child: TextField(
                    controller: _countryCtrl,
                    decoration: _fieldDecoration(context, "country"),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _pickCountry,
                child: AbsorbPointer(
                  child: TextField(
                    controller: _authorityCodeCtrl,
                    decoration: _fieldDecoration(context, "authority"),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Authority name
        GestureDetector(
          onTap: _pickCountry,
          child: AbsorbPointer(
            child: TextField(
              controller: _authorityNameCtrl,
              decoration: _fieldDecoration(context, "authority_name"),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // medical_class (MAYÚSCULA todo)
        TextField(
          controller: _classCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(context, "medical_class"),
        ),
        const SizedBox(height: 12),

        // Observations
        TextField(
          controller: _observationsCtrl,
          maxLines: 2,
          decoration: _fieldDecoration(context, "observations"),
        ),
      ],
    );
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final String title = widget.examId == null
        ? l.t("new_medical_exam")
        : l.t("edit_medical_exam");

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
                  _buildMedicalExamDetailsSection(context),
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
                        await _saveMedicalExam();
                      }
                    },
                    deleteLabel: widget.examId != null ? l.t("delete") : null,
                    onDelete: widget.examId != null
                        ? () async {
                            await _deleteMedicalExam();
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
