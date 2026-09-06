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
  
  static List<dynamic>? cachedSwaps;
  static String? _cachedDate;
  static String? _activeUserId;
  static String? _activeMemberId;

  static String _prefKeyDate(String uid, [String? memberId]) =>
      'nutrisense_swaps_${uid}_${memberId ?? "primary"}_date';
  static String _prefKeyList(String uid, [String? memberId]) =>
      'nutrisense_swaps_${uid}_${memberId ?? "primary"}_list';

  static String get _todayDateStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _resolveUserId(String? explicitUserId) {
    if (explicitUserId != null && explicitUserId.isNotEmpty) return explicitUserId;
    final user = Supabase.instance.client.auth.currentUser;
    return user?.id ?? 'guest';
  }

  /// Clears in-memory swap session state when user signs out
  static void clearSession() {
    cachedSwaps = null;
    _cachedDate = null;
    _activeUserId = null;
    _activeMemberId = null;
    highlightNotifier.value = false;
    highlightedFoodNotifier.value = null;
  }

  /// Clears in-memory and persisted swap cache when user profile/conditions change.
  static Future<void> invalidateSwapsCache({String? userId, String? memberId}) async {
    final uid = _resolveUserId(userId);
    cachedSwaps = [];
    highlightNotifier.value = false;
    highlightedFoodNotifier.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyList(uid, memberId));
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
        cachedSwaps = [];
        await prefs.setString(_prefKeyDate(uid, memberId), today);
        await prefs.remove(_prefKeyList(uid, memberId));
      }
    } catch (e) {
      debugPrint('Error initializing SwapService storage: $e');
      cachedSwaps = [];
      _cachedDate = _todayDateStr;
    }
  }

  static Future<void> _saveToStorage(String uid, [String? memberId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDate(uid, memberId), _cachedDate ?? _todayDateStr);
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
      cachedSwaps = [];
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_prefKeyDate(uid, memberId), today);
        prefs.remove(_prefKeyList(uid, memberId));
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
    }
  }
}
