import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RamadanController extends ChangeNotifier {
  static final RamadanController instance = RamadanController._internal();
  RamadanController._internal();

  static const String _keyRamadanMode = 'is_ramadan_mode';
  static const String _keySuhoorTime = 'ramadan_suhoor_time';
  static const String _keyIftarTime = 'ramadan_iftar_time';
  static const String _keyRamadanReminders = 'ramadan_reminders_enabled';

  bool _isRamadanMode = false;
  TimeOfDay _suhoorTime = const TimeOfDay(hour: 4, minute: 30);
  TimeOfDay _iftarTime = const TimeOfDay(hour: 18, minute: 45);
  bool _remindersEnabled = true;
  bool _isInitialized = false;

  bool get isRamadanMode => _isRamadanMode;
  TimeOfDay get suhoorTime => _suhoorTime;
  TimeOfDay get iftarTime => _iftarTime;
  bool get remindersEnabled => _remindersEnabled;
  bool get isInitialized => _isInitialized;

  /// Load persisted state from SharedPreferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isRamadanMode = prefs.getBool(_keyRamadanMode) ?? false;
      _remindersEnabled = prefs.getBool(_keyRamadanReminders) ?? true;
      
      final suhoorStr = prefs.getString(_keySuhoorTime);
      if (suhoorStr != null) {
        final parts = suhoorStr.split(':');
        if (parts.length == 2) {
          _suhoorTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      }

      final iftarStr = prefs.getString(_keyIftarTime);
      if (iftarStr != null) {
        final parts = iftarStr.split(':');
        if (parts.length == 2) {
          _iftarTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      }
    } catch (e) {
      debugPrint('[RamadanController] Init error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Toggle Ramadan mode on/off
  Future<void> toggleRamadanMode() async {
    await setRamadanMode(!_isRamadanMode);
  }

  /// Explicitly set Ramadan mode
  Future<void> setRamadanMode(bool enabled) async {
    _isRamadanMode = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRamadanMode, enabled);
    } catch (e) {
      debugPrint('[RamadanController] Save error: $e');
    }
  }

  /// Update Suhoor time
  Future<void> setSuhoorTime(TimeOfDay time) async {
    _suhoorTime = time;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySuhoorTime, '${time.hour}:${time.minute}');
    } catch (e) {
      debugPrint('[RamadanController] Set suhoor error: $e');
    }
  }

  /// Update Iftar time
  Future<void> setIftarTime(TimeOfDay time) async {
    _iftarTime = time;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyIftarTime, '${time.hour}:${time.minute}');
    } catch (e) {
      debugPrint('[RamadanController] Set iftar error: $e');
    }
  }

  /// Toggle Ramadan reminders
  Future<void> setRemindersEnabled(bool enabled) async {
    _remindersEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRamadanReminders, enabled);
    } catch (e) {
      debugPrint('[RamadanController] Set reminders error: $e');
    }
  }

  /// Returns true if current local time is within fasting hours (between Suhoor and Iftar)
  bool isCurrentlyFasting() {
    final now = DateTime.now();
    final suhoorMinutes = _suhoorTime.hour * 60 + _suhoorTime.minute;
    final iftarMinutes = _iftarTime.hour * 60 + _iftarTime.minute;
    final currentMinutes = now.hour * 60 + now.minute;

    return currentMinutes >= suhoorMinutes && currentMinutes < iftarMinutes;
  }

  /// Returns progress of today's fast (0.0 to 1.0)
  double getFastingProgress() {
    final now = DateTime.now();
    final suhoorMinutes = _suhoorTime.hour * 60 + _suhoorTime.minute;
    final iftarMinutes = _iftarTime.hour * 60 + _iftarTime.minute;
    final currentMinutes = now.hour * 60 + now.minute;

    if (currentMinutes < suhoorMinutes) return 0.0;
    if (currentMinutes >= iftarMinutes) return 1.0;

    final totalFastDuration = iftarMinutes - suhoorMinutes;
    if (totalFastDuration <= 0) return 0.5;

    final elapsed = currentMinutes - suhoorMinutes;
    return (elapsed / totalFastDuration).clamp(0.0, 1.0);
  }

  /// Returns formatted countdown to next event (Iftar or Sehri)
  Duration getTimeUntilNextEvent() {
    final now = DateTime.now();
    final suhoorToday = DateTime(now.year, now.month, now.day, _suhoorTime.hour, _suhoorTime.minute);
    final iftarToday = DateTime(now.year, now.month, now.day, _iftarTime.hour, _iftarTime.minute);

    if (isCurrentlyFasting()) {
      // Time until Iftar
      return iftarToday.difference(now);
    } else if (now.isBefore(suhoorToday)) {
      // Time until Suhoor today
      return suhoorToday.difference(now);
    } else {
      // Time until Suhoor tomorrow
      final suhoorTomorrow = suhoorToday.add(const Duration(days: 1));
      return suhoorTomorrow.difference(now);
    }
  }

  /// Formats TimeOfDay to user friendly 12-hour string (e.g. 04:30 AM)
  String formatTime(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = tod.minute.toString().padLeft(2, '0');
    final hourStr = hour.toString().padLeft(2, '0');
    return '$hourStr:$minute $period';
  }

  /// Returns localized status text for fasting vs eating window
  String getFastingStatusMessage(String lang) {
    final diff = getTimeUntilNextEvent();
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);

    if (isCurrentlyFasting()) {
      if (lang == 'ur') {
        return '⏳ روزہ جاری ہے • افطار میں $hours گھنٹے $minutes منٹ باقی';
      }
      return '⏳ Fasting in progress • ${hours}h ${minutes}m until Iftar';
    } else {
      if (lang == 'ur') {
        return '🌙 کھانے اور ہائیڈریشن کا وقت • سحری میں $hours گھنٹے $minutes منٹ باقی';
      }
      return '🌙 Eating & Hydration Window • ${hours}h ${minutes}m until Sehri ends';
    }
  }

  /// Returns localized meal name for Ramadan mode
  String getLocalizedMealName(String dbType, String lang) {
    if (lang == 'ur') {
      switch (dbType) {
        case 'breakfast':
          return 'سحری';
        case 'dinner':
          return 'افطار';
        case 'lunch':
          return 'افطار کے بعد کا کھانا';
        case 'snack':
          return 'تراویح اسنیک';
        default:
          return 'غذا';
      }
    } else {
      switch (dbType) {
        case 'breakfast':
          return 'Sehri / Suhoor';
        case 'dinner':
          return 'Iftar';
        case 'lunch':
          return 'Post-Iftar Dinner';
        case 'snack':
          return 'Taraweeh Snack';
        default:
          return 'Meal';
      }
    }
  }
}
