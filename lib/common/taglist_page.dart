import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import '../l10n/app_localizations.dart';

class TagListPage extends StatefulWidget {
  final List<SectionItem> staticItems; // 👈 elementos fijos de solo lectura
  final void Function(SectionItem) onAdd;
  final void Function() onDelete;
  final void Function(SectionItem) onEdit;

  const TagListPage({
    super.key,
    required this.staticItems,
    required this.onAdd,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<TagListPage> createState() => _TagListPageState();
}

class _TagListPageState extends State<TagListPage> {
  SectionItem? _userItem; // 👈 único item creado por el usuario

  void _showAddOrEditDialog(BuildContext context, {bool isEdit = false}) {
    final localizations = AppLocalizations.of(context);
    final item = isEdit ? _userItem : null;

    final labelController = TextEditingController(text: item?.label ?? "");
    final titleController = TextEditingController(text: item?.title ?? "");
    final explanationController =
        TextEditingController(text: item?.explanation ?? "");

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.grayc, // Corregido el color
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 30, vertical: 20), // margen
          title: Text(
            isEdit ? localizations.t("modify") : localizations.t("add_new"),
            style: AppTextStyles.sectionTitle,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  labelText: localizations.t("label"),
                  labelStyle: AppTextStyles.body,
                  filled: true,
                  fillColor: AppColors.grayc, // Corregido el color
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  labelText: localizations.t("title"),
                  labelStyle: AppTextStyles.body,
                  filled: true,
                  fillColor: AppColors.grayc, // Corregido el color
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: explanationController,
                style: AppTextStyles.body,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: localizations.t("explanation"),
                  labelStyle: AppTextStyles.body,
                  filled: true,
                  fillColor: AppColors.grayc, // Corregido el color
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.t("cancel"), style: AppTextStyles.body),
            ),
            ElevatedButton(
              onPressed: () {
                final newItem = SectionItem(
                  id: item?.id,
                  label: labelController.text.trim(),
                  title: titleController.text.trim(),
                  explanation: explanationController.text.trim(),
                  labelColor: Colors.blueGrey,
                  isUserCreated: true,
                );

                setState(() {
                  if (isEdit) {
                    _userItem = newItem;
                    widget.onEdit(newItem);
                  } else {
                    _userItem = newItem;
                    widget.onAdd(newItem);
                  }
                });

                Navigator.pop(context);
              },
              child: Text(
                  isEdit ? localizations.t("modify") : localizations.t("add")),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.black, // Corregido el color
          borderRadius: BorderRadius.circular(12),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // margen
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.white70, thickness: 1),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(localizations.t("tag_list"),
                      style: AppTextStyles.sectionTitle),
                ),
                const Divider(color: Colors.white70, thickness: 1),
              ],
            ),
            const SizedBox(height: 15),

            // Lista completa (7 fijos + 1 del usuario si existe)
            Expanded(
              child: ListView.separated(
                itemCount:
                    widget.staticItems.length + (_userItem != null ? 1 : 0),
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.teal1, thickness: 1),
                itemBuilder: (context, index) {
                  if (index < widget.staticItems.length) {
                    final item = widget.staticItems[index];
                    return _SectionWidget(item: item); // 🔹 fijos sin borrar
                  } else {
                    final item = _userItem!;
                    return _SectionWidget(
                      item: item,
                      onDelete: () {
                        setState(() {
                          _userItem = null;
                        });
                        widget.onDelete();
                      },
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 12),

            // Botón dinámico
            if (_userItem == null)
              OutlinedButton.icon(
                onPressed: () => _showAddOrEditDialog(context, isEdit: false),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(localizations.t("add_another"),
                    style: AppTextStyles.body),
              )
            else
              OutlinedButton.icon(
                onPressed: () => _showAddOrEditDialog(context, isEdit: true),
                icon: const Icon(Icons.edit, color: Colors.white),
                label:
                    Text(localizations.t("modify"), style: AppTextStyles.body),
              ),
          ],
        ),
      ),
    );
  }
}

/// Modelo de datos extendido para SQLite
class SectionItem {
  final int? id;
  final String label;
  final String title;
  final String explanation;
  final Color labelColor;
  final bool isUserCreated;

  SectionItem({
    this.id,
    required this.label,
    required this.title,
    required this.explanation,
    this.labelColor = Colors.blueGrey,
    this.isUserCreated = false,
  });

  SectionItem copyWith({
    int? id,
    String? label,
    String? title,
    String? explanation,
    Color? labelColor,
    bool? isUserCreated,
  }) {
    return SectionItem(
      id: id ?? this.id,
      label: label ?? this.label,
      title: title ?? this.title,
      explanation: explanation ?? this.explanation,
      labelColor: labelColor ?? this.labelColor,
      isUserCreated: isUserCreated ?? this.isUserCreated,
    );
  }
}

/// Render de cada item
class _SectionWidget extends StatelessWidget {
  final SectionItem item;
  final VoidCallback? onDelete;

  const _SectionWidget({
    required this.item,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Etiqueta
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 65),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: item.labelColor,
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              item.label.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Contenido
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.left,
              ),
              Text(
                item.explanation,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),

        // 🔹 Solo el item del usuario tiene borrar
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: SvgPicture.asset(
              "assets/icons/erase.svg",
              height: 14,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
      ],
    );
  }
}
