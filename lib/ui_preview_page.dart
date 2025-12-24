import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:fly_logicd_logbook_app/utils/db_helper.dart' as dbh;
import 'package:fly_logicd_logbook_app/utils/db_exporter.dart' as dbe;

class UIPreviewPage extends StatefulWidget {
  const UIPreviewPage({super.key});

  @override
  State<UIPreviewPage> createState() => _UIPreviewPageState();
}

class _UIPreviewPageState extends State<UIPreviewPage> {
  String? _dbPath;
  bool _isDeleting = false;
  bool _isExporting = false;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();
  List<Map<String, Object?>> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadDBPath();
    _loadNotes();
  }

  Future<void> _loadDBPath() async {
    final path = await getDatabasesPath();
    final fullPath = p.join(path, 'app.db');
    setState(() => _dbPath = fullPath);
  }

  Future<void> _loadNotes() async {
    final notes = await dbh.DBHelper.getAllNotes();
    if (mounted) setState(() => _notes = notes);
  }

  Future<void> _saveNote() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty || content.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❗ Debes llenar ambos campos.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await dbh.DBHelper.insertNote(title: title, content: content);
    _titleCtrl.clear();
    _contentCtrl.clear();
    await _loadNotes();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Nota guardada correctamente.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _editNoteDialog(Map<String, Object?> note) async {
    final titleController =
        TextEditingController(text: note['title'].toString());
    final contentController =
        TextEditingController(text: note['content'].toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('✏️ Editar Nota'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Contenido'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await dbh.DBHelper.updateNote(
                  id: note['id'] as int,
                  title: titleController.text,
                  content: contentController.text,
                );
                if (context.mounted) Navigator.pop(context);
                await _loadNotes();
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Nota actualizada.'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteNote(int id) async {
    await dbh.DBHelper.deleteNote(id);
    await _loadNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ Nota eliminada.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _handleExportDB() async {
    setState(() => _isExporting = true);
    await dbe.DBExporter.exportDB();
    if (!mounted) return;
    setState(() => _isExporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Base de datos exportada a la carpeta Descargas.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handleDeleteDB() async {
    setState(() => _isDeleting = true);
    await dbh.DBHelper.deleteDB();
    if (!mounted) return;
    setState(() => _isDeleting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ Base de datos eliminada correctamente.'),
        backgroundColor: Colors.redAccent,
      ),
    );
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final dbText = _dbPath ?? 'Cargando ruta...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧩 UI Preview Page'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '📁 Ruta actual de la base de datos:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            SelectableText(
              dbText,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Divider(height: 24),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _handleExportDB,
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: Text(
                _isExporting ? 'Exportando...' : 'Exportar Base de Datos',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isDeleting ? null : _handleDeleteDB,
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: Text(
                _isDeleting ? 'Eliminando...' : 'Eliminar Base de Datos',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '📝 Notas (CRUD Completo)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Título de la nota',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                labelText: 'Contenido',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _saveNote,
              icon: const Icon(Icons.save),
              label: const Text('Guardar Nota'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const Divider(height: 24),
            if (_notes.isEmpty)
              const Text(
                'No hay notas guardadas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              )
            else
              Column(
                children: _notes.map((n) {
                  return Dismissible(
                    key: ValueKey(n['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Eliminar nota'),
                          content: const Text(
                              '¿Estás seguro de que deseas eliminar esta nota?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) => _deleteNote(n['id'] as int),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.note, color: Colors.indigo),
                        title: Text(n['title'].toString()),
                        subtitle: Text(
                          n['content'].toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon:
                              const Icon(Icons.edit, color: Colors.blueAccent),
                          onPressed: () => _editNoteDialog(n),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
