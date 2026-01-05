// lib/features/logs/totalspage.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/section_container.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';
import 'package:sqflite/sqflite.dart';

class TotalsPage extends StatefulWidget {
  const TotalsPage({super.key});

  @override
  State<TotalsPage> createState() => _TotalsPageState();
}

class _TotalsPageState extends State<TotalsPage> {
  static const String _tableName = 'previous_totals';

  // id de fila (solo usamos una fila)
  int? _rowId;

  bool _loading = true;
  bool _saving = false;
  bool _isLocked = false;

  // Nombre
  final _nameCtrl = TextEditingController();

  // Flight times (decimales)
  final _totalFlightTimeCtrl = TextEditingController();

  // Aircraft / simulator (decimales)
  final _singleEngineCtrl = TextEditingController();
  final _multiEngineCtrl = TextEditingController();
  final _turbopropCtrl = TextEditingController();
  final _turbojetCtrl = TextEditingController();
  final _lsaCtrl = TextEditingController();
  final _helicopterCtrl = TextEditingController();
  final _gliderCtrl = TextEditingController();
  final _otherAircraftCtrl = TextEditingController();
  final _simulatorCtrl = TextEditingController();

  // Flight conditions (decimales)
  final _condDayCtrl = TextEditingController();
  final _condNightCtrl = TextEditingController();
  final _condIfrCtrl = TextEditingController();

  // Types of flight time (decimales)
  final _crossCountryCtrl = TextEditingController();
  final _soloCtrl = TextEditingController();
  final _picCtrl = TextEditingController();
  final _copilotCtrl = TextEditingController();
  final _instructionReceivedCtrl = TextEditingController();
  final _asInstructorCtrl = TextEditingController();

  // Takeoffs (enteros)
  final TextEditingController _takeoffsDayCtrl =
      TextEditingController(text: '0');
  final TextEditingController _takeoffsNightCtrl =
      TextEditingController(text: '0');

  // Landings (enteros)
  final TextEditingController _landingsDayCtrl =
      TextEditingController(text: '0');
  final TextEditingController _landingsNightCtrl =
      TextEditingController(text: '0');

  // Approaches (enteros)
  final _approachesNumberCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _totalFlightTimeCtrl.dispose();

    _singleEngineCtrl.dispose();
    _multiEngineCtrl.dispose();
    _turbopropCtrl.dispose();
    _turbojetCtrl.dispose();
    _lsaCtrl.dispose();
    _helicopterCtrl.dispose();
    _gliderCtrl.dispose();
    _otherAircraftCtrl.dispose();
    _simulatorCtrl.dispose();

    _condDayCtrl.dispose();
    _condNightCtrl.dispose();
    _condIfrCtrl.dispose();

    _crossCountryCtrl.dispose();
    _soloCtrl.dispose();
    _picCtrl.dispose();
    _copilotCtrl.dispose();
    _instructionReceivedCtrl.dispose();
    _asInstructorCtrl.dispose();

    _takeoffsDayCtrl.dispose();
    _takeoffsNightCtrl.dispose();
    _landingsDayCtrl.dispose();
    _landingsNightCtrl.dispose();
    _approachesNumberCtrl.dispose();

    super.dispose();
  }

  // ================== INIT / DB ==================

  Future<void> _init() async {
    try {
      final db = await DBHelper.getDB();
      await _ensureTable(db);

      final rows = await db.query(_tableName, limit: 1);
      if (rows.isNotEmpty) {
        final r = rows.first;
        _rowId = r['id'] as int?;

        _nameCtrl.text = (r['name'] as String? ?? '').trim();

        _setDecimalFromRow(_totalFlightTimeCtrl, r['totalFlightTime']);

        _setDecimalFromRow(_singleEngineCtrl, r['singleEngine']);
        _setDecimalFromRow(_multiEngineCtrl, r['multiEngine']);
        _setDecimalFromRow(_turbopropCtrl, r['turboprop']);
        _setDecimalFromRow(_turbojetCtrl, r['turbojet']);
        _setDecimalFromRow(_lsaCtrl, r['lsa']);
        _setDecimalFromRow(_helicopterCtrl, r['helicopter']);
        _setDecimalFromRow(_gliderCtrl, r['glider']);
        _setDecimalFromRow(_otherAircraftCtrl, r['otherAircraft']);
        _setDecimalFromRow(_simulatorCtrl, r['simulator']);

        _setDecimalFromRow(_condDayCtrl, r['condDay']);
        _setDecimalFromRow(_condNightCtrl, r['condNight']);
        _setDecimalFromRow(_condIfrCtrl, r['condIFR']);

        _setDecimalFromRow(_crossCountryCtrl, r['timeCrossCountry']);
        _setDecimalFromRow(_soloCtrl, r['timeSolo']);
        _setDecimalFromRow(_picCtrl, r['timePIC']);
        _setDecimalFromRow(_copilotCtrl, r['timeCopilot']);
        _setDecimalFromRow(_instructionReceivedCtrl, r['timeInstruction']);
        _setDecimalFromRow(_asInstructorCtrl, r['timeInstructor']);

        _setIntFromRow(_takeoffsDayCtrl, r['takeoffsDay']);
        _setIntFromRow(_takeoffsNightCtrl, r['takeoffsNight']);
        _setIntFromRow(_landingsDayCtrl, r['landingsDay']);
        _setIntFromRow(_landingsNightCtrl, r['landingsNight']);
        _setIntFromRow(_approachesNumberCtrl, r['approachesNumber']);

        final isLockedVal = r['isLocked'];
        if (isLockedVal is int) {
          _isLocked = isLockedVal != 0;
        } else if (isLockedVal is num) {
          _isLocked = isLockedVal.toInt() != 0;
        } else {
          _isLocked = false;
        }
      } else {
        _setDefaults();
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('Error loading previous totals: $e');
      // ignore: avoid_print
      print(st);
      _setDefaults();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT
      )
    ''');

    final info = await db.rawQuery('PRAGMA table_info($_tableName)');
    final existing = <String>{
      for (final row in info)
        if (row['name'] is String) row['name'] as String,
    };

    Future<void> addColumn(String name, String type) async {
      if (existing.contains(name)) return;
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN $name $type');
        existing.add(name);
      } on DatabaseException catch (e) {
        final msg = e.toString();
        if (msg.contains('duplicate column name')) {
          existing.add(name);
          return;
        }
        rethrow;
      }
    }

    await addColumn('name', 'TEXT');
    await addColumn('totalFlightTime', 'REAL');
    await addColumn('singleEngine', 'REAL');
    await addColumn('multiEngine', 'REAL');
    await addColumn('turboprop', 'REAL');
    await addColumn('turbojet', 'REAL');
    await addColumn('lsa', 'REAL');
    await addColumn('helicopter', 'REAL');
    await addColumn('glider', 'REAL');
    await addColumn('otherAircraft', 'REAL');
    await addColumn('simulator', 'REAL');

    await addColumn('condDay', 'REAL');
    await addColumn('condNight', 'REAL');
    await addColumn('condIFR', 'REAL');

    await addColumn('timeCrossCountry', 'REAL');
    await addColumn('timeSolo', 'REAL');
    await addColumn('timePIC', 'REAL');
    await addColumn('timeCopilot', 'REAL');
    await addColumn('timeInstruction', 'REAL');
    await addColumn('timeInstructor', 'REAL');

    await addColumn('takeoffsDay', 'INTEGER');
    await addColumn('takeoffsNight', 'INTEGER');
    await addColumn('landingsDay', 'INTEGER');
    await addColumn('landingsNight', 'INTEGER');
    await addColumn('approachesNumber', 'INTEGER');

    await addColumn('createdAt', 'TEXT');
    await addColumn('isLocked', 'INTEGER');
  }

  void _setDefaults() {
    _nameCtrl.text = '';
    _isLocked = false;

    // Decimales: 0,00
    for (final c in <TextEditingController>[
      _totalFlightTimeCtrl,
      _singleEngineCtrl,
      _multiEngineCtrl,
      _turbopropCtrl,
      _turbojetCtrl,
      _lsaCtrl,
      _helicopterCtrl,
      _gliderCtrl,
      _otherAircraftCtrl,
      _simulatorCtrl,
      _condDayCtrl,
      _condNightCtrl,
      _condIfrCtrl,
      _crossCountryCtrl,
      _soloCtrl,
      _picCtrl,
      _copilotCtrl,
      _instructionReceivedCtrl,
      _asInstructorCtrl,
    ]) {
      c.text = '0,00';
    }

    // Enteros: 0
    for (final c in <TextEditingController>[
      _takeoffsDayCtrl,
      _takeoffsNightCtrl,
      _landingsDayCtrl,
      _landingsNightCtrl,
      _approachesNumberCtrl,
    ]) {
      c.text = '0';
    }
  }

  void _setDecimalFromRow(TextEditingController ctrl, Object? value) {
    if (value == null) {
      ctrl.text = '0,00';
      return;
    }
    if (value is num) {
      ctrl.text = _formatDecimal(value);
    } else if (value is String && value.trim().isNotEmpty) {
      // si viene con 1 decimal, lo dejamos; al editar/guardar se normaliza por el usuario
      ctrl.text = value.trim();
    } else {
      ctrl.text = '0,00';
    }
  }

  void _setIntFromRow(TextEditingController ctrl, Object? value) {
    if (value == null) {
      ctrl.text = '0';
      return;
    }
    if (value is num) {
      ctrl.text = _formatInt(value.toInt());
    } else if (value is String && value.trim().isNotEmpty) {
      ctrl.text = value.trim();
    } else {
      ctrl.text = '0';
    }
  }

  String _formatDecimal(num value) {
    final double v = value.toDouble();
    final String s = v.toStringAsFixed(2);
    final parts = s.split('.');
    String intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      buffer.write(intPart[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }
    final withDots = buffer.toString().split('').reversed.join();
    return '$withDots,$decPart';
  }

  String _formatInt(int value) {
    String s = value.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  double? _parseDecimal(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final s = t.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(s);
  }

  int? _parseInt(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final s = t.replaceAll('.', '');
    return int.tryParse(s);
  }

  String? _nullIfEmpty(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  bool _isZeroDecimalText(String text) {
    final String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return true;
    final int? n = int.tryParse(digits);
    return (n ?? 0) == 0;
  }

  void _restoreIfEmpty(TextEditingController ctrl, {required bool decimal}) {
    if (ctrl.text.trim().isNotEmpty) return;
    ctrl.text = decimal ? '0,00' : '0';
  }

  // ================== SAVE ==================

  Future<void> _saveTotals() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    try {
      final db = await DBHelper.getDB();

      final data = <String, Object?>{
        'name': _nullIfEmpty(_nameCtrl.text),
        'totalFlightTime': _parseDecimal(_totalFlightTimeCtrl.text),
        'singleEngine': _parseDecimal(_singleEngineCtrl.text),
        'multiEngine': _parseDecimal(_multiEngineCtrl.text),
        'turboprop': _parseDecimal(_turbopropCtrl.text),
        'turbojet': _parseDecimal(_turbojetCtrl.text),
        'lsa': _parseDecimal(_lsaCtrl.text),
        'helicopter': _parseDecimal(_helicopterCtrl.text),
        'glider': _parseDecimal(_gliderCtrl.text),
        'otherAircraft': _parseDecimal(_otherAircraftCtrl.text),
        'simulator': _parseDecimal(_simulatorCtrl.text),
        'condDay': _parseDecimal(_condDayCtrl.text),
        'condNight': _parseDecimal(_condNightCtrl.text),
        'condIFR': _parseDecimal(_condIfrCtrl.text),
        'timeCrossCountry': _parseDecimal(_crossCountryCtrl.text),
        'timeSolo': _parseDecimal(_soloCtrl.text),
        'timePIC': _parseDecimal(_picCtrl.text),
        'timeCopilot': _parseDecimal(_copilotCtrl.text),
        'timeInstruction': _parseDecimal(_instructionReceivedCtrl.text),
        'timeInstructor': _parseDecimal(_asInstructorCtrl.text),
        'takeoffsDay': _parseInt(_takeoffsDayCtrl.text),
        'takeoffsNight': _parseInt(_takeoffsNightCtrl.text),
        'landingsDay': _parseInt(_landingsDayCtrl.text),
        'landingsNight': _parseInt(_landingsNightCtrl.text),
        'approachesNumber': _parseInt(_approachesNumberCtrl.text),
        'isLocked': _isLocked ? 1 : 0,
      };

      if (_rowId == null) {
        data['createdAt'] = DateTime.now().toIso8601String();
        _rowId = await db.insert(_tableName, data);
      } else {
        await db.update(
          _tableName,
          data,
          where: 'id = ?',
          whereArgs: [_rowId],
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error saving previous totals: $e');
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

  Future<void> _persistLockState() async {
    try {
      final db = await DBHelper.getDB();
      await _ensureTable(db);

      final data = <String, Object?>{
        'isLocked': _isLocked ? 1 : 0,
      };

      if (_rowId == null) {
        data['createdAt'] = DateTime.now().toIso8601String();
        _rowId = await db.insert(_tableName, data);
      } else {
        final updated = await db.update(
          _tableName,
          data,
          where: 'id = ?',
          whereArgs: [_rowId],
        );

        if (updated == 0) {
          data['createdAt'] = DateTime.now().toIso8601String();
          _rowId = await db.insert(_tableName, data);
        }
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('Error saving lock state: $e');
      // ignore: avoid_print
      print(st);
    }
  }

  // ================== UI HELPERS ==================

  InputDecoration _numberDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.white, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.white, width: 1),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.6),
          width: 1,
        ),
      ),
    );
  }

  // Campo numérico con ancho dinámico que crece hacia la izquierda
  Widget _numericField({
    required TextEditingController ctrl,
    required bool decimal,
  }) {
    final double baseWidth = decimal ? 90.0 : 80.0;
    final double maxWidth = baseWidth + 80.0;
    const double extraPerChar = 6.0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: baseWidth,
        maxWidth: maxWidth,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (_, value, __) {
            final int len = value.text.length;
            final int extraChars = len > 4 ? (len - 4) : 0;
            final double w = (baseWidth + extraPerChar * extraChars)
                .clamp(baseWidth, maxWidth);

            return SizedBox(
              width: w,
              child: Focus(
                onFocusChange: (hasFocus) {
                  if (_isLocked) return;
                  if (hasFocus) {
                    if (decimal && _isZeroDecimalText(ctrl.text)) {
                      ctrl.clear();
                    }
                  } else {
                    _restoreIfEmpty(ctrl, decimal: decimal);
                  }
                },
                child: TextField(
                  controller: ctrl,
                  enabled: !_isLocked,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: decimal,
                    signed: false,
                  ),
                  inputFormatters: decimal
                      ? [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d,\.]')),
                        ]
                      : [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                  decoration: _numberDecoration(),
                  style: const TextStyle(
                    color: AppColors.teal1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _decimalRow(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          _numericField(ctrl: ctrl, decimal: true),
        ],
      ),
    );
  }

  Widget _integerRow(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          _numericField(ctrl: ctrl, decimal: false),
        ],
      ),
    );
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return BaseScaffold(
      appBar: CustomAppBar(
        title: l.t("totals_previous_title"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SectionContainer(
                    children: <Widget>[
                      // Nombre de estos tiempos + candado
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              l.t("totals_name_of_these_times"),
                              style: AppTextStyles.subtitle
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isLocked ? Icons.lock : Icons.lock_open,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              setState(() {
                                _isLocked = !_isLocked;
                              });
                              await _persistLockState();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _nameCtrl,
                        enabled: !_isLocked,
                        style: const TextStyle(
                          color: AppColors.teal1,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: _numberDecoration(),
                      ),
                      const SizedBox(height: 16),

                      // Tiempos de vuelo
                      SectionItemTitle(
                        title: l.t("totals_flight_times_section"),
                      ),
                      _decimalRow(
                        l.t("totals_total_flight_time"),
                        _totalFlightTimeCtrl,
                      ),

                      const SizedBox(height: 12),

                      // Aeronave / simulador
                      SectionItemTitle(
                        title: l.t("totals_aircraft_simulator_section"),
                      ),
                      _decimalRow(
                        l.t("totals_single_engine_airplane"),
                        _singleEngineCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_multi_engine_airplane"),
                        _multiEngineCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_turboprop_airplane"),
                        _turbopropCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_turbojet_airplane"),
                        _turbojetCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_lsa_airplane"),
                        _lsaCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_helicopter"),
                        _helicopterCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_glider"),
                        _gliderCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_other_aircraft"),
                        _otherAircraftCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_simulator"),
                        _simulatorCtrl,
                      ),

                      const SizedBox(height: 12),

                      // Condiciones de vuelo
                      SectionItemTitle(
                        title: l.t("totals_flight_conditions_section"),
                      ),
                      _decimalRow(
                        l.t("totals_conditions_day"),
                        _condDayCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_conditions_night"),
                        _condNightCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_conditions_ifr"),
                        _condIfrCtrl,
                      ),

                      const SizedBox(height: 12),

                      // Tipos de tiempo de vuelo
                      SectionItemTitle(
                        title: l.t("totals_flight_time_types_section"),
                      ),
                      _decimalRow(
                        l.t("totals_time_cross_country"),
                        _crossCountryCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_time_solo"),
                        _soloCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_time_pic"),
                        _picCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_time_copilot"),
                        _copilotCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_time_instruction_received"),
                        _instructionReceivedCtrl,
                      ),
                      _decimalRow(
                        l.t("totals_time_as_instructor"),
                        _asInstructorCtrl,
                      ),

                      const SizedBox(height: 12),

                      // Despegues
                      SectionItemTitle(
                        title: l.t("totals_takeoffs_section"),
                      ),
                      _integerRow(
                        l.t("totals_takeoffs_day"),
                        _takeoffsDayCtrl,
                      ),
                      _integerRow(
                        l.t("totals_takeoffs_night"),
                        _takeoffsNightCtrl,
                      ),

                      const SizedBox(height: 12),

                      // Aterrizajes
                      SectionItemTitle(
                        title: l.t("totals_landings_section"),
                      ),
                      _integerRow(
                        l.t("totals_landings_day"),
                        _landingsDayCtrl,
                      ),
                      _integerRow(
                        l.t("totals_landings_night"),
                        _landingsNightCtrl,
                      ),

                      const SizedBox(height: 12),

                      // Aproximaciones
                      SectionItemTitle(
                        title: l.t("totals_approaches_section"),
                      ),
                      _integerRow(
                        l.t("totals_approaches_number"),
                        _approachesNumberCtrl,
                      ),
                    ],
                  ),
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
                        await _saveTotals();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}
