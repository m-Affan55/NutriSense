import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_cache.dart';

/// Responsible for syncing locally cached (offline) meal and water logs
/// to Supabase when a network connection is available.
///
/// Called:
///   1. On app startup (main.dart) — catches any logs that were made
///      while offline and not yet synced.
///   2. By connectivity stream listeners — triggered the moment the device
///      reconnects to the internet.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _cache = OfflineCache.instance;
  bool _isSyncing = false;

  /// Subscribe to connectivity changes and sync whenever online.
  /// Call once from main.dart after WidgetsFlutterBinding.ensureInitialized().
  Stream<List<ConnectivityResult>> get connectivityStream =>
      Connectivity().onConnectivityChanged;

  /// Push all pending local rows to Supabase for [userId].
  /// Safe to call multiple times — guards against concurrent runs.
  Future<void> syncPending(String userId) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // Check network before attempting
      final result = await Connectivity().checkConnectivity();
      final isOnline = result.any((r) => r != ConnectivityResult.none);
      if (!isOnline) {
        debugPrint('[SyncService] Offline — skipping sync');
        return;
      }

      final supabase = Supabase.instance.client;

      // ── Sync meal logs ──────────────────────────────────────
      final pendingMeals = await _cache.getPendingMeals();
      for (final meal in pendingMeals) {
        if (meal['user_id'] != userId) continue;
        try {
          await supabase.from('meal_logs').insert({
            'user_id': meal['user_id'],
            'meal_type': meal['meal_type'],
            'notes': meal['notes'],
            'total_calories': meal['calories'],
            'total_protein_g': meal['protein_g'],
            'total_carbs_g': meal['carbs_g'],
            'total_fat_g': meal['fat_g'],
            'logged_at': meal['logged_at'],
          });
          await _cache.markMealSynced(meal['local_id'] as int);
          debugPrint('[SyncService] Meal synced: local_id=${meal['local_id']}');
        } catch (e) {
          // One row failing should not stop the rest
          debugPrint('[SyncService] Meal sync failed (local_id=${meal['local_id']}): $e');
        }
      }

      // ── Sync water logs ─────────────────────────────────────
      final pendingWater = await _cache.getPendingWater();
      for (final water in pendingWater) {
        if (water['user_id'] != userId) continue;
        try {
          await supabase.from('water_logs').insert({
            'user_id': water['user_id'],
            'amount_ml': water['amount_ml'],
            'logged_at': water['logged_at'],
          });
          await _cache.markWaterSynced(water['local_id'] as int);
          debugPrint('[SyncService] Water synced: local_id=${water['local_id']}');
        } catch (e) {
          debugPrint('[SyncService] Water sync failed (local_id=${water['local_id']}): $e');
        }
      }

      debugPrint('[SyncService] Sync complete');
    } catch (e) {
      debugPrint('[SyncService] Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
