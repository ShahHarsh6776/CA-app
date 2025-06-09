import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ca_client_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        panNumber TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        filingStatus TEXT NOT NULL,
        filingDeadline TEXT,
        lastFilingDate TEXT,
        notes TEXT,
        feesCharged REAL DEFAULT 0.0,
        feesPaid REAL DEFAULT 0.0,
        assessmentYear TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE filing_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clientId INTEGER NOT NULL,
        filingType TEXT NOT NULL,
        filingDate TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (clientId) REFERENCES clients (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clientId INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        dueDate TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (clientId) REFERENCES clients (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE clients ADD COLUMN feesCharged REAL DEFAULT 0.0');
      await db
          .execute('ALTER TABLE clients ADD COLUMN feesPaid REAL DEFAULT 0.0');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE clients ADD COLUMN assessmentYear TEXT NOT NULL DEFAULT "${DateTime.now().year}-${DateTime.now().year + 1}"');
    }
  }

  Future<int> insertClient(Map<String, dynamic> client) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      final data = {
        ...client,
        'createdAt': now,
        'updatedAt': now,
      };
      return await db.insert('clients', data);
    } catch (e) {
      throw Exception('Failed to insert client: $e');
    }
  }

  Future<int> updateClient(Map<String, dynamic> client) async {
    try {
      final db = await database;
      final data = {
        ...client,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      return await db.update(
        'clients',
        data,
        where: 'id = ?',
        whereArgs: [client['id']],
      );
    } catch (e) {
      throw Exception('Failed to update client: $e');
    }
  }

  Future<int> deleteClient(int id) async {
    try {
      final db = await database;
      return await db.delete(
        'clients',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to delete client: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllClients() async {
    try {
      final db = await database;
      return await db.query('clients', orderBy: 'name');
    } catch (e) {
      throw Exception('Failed to get clients: $e');
    }
  }

  Future<Map<String, dynamic>?> getClient(int id) async {
    try {
      final db = await database;
      final results = await db.query(
        'clients',
        where: 'id = ?',
        whereArgs: [id],
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      throw Exception('Failed to get client: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchClients(String query) async {
    try {
      final db = await database;
      return await db.query(
        'clients',
        where: 'name LIKE ? OR panNumber LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'name',
      );
    } catch (e) {
      throw Exception('Failed to search clients: $e');
    }
  }

  Future<int> addFilingHistory(Map<String, dynamic> history) async {
    try {
      final db = await database;
      final data = {
        ...history,
        'createdAt': DateTime.now().toIso8601String(),
      };
      return await db.insert('filing_history', data);
    } catch (e) {
      throw Exception('Failed to add filing history: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getClientFilingHistory(
      int clientId) async {
    try {
      final db = await database;
      return await db.query(
        'filing_history',
        where: 'clientId = ?',
        whereArgs: [clientId],
        orderBy: 'filingDate DESC',
      );
    } catch (e) {
      throw Exception('Failed to get filing history: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentFilingHistory() async {
    try {
      final db = await database;
      return await db.query(
        'filing_history',
        orderBy: 'createdAt DESC',
        limit: 5,
      );
    } catch (e) {
      throw Exception('Failed to get recent filing history: $e');
    }
  }

  Future<int> addReminder(Map<String, dynamic> reminder) async {
    try {
      final db = await database;
      final data = {
        ...reminder,
        'createdAt': DateTime.now().toIso8601String(),
      };
      return await db.insert('reminders', data);
    } catch (e) {
      throw Exception('Failed to add reminder: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getClientReminders(int clientId) async {
    try {
      final db = await database;
      return await db.query(
        'reminders',
        where: 'clientId = ?',
        whereArgs: [clientId],
        orderBy: 'dueDate',
      );
    } catch (e) {
      throw Exception('Failed to get reminders: $e');
    }
  }

  Future<int> updateReminderStatus(int reminderId, bool isCompleted) async {
    try {
      final db = await database;
      return await db.update(
        'reminders',
        {'isCompleted': isCompleted ? 1 : 0},
        where: 'id = ?',
        whereArgs: [reminderId],
      );
    } catch (e) {
      throw Exception('Failed to update reminder status: $e');
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  Future<String> getClientNameById(int clientId) async {
    try {
      final db = await database;
      final result = await db.query(
        'clients',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [clientId],
      );
      if (result.isNotEmpty) {
        return result.first['name'] as String;
      }
      return 'Unknown Client';
    } catch (e) {
      throw Exception('Failed to get client name: $e');
    }
  }

  Future<int> updateClientFeesPaid(int clientId, double newFeesPaid) async {
    try {
      final db = await database;
      return await db.update(
        'clients',
        {'feesPaid': newFeesPaid},
        where: 'id = ?',
        whereArgs: [clientId],
      );
    } catch (e) {
      throw Exception('Failed to update client fees paid: $e');
    }
  }
}
