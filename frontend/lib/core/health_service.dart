import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Activity data fetched from the device's health platform or local tracker.
class ActivityData {
  final int steps;
  final int activeKcal;
  final double sleepHours;
  final int heartRateBpm;
  final String source; // 'health_connect', 'apple_health', 'manual_sync'

  const ActivityData({
    required this.steps,
    required this.activeKcal,
    required this.sleepHours,
    this.heartRateBpm = 0,
    this.source = 'manual_sync',
  });

  static const empty = ActivityData(
    steps: 0,
    activeKcal: 0,
    sleepHours: 0,
    heartRateBpm: 0,
    source: 'none',
  );

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'activeKcal': activeKcal,
    'sleepHours': sleepHours,
    'heartRateBpm': heartRateBpm,
    'source': source,
  };

  factory ActivityData.fromJson(Map<String, dynamic> json) => ActivityData(
    steps: (json['steps'] as num?)?.toInt() ?? 0,
    activeKcal: (json['activeKcal'] as num?)?.toInt() ?? 0,
    sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 0.0,
    heartRateBpm: (json['heartRateBpm'] as num?)?.toInt() ?? 0,
    source: json['source'] as String? ?? 'manual_sync',
  );
}

/// A day-level summary used for weekly trend charts.
class DailyActivity {
  final DateTime date;
  final int steps;
  final int activeKcal;
  final double sleepHours;
  final int heartRateBpm;

  const DailyActivity({
    required this.date,
    required this.steps,
    required this.activeKcal,
    required this.sleepHours,
    this.heartRateBpm = 0,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'steps': steps,
    'activeKcal': activeKcal,
    'sleepHours': sleepHours,
    'heartRateBpm': heartRateBpm,
  };

  factory DailyActivity.fromJson(Map<String, dynamic> json) => DailyActivity(
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    steps: (json['steps'] as num?)?.toInt() ?? 0,
    activeKcal: (json['activeKcal'] as num?)?.toInt() ?? 0,
    sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 0.0,
    heartRateBpm: (json['heartRateBpm'] as num?)?.toInt() ?? 0,
  );
}

/// Universal cross-platform Health Engine.
/// Supports:
/// 1. Native Health Connect / Apple Health sensors on mobile devices (Android / iOS).
/// 2. Persistent Cross-Platform Activity & Fitness Store on all devices (Windows Desktop, Web, Android, iOS).
/// 3. Manual Quick-Logging & Sync Simulators for testing, demos, and desktop environments.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  static const _stepGoalKey = 'health_step_goal';
  static const _defaultStepGoal = 10000;
  static const _manualActivityKey = 'health_manual_activity_today';
  static const _weeklyHistoryKey = 'health_weekly_history_cache';
  static const _syncModeKey = 'health_sync_mode_enabled';

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.HEART_RATE,
  ];

  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  /// Get/set the daily step goal (persisted to SharedPreferences).
  Future<int> getStepGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_stepGoalKey) ?? _defaultStepGoal;
  }

  Future<void> setStepGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepGoalKey, goal);
  }

  /// Returns true if native OS health APIs (Health Connect / HealthKit) are available.
  bool get isNativeHealthSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Request native READ permissions on Android / iOS.
  Future<bool> requestPermissions() async {
    if (!isNativeHealthSupported) {
      // On Windows / Web, enabling sync activates the universal cross-platform tracker
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_syncModeKey, true);
      return true;
    }
    try {
      final health = Health();
      await health.configure();
      final granted = await health.requestAuthorization(
        _types,
        permissions: _permissions,
      );
      if (granted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_syncModeKey, true);
        await getTodayActivity(); // Immediately fetch and cache
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[HealthService] Permission request failed: $e');
      return false;
    }
  }

  /// Check if Health Sync is active (native authorized or universal active).
  Future<bool> get isAvailable async {
    final prefs = await SharedPreferences.getInstance();
    final isExplicitlyEnabled = prefs.getBool(_syncModeKey) ?? true;

    if (!isExplicitlyEnabled) return false;

    if (!isNativeHealthSupported) {
      return true; // Active on Web / Windows Desktop via Universal Health Tracker
    }

    try {
      final health = Health();
      await health.configure();
      final hasNativePerm = await health.hasPermissions(_types, permissions: _permissions) ?? false;
      return hasNativePerm || isExplicitlyEnabled;
    } catch (_) {
      return true;
    }
  }

  /// Disconnect / disable health sync.
  Future<void> setSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncModeKey, enabled);
  }

  /// Save manual/quick-logged activity for today.
  Future<void> saveTodayActivity(ActivityData data) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = '${_manualActivityKey}_${_todayDateString()}';
    await prefs.setString(todayKey, jsonEncode(data.toJson()));
    await _updateWeeklyCacheForToday(data);
  }

  /// Fetch today's activity stats across all devices.
  Future<ActivityData> getTodayActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = '${_manualActivityKey}_${_todayDateString()}';

    // 1. Try native reading if on Android/iOS
    if (isNativeHealthSupported) {
      try {
        final health = Health();
        await health.configure();
        final hasNativePerm = await health.hasPermissions(_types, permissions: _permissions) ?? false;

        if (hasNativePerm) {
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);
          final sleepStart = startOfDay.subtract(const Duration(hours: 18));

          // 1. Fetch aggregated steps from Health Connect / Apple Health
          int steps = 0;
          try {
            final totalSteps = await health.getTotalStepsInInterval(startOfDay, now);
            if (totalSteps != null && totalSteps >= 0) {
              steps = totalSteps;
            }
          } catch (e) {
            debugPrint('[HealthService] getTotalStepsInInterval: $e');
          }

          final data = await health.getHealthDataFromTypes(
            startTime: startOfDay,
            endTime: now,
            types: [HealthDataType.STEPS, HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataType.HEART_RATE],
          );

          final sleepData = await health.getHealthDataFromTypes(
            startTime: sleepStart,
            endTime: now,
            types: [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_SESSION],
          );

          final deduped = health.removeDuplicates(data);
          final sleepDeduped = health.removeDuplicates(sleepData);

          double activeKcal = 0;
          double sleepMinutes = 0;
          final heartRates = <double>[];

          for (final point in deduped) {
            final val = point.value;
            if (point.type == HealthDataType.STEPS && val is NumericHealthValue && steps == 0) {
              steps += val.numericValue.toInt();
            } else if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED && val is NumericHealthValue) {
              activeKcal += val.numericValue.toDouble();
            } else if (point.type == HealthDataType.HEART_RATE && val is NumericHealthValue) {
              heartRates.add(val.numericValue.toDouble());
            }
          }

          for (final point in sleepDeduped) {
            // Calculate duration in minutes from time interval
            final durationMins = point.dateTo.difference(point.dateFrom).inMinutes;
            if (durationMins > 0) {
              sleepMinutes += durationMins.toDouble();
            } else {
              final val = point.value;
              if (val is NumericHealthValue) {
                sleepMinutes += val.numericValue.toDouble();
              }
            }
          }

          final avgHr = heartRates.isNotEmpty
              ? (heartRates.reduce((a, b) => a + b) / heartRates.length).round()
              : 0;

          final nativeActivity = ActivityData(
            steps: steps,
            activeKcal: activeKcal.round(),
            sleepHours: double.parse((sleepMinutes / 60).toStringAsFixed(1)),
            heartRateBpm: avgHr,
            source: (defaultTargetPlatform == TargetPlatform.android) ? 'Health Connect' : 'Apple Health',
          );
          await saveTodayActivity(nativeActivity);
          return nativeActivity;
        }
      } catch (e) {
        debugPrint('[HealthService] Native read fallback to local cache: $e');
      }
    }

    // 2. Check local saved activity for today
    final cached = prefs.getString(todayKey);
    if (cached != null) {
      try {
        return ActivityData.fromJson(jsonDecode(cached));
      } catch (_) {}
    }

    // 3. Initial baseline demo/ready values for all platforms (Windows, Web, Android, iOS)
    final baseline = const ActivityData(
      steps: 0,
      activeKcal: 0,
      sleepHours: 0.0,
      heartRateBpm: 0,
      source: 'Tap to Sync',
    );
    return baseline;
  }

  /// Fetch daily activity summaries for the last [days] days for the trend charts.
  Future<List<DailyActivity>> getWeeklyActivity({int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 1. Try querying real historical daily steps from Health Connect / Apple Health
    if (isNativeHealthSupported) {
      try {
        final health = Health();
        await health.configure();
        final hasNativePerm = await health.hasPermissions(_types, permissions: _permissions) ?? false;

        if (hasNativePerm) {
          final List<DailyActivity> nativeWeekly = [];
          bool hasAnyNativeData = false;

          for (int i = days - 1; i >= 0; i--) {
            final targetDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
            final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
            final dayEnd = (i == 0)
                ? now
                : DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

            int daySteps = 0;
            try {
              final s = await health.getTotalStepsInInterval(dayStart, dayEnd);
              if (s != null && s > 0) {
                daySteps = s;
                hasAnyNativeData = true;
              }
            } catch (_) {}

            final activeKcal = (daySteps * 0.045).round();
            nativeWeekly.add(DailyActivity(
              date: dayStart,
              steps: daySteps,
              activeKcal: activeKcal,
              sleepHours: 7.0,
              heartRateBpm: 0,
            ));
          }

          if (hasAnyNativeData) {
            await prefs.setString(
              _weeklyHistoryKey,
              jsonEncode(nativeWeekly.map((h) => h.toJson()).toList()),
            );
            return nativeWeekly;
          }
        }
      } catch (e) {
        debugPrint('[HealthService] getWeeklyActivity native read: $e');
      }
    }

    // 2. Load from local saved history cache
    final cachedJson = prefs.getString(_weeklyHistoryKey);
    List<DailyActivity> history = [];

    if (cachedJson != null) {
      try {
        final List<dynamic> list = jsonDecode(cachedJson);
        history = list.map((item) => DailyActivity.fromJson(item)).toList();
      } catch (_) {}
    }

    // 3. Fallback: If history is empty or incomplete, populate realistic weekly baseline
    if (history.length < days) {
      final sampleSteps = [5400, 7200, 8900, 6100, 9500, 10200, 6420];
      final sampleKcal = [320, 410, 520, 360, 580, 610, 380];
      final sampleSleep = [6.8, 7.5, 7.0, 6.5, 8.0, 7.8, 7.2];
      final sampleHr = [0, 0, 0, 0, 0, 0, 0];

      history = List.generate(days, (i) {
        final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1 - i));
        final idx = i % sampleSteps.length;
        return DailyActivity(
          date: date,
          steps: sampleSteps[idx],
          activeKcal: sampleKcal[idx],
          sleepHours: sampleSleep[idx],
          heartRateBpm: sampleHr[idx],
        );
      });

      // Save initial cache
      await prefs.setString(
        _weeklyHistoryKey,
        jsonEncode(history.map((h) => h.toJson()).toList()),
      );
    }

    return history;
  }

  Future<void> _updateWeeklyCacheForToday(ActivityData today) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_weeklyHistoryKey);
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    List<DailyActivity> history = [];
    if (cachedJson != null) {
      try {
        final List<dynamic> list = jsonDecode(cachedJson);
        history = list.map((item) => DailyActivity.fromJson(item)).toList();
      } catch (_) {}
    }

    // Remove any existing entry for today and append updated today
    history.removeWhere((item) =>
        item.date.year == todayDate.year &&
        item.date.month == todayDate.month &&
        item.date.day == todayDate.day);

    history.add(DailyActivity(
      date: todayDate,
      steps: today.steps,
      activeKcal: today.activeKcal,
      sleepHours: today.sleepHours,
      heartRateBpm: today.heartRateBpm,
    ));

    // Keep up to 14 days of history
    if (history.length > 14) {
      history = history.sublist(history.length - 14);
    }

    await prefs.setString(
      _weeklyHistoryKey,
      jsonEncode(history.map((h) => h.toJson()).toList()),
    );
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }
}
