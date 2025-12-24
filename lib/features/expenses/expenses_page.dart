// lib/features/expenses/expenses_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/popwindow.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

import 'add_expenses_page.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final List<Map<String, dynamic>> _sheets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSheetsFromDb();
  }

  // Carga hojas desde DB (usa los helpers/tables definidos en DBHelper)
  Future<void> _loadSheetsFromDb({Map<int, bool>? preserveEditable}) async {
    final db = await DBHelper.getDB();

    // Si la tabla no existe, lista vacía
    final exists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [DBHelper.tableExpenseSheets],
    );

    if (exists.isEmpty) {
      setState(() {
        _sheets.clear();
        _loading = false;
      });
      return;
    }

    final rows = await db.query(
      DBHelper.tableExpenseSheets,
      orderBy: 'createdAt DESC',
    );

    setState(() {
      _sheets
        ..clear()
        ..addAll(rows.map((r) {
          final id = (r['sheetId'] ?? r['id']) as int;
          final rawTitle = (r['title'] as String?)?.trim() ?? '';
          final prevEditable = preserveEditable?[id];

          return {
            'id': id,
            'title': rawTitle.isEmpty ? 'Expenses' : rawTitle,
            // editable solo en memoria
            'editable': prevEditable ?? true,
          };
        }));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return BaseScaffold(
      appBar: CustomAppBar(
        title: t.t("expenses"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _sheets.isEmpty
                // Mensaje solo + instrucción; sin botón central extra
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.t("No travel expenses yet"),
                          style: AppTextStyles.subtitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.t("Tap the + button to add a new expenses sheet"),
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _sheets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final sheet = _sheets[i];
                      return _buildSheetRow(context, sheet, i);
                    },
                  ),
      ),
      floatingActionButton: ButtonStyles.squareAddButton(
        context: context,
        onTap: _openNewSheetDialog,
      ),
    );
  }

  // ================== FILA HOJA ==================

  // Requisito:
  // - Mantener estilo original (infoButtonOne + lock).
  // - Icono erase.svg dentro del mismo botón.
  // - Visible siempre.
  // - Color blanco.
  // - Solo funciona (onTap) si la hoja es editable; si no, no hace nada.
  Widget _buildSheetRow(
    BuildContext context,
    Map<String, dynamic> sheet,
    int index,
  ) {
    final String title = sheet['title'] as String? ?? 'Expenses';
    final bool canEdit = (sheet['editable'] as bool?) ?? true;
    final int sheetId = sheet['id'] as int;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Botón base con su lock / unlock original
          ButtonStyles.infoButtonOne(
            context: context,
            label: title,
            onTap: () => _openSheet(sheet, index: index),
            locked: !canEdit,
            // Icono de viáticos definido desde la página
            leftIconAsset: 'assets/icons/viatic.svg',
          ),

          // Icono erase dentro del botón, cercano al lock (offset fijo razonable)
          Positioned(
            right: 80, // a la izquierda del lock que ya dibuja infoButtonOne
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: canEdit
                    ? () => _confirmDeleteSheet(context, sheetId, index)
                    : null, // bloqueado: visible pero sin acción
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

  // ================== NUEVA HOJA ==================

  Future<void> _openNewSheetDialog() async {
    final controller = TextEditingController();

    await showPopWindow(
      context: context,
      title: 'New Expenses Sheet',
      children: [
        TextFormField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Name',
          ),
          onFieldSubmitted: (_) {
            final v = controller.text.trim();
            Navigator.pop(context);
            _createAndOpen(v);
          },
        ),
        const SizedBox(height: 15),
        ButtonStyles.pillCancelSave(
          onCancel: () => Navigator.pop(context),
          onSave: () {
            final v = controller.text.trim();
            Navigator.pop(context);
            _createAndOpen(v);
          },
          cancelLabel: 'Cancel',
          saveLabel: 'Save',
        ),
      ],
    );
  }

  Future<void> _createAndOpen(String raw) async {
    final now = DateTime.now();
    final title = raw.trim().isEmpty ? 'New Expenses' : raw.trim();
    final id = now.millisecondsSinceEpoch;

    // Cabecera en DB (helper definido en DBHelper)
    await DBHelper.upsertExpenseSheetHeader(
      sheetId: id,
      title: title,
      createdAt: now,
    );

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpensesPage(
          sheetId: id,
          sheetTitle: title,
          editable: true,
        ),
      ),
    );

    // Recarga para reflejar título final guardado
    await _loadSheetsFromDb();
  }

  // ================== ABRIR HOJA ==================

  Future<void> _openSheet(
    Map<String, dynamic> sheet, {
    required int index,
  }) async {
    final int sheetId = sheet['id'] as int;
    final String sheetTitle = sheet['title'] as String? ?? 'Expenses';
    final bool currentEditable = (sheet['editable'] as bool?) ?? true;

    // Conservar editable actuales por id al recargar
    final preserveEditable = <int, bool>{
      for (final s in _sheets)
        if (s['id'] is int && s['editable'] is bool)
          s['id'] as int: s['editable'] as bool,
    };

    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpensesPage(
          sheetId: sheetId,
          sheetTitle: sheetTitle,
          editable: currentEditable,
        ),
      ),
    );

    // Recarga títulos desde DB para reflejar renombres hechos dentro de AddExpensesPage
    await _loadSheetsFromDb(preserveEditable: preserveEditable);

    // Actualizar flag editable según resultado
    if (result != null) {
      final idx = _sheets.indexWhere((s) => s['id'] == sheetId);
      if (idx != -1) {
        setState(() {
          _sheets[idx]['editable'] = result;
        });
      }
    }
  }

  // ================== BORRADO ==================

  Future<void> _confirmDeleteSheet(
    BuildContext context,
    int sheetId,
    int index,
  ) async {
    await showPopWindow(
      context: context,
      title: 'Delete expenses sheet',
      children: [
        Text(
          'Are you sure you want to delete this expenses sheet?',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 16),
        ButtonStyles.pillCancelSave(
          onCancel: () => Navigator.pop(context),
          onSave: () async {
            Navigator.pop(context);
            await _deleteSheet(sheetId, index);
          },
          cancelLabel: 'Cancel',
          saveLabel: 'Delete',
        ),
      ],
    );
  }

  Future<void> _deleteSheet(int sheetId, int index) async {
    final db = await DBHelper.getDB();

    await db.transaction((txn) async {
      await txn.delete(
        DBHelper.tableExpenseFxRates,
        where: 'sheetId = ?',
        whereArgs: [sheetId],
      );
      await txn.delete(
        DBHelper.tableExpenseCharges,
        where: 'sheetId = ?',
        whereArgs: [sheetId],
      );
      await txn.delete(
        DBHelper.tableExpenseSheets,
        where: 'sheetId = ?',
        whereArgs: [sheetId],
      );
    });

    setState(() {
      if (index >= 0 && index < _sheets.length) {
        _sheets.removeAt(index);
      } else {
        _sheets.removeWhere((s) => s['id'] == sheetId);
      }
    });
  }
}
