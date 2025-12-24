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

          return {
            'id': id,
            'firstName': first,
            'lastName': last,
            // Etiqueta del botón: Nombre + Apellido
            'fullName': full.isEmpty ? 'Crew Member' : full,
          };
        }));
      _loading = false;
    });
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
    final String label =
        member['fullName'] as String? ?? 'Crew Member'; // Nombre + Apellido
    final int id = member['id'] as int;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // BOTÓN PRINCIPAL
          ButtonStyles.infoButtonOne(
            context: context,
            label: label,
            onTap: widget.pickMode
                ? () {
                    // Modo selección: devolvemos el miembro
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context, member);
                    }
                  }
                : () => _openCrewFile(crewId: id),
            leftIconAsset: 'assets/icons/crew.svg',
            locked: false,
          ),

          // Icono erase dentro del botón (solo en modo normal)
          if (!widget.pickMode)
            Positioned(
              right: 80,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _confirmDeleteCrew(context, id, index),
                  child: SvgPicture.asset(
                    'assets/icons/erase.svg',
                    height: 18,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
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
      title: l.t("delete_crew_member"),
      children: [
        Text(
          l.t("are_you_sure_you_want_to_delete_this_crew_member"),
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
