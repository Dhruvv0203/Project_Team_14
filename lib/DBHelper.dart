import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'finance_manager.db');
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL,
        date TEXT,
        type TEXT,
        category TEXT,
        description TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE savings_goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_name TEXT,
        target_amount REAL,
        current_amount REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');

    // Insert default expense categories ONLY
    final defaultCategories = ['Food', 'Rent', 'Entertainment', 'Utilities'];
    for (String category in defaultCategories) {
      await db.insert('categories', {'name': category});
    }
  }

  // Transaction CRUD
  Future<int> insertTransaction(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('transactions', data);
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    return await db.query('transactions', orderBy: 'date DESC');
  }

  Future<int> updateTransaction(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('transactions', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Savings Goal CRUD
  Future<int> insertGoal(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('savings_goals', data);
  }

  Future<List<Map<String, dynamic>>> getAllGoals() async {
    final db = await database;
    return await db.query('savings_goals');
  }

  Future<int> updateGoal(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('savings_goals', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGoal(int id) async {
    final db = await database;
    return await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  // Category CRUD
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query('categories');
  }

  Future<int> addCategory(String name) async {
    final db = await database;
    return await db.insert('categories', {'name': name});
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
..