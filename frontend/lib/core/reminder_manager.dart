import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderManager {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Return early if not on a mobile platform (e.g., Windows desktop or Web)
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    try {
      tz.initializeTimeZones();
      // Setup local location timezone fallback
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    } catch (_) {}
    
    await _notifications.initialize(
      settings: initSettings,
    );
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

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

  static Future<void> scheduleDailyBreakfastReminder() async {
    await _notifications.zonedSchedule(
      id: 1,
      title: 'Breakfast Reminder',
      body: 'Time to log your healthy breakfast! 🍳',
      scheduledDate: _nextInstanceOfTime(9, 0), // 9:00 AM
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrisense_reminders',
          'NutriSense Reminders',
          channelDescription: 'Daily meal logging alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleDailyLunchReminder() async {
    await _notifications.zonedSchedule(
      id: 2,
      title: 'Lunch Reminder',
      body: 'Fuel your afternoon! Time to log your lunch. 🥗',
      scheduledDate: _nextInstanceOfTime(13, 30), // 1:30 PM
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrisense_reminders',
          'NutriSense Reminders',
          channelDescription: 'Daily meal logging alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleDailyDinnerReminder() async {
    await _notifications.zonedSchedule(
      id: 3,
      title: 'Dinner Reminder',
      body: 'Wrap up your day! Don\'t forget to log your dinner. 🍲',
      scheduledDate: _nextInstanceOfTime(20, 30), // 8:30 PM
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrisense_reminders',
          'NutriSense Reminders',
          channelDescription: 'Daily meal logging alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleDailyHydrationReminders() async {
    final times = [
      _Time(11, 0),
      _Time(15, 0),
      _Time(18, 0),
      _Time(21, 0),
    ];
    
    for (int i = 0; i < times.length; i++) {
      await _notifications.zonedSchedule(
        id: 10 + i,
        title: 'Hydration Reminder',
        body: 'Time to drink some water and log your progress! 💧',
        scheduledDate: _nextInstanceOfTime(times[i].hour, times[i].minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'nutrisense_hydration',
            'NutriSense Hydration',
            channelDescription: 'Daily water intake reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> cancelAllReminders() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    await _notifications.cancelAll();
  }

  static Future<void> scheduleAllReminders() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    await cancelAllReminders();
    await scheduleDailyBreakfastReminder();
    await scheduleDailyLunchReminder();
    await scheduleDailyDinnerReminder();
    await scheduleDailyHydrationReminders();
  }
}

class _Time {
  final int hour;
  final int minute;
  _Time(this.hour, this.minute);
}
