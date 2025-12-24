// lib/features/notes/notes_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notes_controller.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';
import 'package:fly_logicd_logbook_app/features/notes/notes.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotesController()..refresh(),
      child: const _NotesView(),
    );
  }
}

class _NotesView extends StatelessWidget {
  const _NotesView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<NotesController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas (SQLite)'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => context.read<NotesController>().refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Ruta DB (log)',
            onPressed: () {
              // Muestra ruta en un SnackBar y también queda en logs (DBHelper.getDB() ya lo imprime al abrir).
              final path = DBHelper.databasePath ?? 'Desconocido';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('DB: $path')),
              );
            },
            icon: const Icon(Icons.folder_open),
          ),
        ],
      ),
      body: ctrl.loading
          ? const Center(child: CircularProgressIndicator())
          : ctrl.notes.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: ctrl.notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final n = ctrl.notes[index];
                    return Dismissible(
                      key: ValueKey(n.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        await context.read<NotesController>().remove(n.id!);
                        return true;
                      },
                      child: ListTile(
                        tileColor: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(n.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          n.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _openEditor(context, existing: n),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {Note? existing}) async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 8,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(existing == null ? 'Nueva nota' : 'Editar nota',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Mínimo 3 caracteres'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contenido',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Contenido requerido'
                      : null,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final title = titleCtrl.text.trim();
                    final content = contentCtrl.text.trim();
                    final notes = context.read<NotesController>();

                    if (existing == null) {
                      await notes.add(title, content);
                    } else {
                      await notes.update(existing.id!, title, content);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(existing == null ? 'Crear' : 'Guardar'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No hay notas. Crea la primera con el botón “Nueva”.'),
      ),
    );
  }
}
