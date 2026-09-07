import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ui/features/auth/auth_view.dart';
import '../ui/features/family_profiles/family_viewmodel.dart';
import '../ui/features/grocery_list/grocery_viewmodel.dart';
import 'swap_service.dart';
import 'health_service.dart';
import 'offline_cache.dart';

/// Centralized Session Manager responsible for atomic, leak-free user sign-out.
/// Ensures all in-memory singletons and user-scoped caches are cleanly wiped
/// so that subsequent logins on the same device never see residual data.
class SessionManager {
  SessionManager._();

  /// Performs a complete session teardown and routes to [AuthScreen].
  static Future<void> logout(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;

    try {
      // 1. Reset in-memory singletons and state stores
      FamilyViewModel.instance.clearSession();
      GroceryViewModel().clearSession();
      SwapService.clearSession();
      if (userId != null) {
        await HealthService.instance.clearSessionCache(userId);
      }

      // 2. Clean legacy unscoped cache keys from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_grocery_list');
      await prefs.remove('nutrisense_cached_family_members');
      await prefs.remove('nutrisense_active_family_member_id');
      await prefs.remove('health_weekly_history_cache');

      // 3. Purge synced offline logs to keep local SQLite storage lean
      await OfflineCache.instance.purgeSyncedLogs();

      // 4. Supabase Auth Sign Out
      await Supabase.instance.client.auth.signOut().catchError((_) {});
    } catch (e) {
      debugPrint('[SessionManager] Logout error during cleanup: $e');
    }

    // 5. Navigate cleanly to AuthScreen
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }
}
