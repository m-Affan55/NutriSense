import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RamadanController extends ChangeNotifier {
  static final RamadanController instance = RamadanController._internal();
  RamadanController._internal();

  static const String _keyRamadanMode = 'is_ramadan_mode';
  static const String _keySuhoorTime = 'ramadan_suhoor_time';
  static const String _keyIftarTime = 'ramadan_iftar_time';

  bool _isRamadanMode = false;
  TimeOfDay _suhoorTime = const TimeOfDay(hour: 4, minute: 30);
  TimeOfDay _iftarTime = const TimeOfDay(hour: 18, minute: 45);
  bool _isInitialized = false;

  bool get isRamadanMode => _isRamadanMode;
  TimeOfDay get suhoorTime => _suhoorTime;
  TimeOfDay get iftarTime => _iftarTime;
  bool get isInitialized => _isInitialized;

  /// Load persisted state from SharedPreferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isRamadanMode = prefs.getBool(_keyRamadanMode) ?? false;
      
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
}
