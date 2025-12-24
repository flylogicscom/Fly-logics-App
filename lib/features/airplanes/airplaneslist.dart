import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

import 'package:fly_logicd_logbook_app/features/airplanes/airplanes.dart';

class AirplanesList extends StatefulWidget {
  final bool pickMode;

  const AirplanesList({super.key, this.pickMode = false});

  @override
  State<AirplanesList> createState() => _AirplanesListState();
}

class _AirplanesListState extends State<AirplanesList> {
  static const String _aircraftTable = 'aircraft_items';

  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFromDb();
  }

  Future<void> _ensureTableExists() async {
    final db = await DBHelper.getDB();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_aircraftTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT
      )
    ''');
    // columnas adicionales se añaden en airplanes.dart (_ensureAircraftTableExists)
  }

  Future<void> _loadFromDb() async {
    final db = await DBHelper.getDB();
    await _ensureTableExists();

    final rows = await db.query(
      _aircraftTable,
      // usamos id DESC por si createdAt aún no existe en todas
      orderBy: 'id DESC',
    );

    // Mapa id -> código
    const Map<int, String> idToCode = {
      1: 'SE',
      2: 'ME',
      3: 'TP',
      4: 'TJ',
      5: 'LSA',
      6: 'HELI',
      7: 'GLID',
      8: 'OTHER',
      9: 'SIM',
    };

    setState(() {
      _items
        ..clear()
        ..addAll(rows.map((r) {
          final dynamic rawId = r['id'];
          int id;
          if (rawId is int) {
            id = rawId;
          } else if (rawId is String) {
            id = int.tryParse(rawId) ?? 0;
          } else {
            id = 0;
          }

          final bool isSimulator =
              (r['isSimulator'] is int && (r['isSimulator'] as int) == 1);

          final registration = (r['registration'] as String? ?? '').trim();
          final identifier = (r['identifier'] as String? ?? '').trim();
          final owner = (r['owner'] as String? ?? '').trim();
          final countryName = (r['countryName'] as String? ?? '').trim();
          final countryFlag = (r['countryFlag'] as String? ?? '').trim();

          // Títulos guardados (ej: "Monomotor|Militar")
          final typeTitleRaw = (r['typeTitle'] as String? ?? '').trim();
          final List<String> typeTitles = typeTitleRaw
              .split('|')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          // Código principal (ej: "SE")
          final String primaryCode =
              (r['typeCode'] as String? ?? '').trim().toUpperCase();

          // Ids de tipo (ej: "1,8")
          final String typeIdsRaw = (r['typeIds'] as String? ?? '').trim();
          final Set<String> codesSet = <String>{};

          if (typeIdsRaw.isNotEmpty) {
            for (final part in typeIdsRaw.split(',')) {
              final idParsed = int.tryParse(part.trim());
              if (idParsed != null && idToCode.containsKey(idParsed)) {
                codesSet.add(idToCode[idParsed]!);
              }
            }
          }
          if (primaryCode.isNotEmpty) {
            codesSet.add(primaryCode);
          }

          // Construimos lista de códigos alineada con los títulos
          // índice 0 -> primaryCode, el resto -> códigos restantes (orden da igual)
          List<String> typeCodes = <String>[];
          if (typeTitles.isNotEmpty) {
            typeCodes =
                List<String>.filled(typeTitles.length, '', growable: false);

            final Set<String> remaining = {...codesSet};
            if (primaryCode.isNotEmpty) {
              typeCodes[0] = primaryCode;
              remaining.remove(primaryCode);
            }

            final List<String> remainingList = remaining.toList();
            int idx = 0;
            for (int i = 1; i < typeCodes.length; i++) {
              if (idx < remainingList.length) {
                typeCodes[i] = remainingList[idx++];
              }
            }
          }

          final makeModelAircraft = (r['makeModel'] as String? ?? '').trim();
          final simCompany = (r['simCompany'] as String? ?? '').trim();
          final simModel = (r['simAircraftModel'] as String? ?? '').trim();
          final simLevel = (r['simLevel'] as String? ?? '').trim();

          // Para la ficha:
          // - aeronave: usa makeModel
          // - simulador: usa simAircraftModel
          final makeModel = isSimulator ? simModel : makeModelAircraft;

          final tagsStr = (r['tags'] as String? ?? '').trim();
          final tags = tagsStr.isEmpty
              ? <String>[]
              : tagsStr
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

          String label;
          if (!isSimulator) {
            if (registration.isNotEmpty) {
              label = registration;
            } else if (typeTitles.isNotEmpty) {
              label = typeTitles.first;
            } else {
              label = 'Aircraft';
            }
          } else {
            if (simCompany.isNotEmpty && simModel.isNotEmpty) {
              label = '$simCompany – $simModel';
            } else if (simCompany.isNotEmpty) {
              label = simCompany;
            } else if (simModel.isNotEmpty) {
              label = simModel;
            } else {
              label = 'Simulator';
            }
          }

          final subtitle = isSimulator
              ? (typeTitles.isNotEmpty ? typeTitles.join(' | ') : 'Simulator')
              : (typeTitles.isNotEmpty ? typeTitles.join(' | ') : '');

          return <String, dynamic>{
            'id': id,
            'isSimulator': isSimulator,
            'label': label,
            'subtitle': subtitle,
            'countryFlag': countryFlag,
            'registration': registration,
            'identifier': identifier,
            'owner': owner,
            'countryName': countryName,
            'typeLabel': subtitle, // sigue existiendo por compatibilidad
            'typeTitles': typeTitles, // NUEVO
            'typeCodes': typeCodes, // NUEVO
            'makeAndModel': makeModel,
            'tags': tags,
            'simCompany': simCompany,
            'simModel': simModel,
            'simLevel': simLevel,
          };
        }));
      _loading = false;
    });
  }

  Future<void> _openAircraftFile({int? aircraftId}) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => Airplanes(aircraftId: aircraftId),
      ),
    );

    if (changed == true) {
      await _loadFromDb();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return BaseScaffold(
      appBar: CustomAppBar(
        title: t.t("aircraft_list_title"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.airplanemode_active,
                          size: 48,
                          color: AppColors.teal5,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.t("no_aircraft_yet"),
                          style: AppTextStyles.subtitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.t("tap_plus_to_add_aircraft"),
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      return _buildRow(context, item);
                    },
                  ),
      ),
      // AHORA SIEMPRE MOSTRAMOS EL BOTÓN "+", TAMBIÉN EN pickMode
      floatingActionButton: ButtonStyles.squareAddButton(
        context: context,
        onTap: () => _openAircraftFile(),
      ),
    );
  }

  Widget _buildRow(BuildContext context, Map<String, dynamic> item) {
    final int id = item['id'] as int;
    final bool isSimulator = item['isSimulator'] as bool? ?? false;

    final String registration = item['registration'] as String? ?? '';
    final String identifier = item['identifier'] as String? ?? '';
    final String owner = item['owner'] as String? ?? '';
    final String countryName = item['countryName'] as String? ?? '';
    final String countryFlag = item['countryFlag'] as String? ?? '';
    final String typeLabel = item['typeLabel'] as String? ?? '';
    final String makeAndModel = item['makeAndModel'] as String? ?? '';
    final List<String> tags =
        (item['tags'] as List?)?.cast<String>() ?? const <String>[];

    final String simulatorCompany = item['simCompany'] as String? ?? '';
    final String simulatorLevel = item['simLevel'] as String? ?? '';

    final List<String> typeTitles =
        (item['typeTitles'] as List?)?.cast<String>() ?? const <String>[];
    final List<String> typeCodes =
        (item['typeCodes'] as List?)?.cast<String>() ?? const <String>[];

    return ButtonStyles.aircraftButton(
      context: context,
      onTap: widget.pickMode
          ? () => Navigator.pop<int>(context, id)
          : () => _openAircraftFile(aircraftId: id),
      registration: registration,
      identifier: identifier,
      countryName: countryName,
      countryFlagEmoji: countryFlag,
      typeLabel: typeLabel,
      makeAndModel: makeAndModel,
      tags: tags,
      isSimulator: isSimulator,
      owner: owner,
      simulatorCompany: simulatorCompany,
      simulatorLevel: simulatorLevel,
      // NUEVO: pasamos info de tipos al botón
      typeTitles: typeTitles,
      typeCodes: typeCodes,
    );
  }
}
