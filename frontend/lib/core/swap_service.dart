import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';
import 'language_controller.dart';
import '../shared/widgets/custom_toast.dart';
import '../ui/features/navigation/main_navigation_screen.dart';
import '../main.dart'; // To access globalNavigatorKey

class SwapService {
  static final ValueNotifier<bool> highlightNotifier = ValueNotifier(false);
  static List<dynamic>? cachedSwaps;

  static Future<void> checkMealForSwaps(String mealNote) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || mealNote.trim().isEmpty) return;

    try {
      final lang = LanguageController.instance.currentLanguage;
      final swapRes = await http.post(
        Uri.parse('${ApiClient.getBaseUrl()}/coaching/food-swaps'),
        headers: ApiClient.getHeaders(),
        body: jsonEncode({
          'user_id': user.id,
          'recent_meals': [mealNote],
          'language': lang,
        }),
      );
      
      if (swapRes.statusCode == 200) {
        final data = jsonDecode(swapRes.body);
        final List<dynamic> swaps = data['swaps'] ?? [];
        
        final context = globalNavigatorKey.currentContext;
        if (swaps.isNotEmpty && context != null && context.mounted) {
          cachedSwaps = swaps;
          final isUrdu = lang == 'ur';
          CustomToast.show(
            context, 
            isUrdu
                ? 'آپ کے کھانے کے لیے صحت مند متبادل دستیاب ہے! دیکھنے کے لیے ٹیپ کریں۔'
                : 'Healthier alternatives found for your meal! Tap to view.',
            isError: false,
            duration: const Duration(seconds: 8),
            onTap: () {
              highlightNotifier.value = true;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              // Null-safe: root navigator context may not have a
              // MainNavigationScreen ancestor, so guard with ?.
              final navState = context
                  .findAncestorStateOfType<MainNavigationScreenState>();
              navState?.currentIndex = 3;
              // Reset highlight after 5 seconds
              Future.delayed(const Duration(seconds: 5), () {
                highlightNotifier.value = false;
              });
            }
          );
        }
      }
    } catch (e) {
      debugPrint('Error in SwapService background check: $e');
    }
  }
}
