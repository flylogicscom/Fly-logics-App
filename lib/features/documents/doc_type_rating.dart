// lib/features/documents/doc_type_rating.dart

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

class DocTypeRatings extends StatefulWidget {
  final int? ratingId; // null = nuevo, no null = editar

  const DocTypeRatings({super.key, this.ratingId});

  @override
  State<DocTypeRatings> createState() => _DocTypeRatingsState();
}

class _DocTypeRatingsState extends State<DocTypeRatings> {
  static const String _typeRatingsTable = 'type_ratings';

  // Habilitación de tipo
  final _typeCodeCtrl = TextEditingController(); // type_rating_code (UPPER)
  final _typeTitleCtrl =
      TextEditingController(); // type_rating_title (Title Case)

  // Número
  final _numberCtrl = TextEditingController(); // number (UPPER)

  // País / autoridad
  final _countryCtrl = TextEditingController();
  final _authorityCodeCtrl = TextEditingController(); // (sin formato)
  final _authorityNameCtrl = TextEditingController(); // (sin formato)
  cdata.CountryData? _selectedCountry;
  String? _countryFlag;

  // Categoría / tipo de aeronave
  final _categoryCtrl = TextEditingController(); // category (UPPER)
  final _aircraftTypeCtrl =
      TextEditingController(); // aircraft_type (Title Case)

  // Fechas
  final _issueDateCtrl = TextEditingController();
  final _expiryDateCtrl = TextEditingController();
  DateTime? _issueDate;
  DateTime? _expiryDate;

  // Observaciones
  final _observationsCtrl = TextEditingController(); // observations (Cap first)

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

  /// Primera letra de cada palabra en mayúscula.
  /// Preserva acrónimos cortos tipo ICAO/IFR/VFR.
  String _toTitleCaseWordsPreservingAcronyms(String input) {
    return input.replaceAllMapped(_wordRe, (m) {
      final w = m.group(0) ?? '';
      if (_isAllLettersUpper(w) && w.length <= 5) return w;
      return _titleCaseWithDelims(w);
    });
  }

  /// Primera letra del texto (primera palabra) en mayúscula.
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
    // type_rating_code: MAYÚSCULA todo
    _attachFormattedController(_typeCodeCtrl, _upperAll);

    // type_rating_title: Title Case
    _attachFormattedController(
        _typeTitleCtrl, _toTitleCaseWordsPreservingAcronyms);

    // number: MAYÚSCULA todo
    _attachFormattedController(_numberCtrl, _upperAll);

    // category: MAYÚSCULA todo
    _attachFormattedController(_categoryCtrl, _upperAll);

    // aircraft_type: Title Case
    _attachFormattedController(
        _aircraftTypeCtrl, _toTitleCaseWordsPreservingAcronyms);

    // observations: primera letra del texto
    _attachFormattedController(_observationsCtrl, _capitalizeFirst);

    // country / authority: sin formato automático
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
    _typeCodeCtrl.dispose();
    _typeTitleCtrl.dispose();
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
    await _ensureTypeRatingsTableExists();
    if (widget.ratingId != null) {
      await _loadTypeRating();
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  // ================== DB / ESQUEMA ==================

  Future<void> _ensureTypeRatingsTableExists() async {
    final db = await DBHelper.getDB();

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_typeRatingsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT
      )
    ''');

    final info = await db.rawQuery('PRAGMA table_info($_typeRatingsTable)');
    final existing = <String>{
      for (final row in info)
        if (row['name'] is String) row['name'] as String,
    };

    Future<void> addColumn(String name, String type) async {
      if (!existing.contains(name)) {
        await db.execute(
          'ALTER TABLE $_typeRatingsTable ADD COLUMN $name $type',
        );
      }
    }

    await addColumn('typeCode', 'TEXT');
    await addColumn('typeTitle', 'TEXT');
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

  Future<void> _loadTypeRating() async {
    final db = await DBHelper.getDB();
    final rows = await db.query(
      _typeRatingsTable,
      where: 'id = ?',
      whereArgs: [widget.ratingId],
      limit: 1,
    );

    if (rows.isEmpty) return;
    final r = rows.first;

    _typeCodeCtrl.text = (r['typeCode'] as String? ?? '').trim();
    _typeTitleCtrl.text = (r['typeTitle'] as String? ?? '').trim();
    _numberCtrl.text = (r['number'] as String? ?? '').trim();
    _categoryCtrl.text = (r['category'] as String? ?? '').trim();
    _aircraftTypeCtrl.text = (r['aircraftType'] as String? ?? '').trim();

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

    // Guardado estable (inglés), mostrado traducido
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

      final prefix = (_countryFlag != null && _countryFlag!.isNotEmpty)
          ? '${_countryFlag!} '
          : '';
      _countryCtrl.text = '$prefix$shown'.trim();
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

  // ================== GUARDAR ==================

  Future<void> _saveTypeRating() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final db = await DBHelper.getDB();
      await _ensureTypeRatingsTableExists();

      // Guardar país estable (inglés)
      String? countryNameEnglish;
      if (_selectedCountry != null) {
        countryNameEnglish = _selectedCountry!.name;
      } else {
        final raw = _countryCtrl.text.trim();
        if (raw.isNotEmpty) {
          final parts = raw.split(' ');
          final hasFlag = parts.isNotEmpty &&
              parts.first.runes.length <= 4 &&
              parts.first.contains(RegExp(r'[\u2190-\u2BFF\u1F300-\u1F5FF]'));

          final nameNoFlag =
              (hasFlag && parts.length > 1) ? parts.sublist(1).join(' ') : raw;

          final match = _matchCountryFromText(nameNoFlag);
          countryNameEnglish = match?.name ?? nameNoFlag;
          _countryFlag ??= match?.flagEmoji.trim().isNotEmpty == true
              ? match!.flagEmoji.trim()
              : null;
        }
      }

      final data = <String, Object?>{
        'typeCode': _nullIfEmpty(_typeCodeCtrl.text),
        'typeTitle': _nullIfEmpty(_typeTitleCtrl.text),
        'number': _nullIfEmpty(_numberCtrl.text),
        'country': _nullIfEmpty(countryNameEnglish),
        'countryFlag': _countryFlag,
        'authorityCode': _nullIfEmpty(_authorityCodeCtrl.text),
        'authorityName': _nullIfEmpty(_authorityNameCtrl.text),
        'category': _nullIfEmpty(_categoryCtrl.text),
        'aircraftType': _nullIfEmpty(_aircraftTypeCtrl.text),
        'issueDate': _issueDate?.toIso8601String(),
        'expiryDate': _expiryDate?.toIso8601String(),
        'observations': _nullIfEmpty(_observationsCtrl.text),
      };

      if (widget.ratingId == null) {
        data['createdAt'] = DateTime.now().toIso8601String();
        await db.insert(_typeRatingsTable, data);
      } else {
        await db.update(
          _typeRatingsTable,
          data,
          where: 'id = ?',
          whereArgs: [widget.ratingId],
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error saving type rating: $e');
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

  Future<void> _deleteTypeRating() async {
    if (widget.ratingId == null) return;

    try {
      final db = await DBHelper.getDB();
      await db.delete(
        _typeRatingsTable,
        where: 'id = ?',
        whereArgs: [widget.ratingId],
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error deleting type rating: $e');
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

  Widget _buildTypeRatingDetailsSection(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SectionContainer(
      children: [
        SectionItemTitle(title: l.t("type_ratings")),
        const SizedBox(height: 8),
        Text(
          l.t("type_rating_header"),
          style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 110,
              child: TextField(
                controller: _typeCodeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _fieldDecoration(context, "type_rating_code"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _typeTitleCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration(context, "type_rating_title"),
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

    final String title = widget.ratingId == null
        ? l.t("new_type_rating")
        : l.t("edit_type_rating");

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
                  _buildTypeRatingDetailsSection(context),
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
                        await _saveTypeRating();
                      }
                    },
                    deleteLabel: widget.ratingId != null ? l.t("delete") : null,
                    onDelete: widget.ratingId != null
                        ? () async {
                            await _deleteTypeRating();
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
