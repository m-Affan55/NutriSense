import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'ramadan_controller.dart';

class ReminderManager {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  // Keys for SharedPreferences
  static const String keyAdaptiveReminders = 'notif_adaptive_reminders';
  static const String keyStreakAlerts = 'notif_streak_alerts';
  static const String keyRiskAlerts = 'notif_risk_alerts';
  static const String keyRamadanAlerts = 'notif_ramadan_alerts';

  // Learned meal timings (defaults in 24h format)
  static const String keyLearnedBreakfastHour = 'learned_breakfast_hour';
  static const String keyLearnedBreakfastMinute = 'learned_breakfast_minute';
  static const String keyLearnedLunchHour = 'learned_lunch_hour';
  static const String keyLearnedLunchMinute = 'learned_lunch_minute';
  static const String keyLearnedDinnerHour = 'learned_dinner_hour';
  static const String keyLearnedDinnerMinute = 'learned_dinner_minute';

  static Future<void> init() async {
    if (_isInitialized) return;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
      
      try {
        tz.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      } catch (_) {}
      
      await _notifications.initialize(
        settings: initSettings,
      );
    }

    _isInitialized = true;

    // Refresh and schedule smart reminders
    await syncRemindersWithMode();
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
    
    final iosImplementation = 
        _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Cancels all existing reminders and sets up either Ramadan or standard adaptive schedule
  static Future<void> syncRemindersWithMode() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    await _notifications.cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final ramadan = RamadanController.instance;
    final ramadanAlertsEnabled = prefs.getBool(keyRamadanAlerts) ?? ramadan.remindersEnabled;
    final streakAlertsEnabled = prefs.getBool(keyStreakAlerts) ?? true;

    if (ramadan.isRamadanMode && ramadanAlertsEnabled) {
      await _scheduleRamadanReminders(ramadan.suhoorTime, ramadan.iftarTime);
    } else {
      await _scheduleAdaptiveStandardReminders(prefs);
    }

    // Schedule evening Streak Saver notification (8:30 PM)
    if (streakAlertsEnabled) {
      await _scheduleStreakSaverAlert();
    }
  }

  /// Backward-compatible alias
  static Future<void> scheduleAllReminders() async {
    await syncRemindersWithMode();
  }

  /// 1. Adaptive Meal Timing Engine:
  /// Learns average logged meal times and schedules personalized reminders
  static Future<void> _scheduleAdaptiveStandardReminders(SharedPreferences prefs) async {
    final isAdaptive = prefs.getBool(keyAdaptiveReminders) ?? true;
    final language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';
    final isUrdu = language == 'ur';

    // Learned or default times
    int bHour = isAdaptive ? (prefs.getInt(keyLearnedBreakfastHour) ?? 9) : 9;
    int bMinute = isAdaptive ? (prefs.getInt(keyLearnedBreakfastMinute) ?? 0) : 0;

    int lHour = isAdaptive ? (prefs.getInt(keyLearnedLunchHour) ?? 13) : 13;
    int lMinute = isAdaptive ? (prefs.getInt(keyLearnedLunchMinute) ?? 30) : 30;

    int dHour = isAdaptive ? (prefs.getInt(keyLearnedDinnerHour) ?? 20) : 20;
    int dMinute = isAdaptive ? (prefs.getInt(keyLearnedDinnerMinute) ?? 30) : 30;

    final String bTimeStr = _format12Hour(bHour, bMinute);
    final String lTimeStr = _format12Hour(lHour, lMinute);
    final String dTimeStr = _format12Hour(dHour, dMinute);

    // Breakfast Alert
    await _notifications.zonedSchedule(
      id: 1,
      title: isUrdu ? '🍳 ناشتے کا وقت' : '🍳 Breakfast Time',
      body: isUrdu
          ? 'آپ عام طور پر $bTimeStr کے قریب ناشتہ کرتے ہیں۔ آج کا کھانا لاگ کرنا نہ بھولیں!'
          : 'You usually eat breakfast around $bTimeStr — don\'t forget to log your meal!',
      scheduledDate: _nextInstanceOfTime(bHour, bMinute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrisense_adaptive_meals',
          'NutriSense Adaptive Reminders',
          channelDescription: 'Personalized meal schedule reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Lunch Alert
    await _notifications.zonedSchedule(
      id: 2,
      title: isUrdu ? '🥗 دوپہر کا کھانا' : '🥗 Lunch Fuel Reminder',
      body: isUrdu
          ? 'آپ عام طور پر $lTimeStr کے قریب کھانا کھاتے ہیں۔ توانائی کے لیے اپنا لنچ لاگ کریں!'
          : 'You usually eat lunch around $lTimeStr — fuel your afternoon and log your meal!',
      scheduledDate: _nextInstanceOfTime(lHour, lMinute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrisense_adaptive_meals',
          'NutriSense Adaptive Reminders',
          channelDescription: 'Personalized meal schedule reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Dinner Alert
    await _notifications.zonedSchedule(
      id: 3,
      title: isUrdu ? '🍲 رات کا کھانا' : '🍲 Dinner Wrap-Up',
      body: isUrdu
          ? 'آپ عام طور پر $dTimeStr کے قریب کھانا کھاتے ہیں۔ اپنے دن کا آخری کھانا لاگ کریں!'
          : 'You usually eat dinner around $dTimeStr — wrap up your day and log your meal!',
      scheduledDate: _nextInstanceOfTime(dHour, dMinute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrisense_adaptive_meals',
          'NutriSense Adaptive Reminders',
          channelDescription: 'Personalized meal schedule reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Standard Hydration reminders (11 AM, 3 PM, 6 PM, 9 PM)
    final hydTimes = [
      const TimeOfDay(hour: 11, minute: 0),
      const TimeOfDay(hour: 15, minute: 0),
      const TimeOfDay(hour: 18, minute: 0),
      const TimeOfDay(hour: 21, minute: 0),
    ];
    for (int i = 0; i < hydTimes.length; i++) {
      await _notifications.zonedSchedule(
        id: 10 + i,
        title: isUrdu ? '💧 پانی پینے کا ہدف' : '💧 Hydration Check',
        body: isUrdu
          ? 'پانی پئیں اور صحت مند ہائیڈریشن کا ہدف برقرار رکھیں!'
          : 'Time for a glass of water to keep your metabolism active! 💧',
        scheduledDate: _nextInstanceOfTime(hydTimes[i].hour, hydTimes[i].minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'nutrisense_hydration',
            'NutriSense Hydration',
            channelDescription: 'Daily water intake reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// 2. Ramadan-specific schedule: Sehri countdown, Iftar alert, and post-fasting hydration
  static Future<void> _scheduleRamadanReminders(TimeOfDay suhoorTime, TimeOfDay iftarTime) async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';
    final isUrdu = language == 'ur';

    // 1. Suhoor Alert (30 mins before Suhoor ends)
    int suhoorAlertMinute = suhoorTime.minute - 30;
    int suhoorAlertHour = suhoorTime.hour;
    if (suhoorAlertMinute < 0) {
      suhoorAlertMinute += 60;
      suhoorAlertHour = (suhoorAlertHour - 1 + 24) % 24;
    }

    await _notifications.zonedSchedule(
      id: 101,
      title: isUrdu ? '🌙 سحری ختم ہونے والی ہے!' : '🌙 Sehri Ending Soon!',
      body: isUrdu
          ? 'سحری ختم ہونے میں 30 منٹ باقی ہیں! پانی پئیں اور اپنا کھانا مکمل کریں۔ 🍳💧'
          : '30 minutes left for Sehri! Drink water & complete your meal. 🍳💧',
      scheduledDate: _nextInstanceOfTime(suhoorAlertHour, suhoorAlertMinute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrisense_ramadan',
          'NutriSense Ramadan Alarms',
          channelDescription: 'Sehri, Iftar and fasting reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // 2. Iftar Alert (at Iftar time)
    await _notifications.zonedSchedule(
      id: 102,
      title: isUrdu ? '🌟 افطار مبارک!' : '🌟 Iftar Mubarak!',
      body: isUrdu
          ? 'افطار کا وقت ہو گیا ہے! کھجور اور پانی سے روزہ کھولیں۔ 🌴🥤'
          : 'Time to break your fast! Start with dates, water & fruit. 🌴🥤',
      scheduledDate: _nextInstanceOfTime(iftarTime.hour, iftarTime.minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrisense_ramadan',
          'NutriSense Ramadan Alarms',
          channelDescription: 'Sehri, Iftar and fasting reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // 3. Post-Iftar / Taraweeh Hydration (9:15 PM)
    await _notifications.zonedSchedule(
      id: 103,
      title: isUrdu ? '💧 رات کا ہائیڈریشن الرٹ' : '💧 Night Hydration',
      body: isUrdu
          ? 'افطار کے بعد 500ml پانی پئیں تاکہ جسم میں نمکیات کا توازن برقرار رہے۔'
          : 'Drink 500ml of water to replenish electrolytes during the eating window!',
      scheduledDate: _nextInstanceOfTime(21, 15),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrisense_ramadan',
          'NutriSense Ramadan Alarms',
          channelDescription: 'Sehri, Iftar and fasting reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // 4. Pre-Sleep Hydration (11:30 PM)
    await _notifications.zonedSchedule(
      id: 104,
      title: isUrdu ? '💧 سونے سے پہلے پانی کا چیک' : '💧 Pre-Bed Water Check',
      body: isUrdu
          ? 'سونے سے پہلے پانی پئیں تاکہ کل کا روزہ آسان ہو۔'
          : 'Stay hydrated before sleeping to make tomorrow\'s fast easier.',
      scheduledDate: _nextInstanceOfTime(23, 30),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrisense_ramadan',
          'NutriSense Ramadan Alarms',
          channelDescription: 'Sehri, Iftar and fasting reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 3. Streak Milestone Notification:
  /// Triggered immediately upon logging a meal when a streak milestone is reached
  static Future<void> triggerStreakMilestoneNotification(int streakDays) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(keyStreakAlerts) ?? true;
    if (!enabled) return;

    final language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';
    final isUrdu = language == 'ur';

    final String title = isUrdu
        ? '🔥 $streakDays دن کا لاگنگ اسٹریک!'
        : '🔥 $streakDays-Day Logging Streak!';
    final String body = isUrdu
        ? 'زبردست کارکردگی! آپ مستقل مزاجی سے اپنے اہداف حاصل کر رہے ہیں۔ کل بھی اسٹریک برقرار رکھیں!'
        : 'You\'re on fire! Keep this momentum going to reach your nutrition targets!';

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _notifications.show(
        id: 201,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'nutrisense_streaks',
            'NutriSense Streak Milestones',
            channelDescription: 'Celebratory streak milestone notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  /// 4. Evening Streak Saver Notification (Scheduled for 8:30 PM):
  static Future<void> _scheduleStreakSaverAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';
    final isUrdu = language == 'ur';

    await _notifications.zonedSchedule(
      id: 202,
      title: isUrdu ? '⚡ اسٹریک برقرار رکھیں!' : '⚡ Don\'t Lose Your Streak!',
      body: isUrdu
          ? 'آج کا کھانا لاگ کرنا نہ بھولیں تاکہ آپ کا لاگنگ اسٹریک جاری رہے۔'
          : 'Log your evening meal and hydration before midnight to keep your daily streak alive!',
      scheduledDate: _nextInstanceOfTime(20, 30),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrisense_streaks',
          'NutriSense Streak Milestones',
          channelDescription: 'Streak reminder alerts',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 5. AI Coach Risk-Based Alert:
  /// Triggered immediately when AI detects medical / clinical dietary safety risks
  static Future<void> showRiskAlert({
    required String title,
    required String message,
    String level = 'warning',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(keyRiskAlerts) ?? true;
    if (!enabled) return;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _notifications.show(
        id: 301,
        title: '🚨 $title',
        body: message,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'nutrisense_risk_alerts',
            'NutriSense Clinical Risk Alerts',
            channelDescription: 'High-priority clinical health & dietary safety warnings',
            importance: level == 'critical' ? Importance.max : Importance.high,
            priority: level == 'critical' ? Priority.max : Priority.high,
            color: level == 'critical' ? const Color(0xFFFF3B30) : const Color(0xFFFF9500),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  }

  /// 6. Auto-learn meal timing from recent meal log entry:
  static Future<void> recordMealLogged(String mealType, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final type = mealType.toLowerCase();

    if (type.contains('breakfast') || type.contains('sehri') || type.contains('suhoor')) {
      final currentH = prefs.getInt(keyLearnedBreakfastHour) ?? 9;
      // Exponential moving average for smooth adaptation
      final newH = ((currentH * 2 + time.hour) / 3).round();
      await prefs.setInt(keyLearnedBreakfastHour, newH);
      await prefs.setInt(keyLearnedBreakfastMinute, time.minute);
    } else if (type.contains('lunch')) {
      final currentH = prefs.getInt(keyLearnedLunchHour) ?? 13;
      final newH = ((currentH * 2 + time.hour) / 3).round();
      await prefs.setInt(keyLearnedLunchHour, newH);
      await prefs.setInt(keyLearnedLunchMinute, time.minute);
    } else if (type.contains('dinner') || type.contains('iftar')) {
      final currentH = prefs.getInt(keyLearnedDinnerHour) ?? 20;
      final newH = ((currentH * 2 + time.hour) / 3).round();
      await prefs.setInt(keyLearnedDinnerHour, newH);
      await prefs.setInt(keyLearnedDinnerMinute, time.minute);
    }

    // Refresh scheduled reminders with newly learned timing
    await syncRemindersWithMode();
  }

  /// 7. Check and update daily streak
  static Future<void> updateAndCheckStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = "\${now.year}-\${now.month.toString().padLeft(2, '0')}-\${now.day.toString().padLeft(2, '0')}";
    final lastLogDateStr = prefs.getString('last_streak_date');

    if (lastLogDateStr == todayStr) {
      // Already logged today, don't increment streak
      return;
    }

    int currentStreak = prefs.getInt('user_current_streak') ?? 4; // Hackathon default fallback

    if (lastLogDateStr != null) {
      final parts = lastLogDateStr.split('-');
      if (parts.length == 3) {
        final lastDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final todayDate = DateTime(now.year, now.month, now.day);
        final difference = todayDate.difference(lastDate).inDays;

        if (difference == 1) {
          currentStreak += 1;
        } else if (difference > 1) {
          currentStreak = 1;
        }
      } else {
        currentStreak += 1;
      }
    } else {
      currentStreak += 1;
    }

    if (currentStreak <= 0) currentStreak = 1;

    await prefs.setInt('user_current_streak', currentStreak);
    await prefs.setString('last_streak_date', todayStr);

    if (currentStreak % 3 == 0 || currentStreak == 5 || currentStreak == 7 || currentStreak == 10 || currentStreak == 14 || currentStreak == 30) {
      await triggerStreakMilestoneNotification(currentStreak);
    }
  }

  static String _format12Hour(int hour, int minute) {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }
}
