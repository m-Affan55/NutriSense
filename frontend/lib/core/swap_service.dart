import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';
import 'language_controller.dart';
import 'ramadan_controller.dart';
import '../shared/widgets/custom_toast.dart';
import '../ui/features/navigation/main_navigation_screen.dart';
import '../main.dart'; // To access globalNavigatorKey

class SwapService {
  static final ValueNotifier<bool> highlightNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String?> highlightedFoodNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<int> swapsUpdatedNotifier = ValueNotifier<int>(0);

  static List<dynamic>? cachedSwaps;
  static String? _cachedDate;
  static String? _activeUserId;
  static String? _activeMemberId;

  /// True when checkMealForSwaps() has completed at least one API call today,
  /// regardless of whether any swaps were found (healthy meals produce 0 swaps).
  /// This is the source-of-truth flag that prevents coaching_screen from
  /// re-calling Gemini for meals that were already evaluated.
  static bool _analyzedToday = false;

  /// In-flight meal note tracker to deduplicate background checks and prevent race conditions.
  static final Set<String> _inProgressMeals = <String>{};
  static bool get isAnalyzing => _inProgressMeals.isNotEmpty;

  static String _prefKeyDate(String uid, [String? memberId]) =>
      'nutrisense_swaps_${uid}_${memberId ?? "primary"}_date';
  static String _prefKeyList(String uid, [String? memberId]) =>
      'nutrisense_swaps_${uid}_${memberId ?? "primary"}_list';
  static String _prefKeyAnalyzed(String uid, [String? memberId]) =>
      'nutrisense_swaps_${uid}_${memberId ?? "primary"}_analyzed';

  static String get _todayDateStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _resolveUserId(String? explicitUserId) {
    if (explicitUserId != null && explicitUserId.isNotEmpty) return explicitUserId;
    final user = Supabase.instance.client.auth.currentUser;
    return user?.id ?? 'guest';
  }

  /// Returns whether meals have already been evaluated for swaps today.
  static bool wasAnalyzedToday({String? userId, String? memberId}) {
    final uid = _resolveUserId(userId);
    if (_activeUserId != uid || _activeMemberId != memberId) {
      return false;
    }
    clearIfNewDay(userId: uid, memberId: memberId);
    return _analyzedToday;
  }

  /// Marks today as analyzed and persists the flag in SharedPreferences.
  static Future<void> markAnalyzedToday({String? userId, String? memberId}) async {
    final uid = _resolveUserId(userId);
    _analyzedToday = true;
    _activeUserId = uid;
    _activeMemberId = memberId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDate(uid, memberId), _cachedDate ?? _todayDateStr);
      await prefs.setBool(_prefKeyAnalyzed(uid, memberId), true);
    } catch (e) {
      debugPrint('Error saving analyzed flag: $e');
    }
  }

  /// Clears in-memory swap session state when user signs out
  static void clearSession() {
    cachedSwaps = null;
    _cachedDate = null;
    _activeUserId = null;
    _activeMemberId = null;
    _analyzedToday = false;
    highlightNotifier.value = false;
    highlightedFoodNotifier.value = null;
  }

  /// Clears in-memory and persisted swap cache when user profile/conditions change.
  static Future<void> invalidateSwapsCache({String? userId, String? memberId}) async {
    final uid = _resolveUserId(userId);
    cachedSwaps = [];
    _analyzedToday = false;
    highlightNotifier.value = false;
    highlightedFoodNotifier.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyList(uid, memberId));
      await prefs.remove(_prefKeyAnalyzed(uid, memberId));
    } catch (e) {
      debugPrint('Error invalidating swaps cache: $e');
    }
  }

  /// Initializes cached swaps from user/member scoped SharedPreferences, wiping if new day or user changed.
  static Future<void> initFromStorage({String? userId, String? memberId}) async {
    try {
      final uid = _resolveUserId(userId);
      final today = _todayDateStr;
      final prefs = await SharedPreferences.getInstance();

      final savedDate = prefs.getString(_prefKeyDate(uid, memberId));
      if (savedDate == today) {
        // Restore the "was analyzed today" flag — independent of swap count
        _analyzedToday = prefs.getBool(_prefKeyAnalyzed(uid, memberId)) ?? false;
        final savedJson = prefs.getString(_prefKeyList(uid, memberId));
        if (savedJson != null && savedJson.isNotEmpty) {
          final decoded = jsonDecode(savedJson);
          if (decoded is List) {
            cachedSwaps = List<dynamic>.from(decoded);
            _cachedDate = today;
            _activeUserId = uid;
            _activeMemberId = memberId;
            return;
          }
        }
        cachedSwaps = [];
        _cachedDate = today;
        _activeUserId = uid;
        _activeMemberId = memberId;
      } else {
        // Date changed or not set for this user/member -> clean rollover
        _cachedDate = today;
        _activeUserId = uid;
        _activeMemberId = memberId;
        _analyzedToday = false;
        cachedSwaps = [];
        await prefs.setString(_prefKeyDate(uid, memberId), today);
        await prefs.remove(_prefKeyList(uid, memberId));
        await prefs.remove(_prefKeyAnalyzed(uid, memberId));
      }
    } catch (e) {
      debugPrint('Error initializing SwapService storage: $e');
      cachedSwaps = [];
      _cachedDate = _todayDateStr;
      _analyzedToday = false;
    }
  }

  static Future<void> _saveToStorage(String uid, [String? memberId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDate(uid, memberId), _cachedDate ?? _todayDateStr);
      await prefs.setBool(_prefKeyAnalyzed(uid, memberId), _analyzedToday);
      if (cachedSwaps != null) {
        await prefs.setString(_prefKeyList(uid, memberId), jsonEncode(cachedSwaps));
      }
    } catch (e) {
      debugPrint('Error saving swaps to storage: $e');
    }
  }

  /// Adds new swaps for today, scoped to the user and optional family member, ensuring no duplicates.
  static void addSwapsForToday(List<dynamic> newSwaps, {String? userId, String? memberId}) {
    final uid = _resolveUserId(userId);
    clearIfNewDay(userId: uid, memberId: memberId);
    if (_activeUserId != uid || _activeMemberId != memberId) {
      _activeUserId = uid;
      _activeMemberId = memberId;
      cachedSwaps = [];
    }
    cachedSwaps ??= [];
    _analyzedToday = true;

    for (final newSwap in newSwaps) {
      if (newSwap is Map) {
        final origFood = (newSwap['original_food'] ?? '').toString().toLowerCase().trim();
        final existingIndex = cachedSwaps!.indexWhere((existing) =>
            existing is Map &&
            (existing['original_food'] ?? '').toString().toLowerCase().trim() == origFood);
        if (existingIndex >= 0) {
          cachedSwaps![existingIndex] = newSwap;
        } else {
          cachedSwaps!.insert(0, newSwap);
        }
      }
    }
    _saveToStorage(uid, memberId);
    swapsUpdatedNotifier.value++;
  }

  /// Synchronously returns swaps for today (if loaded in memory for the active user/member).
  static List<dynamic>? getSwapsForToday({String? userId, String? memberId}) {
    final uid = _resolveUserId(userId);
    if (_activeUserId != uid || _activeMemberId != memberId) {
      // Different user or family member: flush stale memory cache
      cachedSwaps = null;
      _activeUserId = uid;
      _activeMemberId = memberId;
      return [];
    }
    clearIfNewDay(userId: uid, memberId: memberId);
    return cachedSwaps;
  }

  /// Clears in-memory and persistent cache if the date, user, or active family member has changed.
  static void clearIfNewDay({String? userId, String? memberId}) {
    final uid = _resolveUserId(userId);
    final today = _todayDateStr;
    if (_cachedDate != today || _activeUserId != uid || _activeMemberId != memberId) {
      _cachedDate = today;
      _activeUserId = uid;
      _activeMemberId = memberId;
      _analyzedToday = false;
      cachedSwaps = [];
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_prefKeyDate(uid, memberId), today);
        prefs.remove(_prefKeyList(uid, memberId));
        prefs.remove(_prefKeyAnalyzed(uid, memberId));
      }).catchError((_) {});
    }
  }

  /// Checks if a given swap card corresponds to the currently highlighted food item.
  static bool isFoodHighlighted(dynamic swap) {
    if (!highlightNotifier.value) return false;
    final target = highlightedFoodNotifier.value;
    if (target == null || target.trim().isEmpty) return true;
    if (swap is Map) {
      final orig = (swap['original_food'] ?? '').toString().toLowerCase().trim();
      final targetLower = target.toLowerCase().trim();
      return orig == targetLower || orig.contains(targetLower) || targetLower.contains(orig);
    }
    return false;
  }

  /// Asynchronously evaluates a logged meal for clinical compliance and suggests swaps if needed.
  static Future<void> checkMealForSwaps(String mealNote, {String? familyMemberId}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || mealNote.trim().isEmpty) return;

    final normalizedNote = mealNote.toLowerCase().trim();
    if (_inProgressMeals.contains(normalizedNote)) {
      debugPrint('[SwapService] Swap check already in progress for "$mealNote", skipping duplicate.');
      return;
    }

    _inProgressMeals.add(normalizedNote);

    try {
      final lang = LanguageController.instance.currentLanguage;
      final isUrdu = lang == 'ur';
      final bodyMap = <String, dynamic>{
        'user_id': user.id,
        'recent_meals': [mealNote],
        'language': lang,
      };
      if (familyMemberId != null && familyMemberId.isNotEmpty) {
        bodyMap['family_member_id'] = familyMemberId;
      }

      final swapRes = await http.post(
        Uri.parse('${ApiClient.getBaseUrl()}/coaching/food-swaps'),
        headers: ApiClient.getHeaders(),
        body: jsonEncode(bodyMap),
      );
      
      if (swapRes.statusCode == 200) {
        final data = jsonDecode(swapRes.body);
        final List<dynamic> swaps = data['swaps'] is List ? data['swaps'] : [];
        final bool isHealthy = data['is_healthy'] == true || swaps.isEmpty;

        // Mark as evaluated today regardless of whether healthy (0 swaps) or unhealthy
        await markAnalyzedToday(userId: user.id, memberId: familyMemberId);
        swapsUpdatedNotifier.value++;
        
        final context = globalNavigatorKey.currentContext;
        if (context == null || !context.mounted) return;

        if (isHealthy) {
          // Healthy meal: show encouraging validation toast!
          final serverMsg = data['message']?.toString().trim();
          final encouragement = (serverMsg != null && serverMsg.isNotEmpty)
              ? serverMsg
              : (isUrdu
                  ? 'بہترین انتخاب! آپ کا کھانا آپ کے صحت کے پروفائل سے مطابقت رکھتا ہے ✓'
                  : 'Great choice! Your meal aligns with your health profile ✓');

          CustomToast.show(
            context,
            encouragement,
            isError: false,
            icon: Icons.check_circle_rounded,
            borderColor: RamadanController.instance.isRamadanMode ? const Color(0xFF00D2FF) : const Color(0xFF00E676),
            duration: const Duration(seconds: 5),
          );
          return;
        }

        // Unhealthy meal with swaps: persist to user-scoped day cache and show amber swap alert toast
        if (swaps.isNotEmpty) {
          addSwapsForToday(swaps, userId: user.id, memberId: familyMemberId);
          final targetFood = (swaps.first['original_food'] ?? mealNote).toString();

          CustomToast.show(
            context, 
            isUrdu
                ? 'آپ کے کھانے کے لیے صحت مند متبادل دستیاب ہے! دیکھنے کے لیے ٹیپ کریں۔'
                : 'Healthier alternatives found for your meal! Tap to view.',
            isError: false,
            icon: Icons.swap_horiz_rounded,
            borderColor: const Color(0xFFFFB300),
            duration: const Duration(seconds: 8),
            onTap: () {
              highlightedFoodNotifier.value = targetFood;
              highlightNotifier.value = true;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              
              // Pop any open modal or scanner dialog to return to the root screen
              final nav = globalNavigatorKey.currentState;
              if (nav != null && nav.canPop()) {
                nav.popUntil((route) => route.isFirst);
              }
              
              // Switch directly to Coaching screen (tab 3)
              MainNavigationScreenState.switchToTab(3);

              // Reset highlight pulse after 6 seconds
              Future.delayed(const Duration(seconds: 6), () {
                highlightNotifier.value = false;
                highlightedFoodNotifier.value = null;
              });
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Error in SwapService background check: $e');
    } finally {
      _inProgressMeals.remove(normalizedNote);
    }
  }
}

