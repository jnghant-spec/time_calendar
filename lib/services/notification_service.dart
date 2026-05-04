import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:time_calendar/models/calendar_festival.dart';
import 'package:time_calendar/services/festival_service.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _kFestivalReminderKey = 'festival_reminder_enabled';

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(initSettings);

    final platform = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (platform != null) {
      await platform.requestNotificationsPermission();
    }

    final iosImpl = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  static Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kFestivalReminderKey) ?? true;
  }

  static Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFestivalReminderKey, enabled);
    if (enabled) {
      await scheduleUpcomingFestivalReminders();
    } else {
      await _notifications.cancelAll();
    }
  }

  static Future<void> scheduleUpcomingFestivalReminders() async {
    if (!await isReminderEnabled()) return;

    await _notifications.cancelAll();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final windowEnd = today.add(const Duration(days: 90));
    final subscribed = await _loadSubscribedIds();

    final months = <({int year, int month})>{};
    for (var i = 0; i <= 90; i++) {
      final d = today.add(Duration(days: i));
      months.add((year: d.year, month: d.month));
    }

    final upcoming = <CalendarFestival>[];
    for (final ym in months) {
      final festivals = FestivalService.getFestivalsForMonth(
        ym.year,
        ym.month,
        subscribedIds: subscribed,
      );
      for (final f in festivals) {
        final gd = DateTime(
          f.gregorianDate.year,
          f.gregorianDate.month,
          f.gregorianDate.day,
        );
        if (gd.isAfter(today) &&
            !gd.isAfter(windowEnd)) {
          upcoming.add(f);
        }
      }
    }

    upcoming.sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));
    final seen = <String>{};
    final unique = <CalendarFestival>[];
    for (final f in upcoming) {
      if (seen.add(f.id)) unique.add(f);
    }

    for (final f in unique) {
      final triggerDate = DateTime(
        f.gregorianDate.year,
        f.gregorianDate.month,
        f.gregorianDate.day,
        16,
        15,
      ).subtract(const Duration(days: 1));

      if (triggerDate.isAfter(now)) {
        await _scheduleNotification(
          id: f.id.hashCode,
          title: '明天是${f.name}',
          body: '记得关注明天的节日安排',
          scheduledDate: triggerDate,
        );
      }
    }

    // ignore: avoid_print
    print('推送调度完成，共 ${unique.length} 个节日');
    for (final f in unique) {
      final trigger = DateTime(
        f.gregorianDate.year,
        f.gregorianDate.month,
        f.gregorianDate.day,
        16,
        15,
      ).subtract(const Duration(days: 1));
      // ignore: avoid_print
      print('节日: ${f.name}, 计划推送时间: $trigger');
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'festival_channel',
          '节日提醒',
          channelDescription: '节日提前一天提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<Set<String>> _loadSubscribedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(FestivalSubscriptionPrefs.storageKey);
    if (jsonStr == null) {
      return FestivalService.kDefaultSubscribedIds;
    }
    try {
      final List<dynamic> ids = jsonDecode(jsonStr) as List<dynamic>;
      return ids.cast<String>().toSet();
    } catch (_) {
      return FestivalService.kDefaultSubscribedIds;
    }
  }
}
