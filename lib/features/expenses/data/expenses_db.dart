import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ExpensesDB {
  ExpensesDB._();
  static final ExpensesDB instance = ExpensesDB._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expenses.db');
    return openDatabase(path, version: 1, onCreate: _create);
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE travel_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        fechaInicio TEXT,
        fechaFin TEXT,
        nombre TEXT,
        banco TEXT,
        cuenta TEXT,
        montoAprobado REAL DEFAULT 0,
        extraAprobado REAL DEFAULT 0,
        bloqueado INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        travel_id INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        categoria TEXT,
        descripcion TEXT,
        monto REAL DEFAULT 0,
        moneda TEXT DEFAULT 'USD',
        tasaCambio REAL DEFAULT 1,
        FOREIGN KEY(travel_id) REFERENCES travel_expenses(id) ON DELETE CASCADE
      )
    ''');
  }

  // CRUD de viajes
  Future<int> createTravel(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('travel_expenses', data);
  }

  Future<List<Map<String, dynamic>>> getTravels() async {
    final db = await database;
    return db.query('travel_expenses', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getTravel(int id) async {
    final db = await database;
    final res = await db.query('travel_expenses',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isEmpty ? null : res.first;
  }

  Future<int> updateTravel(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('travel_expenses', data, where: 'id = ?', whereArgs: [id]);
  }

  // CRUD de gastos
  Future<int> createExpense(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('expenses', data);
  }

  Future<List<Map<String, dynamic>>> getExpenses(int travelId) async {
    final db = await database;
    return db.query('expenses',
        where: 'travel_id = ?', whereArgs: [travelId], orderBy: 'fecha DESC');
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> sumExpenses(int travelId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT SUM(monto * COALESCE(tasaCambio,1)) AS total FROM expenses WHERE travel_id = ?',
      [travelId],
    );
    final val = res.first['total'];
    return (val is num) ? val.toDouble() : 0.0;
  }
}
