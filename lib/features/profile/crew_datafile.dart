//  lib/features/profile/crew_datafile.dart

import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/section_container.dart';
import 'package:fly_logicd_logbook_app/common/popwindow.dart';
import 'package:fly_logicd_logbook_app/common/phone_formatter.dart';
import 'package:fly_logicd_logbook_app/utils/country_data.dart' as cdata;
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';

// Popup de roles de tripulación
import 'package:fly_logicd_logbook_app/common/pop_layer_crew.dart';

class CrewDataFile extends StatefulWidget {
  final int? crewId; // null = nuevo, no null = editar existente

  const CrewDataFile({super.key, this.crewId});

  @override
  State<CrewDataFile> createState() => _CrewDataFileState();
}

class _CrewDataFileState extends State<CrewDataFile> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _airlineCtrl = TextEditingController();
  final _rankCtrl =
      TextEditingController(); // Role / Rank (texto guardado en DB)
  final _employeeNumberCtrl = TextEditingController();

  String? _phoneFlag;
  cdata.CountryData? _selectedCountry;
  bool _saving = false;
  bool _loading = false;

  // Rol seleccionado (solo para UI)
  CrewRoleSelection? _selectedRole;

  static const String _crewTable = 'crew_members';

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

  /// Primera letra de cada palabra en mayúscula (Title Case), preserva acrónimos cortos.
  String _toTitleCaseWordsPreservingAcronyms(String input) {
    return input.replaceAllMapped(_wordRe, (m) {
      final w = m.group(0) ?? '';
      if (_isAllLettersUpper(w) && w.length <= 5) return w;
      return _titleCaseWithDelims(w);
    });
  }

  void _setupAutoFormat() {
    // first_name / last_name / airline: Title Case
    _attachFormattedController(
        _firstNameCtrl, _toTitleCaseWordsPreservingAcronyms);
    _attachFormattedController(
        _lastNameCtrl, _toTitleCaseWordsPreservingAcronyms);
    _attachFormattedController(
        _airlineCtrl, _toTitleCaseWordsPreservingAcronyms);

    // employee_number: todo en mayúscula
    _attachFormattedController(_employeeNumberCtrl, (s) => s.toUpperCase());
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

  // ================== LIFECYCLE ==================

  @override
  void initState() {
    super.initState();
    _setupAutoFormat();

    if (widget.crewId != null) {
      _loading = true;
      _loadCrew();
    } else {
      _ensureCrewTableExists();
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _countryCtrl.dispose();
    _airlineCtrl.dispose();
    _rankCtrl.dispose();
    _employeeNumberCtrl.dispose();
    super.dispose();
  }

  // ---------- HELPERS DB ----------

  /// Crea la tabla si no existe y añade columnas que falten (migración simple).
  Future<void> _ensureCrewTableExists() async {
    final db = await DBHelper.getDB();

    // Tabla mínima con solo id
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_crewTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT
      )
    ''');

    // Inspeccionamos columnas existentes
    final columnsInfo = await db.rawQuery('PRAGMA table_info($_crewTable)');
    final existingColumns = <String>{
      for (final row in columnsInfo)
        if (row['name'] is String) row['name'] as String,
    };

    Future<void> addColumn(String name, String type) async {
      if (!existingColumns.contains(name)) {
        await db.execute('ALTER TABLE $_crewTable ADD COLUMN $name $type');
      }
    }

    await addColumn('firstName', 'TEXT');
    await addColumn('lastName', 'TEXT');
    await addColumn('phone', 'TEXT');
    await addColumn('phoneFlag', 'TEXT');
    await addColumn('email', 'TEXT');
    await addColumn('country', 'TEXT'); // se guarda en inglés (estable)
    await addColumn('airline', 'TEXT');
    await addColumn('rank', 'TEXT');
    await addColumn('employeeNumber', 'TEXT');
    await addColumn('createdAt', 'TEXT');
  }

  Future<void> _loadCrew() async {
    final db = await DBHelper.getDB();
    await _ensureCrewTableExists();

    final rows = await db.query(
      _crewTable,
      where: 'id = ?',
      whereArgs: [widget.crewId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final r = rows.first;

      _firstNameCtrl.text = (r['firstName'] as String? ?? '').trim();
      _lastNameCtrl.text = (r['lastName'] as String? ?? '').trim();

      final storedPhone = (r['phone'] as String? ?? '').trim();
      if (storedPhone.isNotEmpty) {
        _phoneCtrl.text = storedPhone;
      }

      final savedFlagRaw = r['phoneFlag'] as String?;
      final savedFlag = savedFlagRaw != null && savedFlagRaw.trim().isNotEmpty
          ? savedFlagRaw.trim()
          : null;

      if (savedFlag != null) {
        _phoneFlag = savedFlag;
      } else if (storedPhone.isNotEmpty) {
        _phoneFlag = inferPhoneFlag(storedPhone);
      }

      _emailCtrl.text = (r['email'] as String? ?? '').trim();

      final countryRaw = (r['country'] as String? ?? '').trim();
      if (countryRaw.isNotEmpty) {
        cdata.CountryData? match;
        for (final c in cdata.allCountryData) {
          if (c.name == 'Simulator') continue;
          if (c.name == countryRaw) {
            match = c;
            break;
          }
        }

        _selectedCountry = match;

        if (match != null) {
          final shown = _displayCountryForData(match);
          _countryCtrl.text = '${match.flagEmoji} $shown';
        } else {
          _countryCtrl.text = countryRaw; // fallback
        }
      }

      _airlineCtrl.text = (r['airline'] as String? ?? '').trim();

      final rankRaw = (r['rank'] as String? ?? '').trim();
      _rankCtrl.text = rankRaw;
      _selectedRole = _inferRoleFromStoredRank(rankRaw);

      _employeeNumberCtrl.text = (r['employeeNumber'] as String? ?? '').trim();
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String? _nullIfEmpty(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  // ---------- TELEFONO / BANDERA ----------

  String _normalizePhone(String input) {
    final t = input.trim();
    if (t.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      final ch = t[i];
      if (ch == '+' && buffer.isEmpty) {
        buffer.write(ch);
      } else if (RegExp(r'\d').hasMatch(ch)) {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  String? inferPhoneFlag(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    for (final c in cdata.allCountryData) {
      final flag = c.flagEmoji.trim();
      if (flag.isNotEmpty && raw.startsWith(flag)) {
        return flag;
      }
    }

    final normalized = _normalizePhone(raw);
    if (normalized.isEmpty) return null;

    final digits = normalized.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;

    for (final c in cdata.allCountryData) {
      for (final code in c.phoneCode) {
        final codeNorm = _normalizePhone(code).replaceAll(RegExp(r'[^\d]'), '');
        if (codeNorm.isEmpty) continue;

        if (digits.startsWith(codeNorm)) {
          return c.flagEmoji;
        }
      }
    }

    return null;
  }

  // ---------- ROL (POPUP) ----------

  Future<void> _pickCrewRole() async {
    final selection = await showCrewRolePopup(context);
    if (selection == null) return;

    setState(() {
      _selectedRole = selection;
      _rankCtrl.text = '${selection.code} – ${selection.name}';
    });
  }

  CrewRoleSelection? _inferRoleFromStoredRank(String rankRaw) {
    if (rankRaw.isEmpty) return null;
    final l = AppLocalizations.of(context);

    final match = RegExp(r'^[A-Za-z]+').firstMatch(rankRaw);
    final code = (match?.group(0) ?? '').toUpperCase();
    if (code.isEmpty) return null;

    switch (code) {
      case 'COM':
        return CrewRoleSelection(
          code: 'COM',
          name: l.t("crew_role_com_name"),
          description: l.t("crew_role_com_desc"),
        );
      case 'PIC':
        return CrewRoleSelection(
          code: 'PIC',
          name: l.t("crew_role_pic_name"),
          description: l.t("crew_role_pic_desc"),
        );
      case 'SIC':
        return CrewRoleSelection(
          code: 'SIC',
          name: l.t("crew_role_sic_name"),
          description: l.t("crew_role_sic_desc"),
        );
      case 'SPIC':
        return CrewRoleSelection(
          code: 'SPIC',
          name: l.t("crew_role_spic_name"),
          description: l.t("crew_role_spic_desc"),
        );
      case 'PICUS':
        return CrewRoleSelection(
          code: 'PICUS',
          name: l.t("crew_role_picus_name"),
          description: l.t("crew_role_picus_desc"),
        );
      case 'INS':
        return CrewRoleSelection(
          code: 'INS',
          name: l.t("crew_role_ins_name"),
          description: l.t("crew_role_ins_desc"),
        );
      case 'STU':
        return CrewRoleSelection(
          code: 'STU',
          name: l.t("crew_role_stu_name"),
          description: l.t("crew_role_stu_desc"),
        );
      case 'OTHR':
        return CrewRoleSelection(
          code: 'OTHR',
          name: l.t("crew_role_other_name"),
          description: l.t("crew_role_other_desc"),
          isCustom: true,
        );
      default:
        return null;
    }
  }

  Color _roleColorForCode(String code) {
    switch (code.toUpperCase()) {
      case 'COM':
        return const Color(0xFF024755);
      case 'PIC':
        return const Color(0xFF125864);
      case 'SIC':
        return const Color(0xFF216873);
      case 'SPIC':
        return const Color(0xFF337983);
      case 'PICUS':
        return const Color(0xFF418991);
      case 'INS':
        return const Color(0xFF519AA0);
      case 'STU':
        return const Color(0xFF61AAAF);
      case 'OTHR':
      default:
        return const Color(0xFF72BBBF);
    }
  }

  Widget _buildSelectedRoleDisplay(
    BuildContext context,
    CrewRoleSelection role,
  ) {
    // Tema fijo oscuro
    final titleColor = Colors.white;
    final subtitleColor = Colors.white.withValues(alpha: 0.85);
    final pillColor = _roleColorForCode(role.code);

    return InkWell(
      onTap: _pickCrewRole,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white24,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: Colors.white, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                role.code,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 0),
                  Text(
                    role.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- GUARDAR CREW ----------

  Future<void> _saveCrew() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final db = await DBHelper.getDB();
      await _ensureCrewTableExists();

      final first = _firstNameCtrl.text.trim();
      final last = _lastNameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final airline = _airlineCtrl.text.trim();
      final rank = _rankCtrl.text.trim();
      final employeeNumber = _employeeNumberCtrl.text.trim();

      // País: guardar estable en inglés (name del country_data)
      String? countryToStore;
      if (_selectedCountry != null) {
        countryToStore = _selectedCountry!.name;
      } else {
        final raw = _countryCtrl.text.trim();
        countryToStore = raw.isEmpty ? null : raw;
      }

      final data = <String, Object?>{
        'firstName': _nullIfEmpty(first),
        'lastName': _nullIfEmpty(last),
        'phone': _nullIfEmpty(phone),
        'phoneFlag': _phoneFlag,
        'email': _nullIfEmpty(email),
        'country': countryToStore,
        'airline': _nullIfEmpty(airline),
        'rank': _nullIfEmpty(rank),
        'employeeNumber': _nullIfEmpty(employeeNumber),
      };

      if (widget.crewId == null) {
        data['createdAt'] = DateTime.now().toIso8601String();
        await db.insert(_crewTable, data);
      } else {
        await db.update(
          _crewTable,
          data,
          where: 'id = ?',
          whereArgs: [widget.crewId],
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error saving crew data: $e');
      // ignore: avoid_print
      print(st);

      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("error_saving_crew_data"))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- ELIMINAR CREW ----------

  Future<void> _deleteCrew() async {
    final l = AppLocalizations.of(context);

    await showPopWindow(
      context: context,
      title: l.t("delete_crew_member"),
      children: [
        Text(
          l.t("are_you_sure_you_want_to_delete_this_crew_member"),
        ),
        const SizedBox(height: 16),
        ButtonStyles.pillCancelSave(
          onCancel: () => Navigator.pop(context),
          onSave: () async {
            Navigator.pop(context);

            try {
              final db = await DBHelper.getDB();
              if (widget.crewId != null) {
                await db.delete(
                  _crewTable,
                  where: 'id = ?',
                  whereArgs: [widget.crewId],
                );
              }

              if (!mounted) return;
              Navigator.pop(context, true);
            } catch (e, st) {
              // ignore: avoid_print
              print('Error deleting crew: $e');
              // ignore: avoid_print
              print(st);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.t("error_deleting_data"))),
              );
            }
          },
          cancelLabel: l.t("cancel"),
          saveLabel: l.t("delete"),
        ),
      ],
    );
  }

  // ---------- PAÍS ----------

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
        final shown = _displayCountryForData(selected!);
        _countryCtrl.text = '${selected!.flagEmoji} $shown';
      });
    }
  }

  // ---------- UI BUILDERS ----------

  Widget _buildCrewDetailsSection(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SectionContainer(
      children: [
        SectionItemTitle(title: l.t("crew_details")),
        const SizedBox(height: 8),

        // Role
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t("crew_role"),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            if (_selectedRole == null)
              OutlinedButton(
                onPressed: _pickCrewRole,
                child: Text(l.t("add_role")),
              )
            else
              _buildSelectedRoleDisplay(context, _selectedRole!),
          ],
        ),
        const SizedBox(height: 10),

        // Nombre / Apellido
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _firstNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l.t("first_name"),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _lastNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l.t("last_name"),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: const [PhoneFormatter()],
          decoration: InputDecoration(
            labelText: l.t("phone_number"),
            prefixText: _phoneFlag != null ? '$_phoneFlag ' : null,
          ),
          onChanged: (value) {
            final trimmed = value.trim();

            if (trimmed.isEmpty) {
              setState(() {
                _phoneFlag = null;
              });
              return;
            }

            final newFlag = inferPhoneFlag(value);
            if (newFlag != null) {
              setState(() {
                _phoneFlag = newFlag;
              });
            }
          },
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l.t("email"),
          ),
        ),
        const SizedBox(height: 10),

        GestureDetector(
          onTap: _pickCountry,
          child: AbsorbPointer(
            child: TextField(
              controller: _countryCtrl,
              decoration: InputDecoration(
                labelText: l.t("country"),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _airlineCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l.t("airline"),
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _employeeNumberCtrl,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l.t("employee_number"),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final String title = widget.crewId == null
        ? l.t("new_crew_member")
        : l.t("edit_crew_member");

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
                  _buildCrewDetailsSection(context),
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
                        await _saveCrew();
                      }
                    },
                    // Delete centrado solo al editar
                    deleteLabel: widget.crewId != null ? l.t("delete") : null,
                    onDelete: widget.crewId != null
                        ? () async {
                            await _deleteCrew();
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
