// lib/features/notes/notes_controller.dart
import 'package:flutter/foundation.dart';
import 'package:fly_logicd_logbook_app/features/notes/notes.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

class NotesController extends ChangeNotifier {
  List<Note> _notes = const [];
  bool _loading = false;

  List<Note> get notes => _notes;
  bool get loading => _loading;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    final rows = await DBHelper.getAllNotes();
    _notes = rows.map((e) => Note.fromMap(e)).toList(growable: false);
    _loading = false;
    notifyListeners();
  }

  Future<void> add(String title, String content) async {
    await DBHelper.insertNote(title: title, content: content);
    await refresh();
  }

  Future<void> update(int id, String title, String content) async {
    await DBHelper.updateNote(id: id, title: title, content: content);
    await refresh();
  }

  Future<void> remove(int id) async {
    await DBHelper.deleteNote(id);
    await refresh();
  }
}
