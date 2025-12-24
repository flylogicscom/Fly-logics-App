// lib/features/aircraft/airplanes.dart

import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/section_container.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/popwindow.dart';
import 'package:fly_logicd_logbook_app/common/pop_aircraft_type.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';
import 'package:fly_logicd_logbook_app/utils/country_data.dart' as cdata;

class Airplanes extends StatefulWidget {
  /// null = nuevo, != null = editar
  final int? aircraftId;

  const Airplanes({super.key, this.aircraftId});

  @override
  State<Airplanes> createState() => _AirplanesState();
}

class _AirplanesState extends State<Airplanes> {
  static const String _aircraftTable = 'aircraft_items';

  bool _loading = true;
  bool _saving = false;

  /// Selección de tipo(s) desde el popup
  AircraftTypeSelection? _aircraftType;

  /// Flag para decidir si es simulador (para mostrar/ocultar secciones)
  bool _isSimulator = false;

  // Aircraft
  final TextEditingController _registrationCtrl = TextEditingController();
  final TextEditingController _countryCtrl = TextEditingController();
  final TextEditingController _identifierCtrl = TextEditingController();
  final TextEditingController _makeModelCtrl = TextEditingController();
  final TextEditingController _serialNumberCtrl = TextEditingController();
  final TextEditingController _ownerCtrl = TextEditingController();

  // Simulator
  final TextEditingController _simCompanyCtrl = TextEditingController();
  final TextEditingController _simAircraftModelCtrl = TextEditingController();
  final TextEditingController _simLevelCtrl = TextEditingController();
  final TextEditingController _simSerialNumberCtrl = TextEditingController();

  // Observations + tags (comunes)
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _tagInputCtrl = TextEditingController();
  final List<String> _tags = <String>[];

  cdata.CountryData? _selectedCountry;
  String? _countryFlag; // emoji

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _registrationCtrl.dispose();
    _countryCtrl.dispose();
    _identifierCtrl.dispose();
    _makeModelCtrl.dispose();
    _serialNumberCtrl.dispose();
    _ownerCtrl.dispose();

    _simCompanyCtrl.dispose();
    _simAircraftModelCtrl.dispose();
    _simLevelCtrl.dispose();
    _simSerialNumberCtrl.dispose();

    _notesCtrl.dispose();
    _tagInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _ensureAircraftTableExists();
    if (widget.aircraftId != null) {
      await _loadAircraft();
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // ================== DB / ESQUEMA ==================

  Future<void> _ensureAircraftTableExists() async {
    final db = await DBHelper.getDB();

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_aircraftTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT
      )
    ''');

    final info = await db.rawQuery('PRAGMA table_info($_aircraftTable)');
    final existing = <String>{
      for (final row in info)
        if (row['name'] is String) row['name'] as String,
    };

    Future<void> addColumn(String name, String type) async {
      if (!existing.contains(name)) {
        await db.execute('ALTER TABLE $_aircraftTable ADD COLUMN $name $type');
      }
    }

    // Tipos
    await addColumn('typeCode', 'TEXT'); // código principal (SE, ME, etc.)
    await addColumn('typeTitle', 'TEXT'); // títulos concatenados
    await addColumn('typeIds', 'TEXT'); // ids 1..9 separados por coma
    await addColumn('isSimulator', 'INTEGER');

    // Datos adicionales para "Otro" personalizado
    await addColumn('typeCustomLabel', 'TEXT');
    await addColumn('typeCustomDescription', 'TEXT');
    await addColumn('typeCustomNotes', 'TEXT');

    // Datos de aeronave
    await addColumn('registration', 'TEXT');
    await addColumn('registrationPrefix', 'TEXT');
    await addColumn('countryName', 'TEXT');
    await addColumn('countryFlag', 'TEXT');
    await addColumn('identifier', 'TEXT');
    await addColumn('makeModel', 'TEXT');
    await addColumn('serialNumber', 'TEXT');
    await addColumn('owner', 'TEXT');

    // Simulador
    await addColumn('simCompany', 'TEXT');
    await addColumn('simAircraftModel', 'TEXT');
    await addColumn('simLevel', 'TEXT');
    await addColumn('simSerialNumber', 'TEXT');

    // Notas y tags
    await addColumn('notes', 'TEXT');
    await addColumn('tags', 'TEXT');
    await addColumn('createdAt', 'TEXT');
  }

  Future<void> _loadAircraft() async {
    final db = await DBHelper.getDB();
    final rows = await db.query(
      _aircraftTable,
      where: 'id = ?',
      whereArgs: [widget.aircraftId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final Map<String, Object?> r = rows.first;

    // isSimulator desde la columna
    final isSimVal = r['isSimulator'];
    if (isSimVal is int) {
      _isSimulator = isSimVal != 0;
    } else if (isSimVal is num) {
      _isSimulator = isSimVal != 0;
    } else {
      _isSimulator = false;
    }

    // Fallback: si no había isSimulator pero typeIds contiene SIM (9)
    if (!_isSimulator) {
      final typeIdsStr = (r['typeIds'] as String? ?? '').trim();
      if (typeIdsStr.isNotEmpty) {
        final ids = typeIdsStr
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>()
            .toSet();
        if (ids.contains(9)) {
          _isSimulator = true;
        }
      }
    }

    // Reconstruir selección de tipo (incluye combos + "Otro" personalizado)
    _aircraftType = _rebuildAircraftTypeFromRow(r);

    // Campos comunes
    _registrationCtrl.text = (r['registration'] as String? ?? '').trim();
    _identifierCtrl.text = (r['identifier'] as String? ?? '').trim();
    _makeModelCtrl.text = (r['makeModel'] as String? ?? '').trim();
    _serialNumberCtrl.text = (r['serialNumber'] as String? ?? '').trim();
    _ownerCtrl.text = (r['owner'] as String? ?? '').trim();

    // Simulador
    _simCompanyCtrl.text = (r['simCompany'] as String? ?? '').trim();
    _simAircraftModelCtrl.text =
        (r['simAircraftModel'] as String? ?? '').trim();
    _simLevelCtrl.text = (r['simLevel'] as String? ?? '').trim();
    _simSerialNumberCtrl.text = (r['simSerialNumber'] as String? ?? '').trim();

    // Notas
    _notesCtrl.text = (r['notes'] as String? ?? '').trim();

    // Tags
    final tagsStr = (r['tags'] as String? ?? '').trim();
    if (tagsStr.isNotEmpty) {
      _tags
        ..clear()
        ..addAll(
          tagsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
        );
    }

    // País
    final countryName = (r['countryName'] as String? ?? '').trim();
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
          : (match != null && match.flagEmoji.trim().isNotEmpty
              ? match.flagEmoji.trim()
              : null);

      final prefix = _countryFlag != null && _countryFlag!.isNotEmpty
          ? '${_countryFlag!} '
          : '';
      _countryCtrl.text = '$prefix$countryName';
    } else {
      _selectedCountry = null;
      _countryFlag = null;
      _countryCtrl.clear();
    }
  }

  AircraftTypeSelection? _rebuildAircraftTypeFromRow(
    Map<String, Object?> r,
  ) {
    final storedTypeCode = (r['typeCode'] as String? ?? '').trim();
    final storedTypeTitleJoined = (r['typeTitle'] as String? ?? '').trim();
    final storedTypeIdsStr = (r['typeIds'] as String? ?? '').trim();

    // Títulos: lo que guardaste con allTitles.join('|')
    final titles = storedTypeTitleJoined
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Mapear ids -> códigos SE/ME/…/OTHER/SIM
    final codesFromIds = <String>[];
    if (storedTypeIdsStr.isNotEmpty) {
      for (final part in storedTypeIdsStr.split(',')) {
        final id = int.tryParse(part.trim());
        if (id == null) continue;
        switch (id) {
          case 1:
            codesFromIds.add('SE');
            break;
          case 2:
            codesFromIds.add('ME');
            break;
          case 3:
            codesFromIds.add('TP');
            break;
          case 4:
            codesFromIds.add('TJ');
            break;
          case 5:
            codesFromIds.add('LSA');
            break;
          case 6:
            codesFromIds.add('HELI');
            break;
          case 7:
            codesFromIds.add('GLID');
            break;
          case 8:
            codesFromIds.add('OTHER');
            break;
          case 9:
            codesFromIds.add('SIM');
            break;
          default:
            break;
        }
      }
    }

    // Fallbacks
    if (codesFromIds.isEmpty && storedTypeCode.isNotEmpty) {
      codesFromIds.add(storedTypeCode);
    }
    if (codesFromIds.isEmpty && titles.isEmpty) {
      return null; // no hay nada que reconstruir
    }

    final primaryCode = codesFromIds.isNotEmpty
        ? codesFromIds.first
        : (storedTypeCode.isNotEmpty ? storedTypeCode : 'LEG');

    final extraCodes =
        codesFromIds.length > 1 ? codesFromIds.sublist(1) : const <String>[];

    final primaryTitle = titles.isNotEmpty
        ? titles.first
        : (storedTypeTitleJoined.isNotEmpty
            ? storedTypeTitleJoined
            : (storedTypeCode.isNotEmpty ? storedTypeCode : primaryCode));

    final extraTitles =
        titles.length > 1 ? titles.sublist(1) : const <String>[];

    // Datos de "Otro" personalizado (si aplica)
    final customLabel = (r['typeCustomLabel'] as String? ?? '').trim();
    final customDescription =
        (r['typeCustomDescription'] as String? ?? '').trim();
    final customNotes = (r['typeCustomNotes'] as String? ?? '').trim();

    final bool isOtherSelected =
        codesFromIds.contains('OTHER') || primaryCode.toUpperCase() == 'OTHER';

    final bool isCustom = isOtherSelected &&
        (customLabel.isNotEmpty ||
            customDescription.isNotEmpty ||
            customNotes.isNotEmpty);

    String effectiveTitle = primaryTitle;
    String? effectiveDescription;
    String? effectiveNotes;

    if (isCustom) {
      if (customLabel.isNotEmpty) {
        effectiveTitle = customLabel;
      }
      if (customDescription.isNotEmpty) {
        effectiveDescription = customDescription;
      }
      if (customNotes.isNotEmpty) {
        effectiveNotes = customNotes;
      }
    }

    return AircraftTypeSelection(
      code: primaryCode,
      title: effectiveTitle,
      extraCodes: extraCodes,
      extraTitles: extraTitles,
      isCustom: isCustom,
      description: effectiveDescription,
      notes: effectiveNotes,
    );
  }

  String? _nullIfEmpty(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  // ================== COUNTRY / REGISTRATION HELPERS ==================

  /// Busca país por nombre, probando varias variantes.
  cdata.CountryData? _findCountryByAnyName(List<String> names) {
    final lowerCandidates = names.map((n) => n.toLowerCase()).toList();
    for (final c in cdata.allCountryData) {
      if (c.name == 'Simulator') continue;
      final ln = c.name.toLowerCase();
      if (lowerCandidates.contains(ln)) return c;
    }
    return null;
  }

  /// Busca el país por prefijo de matrícula usando CountryData.registration.
  ///
  /// - Se hace búsqueda por prefijo que empieza el registro.
  /// - Soporta prefijos con y sin guion:
  ///   - Si en la DB está `CC-` y el usuario escribe `CCABC` ⇒ coincide.
  ///   - Si en la DB está `CC-` y el usuario escribe `CC-ABC` ⇒ coincide.
  /// - En caso de conflicto se elige el prefijo más largo (más específico).
  cdata.CountryData? _findCountryByRegistration(String registration) {
    final input = registration.toUpperCase().trim();
    if (input.isEmpty) return null;

    cdata.CountryData? bestCountry;
    int bestPrefixLen = 0;

    for (final country in cdata.allCountryData) {
      if (country.name == 'Simulator') continue;

      for (final rawPrefix in country.registration) {
        var prefix = rawPrefix.toUpperCase().trim();
        if (prefix.isEmpty) continue;

        // Variantes: 'CC-' => ['CC-', 'CC'], 'CC' => ['CC', 'CC-']
        final variants = <String>{prefix};
        if (prefix.endsWith('-')) {
          variants.add(prefix.substring(0, prefix.length - 1));
        } else {
          variants.add('$prefix-');
        }

        for (final v in variants) {
          if (v.isEmpty) continue;
          if (input.startsWith(v) && v.length > bestPrefixLen) {
            bestPrefixLen = v.length;
            bestCountry = country;
          }
        }
      }
    }

    return bestCountry;
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

    if (!mounted || selected == null) return;

    setState(() {
      _selectedCountry = selected;
      final emoji = selected!.flagEmoji.trim();
      _countryFlag = emoji.isEmpty ? null : emoji;
      _countryCtrl.text =
          '${_countryFlag != null ? '${_countryFlag!} ' : ''}${selected!.name}';
    });
  }

  /// La matrícula propone el país según reglas + CountryData.registration:
  /// - N...  => USA siempre.
  /// - B- + letra => China.
  /// - B- + número => Taiwan.
  /// - Resto: no se busca hasta que haya un guion.
  ///   * Excepto VP-, VQ-: se espera al siguiente carácter (ej. VP-B...).
  void _onRegistrationChanged(String value) {
    // Forzar texto en el campo a MAYÚSCULAS
    final upper = value.toUpperCase();
    if (upper != value) {
      _registrationCtrl.value = _registrationCtrl.value.copyWith(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }

    final reg = upper.trim();
    if (reg.isEmpty) return;

    // Si ya hay país seleccionado o escrito, no tocamos nada
    if (_selectedCountry != null || _countryCtrl.text.trim().isNotEmpty) {
      return;
    }

    // Regla fija: N ⇒ USA
    if (reg.startsWith('N')) {
      final us = _findCountryByAnyName([
        'United States',
        'United States of America',
        'USA',
      ]);
      if (us != null) {
        setState(() {
          _selectedCountry = us;
          final emoji = us.flagEmoji.trim();
          _countryFlag = emoji.isEmpty ? null : emoji;
          _countryCtrl.text =
              '${_countryFlag != null ? '${_countryFlag!} ' : ''}${us.name}';
        });
      }
      return;
    }

    // A partir de aquí, para el resto se exige que haya guion
    final hyphenIndex = reg.indexOf('-');
    if (hyphenIndex == -1) {
      // Aún no se ha introducido guion ⇒ no buscamos
      return;
    }

    final prefixWithHyphen = reg.substring(0, hyphenIndex + 1);

    // Excepción: VP-, VQ- ⇒ esperamos a que se escriba el siguiente carácter
    if ((prefixWithHyphen == 'VP-' || prefixWithHyphen == 'VQ-') &&
        reg.length == prefixWithHyphen.length) {
      return;
    }

    // Regla: B- seguido de letras => China, B- seguido de números => Taiwan
    if (prefixWithHyphen == 'B-' && reg.length > prefixWithHyphen.length) {
      String? nextChar;
      for (int i = hyphenIndex + 1; i < reg.length; i++) {
        final c = reg[i];
        if (c != ' ') {
          nextChar = c;
          break;
        }
      }

      if (nextChar != null) {
        final isDigit = RegExp(r'\d').hasMatch(nextChar);
        final target = isDigit
            ? _findCountryByAnyName([
                'Taiwan',
                'Taiwan, Province of China',
                'Republic of China (Taiwan)',
              ])
            : _findCountryByAnyName([
                'China',
                "People's Republic of China",
              ]);

        if (target != null) {
          setState(() {
            _selectedCountry = target;
            final emoji = target.flagEmoji.trim();
            _countryFlag = emoji.isEmpty ? null : emoji;
            _countryCtrl.text =
                '${_countryFlag != null ? '${_countryFlag!} ' : ''}${target.name}';
          });
          return;
        }
      }
    }

    // Búsqueda normal por prefijo de matrícula usando CountryData.registration
    final match = _findCountryByRegistration(reg);
    if (match == null) return;

    setState(() {
      _selectedCountry = match;
      final emoji = match.flagEmoji.trim();
      _countryFlag = emoji.isEmpty ? null : emoji;
      _countryCtrl.text =
          '${_countryFlag != null ? '${_countryFlag!} ' : ''}${match.name}';
    });
  }

  /// Abre el popup de tipo de aeronave / simulador
  Future<void> _pickAircraftType() async {
    final sel = await showAircraftTypePopup(context);
    if (sel == null) return;

    setState(() {
      _aircraftType = sel;
      final codes = sel.allCodes;
      _isSimulator = codes.any((c) => c.toUpperCase() == 'SIM');
    });
  }

  /// Mapea códigos (SE, ME, …) a ids 1..9 para guardar en `typeIds`.
  Set<int> _mapCodesToIds(AircraftTypeSelection sel) {
    final ids = <int>{};
    for (final codeRaw in sel.allCodes) {
      final c = codeRaw.toUpperCase();
      switch (c) {
        case 'SE':
          ids.add(1);
          break;
        case 'ME':
          ids.add(2);
          break;
        case 'TP':
          ids.add(3);
          break;
        case 'TJ':
          ids.add(4);
          break;
        case 'LSA':
          ids.add(5);
          break;
        case 'HELI':
          ids.add(6);
          break;
        case 'GLID':
          ids.add(7);
          break;
        case 'OTHER':
          ids.add(8);
          break;
        case 'SIM':
          ids.add(9);
          break;
        default:
          break;
      }
    }
    return ids;
  }

  // ================== TAGS ==================

  void _addTagFromInput([String? raw]) {
    final txtRaw = (raw ?? _tagInputCtrl.text).trim();
    if (txtRaw.isEmpty) return;

    final txt = txtRaw.toUpperCase();

    if (_tags.contains(txt)) {
      _tagInputCtrl.clear();
      return;
    }
    setState(() {
      _tags.add(txt);
    });
    _tagInputCtrl.clear();
  }

  void _removeTagAt(int index) {
    if (index < 0 || index >= _tags.length) return;
    setState(() {
      _tags.removeAt(index);
    });
  }

  // ================== GUARDAR / BORRAR ==================

  Future<void> _saveAircraft() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final db = await DBHelper.getDB();
      await _ensureAircraftTableExists();

      String? countryName;
      if (_selectedCountry != null) {
        countryName = _selectedCountry!.name;
      } else {
        final raw = _countryCtrl.text.trim();
        if (raw.isNotEmpty) {
          final parts = raw.split(' ');
          if (parts.length > 1 &&
              parts.first.runes.length <= 4 &&
              parts.first.contains(
                RegExp(r'[\u2190-\u2BFF\u1F300-\u1F5FF]'),
              )) {
            countryName = parts.sublist(1).join(' ');
          } else {
            countryName = raw;
          }
        }
      }

      final registration = _registrationCtrl.text.trim();
      final registrationPrefix = _extractRegistrationPrefix(registration);

      final sel = _aircraftType;
      final ids = sel == null ? <int>{} : _mapCodesToIds(sel);
      final isSim =
          sel?.allCodes.any((c) => c.toUpperCase() == 'SIM') ?? _isSimulator;

      final data = <String, Object?>{
        // Tipos
        'typeCode': sel?.code,
        'typeTitle': sel?.allTitles.join('|'), // separador seguro
        'typeIds': ids.isEmpty ? null : ids.join(','),
        'isSimulator': isSim ? 1 : 0,
        'typeCustomLabel': sel != null && sel.isCustom ? sel.title : null,
        'typeCustomDescription':
            sel != null && sel.isCustom ? sel.description : null,
        'typeCustomNotes': sel != null && sel.isCustom ? sel.notes : null,

        // Aeronave / simulador
        'registration': _nullIfEmpty(registration),
        'registrationPrefix': _nullIfEmpty(registrationPrefix),
        'countryName': _nullIfEmpty(countryName),
        'countryFlag': _countryFlag,
        'identifier': _nullIfEmpty(_identifierCtrl.text),
        'makeModel': _nullIfEmpty(_makeModelCtrl.text),
        'serialNumber': _nullIfEmpty(_serialNumberCtrl.text),
        'owner': _nullIfEmpty(_ownerCtrl.text),

        'simCompany': _nullIfEmpty(_simCompanyCtrl.text),
        'simAircraftModel': _nullIfEmpty(_simAircraftModelCtrl.text),
        'simLevel': _nullIfEmpty(_simLevelCtrl.text),
        'simSerialNumber': _nullIfEmpty(_simSerialNumberCtrl.text),

        'notes': _nullIfEmpty(_notesCtrl.text),
        'tags': _tags.isEmpty ? null : _tags.join(','),
      };

      if (widget.aircraftId == null) {
        data['createdAt'] = DateTime.now().toIso8601String();
        await db.insert(_aircraftTable, data);
      } else {
        await db.update(
          _aircraftTable,
          data,
          where: 'id = ?',
          whereArgs: [widget.aircraftId],
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error saving aircraft: $e');
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

  Future<void> _deleteAircraft() async {
    if (widget.aircraftId == null) return;

    try {
      final db = await DBHelper.getDB();
      await db.delete(
        _aircraftTable,
        where: 'id = ?',
        whereArgs: [widget.aircraftId],
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error deleting aircraft: $e');
      // ignore: avoid_print
      print(st);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("error_saving_data"))),
      );
    }
  }

  String _extractRegistrationPrefix(String registration) {
    final up = registration.toUpperCase().trim();
    final buffer = StringBuffer();
    for (final ch in up.runes) {
      final c = String.fromCharCode(ch);
      if (RegExp(r'[A-Z]').hasMatch(c)) {
        buffer.write(c);
      } else {
        break;
      }
    }
    return buffer.toString();
  }

  // ================== UI HELPERS ==================

  InputDecoration _fieldDecoration(BuildContext context, String key) {
    final l = AppLocalizations.of(context);
    return InputDecoration(
      labelText: l.t(key),
      labelStyle: AppTextStyles.headline2,
    );
  }

  Color _chipColorForCode(String code) {
    switch (code.toUpperCase()) {
      case 'SE':
        return AppColors.se;
      case 'ME':
        return AppColors.me;
      case 'TP':
        return AppColors.tp;
      case 'TJ':
        return AppColors.tj;
      case 'LSA':
        return AppColors.lsa;
      case 'HELI':
        return AppColors.he;
      case 'GLID':
        return AppColors.pl;
      case 'OTHER':
        return AppColors.ot;
      case 'SIM':
        return AppColors.sim;
      default:
        return AppColors.teal4;
    }
  }

  Widget _buildTypeSection(BuildContext context) {
    final l = AppLocalizations.of(context);

    final hasSelection =
        _aircraftType != null && _aircraftType!.allCodes.isNotEmpty;

    return SectionContainer(
      children: [
        SectionItemTitle(title: l.t("aircraft_section_type_title")),
        const SizedBox(height: 8),

        // Sin selección: botón pill "add_type_aircraft"
        if (!hasSelection)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _pickAircraftType,
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: BorderSide(color: Colors.white.withOpacity(0.8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                l.t("add_type_aircraft"),
                style: AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          )
        else
          Row(
            children: [
              // Etiquetas de colores con los tipos seleccionados
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(
                    _aircraftType!.allCodes.length,
                    (index) {
                      final code = _aircraftType!.allCodes[index];
                      final titles = _aircraftType!.allTitles;
                      final title =
                          index < titles.length ? titles[index] : code;
                      final color = _chipColorForCode(code);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.0),
                        ),
                        child: Text(
                          title,
                          style: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón cuadrado con esquinas redondas y símbolo +
              Material(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _pickAircraftType,
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: 8),
        Text(
          _isSimulator
              ? l.t("aircraft_mode_simulator_hint")
              : l.t("aircraft_mode_aircraft_hint"),
          style: AppTextStyles.body.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // Datos de aeronave + observaciones + tags en la MISMA sección
  Widget _buildAircraftSection(BuildContext context) {
    if (_isSimulator) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);

    return SectionContainer(
      children: [
        SectionItemTitle(
          title:
              AppLocalizations.of(context).t("aircraft_section_aircraft_title"),
        ),
        const SizedBox(height: 8),

        // Matrícula / País
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _registrationCtrl,
                onChanged: _onRegistrationChanged,
                decoration: _fieldDecoration(
                  context,
                  "aircraft_registration_label",
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _pickCountry,
                child: AbsorbPointer(
                  child: TextField(
                    controller: _countryCtrl,
                    decoration: _fieldDecoration(
                      context,
                      "aircraft_country_label",
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Identificador
        TextField(
          controller: _identifierCtrl,
          onChanged: (value) {
            final upper = value.toUpperCase();
            if (upper != value) {
              _identifierCtrl.value = _identifierCtrl.value.copyWith(
                text: upper,
                selection: TextSelection.collapsed(offset: upper.length),
              );
            }
          },
          decoration: _fieldDecoration(
            context,
            "aircraft_identifier_label",
          ).copyWith(
            hintText: l.t("aircraft_identifier_hint"), // ej. "C-150"
          ),
        ),
        const SizedBox(height: 12),

        // Marca y modelo
        TextField(
          controller: _makeModelCtrl,
          // 1. ESTA ES LA CLAVE:
          // El teclado se pondrá en mayúsculas automáticamente al inicio de cada palabra.
          // Es el comportamiento "por defecto" que buscas.
          textCapitalization: TextCapitalization.words,

          // 2. Deja el onChanged libre de transformaciones:
          onChanged: (value) {
            // Aquí puedes realizar otras acciones (como validaciones),
            // pero NO modifiques el texto del controlador.
          },

          decoration: _fieldDecoration(
            context,
            "aircraft_make_model_label",
          ),
        ),

        // Número de serie
        TextField(
          controller: _serialNumberCtrl,
          decoration: _fieldDecoration(
            context,
            "aircraft_serial_number_label",
          ),
        ),
        const SizedBox(height: 12),

        // Propietario
        TextField(
          controller: _ownerCtrl,
          decoration: _fieldDecoration(
            context,
            "aircraft_owner_label",
          ),
        ),
        const SizedBox(height: 16),

        // Observaciones + Tags
        _buildNotesTagsContent(context),
      ],
    );
  }

  Widget _buildSimulatorSection(BuildContext context) {
    if (!_isSimulator) return const SizedBox.shrink();

    return SectionContainer(
      children: [
        SectionItemTitle(
          title: AppLocalizations.of(context)
              .t("aircraft_section_simulator_title"),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _simCompanyCtrl,
          decoration: _fieldDecoration(
            context,
            "aircraft_sim_company_label",
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _simAircraftModelCtrl,
          decoration: _fieldDecoration(
            context,
            "aircraft_sim_model_label",
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _simLevelCtrl,
          decoration: _fieldDecoration(
            context,
            "aircraft_sim_level_label",
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _simSerialNumberCtrl,
          decoration: _fieldDecoration(
            context,
            "aircraft_sim_serial_label",
          ),
        ),
        const SizedBox(height: 16),

        // Observaciones + Tags en la misma sección del simulador
        _buildNotesTagsContent(context),
      ],
    );
  }

  // Contenido de observaciones + tags reutilizable
  Widget _buildNotesTagsContent(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Observaciones
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: _fieldDecoration(
            context,
            "aircraft_notes_label",
          ),
        ),
        const SizedBox(height: 12),

        // Tags
        Text(
          l.t("aircraft_tags_label"),
          style: AppTextStyles.subtitle.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(_tags.length, (i) {
            final tag = _tags[i];
            return GestureDetector(
              onTap: () => _removeTagAt(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.teal3,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag,
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tagInputCtrl,
          decoration: InputDecoration(
            hintText: l.t("aircraft_tags_hint"),
          ),
          onChanged: (value) {
            final upper = value.toUpperCase();
            if (upper != value) {
              _tagInputCtrl.value = _tagInputCtrl.value.copyWith(
                text: upper,
                selection: TextSelection.collapsed(offset: upper.length),
              );
            }
          },
          onSubmitted: _addTagFromInput,
        ),
      ],
    );
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final String title = widget.aircraftId == null
        ? l.t("aircraft_new_title")
        : l.t("aircraft_edit_title");

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
                  _buildTypeSection(context),
                  const SizedBox(height: 12),
                  _buildAircraftSection(context),
                  const SizedBox(height: 12),
                  _buildSimulatorSection(context),
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
                        await _saveAircraft();
                      }
                    },
                    deleteLabel:
                        widget.aircraftId != null ? l.t("delete") : null,
                    onDelete: widget.aircraftId != null
                        ? () async {
                            await _deleteAircraft();
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
