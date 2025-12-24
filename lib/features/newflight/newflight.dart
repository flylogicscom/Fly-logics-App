// lib/features/newflight/newflight.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/section_container.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';
import 'package:fly_logicd_logbook_app/features/airplanes/airplaneslist.dart';

import 'package:fly_logicd_logbook_app/utils/country_data.dart' as cdata;

// Popup de tipo de tiempo de vuelo / rol de tripulante
import 'package:fly_logicd_logbook_app/common/pop_layer_crew.dart';

DateTime _today() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

// Tamaños de letra configurables para la sección 2
const double kSec2PillFontSize = 22;
const double kSec2MainValueFontSize = 15;
const double kSec2LabelFontSize = 11;
const double kSec2TagFontSize = 10;

/// Resumen mínimo de la aeronave seleccionada para el vuelo.
class _SelectedAircraftSummary {
  final int id;
  final bool isSimulator;
  final String registration;
  final String identifier;
  final String owner;
  final String countryName;
  final String countryFlagEmoji;

  // Datos de aeronave
  final String makeAndModel;

  // Tags libres (las que se escriben a mano)
  final List<String> tags;

  // Tipos de aeronave / simulador (ids 1..9 de typeIds)
  final List<int> typeIds;

  // títulos en orden, sacados de aircraft_items.typeTitle (separado por '|')
  final List<String> typeTitles;

  // Opcional: datos custom para "OTRO"
  final String typeCustomLabel;
  final String typeCustomDescription;

  // Datos opcionales de simulador
  final String simCompany;
  final String simAircraftModel;
  final String simLevel;

  const _SelectedAircraftSummary({
    required this.id,
    required this.isSimulator,
    required this.registration,
    required this.identifier,
    required this.owner,
    required this.countryName,
    required this.countryFlagEmoji,
    this.makeAndModel = '',
    this.tags = const <String>[],
    this.typeIds = const <int>[],
    this.typeTitles = const <String>[],
    this.typeCustomLabel = '',
    this.typeCustomDescription = '',
    this.simCompany = '',
    this.simAircraftModel = '',
    this.simLevel = '',
  });
}

/// Entrada de tripulación en sección 4.
class _CrewEntry {
  final CrewRoleSelection role;
  final String name;

  const _CrewEntry({
    required this.role,
    required this.name,
  });

  _CrewEntry copyWith({
    CrewRoleSelection? role,
    String? name,
  }) {
    return _CrewEntry(
      role: role ?? this.role,
      name: name ?? this.name,
    );
  }
}

enum _CondLastEdited { day, night }

class NewFlightPage extends StatefulWidget {
  final int? flightId;

  const NewFlightPage({
    super.key,
    this.flightId,
  });

  @override
  State<NewFlightPage> createState() => _NewFlightPageState();
}

class _NewFlightPageState extends State<NewFlightPage> {
  bool _saving = false;

  bool get _isEdit => widget.flightId != null;

  // ====== SECTION 01: DATE OF FLIGHT ======
  DateTime _flightBeginDate = _today();
  DateTime _flightEndDate = _today();
  bool _flightEndTouched = false;

  // ====== SECTION 02: AIRCRAFT / SIMULATOR ======
  _SelectedAircraftSummary? _selectedAircraft;

  // ====== SECTION 03: ROUTE (ICAO FROM/TO) ======
  final TextEditingController _fromIcaoCtrl = TextEditingController();
  final TextEditingController _toIcaoCtrl = TextEditingController();

  // ====== SECTION 04: CREW ======
  final List<_CrewEntry> _crewEntries = <_CrewEntry>[];

  Future<String?> _pickCrewMemberFromList() async {
    final db = await DBHelper.getDB();

    await db.execute('''
    CREATE TABLE IF NOT EXISTS crew_members (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      firstName TEXT,
      lastName TEXT,
      phone TEXT,
      phoneFlag TEXT,
      email TEXT,
      country TEXT,
      airline TEXT,
      rank TEXT,
      employeeNumber TEXT,
      createdAt TEXT
    )
  ''');

    final List<Map<String, Object?>> rows = await db.query(
      'crew_members',
      orderBy: 'createdAt DESC',
    );

    if (!mounted) return null;

    final AppLocalizations l = AppLocalizations.of(context);

    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("no_crew_members_yet"))),
      );
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          content: Container(
            width: 360,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: <Color>[AppColors.teal1, AppColors.teal3],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Text(
                    l.t("crew"),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 0.5, color: Colors.white24),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (_, int index) {
                      final Map<String, Object?> r = rows[index];
                      final String first =
                          (r['firstName'] as String? ?? '').trim();
                      final String last =
                          (r['lastName'] as String? ?? '').trim();
                      final String full = ('$first $last').trim().isEmpty
                          ? 'Crew Member'
                          : ('$first $last').trim();

                      return ListTile(
                        title: Text(full,
                            style: const TextStyle(color: Colors.white)),
                        onTap: () => Navigator.of(ctx).pop(full),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _loadingExisting = false;

  CrewRoleSelection _roleFromCode(AppLocalizations l, String codeRaw) {
    final code = codeRaw.trim().toUpperCase();
    if (code == 'PIC') {
      return CrewRoleSelection(
        code: 'PIC',
        name: l.t("crew_role_pic_name"),
        description: l.t("crew_role_pic_desc"),
      );
    }
    // Fallback seguro para otros roles
    return CrewRoleSelection(code: code, name: code, description: '');
  }

  Future<void> _loadExistingFlight() async {
    if (widget.flightId == null) return;

    setState(() => _loadingExisting = true);

    try {
      // ✅ Requiere DBHelper.getFlightById (te dejo el snippet abajo)
      final Map<String, Object?>? row =
          await DBHelper.getFlightById(widget.flightId!);

      if (!mounted) return;

      if (row == null) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.t("error")}: flight not found')),
        );
        Navigator.pop(context, false);
        return;
      }

      Map<String, dynamic>? snap;
      final String? jsonStr = (row['dataJson'] as String?)?.trim();
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) snap = decoded;
      }

      // --- Dates (fallback a columnas si no hay JSON)
      DateTime begin = _flightBeginDate;
      DateTime end = _flightEndDate;

      final int startMs = row['startDate'] as int? ?? 0;
      if (startMs > 0) begin = DateTime.fromMillisecondsSinceEpoch(startMs);

      final int? endMs = row['endDate'] as int?;
      if (endMs != null && endMs > 0) {
        end = DateTime.fromMillisecondsSinceEpoch(endMs);
      }

      final Map? dates = snap?['dates'] as Map?;
      final String? beginIso = dates?['begin']?.toString();
      final String? endIso = dates?['end']?.toString();

      final DateTime? beginParsed =
          beginIso == null ? null : DateTime.tryParse(beginIso);
      final DateTime? endParsed =
          endIso == null ? null : DateTime.tryParse(endIso);

      if (beginParsed != null) begin = beginParsed;
      if (endParsed != null) end = endParsed;

      // --- Route
      final Map? route = snap?['route'] as Map?;
      final String fromIcao = (route?['fromIcao'] ?? row['fromIcao'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      final String toIcao = (route?['toIcao'] ?? row['toIcao'] ?? '')
          .toString()
          .trim()
          .toUpperCase();

      // --- Time
      final Map? time = snap?['time'] as Map?;
      final dynamic useUtcRaw = time?['useUtc'];
      final bool useUtc = (useUtcRaw == true) ||
          (useUtcRaw?.toString().toLowerCase() == 'true');

      final String startT = (time?['start'] ?? '').toString();
      final String endT = (time?['end'] ?? '').toString();

      final num? blockHoursRaw = time?['blockHours'] as num?;
      final int blockMinRow = row['blockTimeMinutes'] as int? ?? 0;
      final double? blockHours = blockHoursRaw?.toDouble() ??
          (blockMinRow > 0 ? (blockMinRow / 60.0) : null);

      // --- Conditions (texto tipo "0,00")
      final Map? cond = snap?['conditions'] as Map?;
      final String dayTxt = (cond?['day'] ?? '0,00').toString();
      final String nightTxt = (cond?['night'] ?? '0,00').toString();
      final String ifrTxt = (cond?['ifr'] ?? '0,00').toString();

      // Touched flags: importante para que no te pise Night al recalcular total
      final int totalCenti =
          blockHours == null ? 0 : (blockHours * 100).round();
      final int dayCenti =
          int.tryParse(dayTxt.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final int nightCenti =
          int.tryParse(nightTxt.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final int ifrCenti =
          int.tryParse(ifrTxt.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      // --- Aircraft snapshot (no guardas id, así que usamos 0)
      _SelectedAircraftSummary? selected;
      final Map? ac = snap?['aircraft'] as Map?;
      if (ac != null) {
        final tags = (ac['tags'] as List?)?.map((e) => e.toString()).toList() ??
            <String>[];
        final typeIds = (ac['typeIds'] as List?)
                ?.map((e) => e is int ? e : (int.tryParse(e.toString()) ?? 0))
                .where((e) => e > 0)
                .toList() ??
            <int>[];

        selected = _SelectedAircraftSummary(
          id: 0,
          isSimulator: (ac['isSimulator'] == true) ||
              (ac['isSimulator']?.toString() == '1'),
          registration: (ac['registration'] ?? '').toString(),
          identifier: (ac['identifier'] ?? '').toString(),
          owner: (ac['owner'] ?? '').toString(),
          countryName: '',
          countryFlagEmoji: '',
          makeAndModel: (ac['makeAndModel'] ?? '').toString(),
          tags: tags,
          typeIds: typeIds,
          typeCustomLabel: (ac['typeCustomLabel'] ?? '').toString(),
          typeCustomDescription: (ac['typeCustomDescription'] ?? '').toString(),
          simCompany: (ac['simCompany'] ?? '').toString(),
          simAircraftModel: (ac['simAircraftModel'] ?? '').toString(),
          simLevel: (ac['simLevel'] ?? '').toString(),
        );
      }

      // --- Crew
      final l = AppLocalizations.of(context);
      final List<_CrewEntry> crew = <_CrewEntry>[];
      final List? crewRaw = snap?['crew'] as List?;
      if (crewRaw != null) {
        for (final c in crewRaw) {
          if (c is Map) {
            final roleCode = (c['role'] ?? '').toString();
            final name = (c['name'] ?? '').toString();
            if (name.trim().isEmpty) continue;
            crew.add(_CrewEntry(
                role: _roleFromCode(l, roleCode), name: name.trim()));
          }
        }
      }

      setState(() {
        _flightBeginDate = DateTime(begin.year, begin.month, begin.day);
        _flightEndDate = DateTime(end.year, end.month, end.day);
        _flightEndTouched =
            _flightEndDate.difference(_flightBeginDate).inDays != 0;

        _fromIcaoCtrl.text = fromIcao;
        _toIcaoCtrl.text = toIcao;

        _selectedAircraft = selected;

        if (crew.isNotEmpty) {
          _crewEntries
            ..clear()
            ..addAll(crew);
        }

        _useUtcTime = useUtc;
        _timeStartCtrl.text = startT;
        _timeEndCtrl.text = endT;
        _blockTimeHours = blockHours;

        _condDayCtrl.text = dayTxt;
        _condNightCtrl.text = nightTxt;
        _condIfrCtrl.text = ifrTxt;

        // flags para que el sync no te rompa day/night al cargar
        _condDayTouched = (dayCenti != totalCenti) || (nightCenti != 0);
        _condNightTouched = (nightCenti != 0);
        _condIfrTouched = (ifrCenti != 0);
        _condLastEdited = _CondLastEdited.day;
      });

      // Recalcula total y clamps sin reventar day/night
      _onFlightTimeChanged();
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.t("error")}: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  Future<void> _deleteFlight() async {
    if (widget.flightId == null) return;

    try {
      final db = await DBHelper.getDB();

      // Usa el nombre REAL de tu tabla de vuelos (el mismo que usas en insert/update)
      await db.delete(
        'flights',
        where: 'id = ?',
        whereArgs: [widget.flightId],
      );

      if (!mounted) return;
      Navigator.pop(context, true); // ✅ para recargar lista
    } catch (e, st) {
      // ignore: avoid_print
      print('Error deleting flight: $e');
      // ignore: avoid_print
      print(st);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("error_saving_data"))),
      );
    }
  }

  Future<_CrewEntry?> _showCrewEntryDialog({_CrewEntry? initial}) async {
    final AppLocalizations l = AppLocalizations.of(context);

    CrewRoleSelection? selectedRole = initial?.role;
    String? selectedName = initial?.name;

    return showDialog<_CrewEntry>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, void Function(void Function()) setSB) {
            return AlertDialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              contentPadding: EdgeInsets.zero,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              content: Container(
                width: 380,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: <Color>[AppColors.teal1, AppColors.teal3],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        l.t("add_new_crew_button"),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.t("pilot_in_command_crew"),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final CrewRoleSelection? role =
                              await showCrewRolePopup(context);
                          if (role != null) {
                            setSB(() => selectedRole = role);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.7),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.teal5,
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: Colors.white, width: 1),
                                ),
                                child: Text(
                                  (selectedRole?.code ?? 'PIC'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  selectedRole?.name ??
                                      l.t("crew_role_pic_name"),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.t("flight_section_04_pilot_crew"),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final String? name = await _pickPilotName();
                                if (name != null && mounted) {
                                  setSB(() => selectedName = name);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: Colors.white.withOpacity(0.7),
                                    width: 1.0),
                              ),
                              child: Text(
                                l.t("pilot_data"),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final String? name =
                                    await _pickCrewMemberFromList();
                                if (name != null && mounted) {
                                  setSB(() => selectedName = name);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: Colors.white.withOpacity(0.7),
                                    width: 1.0),
                              ),
                              child: Text(
                                l.t("crew_details"),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (selectedName != null &&
                          selectedName!.trim().isNotEmpty)
                        Text(
                          selectedName!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            child: Text(l.t("cancel")),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: (selectedRole != null &&
                                    selectedName != null &&
                                    selectedName!.trim().isNotEmpty)
                                ? () {
                                    Navigator.of(ctx).pop(
                                      _CrewEntry(
                                        role: selectedRole!,
                                        name: selectedName!.trim(),
                                      ),
                                    );
                                  }
                                : null,
                            child: Text(l.t("save")),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addNewCrewEntry() async {
    if (_crewEntries.length >= 4) return;

    final _CrewEntry? entry = await _showCrewEntryDialog();
    if (entry == null) return;

    setState(() => _crewEntries.add(entry));
  }

  Future<void> _editCrewEntry(int index) async {
    if (index < 0 || index >= _crewEntries.length) return;

    final _CrewEntry? entry =
        await _showCrewEntryDialog(initial: _crewEntries[index]);
    if (entry == null) return;

    setState(() => _crewEntries[index] = entry);
  }

  Future<void> _confirmDeleteCrewEntry(int index) async {
    if (index < 0 || index >= _crewEntries.length) return;

    final AppLocalizations l = AppLocalizations.of(context);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l.t("delete_crew_member")),
          content:
              Text(l.t("are_you_sure_you_want_to_delete_this_crew_member")),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.t("cancel")),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.t("delete")),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      setState(() => _crewEntries.removeAt(index));
    }
  }

  // ids 1..9 -> códigos de tipo
  // ignore: unused_field
  static const Map<int, String> _kTypeIdToCode = <int, String>{
    1: 'SE', // monomotor
    2: 'ME', // multimotor
    3: 'TP', // turbohélice
    4: 'TJ', // turbojet
    5: 'LSA', // LSA
    6: 'HELI', // helicóptero
    7: 'GLID', // planeador
    8: 'OTHER', // otro
    9: 'SIM', // simulador
  };

  // ====== SECTION 05: FLIGHT TIME ======
  final TextEditingController _timeStartCtrl = TextEditingController();
  final TextEditingController _timeEndCtrl = TextEditingController();
  bool _useUtcTime = false; // false = horómetro, true = UTC
  double? _blockTimeHours;
  bool _utcSameDayErrorShown = false;

  // ====== SECTION 06 & 07: type of aircraft ======
  Color _typeColorForCode(String code) {
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

  String _typeTitleKeyForCode(String code) {
    switch (code.toUpperCase()) {
      case 'SE':
        return "aircraft_type_single_title";
      case 'ME':
        return "aircraft_type_multi_title";
      case 'TP':
        return "aircraft_type_turboprop_title";
      case 'TJ':
        return "aircraft_type_turbojet_title";
      case 'LSA':
        return "aircraft_type_lsa_title";
      case 'HELI':
        return "aircraft_type_helicopter_title";
      case 'GLID':
        return "aircraft_type_glider_title";
      case 'OTHER':
        return "aircraft_type_other_title";
      case 'SIM':
        return "aircraft_type_simulator_title";
      default:
        return code;
    }
  }

  String _typeDescKeyForCode(String code) {
    switch (code.toUpperCase()) {
      case 'SE':
        return "aircraft_type_single_desc";
      case 'ME':
        return "aircraft_type_multi_desc";
      case 'TP':
        return "aircraft_type_turboprop_desc";
      case 'TJ':
        return "aircraft_type_turbojet_desc";
      case 'LSA':
        return "aircraft_type_lsa_desc";
      case 'HELI':
        return "aircraft_type_helicopter_desc";
      case 'GLID':
        return "aircraft_type_glider_desc";
      case 'OTHER':
        return "aircraft_type_other_desc";
      case 'SIM':
        return "aircraft_type_simulator_desc";
      default:
        return "";
    }
  }

  // ====== SECTION 08: FLIGHT CONDITIONS (DAY / NIGHT / IFR) ======
  final TextEditingController _condDayCtrl = TextEditingController();
  final TextEditingController _condNightCtrl = TextEditingController();
  final TextEditingController _condIfrCtrl = TextEditingController();

  final FocusNode _condDayFocus = FocusNode();
  final FocusNode _condNightFocus = FocusNode();
  final FocusNode _condIfrFocus = FocusNode();

  bool _condDayTouched = false;
  bool _condNightTouched = false;
  bool _condIfrTouched = false;
  _CondLastEdited _condLastEdited = _CondLastEdited.day;

  // ====== SECTION 09: FLIGHT TIME TYPES ======
  static const String _kTtCross = 'crosscountry';
  static const String _kTtSolo = 'solo';
  static const String _kTtPic = 'pic';
  static const String _kTtSic = 'sic';
  static const String _kTtInstRe = 'instruction_re';
  static const String _kTtFlyInst = 'fly_instructor';

  static const List<String> _kTypeTimeKeys = <String>[
    _kTtCross,
    _kTtSolo,
    _kTtPic,
    _kTtSic,
    _kTtInstRe,
    _kTtFlyInst,
  ];

// Colores (en orden) como la imagen nueva
  static const Map<String, Color> _kTypeColors = <String, Color>{
    _kTtCross: Color(0xFF004B57),
    _kTtSolo: Color(0xFF006A89),
    _kTtPic: Color(0xFF007AA2),
    _kTtSic: Color(0xFF008DC0),
    _kTtInstRe: Color(0xFF009DCF),
    _kTtFlyInst: Color(0xFF86BEDA),
  };

  // Incompatibilidades (bidireccional vía _areIncompatible)
  static const Map<String, Set<String>> _kIncompat = <String, Set<String>>{
    _kTtSolo: <String>{_kTtSic, _kTtFlyInst}, // 2 con 4,6
    _kTtPic: <String>{_kTtSic}, // 3 con 4
    _kTtSic: <String>{_kTtSolo, _kTtPic}, // 4 con 2,3
    _kTtInstRe: <String>{_kTtFlyInst}, // 5 con 6
    _kTtFlyInst: <String>{_kTtSolo, _kTtInstRe}, // 6 con 2,5
  };

  final TextEditingController _ttCrossCtrl = TextEditingController();
  final TextEditingController _ttSoloCtrl = TextEditingController();
  final TextEditingController _ttPicCtrl = TextEditingController();
  final TextEditingController _ttSicCtrl = TextEditingController();
  final TextEditingController _ttInstReCtrl = TextEditingController();
  final TextEditingController _ttFlyInstCtrl = TextEditingController();

  final FocusNode _ttCrossFocus = FocusNode();
  final FocusNode _ttSoloFocus = FocusNode();
  final FocusNode _ttPicFocus = FocusNode();
  final FocusNode _ttSicFocus = FocusNode();
  final FocusNode _ttInstReFocus = FocusNode();
  final FocusNode _ttFlyInstFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    // ✅ Solo en "nuevo vuelo"
    if (!_isEdit) {
      _initDefaultCrew();
    } else {
      _loadExistingFlight(); // ✅ En "editar vuelo"
    }
    super.initState();
    _initDefaultCrew();

    // valores iniciales sección 8
    _setCentiCtrl(_condDayCtrl, 0);
    _setCentiCtrl(_condNightCtrl, 0);
    _setCentiCtrl(_condIfrCtrl, 0);

    _attachZeroClearBehavior(_condDayFocus, _condDayCtrl);
    _attachZeroClearBehavior(_condNightFocus, _condNightCtrl);
    _attachZeroClearBehavior(_condIfrFocus, _condIfrCtrl);

    // valores iniciales sección 9
    _setCentiCtrl(_ttCrossCtrl, 0);
    _setCentiCtrl(_ttSoloCtrl, 0);
    _setCentiCtrl(_ttPicCtrl, 0);
    _setCentiCtrl(_ttSicCtrl, 0);
    _setCentiCtrl(_ttInstReCtrl, 0);
    _setCentiCtrl(_ttFlyInstCtrl, 0);

    _attachZeroClearBehavior(_ttCrossFocus, _ttCrossCtrl);
    _attachZeroClearBehavior(_ttSoloFocus, _ttSoloCtrl);
    _attachZeroClearBehavior(_ttPicFocus, _ttPicCtrl);
    _attachZeroClearBehavior(_ttSicFocus, _ttSicCtrl);
    _attachZeroClearBehavior(_ttInstReFocus, _ttInstReCtrl);
    _attachZeroClearBehavior(_ttFlyInstFocus, _ttFlyInstCtrl);

    // valores iniciales sección 10
    _setIntCtrl(_tkofDayCtrl, 0);
    _setIntCtrl(_tkofNightCtrl, 0);
    _setIntCtrl(_ldgDayCtrl, 0);
    _setIntCtrl(_ldgNightCtrl, 0);

    // valores iniciales sección 11
    _setIntCtrl(_approachCountCtrl, 0);
    _attachZeroClearIntBehavior(_approachCountFocus, _approachCountCtrl);

    // mantener _approachCount sincronizado si el usuario edita el TextField
    _approachCountCtrl.addListener(() {});

    // comportamiento: si es 0 al tocar -> limpia; si queda vacío al salir -> vuelve 0
    _attachZeroClearIntBehavior(_tkofDayFocus, _tkofDayCtrl);
    _attachZeroClearIntBehavior(_tkofNightFocus, _tkofNightCtrl);
    _attachZeroClearIntBehavior(_ldgDayFocus, _ldgDayCtrl);
    _attachZeroClearIntBehavior(_ldgNightFocus, _ldgNightCtrl);
  }

  Future<void> _initDefaultCrew() async {
    final Map<String, Object?>? data = await DBHelper.getPilot();
    if (!mounted || data == null) return;

    final AppLocalizations l = AppLocalizations.of(context);

    final String displayNameRaw =
        (data['displayName'] as String? ?? data['name'] as String? ?? '')
            .trim();
    if (displayNameRaw.isEmpty) return;

    final CrewRoleSelection defaultRole = CrewRoleSelection(
      code: 'PIC',
      name: l.t("crew_role_pic_name"),
      description: l.t("crew_role_pic_desc"),
    );

    setState(() {
      _crewEntries
        ..clear()
        ..add(_CrewEntry(role: defaultRole, name: displayNameRaw));
    });
  }

  // ====== SECTION 10: TAKEOFFS / LANDINGS (INTEGERS) ======
  final TextEditingController _tkofDayCtrl = TextEditingController();
  final TextEditingController _tkofNightCtrl = TextEditingController();
  final TextEditingController _ldgDayCtrl = TextEditingController();
  final TextEditingController _ldgNightCtrl = TextEditingController();

  final FocusNode _tkofDayFocus = FocusNode();
  final FocusNode _tkofNightFocus = FocusNode();
  final FocusNode _ldgDayFocus = FocusNode();
  final FocusNode _ldgNightFocus = FocusNode();

// ====== SECTION 11: APPROACHES ======
  final TextEditingController _approachCountCtrl = TextEditingController();
  final FocusNode _approachCountFocus = FocusNode();

  String? _approachType; // null = no elegido

  static const List<String> _kApproachTypes = <String>[
    'VFR',
    'VOR',
    'NDB',
    'ILS - CAT I',
    'ILS - CAT II',
    'ILS - CAT III',
  ];

  // ================== SAVE ==================

  Future<void> _saveFlight() async {
    final l = AppLocalizations.of(context);

    if (_saving) return;
    setState(() => _saving = true);

    try {
      final int nowMs = DateTime.now().millisecondsSinceEpoch;

      final String fromIcao = _fromIcaoCtrl.text.trim().toUpperCase();
      final String toIcao = _toIcaoCtrl.text.trim().toUpperCase();

      final String fromFlagEmoji = _flagForIcao(fromIcao);
      final String toFlagEmoji = _flagForIcao(toIcao);

      // Evita el error: double? -> double
      final double blockHours = _blockTimeHours ?? 0.0;
      final int blockTimeMinutes = (blockHours * 60).round();

      // PIC (para filtros)
      String pic = '';
      for (final e in _crewEntries) {
        if (e.role.code.trim().toUpperCase() == 'PIC') {
          pic = e.name.trim();
          break;
        }
      }

      final bool isSim = (_selectedAircraft?.isSimulator ?? false) ||
          fromIcao == 'SIM' ||
          toIcao == 'SIM';

      final String aircraftRegistration =
          isSim ? 'SIM' : (_selectedAircraft?.registration.trim() ?? '');

      final String aircraftIdentifier =
          _selectedAircraft?.identifier.trim() ?? '';

      final int startDateMs = DateTime(
        _flightBeginDate.year,
        _flightBeginDate.month,
        _flightBeginDate.day,
      ).millisecondsSinceEpoch;

      final int endDateMs = DateTime(
        _flightEndDate.year,
        _flightEndDate.month,
        _flightEndDate.day,
      ).millisecondsSinceEpoch;

      // Snapshot completo (puedes ampliar sin tocar el esquema)
      final Map<String, dynamic> dataJson = <String, dynamic>{
        'v': 1,
        'dates': <String, dynamic>{
          'begin': _flightBeginDate.toIso8601String(),
          'end': _flightEndDate.toIso8601String(),
        },
        'route': <String, dynamic>{
          'fromIcao': fromIcao,
          'toIcao': toIcao,
          'fromFlagEmoji': fromFlagEmoji,
          'toFlagEmoji': toFlagEmoji,
        },
        'aircraft': _selectedAircraft == null
            ? null
            : <String, dynamic>{
                'isSimulator': _selectedAircraft!.isSimulator,
                'registration': _selectedAircraft!.registration,
                'identifier': _selectedAircraft!.identifier,
                'owner': _selectedAircraft!.owner,
                'makeAndModel': _selectedAircraft!.makeAndModel,
                'tags': _selectedAircraft!.tags,
                'typeIds': _selectedAircraft!.typeIds,
                'typeCustomLabel': _selectedAircraft!.typeCustomLabel,
                'typeCustomDescription':
                    _selectedAircraft!.typeCustomDescription,
                'simCompany': _selectedAircraft!.simCompany,
                'simAircraftModel': _selectedAircraft!.simAircraftModel,
                'simLevel': _selectedAircraft!.simLevel,
              },
        'crew': <Map<String, dynamic>>[
          for (final e in _crewEntries)
            <String, dynamic>{
              'role': e.role.code,
              'name': e.name.trim(),
            },
        ],
        'time': <String, dynamic>{
          'useUtc': _useUtcTime,
          'start': _timeStartCtrl.text.trim(),
          'end': _timeEndCtrl.text.trim(),
          'blockHours': blockHours,
          'blockMinutes': blockTimeMinutes,
        },
        'conditions': <String, dynamic>{
          'day': _condDayCtrl.text.trim(),
          'night': _condNightCtrl.text.trim(),
          'ifr': _condIfrCtrl.text.trim(),
        },
        // IMPORTANTE: esto reemplaza a _ttDualCtrl/_ttInstrCtrl/_ttNightCtrl
        'typeTimes': <String, dynamic>{
          'dual': '',
          'instr': '',
          'night': '',
        },

        'savedAt': nowMs,
      };

      final Map<String, Object?> row = <String, Object?>{
        'startDate': startDateMs,
        'endDate': endDateMs,
        'blockTimeMinutes': blockTimeMinutes,
        'fromIcao': fromIcao,
        'fromFlagEmoji': fromFlagEmoji,
        'toIcao': toIcao,
        'toFlagEmoji': toFlagEmoji,
        'aircraftRegistration': aircraftRegistration,
        'aircraftIdentifier': aircraftIdentifier,
        'pic': pic,
        'isSimulator': isSim ? 1 : 0,
        'dataJson': jsonEncode(dataJson),
        // createdAt/updatedAt los pone DBHelper
      };

      if (_isEdit && widget.flightId != null) {
        await DBHelper.updateFlight(widget.flightId!, row);
      } else {
        await DBHelper.insertFlight(row);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("flight_saved"))),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.t("error")}: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, false);
    }
  }

  // ================== SECTION 01 LOGIC ==================

  String _fmtDate(BuildContext context, DateTime? d) {
    if (d == null) return '--/--/----';
    final String lang = Localizations.localeOf(context).languageCode;
    final String mm = d.month.toString().padLeft(2, '0');
    final String dd = d.day.toString().padLeft(2, '0');
    final String yyyy = d.year.toString();
    if (lang == 'en') return '$mm/$dd/$yyyy';
    return '$dd/$mm/$yyyy';
  }

  Future<void> _pickFlightBeginDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _flightBeginDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    final DateTime normalized = DateTime(picked.year, picked.month, picked.day);

    setState(() {
      _flightBeginDate = normalized;
      if (!_flightEndTouched) {
        _flightEndDate = normalized;
      }
      if (_flightBeginDate.isAfter(_flightEndDate)) {
        final DateTime minDate = _flightEndDate;
        _flightBeginDate = minDate;
        _flightEndDate = minDate;
      }
    });

    _onFlightTimeChanged();
  }

  Future<void> _pickFlightEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _flightEndDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    final DateTime normalized = DateTime(picked.year, picked.month, picked.day);

    setState(() {
      _flightEndDate = normalized;
      _flightEndTouched = true;

      if (_flightEndDate.isBefore(_flightBeginDate)) {
        final DateTime minDate = _flightEndDate;
        _flightBeginDate = minDate;
        _flightEndDate = minDate;
      }
    });

    _onFlightTimeChanged();
  }

  // ================== SECTION 02 LOGIC ==================

  Future<_SelectedAircraftSummary?> _loadAircraftSummary(int id) async {
    final db = await DBHelper.getDB();
    final List<Map<String, Object?>> rows = await db.query(
      'aircraft_items',
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final Map<String, Object?> r = rows.first;

    bool isSim = false;
    final Object? isSimulatorRaw = r['isSimulator'];
    if (isSimulatorRaw is int) {
      isSim = isSimulatorRaw != 0;
    } else if (isSimulatorRaw is num) {
      isSim = isSimulatorRaw.toInt() != 0;
    } else if (isSimulatorRaw is String) {
      isSim = isSimulatorRaw == '1';
    }

    final String makeModel = (r['makeModel'] as String? ?? '').trim();

    final String tagsStr = (r['tags'] as String? ?? '').trim();
    final List<String> tags = tagsStr.isEmpty
        ? <String>[]
        : tagsStr
            .split(',')
            .map((String e) => e.trim())
            .where((String e) => e.isNotEmpty)
            .toList();

    final String typeIdsStr = (r['typeIds'] as String? ?? '').trim();
    final List<int> typeIds = typeIdsStr.isEmpty
        ? <int>[]
        : typeIdsStr
            .split(',')
            .map((String e) => int.tryParse(e.trim()))
            .whereType<int>()
            .toList();

    final String typeTitleStr = (r['typeTitle'] as String? ?? '').trim();
    final List<String> typeTitles = typeTitleStr.isEmpty
        ? <String>[]
        : typeTitleStr
            .split('|')
            .map((String e) => e.trim())
            .where((String e) => e.isNotEmpty)
            .toList();

    return _SelectedAircraftSummary(
      id: id,
      isSimulator: isSim,
      registration: (r['registration'] as String? ?? '').trim(),
      identifier: (r['identifier'] as String? ?? '').trim(),
      owner: (r['owner'] as String? ?? '').trim(),
      countryName: (r['countryName'] as String? ?? '').trim(),
      countryFlagEmoji: (r['countryFlag'] as String? ?? '').trim(),
      makeAndModel: makeModel,
      tags: tags,
      typeIds: typeIds,
      typeTitles: typeTitles,
      typeCustomLabel: (r['typeCustomLabel'] as String? ?? '').trim(),
      typeCustomDescription:
          (r['typeCustomDescription'] as String? ?? '').trim(),
      simCompany: (r['simCompany'] as String? ?? '').trim(),
      simAircraftModel: (r['simAircraftModel'] as String? ?? '').trim(),
      simLevel: (r['simLevel'] as String? ?? '').trim(),
    );
  }

  Future<void> _pickAircraftForFlight() async {
    final dynamic result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AirplanesList(pickMode: true),
      ),
    );

    int? pickedId;
    if (result is Map<String, dynamic>) {
      pickedId = result['id'] as int?;
    } else if (result is int) {
      pickedId = result;
    }
    if (pickedId == null) return;

    final _SelectedAircraftSummary? summary =
        await _loadAircraftSummary(pickedId);
    if (!mounted || summary == null) return;

    setState(() {
      _selectedAircraft = summary;

      if (summary.isSimulator) {
        _fromIcaoCtrl.text = 'SIM';
        _toIcaoCtrl.text = 'SIM';
      }
    });
  }

  // ================== SECTION 03 LOGIC (ICAO / FLAGS) ==================

  String _flagForIcao(String code) {
    final String normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return '';

    for (final c in cdata.allCountryData) {
      for (final rawPrefix in c.icaoPrefixes) {
        final String p = rawPrefix.trim().toUpperCase();
        if (p.isEmpty) continue;
        if (normalized.startsWith(p)) return c.flagEmoji;
      }
    }
    return '';
  }

  // ================== SECTION 04 LOGIC (CREW) ==================

  // ignore: unused_element
  Future<String?> _pickPilotName() async {
    final Map<String, Object?>? data = await DBHelper.getPilot();
    if (!mounted) return null;

    final AppLocalizations l = AppLocalizations.of(context);

    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("pilot_data"))),
      );
      return null;
    }

    final String displayName =
        (data['displayName'] as String? ?? data['name'] as String? ?? '')
            .trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("pilot_data"))),
      );
      return null;
    }
    return displayName;
  }

  // ================== SECTION 05 LOGIC (FLIGHT TIME) ==================

  void _onToggleFlightTimeMode(bool useUtc) {
    if (_useUtcTime == useUtc) return;
    setState(() {
      _useUtcTime = useUtc;
      _timeStartCtrl.clear();
      _timeEndCtrl.clear();
      _blockTimeHours = null;
      _utcSameDayErrorShown = false;
    });

    _syncConditionsToTotal(totalCenti: 0);
    _clampTypeTimesToTotal(totalCenti: 0);
  }

  void _onFlightTimeChanged() {
    final double? block = _calculateBlockTime();
    setState(() => _blockTimeHours = block);

    final int totalCenti = block == null ? 0 : (block * 100).round();

    _syncConditionsToTotal(totalCenti: totalCenti);
    _clampTypeTimesToTotal(totalCenti: totalCenti);
  }

  double? _calculateBlockTime() {
    final String startText = _timeStartCtrl.text.trim();
    final String endText = _timeEndCtrl.text.trim();
    if (startText.isEmpty || endText.isEmpty) return null;

    if (_useUtcTime) {
      final Duration? start = _parseUtcTime(startText);
      final Duration? end = _parseUtcTime(endText);
      if (start == null || end == null) return null;

      const int minutesInDay = 24 * 60;
      final int dayDiff = _flightEndDate.difference(_flightBeginDate).inDays;

      int diffMinutes;
      if (dayDiff == 0) {
        diffMinutes = end.inMinutes - start.inMinutes;
        if (diffMinutes <= 0) {
          if (!_utcSameDayErrorShown && mounted) {
            _utcSameDayErrorShown = true;
            final AppLocalizations l = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(l.t("flight_section_05_error_same_day_utc"))),
            );
          }
          return null;
        } else {
          _utcSameDayErrorShown = false;
        }
      } else {
        diffMinutes =
            dayDiff * minutesInDay + (end.inMinutes - start.inMinutes);
        if (diffMinutes <= 0) return null;
        _utcSameDayErrorShown = false;
      }

      final double hoursDecimal = diffMinutes / 60.0;
      return double.parse(hoursDecimal.toStringAsFixed(2));
    } else {
      final double? start = _parseHobbsValue(startText);
      final double? end = _parseHobbsValue(endText);
      if (start == null || end == null) return null;

      final double diff = end - start;
      if (diff <= 0) return null;

      return double.parse(diff.toStringAsFixed(2));
    }
  }

  double? _parseHobbsValue(String text) {
    final String normalized = text.replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Duration? _parseUtcTime(String text) {
    String normalized = text.trim().replaceAll(' ', '');
    if (normalized.isEmpty) return null;

    normalized = normalized.replaceAll(',', ':').replaceAll('.', ':');

    String hoursStr;
    String minutesStr;

    final List<String> parts = normalized.split(':');
    if (parts.length == 2) {
      hoursStr = parts[0];
      minutesStr = parts[1];
    } else if (parts.length == 1) {
      final String s = parts[0];
      if (s.length <= 2) {
        hoursStr = s;
        minutesStr = '0';
      } else {
        hoursStr = s.substring(0, s.length - 2);
        minutesStr = s.substring(s.length - 2);
      }
    } else {
      return null;
    }

    final int? hours = int.tryParse(hoursStr);
    final int? minutes = int.tryParse(minutesStr);
    if (hours == null || minutes == null) return null;
    if (minutes < 0 || minutes >= 60) return null;

    return Duration(hours: hours, minutes: minutes);
  }

  String _formatBlockTime(double hours) {
    final bool isNegative = hours < 0;
    final double abs = hours.abs();
    final int intHours = abs.floor();
    final int hundredths = ((abs - intHours) * 100).round().clamp(0, 99);
    final String hStr = intHours.toString().padLeft(2, '0');
    final String mStr = hundredths.toString().padLeft(2, '0');
    return '${isNegative ? '-' : ''}$hStr,$mStr';
  }

  List<TextInputFormatter> _buildFlightTimeInputFormatters() {
    if (_useUtcTime) {
      return <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ];
    }

    // Horómetro: escritura RTL desde centésimas (siempre muestra ,XX)
    return <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      const _RightToLeftCentiHoursFormatter(
          maxDigits: 7), // 99999,99 (ajusta si quieres)
    ];
  }

  void _handleUtcFieldChanged(TextEditingController controller, String value) {
    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);

    String formatted;
    if (digits.length <= 2) {
      formatted = digits;
    } else {
      formatted = '${digits.substring(0, 2)}:${digits.substring(2)}';
    }

    if (formatted != controller.text) {
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    _onFlightTimeChanged();
  }

  // ================== SECTION 08 HELPERS (CENTI) ==================

  bool _isZeroCentiText(String text) {
    final String s = text.trim();
    return s == '0,00' || s == '0,0' || s == '0';
  }

  void _attachZeroClearBehavior(FocusNode node, TextEditingController ctrl) {
    node.addListener(() {
      if (node.hasFocus) {
        if (_isZeroCentiText(ctrl.text)) {
          ctrl.clear();
        } else {
          ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
        }
      } else {
        if (ctrl.text.trim().isEmpty) {
          _setCentiCtrl(ctrl, 0);
        }
      }
    });
  }

  int _parseCentiText(String text) {
    final String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  void _setCentiCtrl(TextEditingController ctrl, int centi) {
    final int v = centi < 0 ? 0 : centi;
    final int intPart = v ~/ 100;
    final int decPart = v % 100;
    final String s = '$intPart,${decPart.toString().padLeft(2, '0')}';
    ctrl.value = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
  }

  int _totalCentiFromSection5() {
    final double? b = _blockTimeHours;
    if (b == null || b <= 0) return 0;
    return (b * 100).round();
  }

  bool _isZeroIntText(String text) {
    final String s = text.trim();
    return s.isEmpty || s == '0';
  }

  int _parseIntText(String text) {
    final String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  void _setIntCtrl(TextEditingController ctrl, int value) {
    final int v = value < 0 ? 0 : value;
    final String s = v.toString();
    ctrl.value = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
  }

  void _attachZeroClearIntBehavior(FocusNode node, TextEditingController ctrl) {
    node.addListener(() {
      if (node.hasFocus) {
        if (_isZeroIntText(ctrl.text)) {
          ctrl.clear();
        } else {
          ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
        }
      } else {
        if (ctrl.text.trim().isEmpty) {
          _setIntCtrl(ctrl, 0);
        }
      }
    });
  }

  void _bumpInt(TextEditingController ctrl, int delta) {
    final int current = _parseIntText(ctrl.text);
    final int next = (current + delta);
    _setIntCtrl(ctrl, next < 0 ? 0 : next);
  }

  // ================== SECTION 08 LOGIC (DAY/NIGHT/IFR) ==================

  void _syncConditionsToTotal({required int totalCenti}) {
    final int total = totalCenti < 0 ? 0 : totalCenti;

    int day = _parseCentiText(_condDayCtrl.text);
    int night = _parseCentiText(_condNightCtrl.text);
    int ifr = _parseCentiText(_condIfrCtrl.text);

    if (!_condIfrTouched) {
      ifr = 0;
    } else {
      if (ifr > total) ifr = total;
    }

    if (!_condDayTouched && !_condNightTouched) {
      day = total;
      night = 0;
    } else if (_condDayTouched && !_condNightTouched) {
      if (day > total) day = total;
      night = total - day;
    } else if (_condNightTouched && !_condDayTouched) {
      if (night > total) night = total;
      day = total - night;
    } else {
      if (_condLastEdited == _CondLastEdited.day) {
        if (day > total) day = total;
        night = total - day;
      } else {
        if (night > total) night = total;
        day = total - night;
      }
    }

    _setCentiCtrl(_condDayCtrl, day);
    _setCentiCtrl(_condNightCtrl, night);
    _setCentiCtrl(_condIfrCtrl, ifr);
  }

  void _onDayChanged(String _) {
    final int total = _totalCentiFromSection5();
    int day = _parseCentiText(_condDayCtrl.text);
    if (day > total) day = total;

    _condDayTouched = true;
    _condLastEdited = _CondLastEdited.day;

    final int night = total - day;

    _setCentiCtrl(_condDayCtrl, day);
    _setCentiCtrl(_condNightCtrl, night);

    if (_condIfrTouched) {
      int ifr = _parseCentiText(_condIfrCtrl.text);
      if (ifr > total) {
        ifr = total;
        _setCentiCtrl(_condIfrCtrl, ifr);
      }
    } else {
      _setCentiCtrl(_condIfrCtrl, 0);
    }
  }

  void _onNightChanged(String _) {
    final int total = _totalCentiFromSection5();
    int night = _parseCentiText(_condNightCtrl.text);
    if (night > total) night = total;

    _condNightTouched = true;
    _condLastEdited = _CondLastEdited.night;

    final int day = total - night;

    _setCentiCtrl(_condNightCtrl, night);
    _setCentiCtrl(_condDayCtrl, day);

    if (_condIfrTouched) {
      int ifr = _parseCentiText(_condIfrCtrl.text);
      if (ifr > total) {
        ifr = total;
        _setCentiCtrl(_condIfrCtrl, ifr);
      }
    } else {
      _setCentiCtrl(_condIfrCtrl, 0);
    }
  }

  void _onIfrChanged(String _) {
    final int total = _totalCentiFromSection5();
    int ifr = _parseCentiText(_condIfrCtrl.text);
    if (ifr > total) ifr = total;

    _condIfrTouched = true;
    _setCentiCtrl(_condIfrCtrl, ifr);
  }

  // ================== SECTION 09 LOGIC ==================

  TextEditingController _ctrlForType(String key) {
    switch (key) {
      case _kTtCross:
        return _ttCrossCtrl;
      case _kTtSolo:
        return _ttSoloCtrl;
      case _kTtPic:
        return _ttPicCtrl;
      case _kTtSic:
        return _ttSicCtrl;
      case _kTtInstRe:
        return _ttInstReCtrl;
      case _kTtFlyInst:
        return _ttFlyInstCtrl;
      default:
        return _ttCrossCtrl;
    }
  }

  FocusNode _focusForType(String key) {
    switch (key) {
      case _kTtCross:
        return _ttCrossFocus;
      case _kTtSolo:
        return _ttSoloFocus;
      case _kTtPic:
        return _ttPicFocus;
      case _kTtSic:
        return _ttSicFocus;
      case _kTtInstRe:
        return _ttInstReFocus;
      case _kTtFlyInst:
        return _ttFlyInstFocus;
      default:
        return _ttCrossFocus;
    }
  }

  Color _colorForType(String key) => _kTypeColors[key] ?? AppColors.teal4;

  bool _hasTypeValue(String key) => _parseCentiText(_ctrlForType(key).text) > 0;

  bool _areIncompatible(String a, String b) {
    final Set<String>? sa = _kIncompat[a];
    final Set<String>? sb = _kIncompat[b];
    return (sa != null && sa.contains(b)) || (sb != null && sb.contains(a));
  }

  bool _isTypeEnabled(String key) {
    // si ya tiene valor, permitir editar siempre
    if (_hasTypeValue(key)) return true;

    for (final String other in _kTypeTimeKeys) {
      if (other == key) continue;
      if (_hasTypeValue(other) && _areIncompatible(key, other)) return false;
    }
    return true;
  }

  void _clampTypeTimesToTotal({required int totalCenti}) {
    final int total = totalCenti < 0 ? 0 : totalCenti;
    for (final String k in _kTypeTimeKeys) {
      final TextEditingController c = _ctrlForType(k);
      int v = _parseCentiText(c.text);
      if (v > total) {
        _setCentiCtrl(c, total);
      }
      if (total == 0) {
        _setCentiCtrl(c, 0);
      }
    }
  }

  void _clearIncompatibleIfNeeded(String key) {
    if (!_hasTypeValue(key)) return;
    for (final String other in _kTypeTimeKeys) {
      if (other == key) continue;
      if (_areIncompatible(key, other) && _hasTypeValue(other)) {
        _setCentiCtrl(_ctrlForType(other), 0);
      }
    }
  }

  String _titleKeyForType(String key) {
    switch (key) {
      case _kTtCross:
        return "crosscountry";
      case _kTtSolo:
        return "solo";
      case _kTtPic:
        return "pic";
      case _kTtSic:
        return "sic";
      case _kTtInstRe:
        return "instruction_re";
      case _kTtFlyInst:
        return "fly_instructor";
      default:
        return key;
    }
  }

  String _descKeyForType(String key) {
    switch (key) {
      case _kTtCross:
        return "travesia";
      case _kTtSolo:
        return "vuelo_solo";
      case _kTtPic:
        return "responsable";
      case _kTtSic:
        return "doble_mando";
      case _kTtInstRe:
        return "bajo_instruccion";
      case _kTtFlyInst:
        return "instructor";
      default:
        return "";
    }
  }

  String _abbrForType(AppLocalizations l, String key) {
    switch (key) {
      case _kTtCross:
        return l.t("crosscountry_card");
      case _kTtSolo:
        return "Solo";
      case _kTtPic:
        return "PIC";
      case _kTtSic:
        return "SIC";
      case _kTtInstRe:
        return "INS";
      case _kTtFlyInst:
        return l.t("fly_instructor_card");
      default:
        return key.toUpperCase();
    }
  }

  Future<void> _openTypeTimesPopup() async {
    final AppLocalizations l = AppLocalizations.of(context);

    final Map<String, String> snapshot = <String, String>{
      for (final String k in _kTypeTimeKeys) k: _ctrlForType(k).text,
    };

    final int total = _totalCentiFromSection5();

    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, void Function(void Function()) setSB) {
            Widget buildHeader() {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l.t("flight_section_09_flight_time_types").toUpperCase(),
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.teal3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 1.0),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          l.t("flight_section_05_block_title"),
                          style: AppTextStyles.body.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCenti(total),
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            void onChangedType(String key, String _) {
              final int t = _totalCentiFromSection5();
              int v = _parseCentiText(_ctrlForType(key).text);
              if (v > t) v = t;
              _setCentiCtrl(_ctrlForType(key), v);

              // si pone valor, limpia incompatibles
              _clearIncompatibleIfNeeded(key);

              setSB(() {});
            }

            void onTapLabelSetTotal(String key) {
              final int t = _totalCentiFromSection5();
              if (t <= 0) return;

              if (_isZeroCentiText(_ctrlForType(key).text)) {
                _setCentiCtrl(_ctrlForType(key), t);
                _clearIncompatibleIfNeeded(key);
                setSB(() {});
              } else {
                // si no es cero, solo enfocar campo
                FocusScope.of(ctx).requestFocus(_focusForType(key));
              }
            }

            Widget buildTypeRow(String key) {
              final bool enabled = _isTypeEnabled(key);
              final TextEditingController ctrl = _ctrlForType(key);

              final TextStyle labelTextStyle = AppTextStyles.subtitle.copyWith(
                fontSize: 16, // etiqueta un poco más grande
                fontWeight: FontWeight.w800,
                color: Colors.white,
              );

              final TextStyle descStyle = AppTextStyles.body.copyWith(
                fontSize: 11, // explicación un poco más pequeña
                color: Colors.white.withOpacity(enabled ? 0.9 : 0.35),
              );

              // ETIQUETA SIN COLOR (solo borde)
              final Widget labelPill = GestureDetector(
                onTap: enabled ? () => onTapLabelSetTotal(key) : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 0.8),
                  ),
                  child: Text(
                    l.t(_titleKeyForType(key)),
                    style: labelTextStyle.copyWith(
                      color: enabled ? Colors.white : Colors.white38,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );

              final String descKey = _descKeyForType(key);
              final String desc = descKey.isEmpty ? '' : l.t(descKey);

              final bool hasVal = _parseCentiText(ctrl.text) > 0;

              final Color iconColor = !enabled
                  ? Colors.white24
                  : (hasVal ? AppColors.teal5 : Colors.white.withOpacity(0.85));

              final TextStyle numStyle = TextStyle(
                color: enabled ? AppColors.teal1 : Colors.black26,
                fontWeight: FontWeight.bold,
              );

              final Color fillColor =
                  enabled ? Colors.white : Colors.white.withOpacity(0.35);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // IZQUIERDA (MAX)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          labelPill,
                          const SizedBox(height: 6),
                          Text(desc, style: descStyle),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // DERECHA (MIN): icono + número pegados
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SvgPicture.asset(
                          'assets/icons/timeajust.svg',
                          width: 18,
                          height: 18,
                          colorFilter:
                              ColorFilter.mode(iconColor, BlendMode.srcIn),
                        ),
                        const SizedBox(width: 8),
                        _rtlCentiField(
                          ctrl: ctrl,
                          // ignore: no_wildcard_variable_uses
                          onChanged: (_) => onChangedType(key, _),
                          focusNode: _focusForType(key),
                          enabled: enabled,
                          fillColor: fillColor,
                          textStyle: numStyle,
                          centerText: true,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              contentPadding: EdgeInsets.zero,
              insetPadding: const EdgeInsets.symmetric(horizontal: 12),
              content: Container(
                width: 420,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: <Color>[AppColors.teal1, AppColors.teal3],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      buildHeader(),
                      const SizedBox(height: 10),
                      Container(
                        height: 0.5,
                        color: Colors.white.withOpacity(0.55),
                      ),
                      const SizedBox(height: 8),
                      for (final String k in _kTypeTimeKeys) ...<Widget>[
                        buildTypeRow(k),
                        if (k != _kTypeTimeKeys.last)
                          Container(
                            height: 0.5,
                            color: Colors.white.withOpacity(0.25),
                          ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(l.t("cancel")),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(l.t("save")),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      // clamp final por si acaso
      _clampTypeTimesToTotal(totalCenti: _totalCentiFromSection5());
      setState(() {});
      return;
    }

    // cancelar: restaurar snapshot
    for (final String k in _kTypeTimeKeys) {
      final String? t = snapshot[k];
      if (t != null) {
        _ctrlForType(k).value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
      }
    }
    setState(() {});
  }

  bool _hasAnyTypeTimes() {
    for (final String k in _kTypeTimeKeys) {
      if (_hasTypeValue(k)) return true;
    }
    return false;
  }

  String _formatCenti(int centi) {
    final int v = centi < 0 ? 0 : centi;
    final int intPart = v ~/ 100;
    final int decPart = v % 100;
    return '$intPart,${decPart.toString().padLeft(2, '0')}';
  }

  // ================== UI HELPERS ==================

  Widget _placeholderText(String text, {double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: AppTextStyles.body.copyWith(
          color: Colors.white.withOpacity(0.7),
          fontStyle: FontStyle.italic,
          fontSize: fontSize,
        ),
      ),
    );
  }

  InputDecoration _pillNumberDecoration({Color? fillColor}) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: fillColor ?? Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  Widget _rtlCentiField({
    required TextEditingController ctrl,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
    bool enabled = true,
    Color? fillColor,
    TextStyle? textStyle,
    bool centerText = true,
  }) {
    const double baseWidth = 80.0;
    const double maxWidth = 90.0;
    const double extraPerChar = 6.0;

    return ConstrainedBox(
      constraints:
          const BoxConstraints(minWidth: baseWidth, maxWidth: maxWidth),
      child: Align(
        alignment: Alignment.centerRight,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (_, TextEditingValue value, __) {
            final int len = value.text.length;
            final int extraChars = len > 4 ? (len - 4) : 0;
            final double w = (baseWidth + extraPerChar * extraChars)
                .clamp(baseWidth, maxWidth);

            return SizedBox(
              width: w,
              child: TextField(
                enabled: enabled,
                focusNode: focusNode,
                controller: ctrl,
                textAlign: centerText ? TextAlign.center : TextAlign.right,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  const _RightToLeftCentiHoursFormatter(maxDigits: 6),
                ],
                style: textStyle ??
                    const TextStyle(
                      color: AppColors.teal1,
                      fontWeight: FontWeight.bold,
                    ),
                decoration: _pillNumberDecoration(
                  fillColor: fillColor ?? Colors.white,
                ),
                onTap: () {
                  // si es 0,00 -> limpiar sin que el usuario borre
                  if (_isZeroCentiText(ctrl.text)) {
                    ctrl.clear();
                  }
                },
                onChanged: onChanged,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _conditionRow({
    required String iconPath,
    required String label,
    required TextEditingController ctrl,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
    bool showDividerBelow = true,
  }) {
    final TextStyle labelStyle = AppTextStyles.subtitle.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    );

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  SvgPicture.asset(
                    iconPath,
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(label, style: labelStyle),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _rtlCentiField(
              ctrl: ctrl,
              onChanged: onChanged,
              focusNode: focusNode,
            ),
          ],
        ),
        if (showDividerBelow)
          Container(
            height: 0.5,
            margin: const EdgeInsets.symmetric(vertical: 6),
            color: Colors.white.withOpacity(0.6),
          ),
      ],
    );
  }

  Widget _buildSection11ApproachesContent() {
    final AppLocalizations l = AppLocalizations.of(context);

    final TextStyle valueStyle = AppTextStyles.body.copyWith(
      color: AppColors.teal5,
      fontWeight: FontWeight.w700,
      fontSize: 15,
    );

    final TextStyle hintStyle = AppTextStyles.body.copyWith(
      color: Colors.white.withOpacity(0.75),
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w600,
      fontSize: 15,
    );

    // Parte 1: icono (VFR vs IFR)
    final String iconPath = (_approachType == 'VFR')
        ? 'assets/icons/vfrapp.svg'
        : 'assets/icons/ifrapp.svg';

    Widget arrow({required IconData icon, required int delta}) {
      return InkWell(
        onTap: () => _bumpInt(_approachCountCtrl, delta),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
          child: Icon(icon, size: 30, color: AppColors.teal5),
        ),
      );
    }

    return Row(
      children: <Widget>[
        // Parte 1 + Parte 2: 5/10
        Expanded(
          flex: 5,
          child: Row(
            children: <Widget>[
              SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
              const SizedBox(width: 10),

              // Parte 2: dropdown (sin icono "pegado")
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.transparent,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _approachType,
                      isExpanded: true,
                      icon: const SizedBox.shrink(),
                      iconSize: 0,
                      dropdownColor: AppColors.teal2,
                      hint: Text(
                        l.t("add_app"),
                        style: hintStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final String t in _kApproachTypes)
                          DropdownMenuItem<String>(
                            value: t,
                            child: Text(
                              t,
                              style: valueStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        DropdownMenuItem<String>(
                          value: '__CLEAR__',
                          child: Text(
                            l.t("clear"),
                            style: valueStyle.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (String? v) {
                        setState(() {
                          if (v == null || v == '__CLEAR__') {
                            _approachType = null;
                          } else {
                            _approachType = v;
                          }
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Parte 3: 5/10 (selector numérico con flechas)
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                arrow(icon: Icons.chevron_left, delta: -1),
                _intPillField(
                    ctrl: _approachCountCtrl, focusNode: _approachCountFocus),
                arrow(icon: Icons.chevron_right, delta: 1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _measureTextWidth(BuildContext context, String text, TextStyle style) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaleFactor: MediaQuery.of(context).textScaleFactor,
    )..layout();
    return tp.width;
  }

  // ignore: unused_element
  double _approachDropdownWidth(BuildContext context) {
    final TextStyle style = AppTextStyles.body.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    );

    double maxText = 0;
    for (final String t in _kApproachTypes) {
      final double w = _measureTextWidth(context, t, style);
      if (w > maxText) maxText = w;
    }

    const double iconW = 16;
    const double gap = 8;
    const double horizontalPadding = 24; // 12 + 12 del contenedor
    const double safety = 8;

    return maxText + iconW + gap + horizontalPadding + safety;
  }

  // ignore: unused_element
  Widget _buildApproachDropdownFixedWidth() {
    final AppLocalizations l = AppLocalizations.of(context);

    final TextStyle itemStyle = AppTextStyles.body.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    );

    final TextStyle hintStyle = itemStyle.copyWith(
      color: Colors.white.withOpacity(0.75),
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w600,
    );

    // ancho fijo: el más largo de la lista ("ILS - CAT III")
    double maxTextW = 0;
    for (final String t in _kApproachTypes) {
      final TextPainter tp = TextPainter(
        text: TextSpan(text: t, style: itemStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > maxTextW) maxTextW = tp.width;
    }

    // padding + icon del dropdown
    final double fixedW = maxTextW + 6 + 12 + 28 + 6;

    return SizedBox(
      width: fixedW,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.teal5, width: 2),
          color: Colors.transparent,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _approachType,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            dropdownColor: AppColors.teal2,
            hint: Text(l.t("add_app"), style: hintStyle),
            items: _kApproachTypes.map((String t) {
              return DropdownMenuItem<String>(
                value: t,
                child: Text(
                  t,
                  style: itemStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (String? v) => setState(() => _approachType = v),
          ),
        ),
      ),
    );
  }

// ====== SECTION 12: REMARKS + TAGS ======
  final TextEditingController _remarksCtrl = TextEditingController();
  final TextEditingController _remarkTagCtrl = TextEditingController();
  final List<String> _remarkTags = <String>[];

  // ---------- SUB-SECCIÓN 01: FECHA ----------

  Widget _buildDateSection() {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    final Color iconColor = theme.iconTheme.color ?? Colors.white;
    final bool isMultiDay = _flightEndDate.isAfter(_flightBeginDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionItemTitle(title: l.t("flight_section_01_date_of_flight")),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                onTap: _pickFlightBeginDate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.t('flight_begins'), style: AppTextStyles.body),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.calendar_today, size: 18, color: iconColor),
                        const SizedBox(width: 6),
                        Text(
                          _fmtDate(context, _flightBeginDate),
                          style: AppTextStyles.body.copyWith(fontSize: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
                width: 1,
                height: 58,
                color: theme.dividerColor.withOpacity(0.6)),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: _pickFlightEndDate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(l.t('flight_ends'), style: AppTextStyles.body),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          _fmtDate(context, _flightEndDate),
                          style: AppTextStyles.body.copyWith(fontSize: 18),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.calendar_today, size: 18, color: iconColor),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isMultiDay)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.teal3.withOpacity(0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.teal4, width: 1),
            ),
            child: Text(
              l.t('flight_multi_day_hint'),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  // ---------- SUB-SECCIÓN 02: AERONAVE / SIM ----------

  Widget _buildAircraftSection() {
    final AppLocalizations l = AppLocalizations.of(context);

    if (_selectedAircraft == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionItemTitle(title: l.t("flight_section_02_aircraft_simulator")),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton(
              onPressed: _pickAircraftForFlight,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.teal3, width: 1.5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                l.t("flight_add_aircraft_button"),
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _placeholderText(l.t("flight_add_aircraft_hint"), fontSize: 12),
        ],
      );
    }

    final _SelectedAircraftSummary a = _selectedAircraft!;
    final bool isSim = a.isSimulator;

    final String regText =
        a.registration.trim().isEmpty ? '—' : a.registration.trim();
    final String identifierText =
        a.identifier.trim().isEmpty ? '—' : a.identifier.trim();
    final String ownerText = a.owner.trim();
    final String makeModelText =
        a.makeAndModel.trim().isEmpty ? '—' : a.makeAndModel.trim();

    final String simCompanyText = a.simCompany.trim();
    final String simModelText = a.simAircraftModel.trim();
    final String simLevelText = a.simLevel.trim();

    final TextStyle pillStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: kSec2PillFontSize,
      letterSpacing: 0.2,
    );

    final TextStyle mainValueTeal3 = AppTextStyles.subtitle.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: AppColors.teal4,
    );

    final TextStyle mainValueTeal4 = AppTextStyles.subtitle.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.white,
    );

    final TextStyle labelTeal4 = AppTextStyles.body.copyWith(
      fontSize: kSec2LabelFontSize,
      fontWeight: FontWeight.w600,
      color: AppColors.teal4.withOpacity(0.95),
    );

    Widget buildLeftPill() {
      final String pillText =
          isSim ? l.t("aircraft_type_simulator_title") : regText;

      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.teal2,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: Colors.white, width: 1.0),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            pillText,
            style: pillStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      );
    }

    Widget buildCenterColumn() {
      if (!isSim) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              identifierText,
              style: mainValueTeal3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            const SizedBox(height: 2),
            Text(
              makeModelText,
              style: mainValueTeal4,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            simCompanyText.isEmpty ? '—' : simCompanyText,
            style: mainValueTeal3,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          const SizedBox(height: 2),
          Text(
            simModelText.isEmpty ? '—' : simModelText,
            style: mainValueTeal4,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ],
      );
    }

    Widget buildRightColumn() {
      if (!isSim) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l.t("aircraft_owner_label"),
              style: labelTeal4,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            const SizedBox(height: 1),
            Text(
              ownerText.isEmpty ? '—' : ownerText,
              style: mainValueTeal4,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l.t("aircraft_sim_level_label"),
            style: AppTextStyles.body.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.teal4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          Text(
            simLevelText.isEmpty ? '—' : simLevelText,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: kSec2MainValueFontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ],
      );
    }

    Widget buildTagsRow() {
      final List<String> rawTags = a.tags;
      if (rawTags.isEmpty) return const SizedBox.shrink();

      final List<String> upperTags =
          rawTags.map((String e) => e.toUpperCase()).toList();

      final List<String> visibleTags = upperTags.take(4).toList();
      final bool hasMoreTags = upperTags.length > 4;

      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              l.t("aircraft_tags_label").toUpperCase(),
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: AppColors.teal4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final String tag in visibleTags) ...<Widget>[
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white, width: 0.8),
                        ),
                        child: Text(
                          tag,
                          style: AppTextStyles.body.copyWith(
                            fontSize: kSec2TagFontSize,
                            color: AppColors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ],
                    if (hasMoreTags)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white, width: 0.8),
                        ),
                        child: Center(
                          child: Text(
                            '...',
                            style: AppTextStyles.body.copyWith(
                              fontSize: kSec2TagFontSize,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teal4,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionItemTitle(title: l.t("flight_section_02_aircraft_simulator")),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickAircraftForFlight,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 4, child: buildLeftPill()),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: buildCenterColumn()),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: buildRightColumn()),
                ],
              ),
              const SizedBox(height: 5),
              Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: Colors.white.withOpacity(0.6),
              ),
              buildTagsRow(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- SUB-SECCIÓN 03: RUTA ----------

  Widget _buildRouteSection() {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    final String fromCode = _fromIcaoCtrl.text.trim().toUpperCase();
    final String toCode = _toIcaoCtrl.text.trim().toUpperCase();

    final String fromFlag = fromCode.isNotEmpty ? _flagForIcao(fromCode) : '';
    final String toFlag = toCode.isNotEmpty ? _flagForIcao(toCode) : '';

    final bool hasSim = fromCode == 'SIM' || toCode == 'SIM';

    final TextStyle labelStyle =
        AppTextStyles.body.copyWith(fontWeight: FontWeight.w600);
    final TextStyle icaoStyle =
        AppTextStyles.body.copyWith(fontSize: 18, fontWeight: FontWeight.w700);
    final TextStyle placeholderStyle = icaoStyle.copyWith(
      color: Colors.white.withOpacity(0.6),
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
    );

    final String airportPlaceholder =
        l.t("flight_airport_placeholder").toUpperCase();

    final InputDecorationTheme noBorderDecoration = const InputDecorationTheme(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      isDense: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionItemTitle(title: l.t("flight_section_03_route")),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(l.t("flight_from"), style: labelStyle),
            Container(
                width: 1,
                height: 24,
                color: theme.dividerColor.withOpacity(0.4)),
            Text(l.t("flight_to"), style: labelStyle),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  SvgPicture.asset(
                    'assets/icons/location.svg',
                    width: 18,
                    height: 18,
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 12),
                  if (fromFlag.isNotEmpty) ...<Widget>[
                    Text(fromFlag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Theme(
                      data: theme.copyWith(
                          inputDecorationTheme: noBorderDecoration),
                      child: TextField(
                        controller: _fromIcaoCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                          LengthLimitingTextInputFormatter(4),
                        ],
                        onChanged: (String value) {
                          final String upper = value.toUpperCase();
                          if (upper != value) {
                            _fromIcaoCtrl.value = _fromIcaoCtrl.value.copyWith(
                              text: upper,
                              selection:
                                  TextSelection.collapsed(offset: upper.length),
                            );
                          }
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: airportPlaceholder,
                          hintStyle: placeholderStyle,
                          counterText: '',
                        ),
                        style: icaoStyle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 40,
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/plane.svg',
                  width: 22,
                  height: 22,
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Flexible(
                    child: Theme(
                      data: theme.copyWith(
                          inputDecorationTheme: noBorderDecoration),
                      child: TextField(
                        controller: _toIcaoCtrl,
                        textAlign: TextAlign.right,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                          LengthLimitingTextInputFormatter(4),
                        ],
                        onChanged: (String value) {
                          final String upper = value.toUpperCase();
                          if (upper != value) {
                            _toIcaoCtrl.value = _toIcaoCtrl.value.copyWith(
                              text: upper,
                              selection:
                                  TextSelection.collapsed(offset: upper.length),
                            );
                          }
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: airportPlaceholder,
                          hintStyle: placeholderStyle,
                          counterText: '',
                        ),
                        style: icaoStyle,
                      ),
                    ),
                  ),
                  if (toFlag.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 6),
                    Text(toFlag, style: const TextStyle(fontSize: 22)),
                  ],
                  const SizedBox(width: 12),
                  SvgPicture.asset(
                    'assets/icons/location.svg',
                    width: 18,
                    height: 18,
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (hasSim) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            l.t("flight_simulator_authority_hint"),
            style: AppTextStyles.body.copyWith(
              fontStyle: FontStyle.italic,
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

// ---------- SUB-SECCIÓN 04: CREW ----------

  Widget _buildCrewSection() {
    final AppLocalizations l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionItemTitle(title: l.t("flight_section_04_pilot_crew")),
        const SizedBox(height: 16),
        if (_crewEntries.isEmpty)
          _placeholderText(l.t("flight_add_aircraft_hint")),
        for (int i = 0; i < _crewEntries.length; i++) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: () => _editCrewEntry(i),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.teal2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: Text(
                          _crewEntries[i].role.code,
                          style: AppTextStyles.subtitle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _crewEntries[i].name,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDeleteCrewEntry(i),
                child: SvgPicture.asset(
                  'assets/icons/erase.svg',
                  height: 16,
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (_crewEntries.length < 4)
          Center(
            child: OutlinedButton(
              onPressed: _addNewCrewEntry,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.teal3, width: 1.5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                shape: const StadiumBorder(),
              ),
              child: Text(
                l.t("add_new_crew_button"),
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- SUB-SECCIÓN 05: TIEMPO DE VUELO / BLOCK TIME ----------

  Widget _buildFlightTimeSection() {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    final bool hasAnyInput = _timeStartCtrl.text.trim().isNotEmpty ||
        _timeEndCtrl.text.trim().isNotEmpty;

    final List<TextInputFormatter> formatters =
        _buildFlightTimeInputFormatters();

    final TextStyle labelStyle = AppTextStyles.body.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 15,
    );

    final TextStyle valueStyle = AppTextStyles.subtitle.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: Colors.white.withOpacity(0.9),
    );

    final TextStyle valueHintStyle =
        valueStyle.copyWith(color: Colors.white.withOpacity(0.4));

    return Column(
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            SectionContainer(
              children: <Widget>[
                SectionItemTitle(title: l.t("flight_section_05_flight_time")),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 4,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          l.t("flight_section_05_hobbs_label"),
                          textAlign: TextAlign.right,
                          style: labelStyle,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Transform.scale(
                          scale: 0.6,
                          child: Switch(
                            value: _useUtcTime,
                            onChanged: _onToggleFlightTimeMode,
                            activeColor: Colors.white,
                            inactiveThumbColor: Colors.white,
                            activeTrackColor: AppColors.teal3,
                            inactiveTrackColor: AppColors.teal3,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l.t("flight_section_05_utc_label"),
                          textAlign: TextAlign.left,
                          style: labelStyle,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(height: 0.5, color: Colors.white.withOpacity(0.6)),
                const SizedBox(height: 2),
                if (!hasAnyInput)
                  Center(
                    child: Text(
                      l.t("flight_section_05_decimal_hint"),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: AppColors.teal4,
                      ),
                    ),
                  ),
                if (!hasAnyInput) const SizedBox(height: 4),
                Container(height: 0.5, color: Colors.white.withOpacity(0.6)),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Center(
                        child: Text(l.t("flight_section_05_start_label"),
                            style: labelStyle),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(l.t("flight_section_05_end_label"),
                            style: labelStyle),
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          SvgPicture.asset(
                            'assets/icons/time.svg',
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                                Colors.white, BlendMode.srcIn),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _timeStartCtrl,
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                signed: false,
                                decimal: true,
                              ),
                              inputFormatters: formatters,
                              style: valueStyle,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 0),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                hintText: _useUtcTime ? 'HH:MM' : '0,00',
                                hintStyle: valueHintStyle,
                              ),
                              onChanged: (String v) {
                                if (_useUtcTime) {
                                  _handleUtcFieldChanged(_timeStartCtrl, v);
                                } else {
                                  _onFlightTimeChanged();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 26,
                        color: theme.dividerColor.withOpacity(0.6)),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _timeEndCtrl,
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                signed: false,
                                decimal: true,
                              ),
                              inputFormatters: formatters,
                              style: valueStyle,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 0),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                hintText: _useUtcTime ? 'HH:MM' : '0,00',
                                hintStyle: valueHintStyle,
                              ),
                              onChanged: (String v) {
                                if (_useUtcTime) {
                                  _handleUtcFieldChanged(_timeEndCtrl, v);
                                } else {
                                  _onFlightTimeChanged();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            'assets/icons/time.svg',
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                                Colors.white, BlendMode.srcIn),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -16,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.teal3,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        l.t("flight_section_05_block_title"),
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _blockTimeHours != null
                            ? _formatBlockTime(_blockTimeHours!)
                            : '00,00',
                        style: AppTextStyles.subtitle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

// ---------- SUB-SECCIÓN 06–07: contenido (SIN SectionContainer) ----------
  Widget _buildTypeAndSimSubsectionContent() {
    final AppLocalizations l = AppLocalizations.of(context);

    if (_selectedAircraft == null || _selectedAircraft!.typeIds.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionItemTitle(
            title: l.t("flight_section_06_07_aircraft_type_and_sim_time"),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.t("flight_section_06_07_hint"),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withOpacity(0.7),
                fontStyle: FontStyle.italic,
                fontSize: 16,
              ),
            ),
          ),
        ],
      );
    }

    final _SelectedAircraftSummary a = _selectedAircraft!;

    final Map<String, String> codeToLabel = <String, String>{};
    final List<int> originalIds = a.typeIds;
    final List<String> titles = a.typeTitles;

    final int len =
        originalIds.length < titles.length ? originalIds.length : titles.length;

    for (int i = 0; i < len; i++) {
      final int id = originalIds[i];
      final String? code = _kTypeIdToCode[id];
      if (code == null) continue;
      final String label = titles[i].trim();
      if (label.isEmpty) continue;
      codeToLabel.putIfAbsent(code.toUpperCase(), () => label);
    }

    if (a.typeCustomLabel.trim().isNotEmpty) {
      codeToLabel['OTHER'] = a.typeCustomLabel.trim();
    }

    final List<int> ids = List<int>.from(a.typeIds);

    final TextStyle pillTextStyle = AppTextStyles.subtitle.copyWith(
      fontWeight: FontWeight.w700,
      color: Colors.white,
      fontSize: 13,
    );

    final TextStyle descTextStyle = AppTextStyles.body.copyWith(
      fontSize: 12,
      color: Colors.white.withOpacity(0.9),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionItemTitle(
          title: l.t("flight_section_06_07_aircraft_type_and_sim_time"),
        ),
        const SizedBox(height: 6),
        Column(
          children: <Widget>[
            for (int i = 0; i < ids.length; i++) ...<Widget>[
              Builder(
                builder: (BuildContext ctx) {
                  final int id = ids[i];
                  final String? rawCode = _kTypeIdToCode[id];
                  if (rawCode == null) return const SizedBox.shrink();
                  final String code = rawCode.toUpperCase();

                  final String title =
                      codeToLabel[code] ?? l.t(_typeTitleKeyForCode(code));

                  String desc;
                  if (code == 'OTHER' && a.typeCustomDescription.isNotEmpty) {
                    desc = a.typeCustomDescription;
                  } else {
                    final String dk = _typeDescKeyForCode(code);
                    desc = dk.isEmpty ? "" : l.t(dk);
                  }

                  final Color color = _typeColorForCode(code);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Text(title.toUpperCase(), style: pillTextStyle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(desc, style: descTextStyle)),
                    ],
                  );
                },
              ),
              if (i != ids.length - 1)
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.white.withOpacity(0.5),
                ),
            ],
          ],
        ),
      ],
    );
  }

  InputDecoration _pillIntDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  Widget _intPillField({
    required TextEditingController ctrl,
    required FocusNode focusNode,
  }) {
    const double baseWidth = 56.0;
    const double maxWidth = 90.0;
    const double extraPerChar = 8.0;

    return ConstrainedBox(
      constraints:
          const BoxConstraints(minWidth: baseWidth, maxWidth: maxWidth),
      child: Align(
        alignment: Alignment.center,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (_, TextEditingValue value, __) {
            final int len = value.text.length;
            final int extraChars = len > 2 ? (len - 2) : 0;
            final double w = (baseWidth + extraPerChar * extraChars)
                .clamp(baseWidth, maxWidth);

            return SizedBox(
              width: w,
              child: TextField(
                focusNode: focusNode,
                controller: ctrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(
                  color: AppColors.teal1,
                  fontWeight: FontWeight.bold,
                ),
                decoration: _pillIntDecoration(),
                onTap: () {
                  if (_isZeroIntText(ctrl.text)) {
                    ctrl.clear();
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

//==============SECCION 10===========================//
  Widget _dayNightIntRow({
    required String iconPath,
    required String label,
    required TextEditingController ctrl,
    required FocusNode focusNode,
    bool showDividerBelow = true,
  }) {
    final TextStyle labelStyle = AppTextStyles.subtitle.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    );

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  SvgPicture.asset(
                    iconPath,
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(label, style: labelStyle),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  InkWell(
                    onTap: () => _bumpInt(ctrl, -1),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 2),
                      child: Icon(
                        Icons.chevron_left,
                        size: 30,
                        color: AppColors.teal5,
                      ),
                    ),
                  ),
                  _intPillField(ctrl: ctrl, focusNode: focusNode),
                  InkWell(
                    onTap: () => _bumpInt(ctrl, 1),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 2),
                      child: Icon(
                        Icons.chevron_right,
                        size: 30,
                        color: AppColors.teal5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showDividerBelow)
          Container(
            height: 0.5,
            margin: const EdgeInsets.symmetric(vertical: 6),
            color: Colors.white.withOpacity(0.6),
          ),
      ],
    );
  }

  Widget _buildSection10TakeoffsLandingsContent() {
    final AppLocalizations l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Despegues
        SectionItemTitle(title: l.t("totals_takeoffs_section")),
        _dayNightIntRow(
          iconPath: 'assets/icons/takeoffd.svg',
          label: l.t("day"),
          ctrl: _tkofDayCtrl,
          focusNode: _tkofDayFocus,
        ),
        _dayNightIntRow(
          iconPath: 'assets/icons/takeoffn.svg',
          label: l.t("night"),
          ctrl: _tkofNightCtrl,
          focusNode: _tkofNightFocus,
          showDividerBelow: false,
        ),

        const SizedBox(height: 12),

        // Aterrizajes
        SectionItemTitle(title: l.t("totals_landings_section")),
        _dayNightIntRow(
          iconPath: 'assets/icons/landingd.svg',
          label: l.t("day"),
          ctrl: _ldgDayCtrl,
          focusNode: _ldgDayFocus,
        ),
        _dayNightIntRow(
          iconPath: 'assets/icons/landingn.svg',
          label: l.t("night"),
          ctrl: _ldgNightCtrl,
          focusNode: _ldgNightFocus,
          showDividerBelow: false,
        ),
      ],
    );
  }

  void _addRemarkTagFromInput() {
    final String raw = _remarkTagCtrl.text.trim();
    if (raw.isEmpty) return;

    final String tag = raw; // si quieres, aquí puedes .toUpperCase()
    if (_remarkTags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
      _remarkTagCtrl.clear();
      return;
    }

    setState(() {
      _remarkTags.add(tag);
      _remarkTagCtrl.clear();
    });
  }

  void _removeRemarkTag(String tag) {
    setState(() => _remarkTags.remove(tag));
  }

  Widget _buildRemarkTags() {
    final AppLocalizations l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: TextField(
                  controller: _remarkTagCtrl,
                  textInputAction: TextInputAction.done,
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: l.t("flight_section_12_add_tag_hint"),
                    hintStyle: AppTextStyles.body.copyWith(
                      color: Colors.white.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  onSubmitted: (_) => _addRemarkTagFromInput(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _addRemarkTagFromInput,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white, width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_remarkTags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _remarkTags.map((String tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      tag,
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _removeRemarkTag(tag),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ---------- SECCIÓN 06–11 (UNA SOLA SECCIÓN VISUAL) ----------
  // (tu código de 06–07 se mantiene igual que antes; aquí solo dejamos 08 y 09 reales)

  Widget _buildSection08FlightConditionsContent() {
    final AppLocalizations l = AppLocalizations.of(context);

    return Column(
      children: <Widget>[
        _conditionRow(
          iconPath: 'assets/icons/day.svg',
          label: l.t("day"),
          ctrl: _condDayCtrl,
          onChanged: _onDayChanged,
          focusNode: _condDayFocus,
        ),
        _conditionRow(
          iconPath: 'assets/icons/night.svg',
          label: l.t("night"),
          ctrl: _condNightCtrl,
          onChanged: _onNightChanged,
          focusNode: _condNightFocus,
        ),
        _conditionRow(
          iconPath: 'assets/icons/ifr.svg',
          label: l.t("ifr").toUpperCase(),
          ctrl: _condIfrCtrl,
          onChanged: _onIfrChanged,
          focusNode: _condIfrFocus,
          showDividerBelow: false,
        ),
      ],
    );
  }

  Widget _buildSection09FlightTimeTypesContent() {
    final AppLocalizations l = AppLocalizations.of(context);

    if (!_hasAnyTypeTimes()) {
      return Center(
        child: OutlinedButton(
          onPressed: _openTypeTimesPopup,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.teal3, width: 1.5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            shape: const StadiumBorder(),
          ),
          child: Text(
            l.t("add_type_fl_time"),
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    final List<String> visible = <String>[
      for (final String k in _kTypeTimeKeys)
        if (_hasTypeValue(k)) k,
    ];

    return InkWell(
      onTap: _openTypeTimesPopup,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final String k in visible)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _colorForType(k),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 0.8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _abbrForType(l, k),
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _ctrlForType(k).text,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSections06to11Section() {
    final AppLocalizations l = AppLocalizations.of(context);

    return SectionContainer(
      children: <Widget>[
        // 06–07 (RESTAURADA)
        _buildTypeAndSimSubsectionContent(),
        const SizedBox(height: 12),

        // 08
        SectionItemTitle(title: l.t("flight_section_08_flight_conditions")),
        _buildSection08FlightConditionsContent(),
        const SizedBox(height: 12),

        // 09
        SectionItemTitle(title: l.t("flight_section_09_flight_time_types")),
        _buildSection09FlightTimeTypesContent(),
        const SizedBox(height: 12),

        // 10
        SectionItemTitle(title: l.t("flight_section_10_tkof_landings")),
        _buildSection10TakeoffsLandingsContent(),
        const SizedBox(height: 12),

        // 11
        SectionItemTitle(title: l.t("flight_section_11_approaches")),
        _buildSection11ApproachesContent(),
      ],
    );
  }

  // ---------- SECCIÓN PRINCIPAL 01–04 ----------

  Widget _buildMainInfoSection() {
    return SectionContainer(
      children: <Widget>[
        _buildDateSection(),
        const SizedBox(height: 8),
        _buildAircraftSection(),
        const SizedBox(height: 8),
        _buildRouteSection(),
        const SizedBox(height: 8),
        _buildCrewSection(),
      ],
    );
  }

  // ================== LIFECYCLE ==================

  @override
  void dispose() {
    _fromIcaoCtrl.dispose();
    _toIcaoCtrl.dispose();
    _timeStartCtrl.dispose();
    _timeEndCtrl.dispose();

    _condDayCtrl.dispose();
    _condNightCtrl.dispose();
    _condIfrCtrl.dispose();

    _condDayFocus.dispose();
    _condNightFocus.dispose();
    _condIfrFocus.dispose();

    _ttCrossCtrl.dispose();
    _ttSoloCtrl.dispose();
    _ttPicCtrl.dispose();
    _ttSicCtrl.dispose();
    _ttInstReCtrl.dispose();
    _ttFlyInstCtrl.dispose();

    _ttCrossFocus.dispose();
    _ttSoloFocus.dispose();
    _ttPicFocus.dispose();
    _ttSicFocus.dispose();
    _ttInstReFocus.dispose();
    _ttFlyInstFocus.dispose();

    _tkofDayCtrl.dispose();
    _tkofNightCtrl.dispose();
    _ldgDayCtrl.dispose();
    _ldgNightCtrl.dispose();

    _tkofDayFocus.dispose();
    _tkofNightFocus.dispose();
    _ldgDayFocus.dispose();
    _ldgNightFocus.dispose();

    _remarksCtrl.dispose();
    _remarkTagCtrl.dispose();

    _approachCountCtrl.dispose();
    _approachCountFocus.dispose();

    super.dispose();
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);

    final String title =
        _isEdit ? l.t("edit_flight_title") : l.t("add_flight_title");

    return BaseScaffold(
      appBar: CustomAppBar(
        title: title,
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: _cancel,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildMainInfoSection(),
            const SizedBox(height: 2),

            _buildFlightTimeSection(),
            const SizedBox(height: 0),

            _buildSections06to11Section(),
            const SizedBox(height: 2),

            // 12
            SectionContainer(
              children: <Widget>[
                SectionItemTitle(title: l.t("flight_section_12_remarks")),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: TextField(
                    controller: _remarksCtrl,
                    maxLines: 2,
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: l.t("flight_section_12_remarks_hint"),
                      hintStyle: AppTextStyles.body.copyWith(
                        color: Colors.white.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildRemarkTags(),
              ],
            ),

            ButtonStyles.pillCancelSave(
              cancelLabel: l.t("cancel"),
              saveLabel: _saving ? l.t("saving") : l.t("save"),
              onCancel: () => Navigator.pop(context, false),
              onSave: () async {
                if (!_saving) await _saveFlight();
              },

              // ✅ SOLO en editar
              deleteLabel: widget.flightId != null ? l.t("delete") : null,
              onDelete:
                  widget.flightId != null ? () async => _deleteFlight() : null,
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  void _dbKeyForType(String k) {}
}

class _RightToLeftCentiHoursFormatter extends TextInputFormatter {
  final int maxDigits;

  const _RightToLeftCentiHoursFormatter({required this.maxDigits});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    // permitir vacío mientras edita (al perder foco vuelve a 0,00)
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final String padded = digits.padLeft(3, '0');
    final String dec = padded.substring(padded.length - 2);
    String intPart = padded.substring(0, padded.length - 2);
    intPart = intPart.replaceFirst(RegExp(r'^0+'), '');
    if (intPart.isEmpty) intPart = '0';

    final String out = '$intPart,$dec';
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}
