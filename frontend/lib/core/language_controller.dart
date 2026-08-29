import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageController extends ChangeNotifier {
  static final LanguageController instance = LanguageController._internal();
  LanguageController._internal();

  static const String _keyLanguage = 'language';
  static const String _keyAppLanguage = 'app_language';

  String _currentLanguage = 'en';
  bool _isInitialized = false;

  String get currentLanguage => _currentLanguage;
  bool get isUrdu => _currentLanguage == 'ur';
  bool get isInitialized => _isInitialized;

  /// Load persisted language from SharedPreferences on app startup
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLanguage = prefs.getString(_keyLanguage) ?? prefs.getString(_keyAppLanguage) ?? 'en';
    } catch (e) {
      debugPrint('[LanguageController] Init error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Change and persist active app language across all screens
  Future<void> setLanguage(String languageCode) async {
    if (_currentLanguage == languageCode) return;
    _currentLanguage = languageCode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLanguage, languageCode);
      await prefs.setString(_keyAppLanguage, languageCode);
    } catch (e) {
      debugPrint('[LanguageController] Save error: $e');
    }
  }
}
