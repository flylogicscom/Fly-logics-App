// lib/common/pop_layer_crew.dart

import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';

/// Result of selecting a crew role from the popup.
class CrewRoleSelection {
  /// Short code (COM, PIC, SIC, SPIC, PICUS, INS, STU, OTHR or custom tag).
  final String code;

  /// Human-readable name (Commander, Pilot in Command, etc.).
  final String name;

  /// Short description of the role.
  final String description;

  /// True if this role comes from the "Other" custom option.
  final bool isCustom;

  /// Optional notes for custom roles (or extra info).
  final String? notes;

  const CrewRoleSelection({
    required this.code,
    required this.name,
    required this.description,
    this.isCustom = false,
    this.notes,
  });
}

enum _CrewRoleKind {
  com,
  pic,
  sic,
  spic,
  picus,
  ins,
  stu,
  other,
}

/// Shows the "Pilot in Command & Crew" popup and returns the selected role.
/// Returns `null` if the user closes the popup without selecting anything.
Future<CrewRoleSelection?> showCrewRolePopup(BuildContext context) async {
  final l = AppLocalizations.of(context);

  // Solo claves de traducción
  final titlePopup = l.t("pilot_in_command_crew");

  final comName = l.t("crew_role_com_name");
  final comDesc = l.t("crew_role_com_desc");

  final picName = l.t("crew_role_pic_name");
  final picDesc = l.t("crew_role_pic_desc");

  final sicName = l.t("crew_role_sic_name");
  final sicDesc = l.t("crew_role_sic_desc");

  final spicName = l.t("crew_role_spic_name");
  final spicDesc = l.t("crew_role_spic_desc");

  final picusName = l.t("crew_role_picus_name");
  final picusDesc = l.t("crew_role_picus_desc");

  final insName = l.t("crew_role_ins_name");
  final insDesc = l.t("crew_role_ins_desc");

  final stuName = l.t("crew_role_stu_name");
  final stuDesc = l.t("crew_role_stu_desc");

  final otherName = l.t("crew_role_other_name");
  final otherDesc = l.t("crew_role_other_desc");

  final _CrewRoleKind? kind = await showDialog<_CrewRoleKind>(
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
            gradient: const LinearGradient(
              colors: [AppColors.teal1, AppColors.teal2],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Text(
                  titlePopup,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const Divider(
                thickness: 0.5,
                height: 8,
                color: Colors.white24,
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRoleTile(
                      context: ctx,
                      kind: _CrewRoleKind.com,
                      code: 'COM',
                      title: comName,
                      description: comDesc,
                      color: const Color(0xFF024755),
                    ),
                    _thinDivider(),
                    _buildRoleTile(
                      context: ctx,
                      kind: _CrewRoleKind.pic,
                      code: 'PIC',
                      title: picName,
                      description: picDesc,
                      color: const Color(0xFF125864),
                    ),
                    _thinDivider(),
                    _buildRoleTile(
                      context: ctx,
                      kind: _CrewRoleKind.sic,
                      code: 'SIC',
                      title: sicName,
                      description: sicDesc,
                      color: const Color(0xFF216873),
                    ),
                    _thinDivider(),
                    _buildRoleTile(
                      context: ctx,
                      kind: _CrewRoleKind.spic,
                      code: 'SPIC',
                      title: spicName,
                      description: spicDesc,
                      color: const Color(0xFF337983),
                    ),
                    _thinDivider(),
                    _buildRoleTile(
                      context: ctx,
                      kind: _CrewRoleKind.picus,
                      code: 'PICUS',
                      title: picusName,
                      description: picusDesc,
                      color: const Color(0xFF418991),
                    ),
                    _thinDivider(),
                    _buildRoleTile(
                      context: ctx,
                      kind: _CrewRoleKind.ins,
                      code: 'INS',
                      title: insName,
                      description: insDesc,
                      color: const Color(0xFF519AA0),
                    ),
                    _thinDivider(),
                    _buildRoleTile(
                      context: ctx,
                      kind: _CrewRoleKind.stu,
                      code: 'STU',
                      title: stuName,
                      description: stuDesc,
                      color: const Color(0xFF61AAAF),
                    ),
                    _thinDivider(),
                    _buildRoleTile(
                      context: ctx,
                      kind: _CrewRoleKind.other,
                      code: 'OTHR',
                      title: otherName,
                      description: otherDesc,
                      color: const Color(0xFF72BBBF),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (kind == null) return null;

  if (kind == _CrewRoleKind.other) {
    return _showCustomCrewRolePopup(context);
  }

  return _standardSelectionForKind(context, kind);
}

// ---------- Helpers ----------

CrewRoleSelection _standardSelectionForKind(
  BuildContext context,
  _CrewRoleKind kind,
) {
  final l = AppLocalizations.of(context);

  switch (kind) {
    case _CrewRoleKind.com:
      return CrewRoleSelection(
        code: 'COM',
        name: l.t("crew_role_com_name"),
        description: l.t("crew_role_com_desc"),
      );
    case _CrewRoleKind.pic:
      return CrewRoleSelection(
        code: 'PIC',
        name: l.t("crew_role_pic_name"),
        description: l.t("crew_role_pic_desc"),
      );
    case _CrewRoleKind.sic:
      return CrewRoleSelection(
        code: 'SIC',
        name: l.t("crew_role_sic_name"),
        description: l.t("crew_role_sic_desc"),
      );
    case _CrewRoleKind.spic:
      return CrewRoleSelection(
        code: 'SPIC',
        name: l.t("crew_role_spic_name"),
        description: l.t("crew_role_spic_desc"),
      );
    case _CrewRoleKind.picus:
      return CrewRoleSelection(
        code: 'PICUS',
        name: l.t("crew_role_picus_name"),
        description: l.t("crew_role_picus_desc"),
      );
    case _CrewRoleKind.ins:
      return CrewRoleSelection(
        code: 'INS',
        name: l.t("crew_role_ins_name"),
        description: l.t("crew_role_ins_desc"),
      );
    case _CrewRoleKind.stu:
      return CrewRoleSelection(
        code: 'STU',
        name: l.t("crew_role_stu_name"),
        description: l.t("crew_role_stu_desc"),
      );
    case _CrewRoleKind.other:
      return CrewRoleSelection(
        code: 'OTHR',
        name: l.t("crew_role_other_name"),
        description: l.t("crew_role_other_desc"),
      );
  }
}

Widget _thinDivider() {
  return const Divider(
    thickness: 0.5,
    height: 8,
    color: Colors.white24,
  );
}

/// Popup for custom "OTHER" crew member: tag, name, notes.
Future<CrewRoleSelection?> _showCustomCrewRolePopup(
  BuildContext context,
) async {
  final l = AppLocalizations.of(context);

  final title = l.t("other_crew_member_title");
  final tagLabel = l.t("crew_tag_label");
  final tagHint = l.t("crew_tag_hint");
  final roleNameLabel = l.t("crew_role_name_label");
  final roleNameHint = l.t("crew_role_name_hint");
  final notesLabel = l.t("crew_notes_label");
  final notesHint = l.t("crew_notes_hint");
  final cancelText = l.t("cancel");
  final saveText = l.t("save");
  final otherName = l.t("crew_role_other_name");
  final otherDesc = l.t("crew_role_other_desc");

  final tagCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  final CrewRoleSelection? selection = await showDialog<CrewRoleSelection>(
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
            gradient: const LinearGradient(
              colors: [AppColors.teal1, AppColors.teal3],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: tagLabel,
                    hintText: tagHint,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: roleNameLabel,
                    hintText: roleNameHint,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: notesLabel,
                    hintText: notesHint,
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
                        final code = tagCtrl.text.trim().isEmpty
                            ? 'OTHR'
                            : tagCtrl.text.trim();
                        final name = nameCtrl.text.trim().isEmpty
                            ? otherName
                            : nameCtrl.text.trim();
                        final notes = notesCtrl.text.trim();

                        Navigator.of(ctx).pop(
                          CrewRoleSelection(
                            code: code,
                            name: name,
                            description: notes.isEmpty ? otherDesc : notes,
                            isCustom: true,
                            notes: notes.isEmpty ? null : notes,
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

  // No dispose() para evitar errores con TextEditingController.
  return selection;
}

/// A role row with left pill and text on the right.
Widget _buildRoleTile({
  required BuildContext context,
  required _CrewRoleKind kind,
  required String code,
  required String title,
  required String description,
  required Color color,
}) {
  const titleColor = Colors.white;
  // ignore: deprecated_member_use
  final subtitleColor = Colors.white.withOpacity(0.85);

  return InkWell(
    onTap: () {
      Navigator.of(context).pop(kind);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left label: rectangle, rounded corners, white border, soft shadow
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 3.5,
            ),
            decoration: BoxDecoration(
              color: color,
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
              code,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 0),
                Text(
                  description,
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
