// lib/common/pop_aircraft_type.dart

import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

/// Resultado de seleccionar uno o varios tipos de aeronave / simulador
/// desde el popup.
class AircraftTypeSelection {
  /// Código principal (por ejemplo: SE, ME, TP, TJ, LSA, HELI, GLID, OTHER, SIM).
  final String code;

  /// Título visible principal.
  final String title;

  /// Códigos adicionales seleccionados (sin incluir [code]).
  /// Solo se usa si el usuario seleccionó más de un tipo.
  final List<String> extraCodes;

  /// Títulos adicionales seleccionados (sin incluir [title]).
  final List<String> extraTitles;

  /// Indica si la selección principal es un "Otro" personalizado.
  final bool isCustom;

  /// Descripción asociada (para "Otro" personalizado).
  final String? description;

  /// Notas adicionales (para "Otro" personalizado).
  final String? notes;

  const AircraftTypeSelection({
    required this.code,
    required this.title,
    this.extraCodes = const [],
    this.extraTitles = const [],
    this.isCustom = false,
    this.description,
    this.notes,
  });

  /// Todos los códigos (principal + adicionales).
  List<String> get allCodes =>
      [code, ...extraCodes.where((c) => c.trim().isNotEmpty)];

  /// Todos los títulos (principal + adicionales).
  List<String> get allTitles =>
      [title, ...extraTitles.where((t) => t.trim().isNotEmpty)];
}

enum _AircraftTypeKind {
  singleEngine,
  multiEngine,
  turboprop,
  turbojet,
  lsa,
  helicopter,
  glider,
  other,
  simulator,
}

/// Datos internos para "Otro" personalizado.
class _CustomAircraftOtherData {
  final String label;
  final String description;
  final String? notes;

  const _CustomAircraftOtherData({
    required this.label,
    required this.description,
    this.notes,
  });
}

// ================== CONFIG GLOBAL PARA "OTRO" ==================

const String _aircraftOtherConfigTable = 'aircraft_other_config';

Future<_CustomAircraftOtherData?> _loadGlobalOtherConfig() async {
  final db = await DBHelper.getDB();

  await db.execute('''
    CREATE TABLE IF NOT EXISTS $_aircraftOtherConfigTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      label TEXT,
      description TEXT,
      notes TEXT
    )
  ''');

  final rows = await db.query(
    _aircraftOtherConfigTable,
    orderBy: 'id DESC',
    limit: 1,
  );

  if (rows.isEmpty) return null;

  final r = rows.first;
  final label = (r['label'] as String? ?? '').trim();
  final description = (r['description'] as String? ?? '').trim();
  final notesRaw = (r['notes'] as String? ?? '').trim();

  return _CustomAircraftOtherData(
    label: label,
    description: description,
    notes: notesRaw.isEmpty ? null : notesRaw,
  );
}

Future<void> _saveGlobalOtherConfig(_CustomAircraftOtherData data) async {
  final db = await DBHelper.getDB();

  await db.insert(
    _aircraftOtherConfigTable,
    {
      'label': data.label,
      'description': data.description,
      'notes': data.notes,
    },
  );
}

/// Mapa de incompatibilidades entre tipos.
/// Es simétrico: si A es incompatible con B, B también lo es con A.
const Map<_AircraftTypeKind, Set<_AircraftTypeKind>> _incompatibleTypeMap = {
  _AircraftTypeKind.singleEngine: {
    _AircraftTypeKind.multiEngine,
    _AircraftTypeKind.helicopter,
    _AircraftTypeKind.glider,
  },
  _AircraftTypeKind.multiEngine: {
    _AircraftTypeKind.singleEngine,
    _AircraftTypeKind.glider,
  },
  _AircraftTypeKind.turboprop: {
    _AircraftTypeKind.glider,
  },
  _AircraftTypeKind.turbojet: {
    _AircraftTypeKind.glider,
  },
  _AircraftTypeKind.lsa: {
    _AircraftTypeKind.glider,
  },
  _AircraftTypeKind.helicopter: {
    _AircraftTypeKind.singleEngine,
    _AircraftTypeKind.multiEngine,
    _AircraftTypeKind.turboprop,
    _AircraftTypeKind.turbojet,
    _AircraftTypeKind.lsa,
    _AircraftTypeKind.glider,
  },
  _AircraftTypeKind.glider: {
    _AircraftTypeKind.singleEngine,
    _AircraftTypeKind.multiEngine,
    _AircraftTypeKind.turboprop,
    _AircraftTypeKind.turbojet,
    _AircraftTypeKind.lsa,
    _AircraftTypeKind.helicopter,
  },
  // "Otro" ahora es compatible con todos los tipos
  _AircraftTypeKind.other: {},
  // Simulador sin restricciones especiales.
  _AircraftTypeKind.simulator: {},
};

bool _isKindDisabled(
  _AircraftTypeKind kind,
  Set<_AircraftTypeKind> selectedKinds,
) {
  if (selectedKinds.isEmpty) return false;
  if (selectedKinds.contains(kind)) return false;

  for (final selected in selectedKinds) {
    final incompatible = _incompatibleTypeMap[selected];
    if (incompatible != null && incompatible.contains(kind)) {
      return true;
    }
  }
  return false;
}

/// Popup de selección de tipo de aeronave / simulador.
Future<AircraftTypeSelection?> showAircraftTypePopup(
  BuildContext context,
) async {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final l = AppLocalizations.of(context);

  final popupTitle = l.t("aircraft_type_popup_title");

  final singleTitle = l.t("aircraft_type_single_title");
  final singleDesc = l.t("aircraft_type_single_desc");

  final multiTitle = l.t("aircraft_type_multi_title");
  final multiDesc = l.t("aircraft_type_multi_desc");

  final turbopropTitle = l.t("aircraft_type_turboprop_title");
  final turbopropDesc = l.t("aircraft_type_turboprop_desc");

  final turbojetTitle = l.t("aircraft_type_turbojet_title");
  final turbojetDesc = l.t("aircraft_type_turbojet_desc");

  final lsaTitle = l.t("aircraft_type_lsa_title");
  final lsaDesc = l.t("aircraft_type_lsa_desc");

  final heliTitle = l.t("aircraft_type_helicopter_title");
  final heliDesc = l.t("aircraft_type_helicopter_desc");

  final gliderTitle = l.t("aircraft_type_glider_title");
  final gliderDesc = l.t("aircraft_type_glider_desc");

  final defaultOtherTitle = l.t("aircraft_type_other_title");
  final defaultOtherDesc = l.t("aircraft_type_other_desc");

  final simTitle = l.t("aircraft_type_simulator_title");
  final simDesc = l.t("aircraft_type_simulator_desc");

  final acceptText = l.t("accept");

  // Aviso para editar OTRO
  final otherEditWarningTitle = l.t("aircraft_type_other_edit_warning_title");
  final otherEditWarningBody = l.t("aircraft_type_other_edit_warning_body");
  final otherEditWarningConfirm =
      l.t("aircraft_type_other_edit_warning_confirm");
  final otherEditWarningCancel = l.t("cancel");

  // Config global de OTRO
  _CustomAircraftOtherData? otherCustomData =
      await _loadGlobalOtherConfig(); // puede ser null

  final selectedKinds = <_AircraftTypeKind>{};

  String codeFor(_AircraftTypeKind kind) {
    switch (kind) {
      case _AircraftTypeKind.singleEngine:
        return 'SE';
      case _AircraftTypeKind.multiEngine:
        return 'ME';
      case _AircraftTypeKind.turboprop:
        return 'TP';
      case _AircraftTypeKind.turbojet:
        return 'TJ';
      case _AircraftTypeKind.lsa:
        return 'LSA';
      case _AircraftTypeKind.helicopter:
        return 'HELI';
      case _AircraftTypeKind.glider:
        return 'GLID';
      case _AircraftTypeKind.other:
        return 'OTHER';
      case _AircraftTypeKind.simulator:
        return 'SIM';
    }
  }

  String titleFor(_AircraftTypeKind kind) {
    switch (kind) {
      case _AircraftTypeKind.singleEngine:
        return singleTitle;
      case _AircraftTypeKind.multiEngine:
        return multiTitle;
      case _AircraftTypeKind.turboprop:
        return turbopropTitle;
      case _AircraftTypeKind.turbojet:
        return turbojetTitle;
      case _AircraftTypeKind.lsa:
        return lsaTitle;
      case _AircraftTypeKind.helicopter:
        return heliTitle;
      case _AircraftTypeKind.glider:
        return gliderTitle;
      case _AircraftTypeKind.other:
        if (otherCustomData != null &&
            otherCustomData!.label.trim().isNotEmpty) {
          return otherCustomData!.label.trim();
        }
        return defaultOtherTitle;
      case _AircraftTypeKind.simulator:
        return simTitle;
    }
  }

  final Set<_AircraftTypeKind>? resultKinds =
      await showDialog<Set<_AircraftTypeKind>>(
    context: context,
    builder: (dialogCtx) {
      final maxHeight = MediaQuery.of(dialogCtx).size.height * 0.8;

      return AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: StatefulBuilder(
            builder: (ctx, setSB) {
              Future<void> handleTap(_AircraftTypeKind kind) async {
                if (_isKindDisabled(kind, selectedKinds) &&
                    !selectedKinds.contains(kind)) {
                  return;
                }

                if (kind == _AircraftTypeKind.other) {
                  // Si NO hay config global todavía -> crearla (primer uso)
                  if (otherCustomData == null) {
                    final custom = await _showCustomAircraftOtherPopup(
                      context,
                      initial: null,
                    );
                    if (custom == null) return;

                    await _saveGlobalOtherConfig(custom);

                    setSB(() {
                      otherCustomData = custom;
                      selectedKinds.add(kind);
                    });
                  } else {
                    // Ya existe config global: solo toggle de selección
                    setSB(() {
                      if (selectedKinds.contains(kind)) {
                        selectedKinds.remove(kind);
                      } else {
                        selectedKinds.add(kind);
                      }
                    });
                  }
                  return;
                }

                setSB(() {
                  if (selectedKinds.contains(kind)) {
                    selectedKinds.remove(kind);
                  } else {
                    selectedKinds.add(kind);
                  }
                });
              }

              Future<void> handleLongPressOther() async {
                // Solo tiene sentido si ya hay configuración creada
                if (otherCustomData == null) {
                  // Si no hay config, nos comportamos como primer uso:
                  final custom = await _showCustomAircraftOtherPopup(
                    context,
                    initial: null,
                  );
                  if (custom == null) return;
                  await _saveGlobalOtherConfig(custom);
                  setSB(() {
                    otherCustomData = custom;
                    selectedKinds.add(_AircraftTypeKind.other);
                  });
                  return;
                }

                final bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (warnCtx) {
                    return AlertDialog(
                      title: Text(otherEditWarningTitle),
                      content: Text(otherEditWarningBody),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(warnCtx).pop(false),
                          child: Text(otherEditWarningCancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(warnCtx).pop(true),
                          child: Text(otherEditWarningConfirm),
                        ),
                      ],
                    );
                  },
                );

                if (confirm != true) return;

                final custom = await _showCustomAircraftOtherPopup(
                  context,
                  initial: otherCustomData,
                );
                if (custom == null) return;

                await _saveGlobalOtherConfig(custom);

                setSB(() {
                  otherCustomData = custom;
                  // No tocamos selectedKinds aquí: solo se edita el texto.
                });
              }

              return Container(
                width: 380,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: isDark
                      ? LinearGradient(
                          colors: [AppColors.teal1, AppColors.teal2],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  // ignore: deprecated_member_use
                  color: isDark ? null : theme.dialogBackgroundColor,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 15, 15, 8),
                      child: Text(
                        popupTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                    ),
                    Divider(
                      thickness: 0.5,
                      height: 8,
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () =>
                                  handleTap(_AircraftTypeKind.singleEngine),
                              child: _buildAircraftTile(
                                title: singleTitle,
                                description: singleDesc,
                                color: AppColors.se,
                                isDark: isDark,
                                selected: selectedKinds.contains(
                                  _AircraftTypeKind.singleEngine,
                                ),
                                disabled: _isKindDisabled(
                                  _AircraftTypeKind.singleEngine,
                                  selectedKinds,
                                ),
                              ),
                            ),
                            _thinDivider(isDark),
                            InkWell(
                              onTap: () =>
                                  handleTap(_AircraftTypeKind.multiEngine),
                              child: _buildAircraftTile(
                                title: multiTitle,
                                description: multiDesc,
                                color: AppColors.me,
                                isDark: isDark,
                                selected: selectedKinds.contains(
                                  _AircraftTypeKind.multiEngine,
                                ),
                                disabled: _isKindDisabled(
                                  _AircraftTypeKind.multiEngine,
                                  selectedKinds,
                                ),
                              ),
                            ),
                            _thinDivider(isDark),
                            InkWell(
                              onTap: () =>
                                  handleTap(_AircraftTypeKind.turboprop),
                              child: _buildAircraftTile(
                                title: turbopropTitle,
                                description: turbopropDesc,
                                color: AppColors.tp,
                                isDark: isDark,
                                selected: selectedKinds.contains(
                                  _AircraftTypeKind.turboprop,
                                ),
                                disabled: _isKindDisabled(
                                  _AircraftTypeKind.turboprop,
                                  selectedKinds,
                                ),
                              ),
                            ),
                            _thinDivider(isDark),
                            InkWell(
                              onTap: () =>
                                  handleTap(_AircraftTypeKind.turbojet),
                              child: _buildAircraftTile(
                                title: turbojetTitle,
                                description: turbojetDesc,
                                color: AppColors.tj,
                                isDark: isDark,
                                selected: selectedKinds.contains(
                                  _AircraftTypeKind.turbojet,
                                ),
                                disabled: _isKindDisabled(
                                  _AircraftTypeKind.turbojet,
                                  selectedKinds,
                                ),
                              ),
                            ),
                            _thinDivider(isDark),
                            InkWell(
                              onTap: () => handleTap(_AircraftTypeKind.lsa),
                              child: _buildAircraftTile(
                                title: lsaTitle,
                                description: lsaDesc,
                                color: AppColors.lsa,
                                isDark: isDark,
                                selected: selectedKinds.contains(
                                  _AircraftTypeKind.lsa,
                                ),
                                disabled: _isKindDisabled(
                                  _AircraftTypeKind.lsa,
                                  selectedKinds,
                                ),
                              ),
                            ),
                            _thinDivider(isDark),
                            InkWell(
                              onTap: () =>
                                  handleTap(_AircraftTypeKind.helicopter),
                              child: _buildAircraftTile(
                                title: heliTitle,
                                description: heliDesc,
                                color: AppColors.he,
                                isDark: isDark,
                                selected: selectedKinds.contains(
                                  _AircraftTypeKind.helicopter,
                                ),
                                disabled: _isKindDisabled(
                                  _AircraftTypeKind.helicopter,
                                  selectedKinds,
                                ),
                              ),
                            ),
                            _thinDivider(isDark),
                            InkWell(
                              onTap: () => handleTap(_AircraftTypeKind.glider),
                              child: _buildAircraftTile(
                                title: gliderTitle,
                                description: gliderDesc,
                                color: AppColors.pl,
                                isDark: isDark,
                                selected: selectedKinds.contains(
                                  _AircraftTypeKind.glider,
                                ),
                                disabled: _isKindDisabled(
                                  _AircraftTypeKind.glider,
                                  selectedKinds,
                                ),
                              ),
                            ),
                            _thinDivider(isDark),
                            InkWell(
                              onTap: () => handleTap(_AircraftTypeKind.other),
                              onLongPress: handleLongPressOther,
                              child: _buildAircraftTile(
                                title: titleFor(_AircraftTypeKind.other),
                                description: (otherCustomData != null &&
                                        otherCustomData!.description.isNotEmpty)
                                    ? otherCustomData!.description
                                    : defaultOtherDesc,
                                color: AppColors.ot,
                                isDark: isDark,
                                selected: selectedKinds.contains(
                                  _AircraftTypeKind.other,
                                ),
                                disabled: _isKindDisabled(
                                  _AircraftTypeKind.other,
                                  selectedKinds,
                                ),
                              ),
                            ),
                            _thinDivider(isDark),
                            InkWell(
                              onTap: () =>
                                  handleTap(_AircraftTypeKind.simulator),
                              child: _buildAircraftTile(
                                title: simTitle,
                                description: simDesc,
                                color: AppColors.sim,
                                isDark: isDark,
                                selected: selectedKinds.contains(
                                  _AircraftTypeKind.simulator,
                                ),
                                disabled: _isKindDisabled(
                                  _AircraftTypeKind.simulator,
                                  selectedKinds,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Center(
                        child: ElevatedButton(
                          onPressed: selectedKinds.isEmpty
                              ? null
                              : () {
                                  Navigator.of(dialogCtx).pop(
                                    Set<_AircraftTypeKind>.from(
                                      selectedKinds,
                                    ),
                                  );
                                },
                          child: Text(acceptText),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );

  if (resultKinds == null || resultKinds.isEmpty) {
    return null;
  }

  final orderedKinds = resultKinds.toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  final allCodes = <String>[];
  final allTitles = <String>[];

  for (final kind in orderedKinds) {
    final code = codeFor(kind);
    String title;
    if (kind == _AircraftTypeKind.other &&
        otherCustomData != null &&
        otherCustomData!.label.trim().isNotEmpty) {
      title = otherCustomData!.label.trim();
    } else {
      title = titleFor(kind);
    }
    allCodes.add(code);
    allTitles.add(title);
  }

  final primaryCode = allCodes.first;
  final primaryTitle = allTitles.first;
  final extraCodes =
      allCodes.length > 1 ? allCodes.sublist(1) : const <String>[];
  final extraTitles =
      allTitles.length > 1 ? allTitles.sublist(1) : const <String>[];

  return AircraftTypeSelection(
    code: primaryCode,
    title: primaryTitle,
    extraCodes: extraCodes,
    extraTitles: extraTitles,
    isCustom: orderedKinds.first == _AircraftTypeKind.other &&
        otherCustomData != null,
    description: otherCustomData?.description,
    notes: otherCustomData?.notes,
  );
}

// ---------- Helpers ----------

Widget _thinDivider(bool isDark) {
  return Divider(
    thickness: 0.5,
    height: 8,
    color: isDark ? Colors.white24 : Colors.black12,
  );
}

Widget _buildAircraftTile({
  required String title,
  required String description,
  required Color color,
  required bool isDark,
  required bool selected,
  required bool disabled,
}) {
  final opacity = disabled ? 0.35 : 1.0;
  final effectiveColor = disabled ? color.withOpacity(0.35) : color;
  final borderColor = selected ? Colors.white : Colors.white.withOpacity(0.8);
  final boxShadowColor = Colors.black.withOpacity(disabled ? 0.05 : 0.15);
  final descColor = isDark ? Colors.white : Colors.black87;

  return Opacity(
    opacity: opacity,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9.0,
              vertical: 6.0,
            ),
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: boxShadowColor,
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: descColor,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: isDark ? Colors.white : color,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Popup para "OTRO" personalizado
Future<_CustomAircraftOtherData?> _showCustomAircraftOtherPopup(
  BuildContext context, {
  _CustomAircraftOtherData? initial,
}) async {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final l = AppLocalizations.of(context);

  final title = l.t("aircraft_type_other_custom_title");
  final labelText = l.t("aircraft_type_other_label");
  final labelHint = l.t("aircraft_type_other_label_hint");
  final descText = l.t("aircraft_type_other_description");
  final notesText = l.t("aircraft_type_other_notes");
  final cancelText = l.t("cancel");
  final saveText = l.t("save");
  final defaultLabel = l.t("aircraft_type_other_title");
  final defaultDesc = l.t("aircraft_type_other_desc");

  final labelCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  if (initial != null) {
    labelCtrl.text = initial.label;
    descCtrl.text = initial.description;
    notesCtrl.text = initial.notes ?? '';
  }

  final _CustomAircraftOtherData? selection =
      await showDialog<_CustomAircraftOtherData>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        content: Container(
          width: 360,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isDark
                ? LinearGradient(
                    colors: [AppColors.teal1, AppColors.teal3],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            // ignore: deprecated_member_use
            color: isDark ? null : theme.dialogBackgroundColor,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: isDark ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: labelText,
                    hintText: labelHint,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: descText,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: notesText,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop(null);
                      },
                      child: Text(cancelText),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final rawLabel = labelCtrl.text.trim();
                        final rawDesc = descCtrl.text.trim();
                        final rawNotes = notesCtrl.text.trim();

                        final label =
                            rawLabel.isEmpty ? defaultLabel : rawLabel;
                        final desc = rawDesc.isEmpty ? defaultDesc : rawDesc;
                        final notes = rawNotes.isEmpty ? null : rawNotes;

                        Navigator.of(ctx).pop(
                          _CustomAircraftOtherData(
                            label: label,
                            description: desc,
                            notes: notes,
                          ),
                        );
                      },
                      child: Text(saveText),
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

  return selection;
}
