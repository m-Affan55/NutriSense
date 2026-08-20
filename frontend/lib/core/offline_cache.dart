import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Singleton SQLite cache for offline-first meal and water log persistence.
///
/// Strategy:
///   1. Every write goes here first (always succeeds, even offline).
///   2. SyncService then pushes unsynced rows to Supabase in the background.
///   3. Once confirmed synced, rows are marked synced=1 and excluded from
///      future queries (to avoid double-counting against Supabase results).
class OfflineCache {
  OfflineCache._();
  static final OfflineCache instance = OfflineCache._();

  static const _dbName = 'nutrisense_offline.db';
  static const _dbVersion = 1;

  // Table names
  static const _mealTable = 'pending_meal_logs';
  static const _waterTable = 'pending_water_logs';

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_mealTable (
            local_id    INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     TEXT NOT NULL,
            meal_type   TEXT NOT NULL,
            notes       TEXT NOT NULL,
            calories    INTEGER NOT NULL,
            protein_g   INTEGER NOT NULL,
            carbs_g     INTEGER NOT NULL,
            fat_g       INTEGER NOT NULL,
            logged_at   TEXT NOT NULL,
            synced      INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE $_waterTable (
            local_id    INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     TEXT NOT NULL,
            amount_ml   INTEGER NOT NULL,
            logged_at   TEXT NOT NULL,
            synced      INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  // ──────────────────────────────────────────────
  //  MEAL LOGS
  // ──────────────────────────────────────────────

  /// Insert a meal log into the local cache (synced=0).
  Future<int> insertPendingMeal({
    required String userId,
    required String mealType,
    required String notes,
    required int calories,
    required int proteinG,
    required int carbsG,
    required int fatG,
  }) async {
    final db = await _database;
    return db.insert(_mealTable, {
      'user_id': userId,
      'meal_type': mealType,
      'notes': notes,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'logged_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  /// Get all unsynced meal rows.
  Future<List<Map<String, dynamic>>> getPendingMeals() async {
    final db = await _database;
    return db.query(_mealTable, where: 'synced = 0');
  }

  /// Get all unsynced meal rows for a specific user logged today.
  Future<List<Map<String, dynamic>>> getTodayPendingMeals(String userId) async {
    final db = await _database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.query(
      _mealTable,
      where: 'user_id = ? AND synced = 0 AND logged_at LIKE ?',
      whereArgs: [userId, '$today%'],
    );
  }

  /// Mark a meal as synced (won't be re-uploaded or shown as pending).
  Future<void> markMealSynced(int localId) async {
    final db = await _database;
    await db.update(
      _mealTable,
      {'synced': 1},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Returns count of unsynced meals across all dates (for badge display).
  Future<int> getPendingMealCount(String userId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_mealTable WHERE user_id = ? AND synced = 0',
      [userId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ──────────────────────────────────────────────
  //  WATER LOGS
  // ──────────────────────────────────────────────

  /// Insert a water log into the local cache (synced=0).
  Future<int> insertPendingWater({
    required String userId,
    required int amountMl,
  }) async {
    final db = await _database;
    return db.insert(_waterTable, {
      'user_id': userId,
      'amount_ml': amountMl,
      'logged_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  /// Get all unsynced water rows.
  Future<List<Map<String, dynamic>>> getPendingWater() async {
    final db = await _database;
    return db.query(_waterTable, where: 'synced = 0');
  }

  /// Get unsynced water totals for today (to merge with Supabase data).
  Future<int> getTodayPendingWaterMl(String userId) async {
    final db = await _database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      'SELECT SUM(amount_ml) as total FROM $_waterTable WHERE user_id = ? AND synced = 0 AND logged_at LIKE ?',
      [userId, '$today%'],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Mark a water log as synced.
  Future<void> markWaterSynced(int localId) async {
    final db = await _database;
    await db.update(
      _waterTable,
      {'synced': 1},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Returns count of unsynced water logs.
  Future<int> getPendingWaterCount(String userId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_waterTable WHERE user_id = ? AND synced = 0',
      [userId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Total unsynced items (meals + water) for badge.
  Future<int> getTotalPendingCount(String userId) async {
    final meals = await getPendingMealCount(userId);
    final water = await getPendingWaterCount(userId);
    return meals + water;
  }
}
