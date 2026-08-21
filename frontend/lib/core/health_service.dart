import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Activity data fetched from the device's health platform.
class ActivityData {
  final int steps;
  final int activeKcal;
  final double sleepHours;
  const ActivityData({
    required this.steps,
    required this.activeKcal,
    required this.sleepHours,
  });

  static const empty = ActivityData(steps: 0, activeKcal: 0, sleepHours: 0);
}

/// Wraps the `health` Flutter package to read from Health Connect (Android)
/// or Apple Health (iOS) — read-only, no writes to the health platform.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
  ];

  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  /// Request READ permissions. Returns true if granted.
  /// This will also prompt the user to install Health Connect if needed on Android 13-.
  Future<bool> requestPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    try {
      final health = Health();
      await health.configure();
      final granted = await health.requestAuthorization(
        _types,
        permissions: _permissions,
      );
      return granted;
    } catch (e) {
      debugPrint('[HealthService] Permission request failed: $e');
      return false;
    }
  }

  /// Check if Health Connect / Apple Health is installed and authorized.
  Future<bool> get isAvailable async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    try {
      final health = Health();
      await health.configure();
      return await health.hasPermissions(_types, permissions: _permissions) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Fetch today's activity stats. Returns [ActivityData.empty] on any failure.
  Future<ActivityData> getTodayActivity() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return ActivityData.empty;
    try {
      final authorized = await isAvailable;
      if (!authorized) {
        final granted = await requestPermissions();
        if (!granted) return ActivityData.empty;
      }

      final health = Health();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      // Sleep window: midnight to now covers last night's logged sleep
      final sleepStart = startOfDay.subtract(const Duration(hours: 12));

      final data = await health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: now,
        types: [HealthDataType.STEPS, HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      final sleepData = await health.getHealthDataFromTypes(
        startTime: sleepStart,
        endTime: now,
        types: [HealthDataType.SLEEP_ASLEEP],
      );

      // De-duplicate (Health Connect may return overlapping intervals)
      final deduped = health.removeDuplicates(data);
      final sleepDeduped = health.removeDuplicates(sleepData);

      int steps = 0;
      double activeKcal = 0;
      double sleepMinutes = 0;

      for (final point in deduped) {
        final val = point.value;
        if (point.type == HealthDataType.STEPS && val is NumericHealthValue) {
          steps += val.numericValue.toInt();
        } else if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED &&
            val is NumericHealthValue) {
          activeKcal += val.numericValue.toDouble();
        }
      }

      for (final point in sleepDeduped) {
        final val = point.value;
        if (val is NumericHealthValue) {
          sleepMinutes += val.numericValue.toDouble();
        }
      }

      return ActivityData(
        steps: steps,
        activeKcal: activeKcal.round(),
        sleepHours: double.parse((sleepMinutes / 60).toStringAsFixed(1)),
      );
    } catch (e) {
      debugPrint('[HealthService] getTodayActivity failed: $e');
      return ActivityData.empty;
    }
  }
}
