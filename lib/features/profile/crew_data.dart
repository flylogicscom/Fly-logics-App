//lib\features\profile\crew_data.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/popwindow.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

// Página de detalle / edición de Crew
import 'package:fly_logicd_logbook_app/features/profile/crew_datafile.dart';

class CrewData extends StatefulWidget {
  /// pickMode = true -> al tocar un miembro se devuelve ese miembro (Map).
  final bool pickMode;

  const CrewData({super.key, this.pickMode = false});

  @override
  State<CrewData> createState() => _CrewDataState();
}

class _CrewDataState extends State<CrewData> {
  final List<Map<String, dynamic>> _crew = [];
  bool _loading = true;

  static const String _crewTable = 'crew_members';

  @override
  void initState() {
    super.initState();
    _loadCrewFromDb();
  }

  // ================== DB HELPERS ==================

  Future<void> _ensureCrewTableExists() async {
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
  }

  Future<void> _loadCrewFromDb() async {
    final db = await DBHelper.getDB();
    await _ensureCrewTableExists();

    final rows = await db.query(
      _crewTable,
      orderBy: 'createdAt DESC',
    );

    setState(() {
      _crew
        ..clear()
        ..addAll(rows.map((r) {
          final int id = (r['id'] as int?) ?? 0;
          final String first = (r['firstName'] as String? ?? '').trim();
          final String last = (r['lastName'] as String? ?? '').trim();
          final String full = ('$first $last').trim();

          final String rank = (r['rank'] as String? ?? '').trim();
          final String roleCode = _roleCodeFromRank(rank) ?? '';

          return {
            'id': id,
            'firstName': first,
            'lastName': last,
            'rank': rank,
            'roleCode': roleCode,
            'fullName': full.isEmpty ? 'Crew Member' : full,
          };
        }));
      _loading = false;
    });
  }

  String? _roleCodeFromRank(String rankRaw) {
    final raw = rankRaw.trim();
    if (raw.isEmpty) return null;
    final m = RegExp(r'^[A-Za-z]+').firstMatch(raw);
    final code = (m?.group(0) ?? '').toUpperCase();
    return code.isEmpty ? null : code;
  }

  Future<void> _deleteCrew(int id, int index) async {
    final db = await DBHelper.getDB();
    await _ensureCrewTableExists();

    await db.delete(
      _crewTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    setState(() {
      if (index >= 0 && index < _crew.length) {
        _crew.removeAt(index);
      } else {
        _crew.removeWhere((c) => c['id'] == id);
      }
    });
  }

  // ================== NAVEGACIÓN A crew_datafile.dart ==================

  // crewId == null -> nuevo crew
  // crewId != null -> editar crew existente
  Future<void> _openCrewFile({int? crewId}) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CrewDataFile(crewId: crewId),
      ),
    );

    if (changed == true) {
      await _loadCrewFromDb();
    }
  }

  // ================== UI PRINCIPAL ==================

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return BaseScaffold(
      appBar: CustomAppBar(
        title: t.t("crew"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _crew.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // LOGO DEL ESTADO VACÍO (color fijo estilo oscuro)
                        SvgPicture.asset(
                          'assets/icons/crew.svg',
                          height: 45,
                          colorFilter: const ColorFilter.mode(
                            AppColors.teal5,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.t("no_crew_members_yet"),
                          style: AppTextStyles.subtitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.t(
                            "tap_the_+_button_to_add_a_new_crew_member",
                          ),
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _crew.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final member = _crew[i];
                      return _buildCrewRow(context, member, i);
                    },
                  ),
      ),
      floatingActionButton: ButtonStyles.squareAddButton(
        context: context,
        // BOTÓN + -> crew_datafile.dart (nuevo crew)
        onTap: () => _openCrewFile(),
      ),
    );
  }

  // ================== FILA DE CREW ==================

  Widget _buildCrewRow(
    BuildContext context,
    Map<String, dynamic> member,
    int index,
  ) {
    final String baseName = member['fullName'] as String? ?? 'Crew Member';
    final String roleCode = (member['roleCode'] as String? ?? '').trim();
    final int id = member['id'] as int;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // BOTÓN PRINCIPAL (sin locked -> sin candado)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: (!widget.pickMode)
                ? () => _confirmDeleteCrew(context, id, index)
                : null,
            child: ButtonStyles.infoButtonOne(
              context: context,
              label: baseName,
              onTap: widget.pickMode
                  ? () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context, member);
                      }
                    }
                  : () => _openCrewFile(crewId: id),
              leftIconAsset: 'assets/icons/crew.svg',
            ),
          ),

          // PILL DEL ROL A LA DERECHA
          if (roleCode.isNotEmpty)
            Positioned(
              right: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.teal2,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.70),
                        width: 0.5,
                      ),
                    ),
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      roleCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ================== BORRADO ==================

  Future<void> _confirmDeleteCrew(
    BuildContext context,
    int id,
    int index,
  ) async {
    final l = AppLocalizations.of(context);

    await showPopWindow(
      context: context,
      // antes: delete_crew_member
      title: l.t("confirm_delete_title"),
      children: [
        Text(
          // antes: are_you_sure_you_want_to_delete_this_crew_member
          l.t("confirm_delete_message"),
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 16),
        ButtonStyles.pillCancelSave(
          onCancel: () => Navigator.pop(context),
          onSave: () async {
            Navigator.pop(context);
            await _deleteCrew(id, index);
          },
          cancelLabel: l.t("cancel"),
          saveLabel: l.t("delete"),
        ),
      ],
    );
  }
}
