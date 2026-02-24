import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  static Future<Database> initDB() async {
    final path = join(await getDatabasesPath(), "app_database.db");
    return await openDatabase(
      path,
      version: 6, // ⭐ UPDATED VERSION
      onCreate: (db, version) async {
        print("🆕 Creating database");

        await db.execute('''
        CREATE TABLE slot_chats (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          slot TEXT NOT NULL,
          chat TEXT NOT NULL
        )
        ''');

        await db.execute('''
        CREATE TABLE weekly_status (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          startDate TEXT NOT NULL,
          endDate TEXT NOT NULL,
          isCompleted INTEGER NOT NULL DEFAULT 0
        )
        ''');

        await db.execute('''
        CREATE TABLE thought_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          trigger TEXT NOT NULL,
          feeling TEXT NOT NULL,
          negative_thought TEXT NOT NULL,
          new_thought TEXT,
          outcome TEXT,
          created_at TEXT NOT NULL
        )
        ''');

        await db.execute('''
CREATE TABLE walkthrough_status (
  id INTEGER PRIMARY KEY,
  completed INTEGER NOT NULL DEFAULT 0
)
''');

        await db.execute('''
CREATE TABLE home_showcase_status (
  id INTEGER PRIMARY KEY,
  completed INTEGER NOT NULL DEFAULT 0
)
''');

        // ⭐ NEW TABLE
        await db.execute('''
CREATE TABLE phq9_showcase_status (
  id INTEGER PRIMARY KEY,
  completed INTEGER NOT NULL DEFAULT 0
)
''');
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        print("⬆️ Upgrading DB from $oldVersion → $newVersion");

        if (oldVersion < 2) {
          await db.execute('''
          CREATE TABLE weekly_status (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            startDate TEXT NOT NULL,
            endDate TEXT NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0
          )
          ''');
        }

        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS thought_records');
          await db.execute('''
          CREATE TABLE thought_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trigger TEXT NOT NULL,
            feeling TEXT NOT NULL,
            negative_thought TEXT NOT NULL,
            new_thought TEXT,
            outcome TEXT,
            created_at TEXT NOT NULL
          )
          ''');
        }

        if (oldVersion < 4) {
          await db.execute('''
CREATE TABLE walkthrough_status (
  id INTEGER PRIMARY KEY,
  completed INTEGER NOT NULL DEFAULT 0
)
''');
        }

        if (oldVersion < 5) {
          await db.execute('''
CREATE TABLE home_showcase_status (
  id INTEGER PRIMARY KEY,
  completed INTEGER NOT NULL DEFAULT 0
)
''');
        }

        // ⭐ NEW MIGRATION
        if (oldVersion < 6) {
          await db.execute('''
CREATE TABLE phq9_showcase_status (
  id INTEGER PRIMARY KEY,
  completed INTEGER NOT NULL DEFAULT 0
)
''');
        }
      },
    );
  }

  // =======================================================================
  // Weekly Activity & Lifecycle
  // =======================================================================

  static Future<void> saveChat(String date, String slot, String newMessage) async {
    final db = await database;

    if (newMessage.trim().isEmpty) {
      await db.delete('slot_chats', where: 'date = ? AND slot = ?', whereArgs: [date, slot]);
      return;
    }

    final existing = await db.query('slot_chats', where: 'date = ? AND slot = ?', whereArgs: [date, slot], limit: 1);

    if (existing.isNotEmpty) {
      final oldChat = existing.first['chat'] as String? ?? "";
      await db.update('slot_chats', {'chat': "$oldChat\n$newMessage"}, where: 'date = ? AND slot = ?', whereArgs: [date, slot]);
    } else {
      await db.insert('slot_chats', {'date': date, 'slot': slot, 'chat': newMessage});
    }

    final activeWeek = await getCurrentWeekData();
    if (activeWeek == null) {
      final now = DateTime.now();
      await startNewWeek(DateTime(now.year, now.month, now.day));
    }
  }

  static Future<void> startNewWeek(DateTime startDate) async {
    final db = await database;
    final endDate = startDate.add(const Duration(days: 7));
    await db.insert('weekly_status', {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isCompleted': 0,
    });
  }

  static Future<Map<String, dynamic>?> getCurrentWeekData() async {
    final db = await database;
    final result = await db.query('weekly_status', orderBy: 'startDate DESC', limit: 1);

    if (result.isNotEmpty) {
      final startDate = DateTime.parse(result.first['startDate'] as String);
      if (DateTime.now().difference(startDate).inDays < 7) {
        return result.first;
      }
    }
    return null;
  }

  static Future<DateTime?> getFixedStartDay() async {
    final weekData = await getCurrentWeekData();
    if (weekData != null) return DateTime.parse(weekData['startDate'] as String);
    return null;
  }

  static Future<String?> getChat(String date, String slot) async {
    final db = await database;
    final result = await db.query('slot_chats', where: 'date = ? AND slot = ?', whereArgs: [date, slot], limit: 1);
    return result.isNotEmpty ? result.first['chat'] as String? : null;
  }

  static Future<List<Map<String, dynamic>>> getAllChats() async {
    final db = await database;
    return await db.query('slot_chats', orderBy: 'date ASC, slot ASC');
  }

  static Future<void> markWeekAsCompleted() async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE weekly_status
      SET isCompleted = 1
      WHERE rowid = (
        SELECT rowid FROM weekly_status ORDER BY startDate DESC LIMIT 1
      )
    ''');
  }

  static Future<void> resetWeeklyStatus() async {
    final db = await database;
    await db.delete('weekly_status');
  }

  // =======================================================================
  // Thought Records
  // =======================================================================

  static Future<void> insertThoughtRecord({
    required String trigger,
    required String feeling,
    required String negativeThought,
    String? newThought,
    String? outcome,
  }) async {
    final db = await database;
    await db.insert('thought_records', {
      'trigger': trigger,
      'feeling': feeling,
      'negative_thought': negativeThought,
      'new_thought': newThought,
      'outcome': outcome,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getAllThoughtRecords() async {
    final db = await database;
    return await db.query('thought_records', orderBy: 'created_at DESC');
  }

  static Future<void> deleteThoughtRecord(int id) async {
    final db = await database;
    await db.delete('thought_records', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> clearAllThoughtRecords() async {
    final db = await database;
    await db.delete('thought_records');
  }

  // =======================================================================
  // Walkthrough
  // =======================================================================

  static Future<void> setWalkthroughCompleted(bool completed) async {
    final db = await database;
    final existing = await db.query('walkthrough_status', where: 'id = 1');
    if (existing.isEmpty) {
      await db.insert('walkthrough_status', {'id': 1, 'completed': completed ? 1 : 0});
    } else {
      await db.update('walkthrough_status', {'completed': completed ? 1 : 0}, where: 'id = 1');
    }
  }

  static Future<bool> getWalkthroughCompleted() async {
    final db = await database;
    final result = await db.query('walkthrough_status', where: 'id = 1', limit: 1);
    if (result.isEmpty) return false;
    return (result.first['completed'] as int) == 1;
  }

  // =======================================================================
  // HOME SHOWCASE — controls menu, chat, thought button
  // =======================================================================

  static Future<void> setHomeShowcaseCompleted(bool completed) async {
    final db = await database;
    final existing = await db.query('home_showcase_status', where: 'id = 1');
    if (existing.isEmpty) {
      await db.insert('home_showcase_status', {'id': 1, 'completed': completed ? 1 : 0});
    } else {
      await db.update('home_showcase_status', {'completed': completed ? 1 : 0}, where: 'id = 1');
    }
  }

  static Future<bool?> getHomeShowcaseCompleted() async {
    final db = await database;
    final result = await db.query('home_showcase_status', where: 'id = 1', limit: 1);
    if (result.isEmpty) return null;
    return (result.first['completed'] as int) == 1;
  }

  // =======================================================================
  // ⭐ PHQ9 SHOWCASE — controls PHQ-9 card only
  // =======================================================================

  static Future<void> setPHQ9ShowcaseCompleted(bool completed) async {
    final db = await database;
    final existing = await db.query('phq9_showcase_status', where: 'id = 1');
    if (existing.isEmpty) {
      await db.insert('phq9_showcase_status', {'id': 1, 'completed': completed ? 1 : 0});
    } else {
      await db.update('phq9_showcase_status', {'completed': completed ? 1 : 0}, where: 'id = 1');
    }
  }

  static Future<bool?> getPHQ9ShowcaseCompleted() async {
    final db = await database;
    final result = await db.query('phq9_showcase_status', where: 'id = 1', limit: 1);
    if (result.isEmpty) return null;
    return (result.first['completed'] as int) == 1;
  }

  // =======================================================================
  // SHOWCASE STEPS (Progressive system)
  // =======================================================================

  static Future<bool> getShowcaseStep(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  static Future<void> setShowcaseStep(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}