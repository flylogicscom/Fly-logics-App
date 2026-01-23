// lib/features/documents/doc_class_ratings.dart

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

class DocClassRatings extends StatefulWidget {
  final int? ratingId; // null = nuevo, >0 = editar (0 se trata como nuevo)

  const DocClassRatings({super.key, this.ratingId});

  @override
  State<DocClassRatings> createState() => _DocClassRatingsState();
}

class _DocClassRatingsState extends State<DocClassRatings> {
  static const String _classRatingsTable = 'class_ratings';

  // Nombre en la licencia (prefill desde PilotData)
  final _pilotNameCtrl = TextEditingController();

  // Habilitación de clase
  final _classCodeCtrl = TextEditingController(); // uppercase
  final _classTitleCtrl = TextEditingController(); // Title Case words

  // Número
  final _numberCtrl = TextEditingController(); // uppercase

  // País / autoridad
  final _countryCtrl = TextEditingController();
  final _authorityCodeCtrl = TextEditingController();
  final _authorityNameCtrl = TextEditingController();
  cdata.CountryData? _selectedCountry;
  String? _countryFlag;

  // Categoría / tipo de aeronave
  final _categoryCtrl = TextEditingController(); // uppercase
  final _aircraftTypeCtrl = TextEditingController(); // Title Case words

  // Fechas
  final _issueDateCtrl = TextEditingController();
  final _expiryDateCtrl = TextEditingController();
  DateTime? _issueDate;
  DateTime? _expiryDate;

  // Observaciones: primera letra y después de cada punto en mayúscula
  final _observationsCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  // ================== AUTO FORMATO ==================
  bool _formatting = false;

  static final RegExp _wordRe =
      RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ]+(?:[’'\-][A-Za-zÀ-ÖØ-öø-ÿ]+)*");
  static final RegExp _letterRe = RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ]");

  bool get _isEdit => (widget.ratingId ?? 0) > 0;

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

  /// Title Case por palabras, preserva acrónimos cortos (IFR/VFR/ICAO).
  String _toTitleCaseWordsPreservingAcronyms(String input) {
    return input.replaceAllMapped(_wordRe, (m) {
      final w = m.group(0) ?? '';
      if (_isAllLettersUpper(w) && w.length <= 5) return w;
      return _titleCaseWithDelims(w);
    });
  }

  /// Regla: primera letra en mayúscula y después de cada punto (.), !, ? o salto de línea.
  /// No fuerza minúsculas en el resto (solo “sube” mayúsculas cuando toca).
  String _capitalizeSentences(String s) {
    if (s.isEmpty) return s;

    final chars = s.split('');
    bool capNext = true;

    for (int i = 0; i < chars.length; i++) {
      final ch = chars[i];

      if (_letterRe.hasMatch(ch)) {
        if (capNext) {
          chars[i] = ch.toUpperCase();
          capNext = false;
        }
        continue;
      }

      if (ch == '.' || ch == '!' || ch == '?' || ch == '\n') {
        capNext = true;
      }
    }

    return chars.join();
  }

  void _setupAutoFormat() {
    _attachFormattedController(
      _pilotNameCtrl,
      _toTitleCaseWordsPreservingAcronyms,
    );

    _attachFormattedController(_classCodeCtrl, _upperAll);
    _attachFormattedController(
        _classTitleCtrl, _toTitleCaseWordsPreservingAcronyms);
    _attachFormattedController(_numberCtrl, _upperAll);
    _attachFormattedController(_categoryCtrl, _upperAll);
    _attachFormattedController(
      _aircraftTypeCtrl,
      _toTitleCaseWordsPreservingAcronyms,
    );

    // Observations: capitalización por frases (punto -> mayúscula)
    _attachFormattedController(_observationsCtrl, _capitalizeSentences);
  }

  @override
  void initState() {
    super.initState();
    _setupAutoFormat();
    _init();
  }

  @override
  void dispose() {
    _pilotNameCtrl.dispose();
    _classCodeCtrl.dispose();
    _classTitleCtrl.dispose();
    _numberCtrl.dispose();
    _countryCtrl.dispose();
    _authorityCodeCtrl.dispose();
    _authorityNameCtrl.dispose();
    _categoryCtrl.dispose();
    _aircraftTypeCtrl.dispose();
    _issueDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    _observationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _ensureClassRatingsTableExists();

    if (_isEdit) {
      await _loadClassRating();
      // Fallback: si el registro viejo no tiene pilotName guardado
      await _prefillPilotNameIfEmpty();
    } else {
      await _prefillPilotNameIfEmpty();
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _prefillPilotNameIfEmpty() async {
    if (_pilotNameCtrl.text.trim().isNotEmpty) return;

    // Usa tu método (lo “correcto” para no duplicar lógica)
    final name = await DBHelper.getPilotDisplayName();
    if (!mounted) return;

    if (name != null && name.trim().isNotEmpty) {
      _pilotNameCtrl.text = name.trim();
    }
  }

  // ================== DB / ESQUEMA ==================

  Future<void> _ensureClassRatingsTableExists() async {
    final db = await DBHelper.getDB();

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_classRatingsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT
      )
    ''');

    final info = await db.rawQuery('PRAGMA table_info($_classRatingsTable)');
    final existing = <String>{
      for (final row in info)
        if (row['name'] is String) row['name'] as String,
    };

    Future<void> addColumn(String name, String type) async {
      if (!existing.contains(name)) {
        await db
            .execute('ALTER TABLE $_classRatingsTable ADD COLUMN $name $type');
      }
    }

    // Nombre titular en licencia
    await addColumn('pilotName', 'TEXT');

    await addColumn('classCode', 'TEXT');
    await addColumn('classTitle', 'TEXT');
    await addColumn('number', 'TEXT');
    await addColumn('country', 'TEXT');
    await addColumn('countryFlag', 'TEXT');
    await addColumn('authorityCode', 'TEXT');
    await addColumn('authorityName', 'TEXT');
    await addColumn('category', 'TEXT');
    await addColumn('aircraftType', 'TEXT');
    await addColumn('issueDate', 'TEXT');
    await addColumn('expiryDate', 'TEXT');
    await addColumn('observations', 'TEXT');
    await addColumn('createdAt', 'TEXT');
  }

  Future<void> _loadClassRating() async {
    final db = await DBHelper.getDB();
    final rows = await db.query(
      _classRatingsTable,
      where: 'id = ?',
      whereArgs: [widget.ratingId],
      limit: 1,
    );

    if (rows.isEmpty) return;
    final r = rows.first;

    _pilotNameCtrl.text = (r['pilotName'] as String? ?? '').trim();

    _classCodeCtrl.text = (r['classCode'] as String? ?? '').trim();
    _classTitleCtrl.text = (r['classTitle'] as String? ?? '').trim();
    _numberCtrl.text = (r['number'] as String? ?? '').trim();
    _categoryCtrl.text = (r['category'] as String? ?? '').trim();
    _aircraftTypeCtrl.text = (r['aircraftType'] as String? ?? '').trim();

    final issueStr = (r['issueDate'] as String? ?? '').trim();
    if (issueStr.isNotEmpty) {
      final parsed = DateTime.tryParse(issueStr);
      if (parsed != null) {
        _issueDate = parsed;
        _issueDateCtrl.text = _formatDate(parsed);
      }
    }

    final expiryStr = (r['expiryDate'] as String? ?? '').trim();
    if (expiryStr.isNotEmpty) {
      final parsed = DateTime.tryParse(expiryStr);
      if (parsed != null) {
        _expiryDate = parsed;
        _expiryDateCtrl.text = _formatDate(parsed);
      }
    }

    final countryName = (r['country'] as String? ?? '').trim();
    final storedFlag = (r['countryFlag'] as String? ?? '').trim();
    if (countryName.isNotEmpty) {
      cdata.CountryData? match;
      for (final c in cdata.allCountryData) {
        if (c.name == 'Simulator') continue;
        if (c.name == countryName) {
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

      final prefix = _countryFlag != null && _countryFlag!.isNotEmpty
          ? '${_countryFlag!} '
          : '';
      _countryCtrl.text = '$prefix$countryName';
    }

    _authorityCodeCtrl.text = (r['authorityCode'] as String? ?? '').trim();
    _authorityNameCtrl.text = (r['authorityName'] as String? ?? '').trim();
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
                  decoration: InputDecoration(labelText: l.t("search")),
                  onChanged: (txt) {
                    final q = txt.trim().toLowerCase();
                    setSB(() {
                      filtered = cdata.allCountryData
                          .where((c) => c.name != 'Simulator')
                          .where((c) =>
                              c.name.toLowerCase().contains(q) ||
                              c.flagEmoji.contains(q))
                          .toList();
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
                      return ListTile(
                        leading: Text(
                          c.flagEmoji,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        title: Text(
                          c.name,
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
        _countryCtrl.text =
            '${_countryFlag ?? ''} ${_selectedCountry?.name ?? ''}'.trim();

        _authorityCodeCtrl.text = selected!.authorityAcronym;
        _authorityNameCtrl.text = selected!.authorityOfficialName;
      });
    }
  }

  // ================== GUARDAR ==================

  Future<void> _saveClassRating() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final db = await DBHelper.getDB();
      await _ensureClassRatingsTableExists();

      String? countryName;
      if (_selectedCountry != null) {
        countryName = _selectedCountry!.name;
      } else {
        final raw = _countryCtrl.text.trim();
        if (raw.isNotEmpty) {
          final parts = raw.split(' ');
          if (parts.length > 1 &&
              parts.first.runes.length <= 4 &&
              parts.first.contains(RegExp(r'[\u2190-\u2BFF\u1F300-\u1F5FF]'))) {
            countryName = parts.sublist(1).join(' ');
          } else {
            countryName = raw;
          }
        }
      }

      final data = <String, Object?>{
        'pilotName': _nullIfEmpty(_pilotNameCtrl.text),
        'classCode': _nullIfEmpty(_classCodeCtrl.text),
        'classTitle': _nullIfEmpty(_classTitleCtrl.text),
        'number': _nullIfEmpty(_numberCtrl.text),
        'country': _nullIfEmpty(countryName),
        'countryFlag': _countryFlag,
        'authorityCode': _nullIfEmpty(_authorityCodeCtrl.text),
        'authorityName': _nullIfEmpty(_authorityNameCtrl.text),
        'category': _nullIfEmpty(_categoryCtrl.text),
        'aircraftType': _nullIfEmpty(_aircraftTypeCtrl.text),
        'issueDate': _issueDate?.toIso8601String(),
        'expiryDate': _expiryDate?.toIso8601String(),
        'observations': _nullIfEmpty(_observationsCtrl.text),
      };

      if (!_isEdit) {
        data['createdAt'] = DateTime.now().toIso8601String();
        await db.insert(_classRatingsTable, data);
      } else {
        await db.update(
          _classRatingsTable,
          data,
          where: 'id = ?',
          whereArgs: [widget.ratingId],
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error saving class rating: $e');
      // ignore: avoid_print
      print(st);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("error_saving_data"))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteClassRating() async {
    if (!_isEdit) return;

    try {
      final db = await DBHelper.getDB();
      await db.delete(
        _classRatingsTable,
        where: 'id = ?',
        whereArgs: [widget.ratingId],
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error deleting class rating: $e');
      // ignore: avoid_print
      print(st);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("error_saving_data"))),
      );
    }
  }

  // ================== UI ==================

  InputDecoration _fieldDecoration(BuildContext context, String key) {
    final l = AppLocalizations.of(context);
    return InputDecoration(
      labelText: l.t(key),
      labelStyle: AppTextStyles.headline2,
    );
  }

  Widget _buildClassRatingDetailsSection(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SectionContainer(
      children: [
        SectionItemTitle(title: l.t("class_ratings")),
        const SizedBox(height: 8),
        Text(
          l.t("class_rating_header"),
          style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        // Nombre (prefill desde PilotData)
        TextField(
          controller: _pilotNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(context, "name_lastname"),
        ),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: TextField(
                controller: _classCodeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _fieldDecoration(context, "class_rating_code"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _classTitleCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration(context, "class_rating_title"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _numberCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(context, "number"),
        ),
        const SizedBox(height: 12),
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
        TextField(
          controller: _categoryCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(context, "category"),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _aircraftTypeCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(context, "aircraft_type"),
        ),
        const SizedBox(height: 12),
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
        TextField(
          controller: _observationsCtrl,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          decoration: _fieldDecoration(context, "observations"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final String title =
        !_isEdit ? l.t("new_class_rating") : l.t("edit_class_rating");

    return BaseScaffold(
      appBar: CustomAppBar(
        title: title,
        rightIconPath: 'assets/icons/logoback.svg',
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context, false);
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildClassRatingDetailsSection(context),
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
                      if (!_saving) await _saveClassRating();
                    },
                    deleteLabel: _isEdit ? l.t("delete") : null,
                    onDelete: _isEdit ? () async => _deleteClassRating() : null,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}
