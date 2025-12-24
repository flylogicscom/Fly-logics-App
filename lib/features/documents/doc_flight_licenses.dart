// lib/features/documents/doc_flight_licensesfile.dart
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
import 'package:fly_logicd_logbook_app/common/pop_layer_licenses.dart';

class DocFlightLicenses extends StatefulWidget {
  final int? licenseId; // null = nueva licencia, no null = editar

  const DocFlightLicenses({super.key, this.licenseId});

  @override
  State<DocFlightLicenses> createState() => _DocFlightLicensesFileState();
}

class _DocFlightLicensesFileState extends State<DocFlightLicenses> {
  static const String _licensesTable = 'flight_licenses';

  // Datos básicos
  LicenseSelection? _selectedLicense;
  final _nameOnLicenseCtrl = TextEditingController();
  final _licenseNumberCtrl = TextEditingController();

  // Fechas
  final _issueDateCtrl = TextEditingController();
  final _expiryDateCtrl = TextEditingController();
  DateTime? _issueDate;
  DateTime? _expiryDate;

  // País / autoridad
  final _countryCtrl = TextEditingController();
  final _authorityCodeCtrl = TextEditingController();
  final _authorityNameCtrl = TextEditingController();
  cdata.CountryData? _selectedCountry;
  String? _countryFlag;

  // Observaciones
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

  /// Title Case para nombres (primera letra de cada palabra en mayúscula).
  /// Preserva acrónimos cortos tipo IFR/VFR/ICAO.
  String _toTitleCaseWordsPreservingAcronyms(String input) {
    return input.replaceAllMapped(_wordRe, (m) {
      final w = m.group(0) ?? '';
      if (_isAllLettersUpper(w) && w.length <= 5) return w;
      return _titleCaseWithDelims(w);
    });
  }

  void _setupAutoFormat() {
    // name_on_license: primera letra de cada palabra en mayúscula
    _attachFormattedController(
      _nameOnLicenseCtrl,
      _toTitleCaseWordsPreservingAcronyms,
    );

    // number: mayúscula todo
    _attachFormattedController(_licenseNumberCtrl, _upperAll);

    // country / authority / authority_name: nada automático
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
    _nameOnLicenseCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _issueDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    _countryCtrl.dispose();
    _authorityCodeCtrl.dispose();
    _authorityNameCtrl.dispose();
    _observationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _ensureLicensesTableExists();
    if (widget.licenseId != null) {
      await _loadLicense();
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  // ================== DB / ESQUEMA ==================

  Future<void> _ensureLicensesTableExists() async {
    final db = await DBHelper.getDB();

    // Tabla mínima
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_licensesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT
      )
    ''');

    // Añadir columnas que falten
    final info = await db.rawQuery('PRAGMA table_info($_licensesTable)');
    final existing = <String>{
      for (final row in info)
        if (row['name'] is String) row['name'] as String,
    };

    Future<void> addColumn(String name, String type) async {
      if (!existing.contains(name)) {
        await db.execute('ALTER TABLE $_licensesTable ADD COLUMN $name $type');
      }
    }

    await addColumn('licenseCode', 'TEXT');
    await addColumn('licenseTitle', 'TEXT');
    await addColumn('nameOnLicense', 'TEXT');
    await addColumn('licenseNumber', 'TEXT');
    await addColumn('issueDate', 'TEXT');
    await addColumn('expiryDate', 'TEXT');
    await addColumn('country', 'TEXT');
    await addColumn('countryFlag', 'TEXT');
    await addColumn('authorityCode', 'TEXT');
    await addColumn('authorityName', 'TEXT');
    await addColumn('observations', 'TEXT');
    await addColumn('createdAt', 'TEXT');
  }

  Future<void> _loadLicense() async {
    final db = await DBHelper.getDB();
    final rows = await db.query(
      _licensesTable,
      where: 'id = ?',
      whereArgs: [widget.licenseId],
      limit: 1,
    );

    if (rows.isEmpty) return;
    final r = rows.first;

    final code = (r['licenseCode'] as String? ?? '').trim();
    final title = (r['licenseTitle'] as String? ?? '').trim();
    if (code.isNotEmpty || title.isNotEmpty) {
      _selectedLicense = LicenseSelection(
        code: code.isEmpty ? '---' : code,
        title: title.isEmpty ? code : title,
      );
    }

    _nameOnLicenseCtrl.text = (r['nameOnLicense'] as String? ?? '').trim();
    _licenseNumberCtrl.text = (r['licenseNumber'] as String? ?? '').trim();

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
      _countryCtrl.text = '$prefix$shown';
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
    // Formato dd/MM/yyyy para mostrar
    return '$dd/$mm/$yyyy';
  }

  // ================== PICKERS ==================

  Future<void> _pickLicense() async {
    final sel = await showLicensePopup(context);
    if (sel == null) return;
    setState(() {
      _selectedLicense = sel;
    });
  }

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

  // ================== COLORES LICENCIA ==================

  Color _licenseColorForCode(String code) {
    final c = code.toUpperCase();
    switch (c) {
      case 'PPL(A)':
        return const Color(0xFF024755);
      case 'PPL(H)':
        return const Color(0xFF125864);
      case 'CPL(A)':
        return const Color(0xFF216873);
      case 'CPL(H)':
        return const Color(0xFF337983);
      case 'ATPL(A)':
        return const Color(0xFF418991);
      case 'ATPL(H)':
        return const Color(0xFF519AA0);
      case 'FI(A)':
        return const Color(0xFF61AAAF);
      case 'FI(H)':
        return const Color(0xFF72BBBF);
      case 'MPL':
        return const Color(0xFF3B6D7C);
      case 'SPL':
        return const Color(0xFF2F5E6C);
      case 'BPL':
        return const Color(0xFF25505E);
      case 'RPL':
        return const Color(0xFF1C4454);
      case 'LAPL(A)':
        return const Color(0xFF16505A);
      case 'LAPL(H)':
        return const Color(0xFF14646F);
      case 'ACPL':
        return const Color(0xFF0F767D);
      case 'OTRO':
      default:
        return const Color(0xFF0A8A88);
    }
  }

  Widget _buildSelectedLicenseDisplay() {
    final l = AppLocalizations.of(context);

    if (_selectedLicense == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: _pickLicense,
          child: Text(l.t("add_license_type")),
        ),
      );
    }

    final lic = _selectedLicense!;
    final pillColor = _licenseColorForCode(lic.code);
    const titleColor = Colors.white;

    return InkWell(
      onTap: _pickLicense,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 3.5,
            ),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: Colors.white, width: 1.0),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              lic.code,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lic.title,
              style: AppTextStyles.headline1.copyWith(
                color: titleColor,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================== UI SECCIÓN ==================

  InputDecoration _fieldDecoration(BuildContext context, String key) {
    final l = AppLocalizations.of(context);
    return InputDecoration(
      labelText: l.t(key),
      labelStyle: AppTextStyles.headline2,
    );
  }

  Widget _buildLicenseDetailsSection(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SectionContainer(
      children: [
        SectionItemTitle(title: l.t("licenses_popup_title")),
        const SizedBox(height: 8),

        _buildSelectedLicenseDisplay(),
        const SizedBox(height: 16),

        // Nombre en la licencia (Title Case por palabras)
        TextField(
          controller: _nameOnLicenseCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(context, "name_on_license"),
        ),
        const SizedBox(height: 12),

        // Número (MAYÚSCULA Todo)
        TextField(
          controller: _licenseNumberCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(context, "number"),
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

        // País / Autoridad
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
          controller: _observationsCtrl,
          maxLines: 2,
          decoration: _fieldDecoration(context, "observations"),
        ),
      ],
    );
  }

  // ================== GUARDAR ==================

  Future<void> _saveLicense() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final db = await DBHelper.getDB();
      await _ensureLicensesTableExists();

      // IMPORTANTE: se guarda el país en inglés (estable) para no romper el match al cargar
      String? countryNameEnglish;
      if (_selectedCountry != null) {
        countryNameEnglish = _selectedCountry!.name;
      } else {
        final raw = _countryCtrl.text.trim();
        if (raw.isNotEmpty) {
          // Si viene "🇨🇱 Chile", quitamos emoji inicial
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
        'licenseCode': _selectedLicense?.code,
        'licenseTitle': _selectedLicense?.title,
        'nameOnLicense': _nullIfEmpty(_nameOnLicenseCtrl.text),
        'licenseNumber': _nullIfEmpty(_licenseNumberCtrl.text),
        'issueDate': _issueDate?.toIso8601String(),
        'expiryDate': _expiryDate?.toIso8601String(),
        'country': _nullIfEmpty(countryNameEnglish),
        'countryFlag': _countryFlag,
        'authorityCode': _nullIfEmpty(_authorityCodeCtrl.text),
        'authorityName': _nullIfEmpty(_authorityNameCtrl.text),
        'observations': _nullIfEmpty(_observationsCtrl.text),
      };

      if (widget.licenseId == null) {
        data['createdAt'] = DateTime.now().toIso8601String();
        await db.insert(_licensesTable, data);
      } else {
        await db.update(
          _licensesTable,
          data,
          where: 'id = ?',
          whereArgs: [widget.licenseId],
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error saving flight license: $e');
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

  // ================== BORRAR ==================

  Future<void> _deleteLicense() async {
    if (widget.licenseId == null) return;

    try {
      final db = await DBHelper.getDB();
      await db.delete(
        _licensesTable,
        where: 'id = ?',
        whereArgs: [widget.licenseId],
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error deleting flight license: $e');
      // ignore: avoid_print
      print(st);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("error_saving_data"))),
      );
    }
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final String title = widget.licenseId == null
        ? l.t("new_flight_license")
        : l.t("edit_flight_license");

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
                  _buildLicenseDetailsSection(context),
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
                        await _saveLicense();
                      }
                    },
                    deleteLabel:
                        widget.licenseId != null ? l.t("delete") : null,
                    onDelete: widget.licenseId != null
                        ? () async {
                            await _deleteLicense();
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
