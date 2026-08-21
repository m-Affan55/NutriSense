import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'ramadan_controller.dart';

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
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    } catch (_) {}
    
    await _notifications.initialize(
      settings: initSettings,
    );

    // Initial schedule based on active mode
    await syncRemindersWithMode();
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

  /// Cancels all existing reminders and sets up either Ramadan or standard schedule
  static Future<void> syncRemindersWithMode() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    await _notifications.cancelAll();

    final ramadan = RamadanController.instance;
    if (ramadan.isRamadanMode && ramadan.remindersEnabled) {
      await _scheduleRamadanReminders(ramadan.suhoorTime, ramadan.iftarTime);
    } else {
      await _scheduleStandardReminders();
    }
  }

  /// Backward-compatible alias for initializing/refreshing all scheduled reminders
  static Future<void> scheduleAllReminders() async {
    await syncRemindersWithMode();
  }

  /// Ramadan-specific schedules: Sehri countdown, Iftar alert, and post-fasting hydration
  static Future<void> _scheduleRamadanReminders(TimeOfDay suhoorTime, TimeOfDay iftarTime) async {
    // 1. Suhoor Alert (30 mins before Suhoor ends)
    int suhoorAlertMinute = suhoorTime.minute - 30;
    int suhoorAlertHour = suhoorTime.hour;
    if (suhoorAlertMinute < 0) {
      suhoorAlertMinute += 60;
      suhoorAlertHour = (suhoorAlertHour - 1 + 24) % 24;
    }

    await _notifications.zonedSchedule(
      id: 101,
      title: '🌙 Sehri Ending Soon!',
      body: '30 minutes left for Sehri! Drink water & complete your meal. 🍳💧',
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
      title: '🌟 Iftar Mubarak!',
      body: 'Time to break your fast! Start with dates, water & fruit. 🌴🥤',
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
      title: '💧 Night Hydration',
      body: 'Drink 500ml of water to replenish during the non-fasting window!',
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
      title: '💧 Pre-Bed Water Check',
      body: 'Stay hydrated before sleeping to make tomorrow\'s fast easier.',
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

  /// Standard non-fasting reminders
  static Future<void> _scheduleStandardReminders() async {
    // Breakfast
    await _notifications.zonedSchedule(
      id: 1,
      title: 'Breakfast Reminder',
      body: 'Time to log your healthy breakfast! 🍳',
      scheduledDate: _nextInstanceOfTime(9, 0),
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

    // Lunch
    await _notifications.zonedSchedule(
      id: 2,
      title: 'Lunch Reminder',
      body: 'Fuel your afternoon! Time to log your lunch. 🥗',
      scheduledDate: _nextInstanceOfTime(13, 30),
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

    // Dinner
    await _notifications.zonedSchedule(
      id: 3,
      title: 'Dinner Reminder',
      body: 'Wrap up your day! Don\'t forget to log your dinner. 🍲',
      scheduledDate: _nextInstanceOfTime(20, 30),
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

    // Standard Hydration reminders
    final times = [
      const TimeOfDay(hour: 11, minute: 0),
      const TimeOfDay(hour: 15, minute: 0),
      const TimeOfDay(hour: 18, minute: 0),
      const TimeOfDay(hour: 21, minute: 0),
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
}
