// lib/common/sheet_template_page.dart

import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/section_container.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/popwindow.dart';

/// Builder que recibe [editable] y devuelve la lista de secciones
/// específicas de cada pantalla.
typedef SheetBodyBuilder = List<Widget> Function(
  BuildContext context,
  bool editable,
);

/// Plantilla genérica de hoja editable:
/// - AppBar con back
/// - Título editable
/// - Candado editable / solo lectura
/// - Contenido scroll
/// - Botones Cancel / Save que devuelven cambios al caller
class SheetTemplatePage extends StatefulWidget {
  final String initialTitle;
  final bool initialEditable;
  final SheetBodyBuilder buildSections;

  const SheetTemplatePage({
    super.key,
    required this.initialTitle,
    required this.buildSections,
    this.initialEditable = true,
  });

  @override
  State<SheetTemplatePage> createState() => _SheetTemplatePageState();
}

class _SheetTemplatePageState extends State<SheetTemplatePage> {
  late String _title;
  late bool _editable;

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    _editable = widget.initialEditable;
  }

  void _toggleEditable() {
    setState(() {
      _editable = !_editable;
    });
    // Si quieres persistir, hazlo fuera usando el resultado del pop.
  }

  void _close() {
    Navigator.pop<Map<String, dynamic>>(context, {
      'title': _title,
      'editable': _editable,
    });
  }

  Future<void> _editTitle() async {
    final ctrl = TextEditingController(text: _title);

    await showPopWindow(
      context: context,
      title: 'Edit title',
      children: [
        TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Title',
          ),
        ),
        const SizedBox(height: 12),
        ButtonStyles.pillCancelSave(
          onCancel: () => Navigator.pop(context),
          onSave: () {
            final v = ctrl.text.trim();
            if (v.isNotEmpty) {
              setState(() => _title = v);
            }
            Navigator.pop(context);
          },
          cancelLabel: 'Cancel',
          saveLabel: 'Save',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        if (!didPop) {
          _close();
        }
      },
      child: BaseScaffold(
        appBar: CustomAppBar(
          title: _title,
          rightIconPath: 'assets/icons/logoback.svg',
          onRightIconTap: _close,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Cabecera reutilizable (título + lock + texto estado)
              SectionContainer(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _editTitle,
                        child: Text(
                          _title,
                          style: AppTextStyles.headline2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _toggleEditable,
                        icon: Icon(
                          _editable ? Icons.lock_open : Icons.lock,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 2,
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _editable
                        ? 'This section is editable.'
                        : 'This section is read only.',
                    style: AppTextStyles.body,
                  ),
                ],
              ),

              // Secciones específicas de la hoja (definidas por el caller)
              ...widget.buildSections(context, _editable),

              const SizedBox(height: 12),

              // Botones estándar
              ButtonStyles.pillCancelSave(
                onCancel: _close,
                onSave: _close,
                cancelLabel: 'Cancel',
                saveLabel: 'Save',
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
