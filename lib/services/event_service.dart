import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/services/event_usage_service.dart';
import 'package:time_calendar/services/membership_service.dart';

/// 清单/日历提醒事项的本地持久化（SharedPreferences）。
class EventService {
  EventService._();

  static const String prefsKey = 'list_reminder_events_v1';

  static Future<List<ListEvent>> loadAllEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          ListEvent.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAllEvents(List<ListEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
    EventUsageService.updateCount(events.length);
  }

  /// 清空提醒事项及会员归档残留。
  static Future<void> clearAllEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    await MembershipService.clearArchivedEventIds();
    EventUsageService.updateCount(0);
  }

  /// 写入 7 条 2026-06-05 测试提醒并持久化。
  static Future<List<ListEvent>> seedJune5Events() async {
    final events = buildJune5TestEvents();
    await saveAllEvents(events);
    return events;
  }

  /// 重置：先清空再写入六月五日测试集。
  static Future<List<ListEvent>> resetToJune5TestEvents() async {
    await clearAllEvents();
    return seedJune5Events();
  }

  static List<ListEvent> buildJune5TestEvents() {
    final d = kListEventJune5TestDate;
    return [
      ListEvent(
        id: 'j5_birthday',
        title: '好友生日',
        baseDate: d,
        tagId: 'birthday',
        isPinned: true,
        repeatRule: EventRepeatRule.yearly,
        reminderType: EventReminderType.advanceAndSameDay,
        advanceDaysOption: EventAdvanceDaysOption.oneDay,
        advanceTimeHm: '08:00',
        sameDayTimeHm: '09:00',
        note: '订蛋糕',
      ),
      ListEvent(
        id: 'j5_partner',
        title: '纪念日晚餐',
        baseDate: d,
        tagId: 'partner',
        repeatRule: EventRepeatRule.yearly,
        reminderType: EventReminderType.advanceAndSameDay,
        advanceDaysOption: EventAdvanceDaysOption.threeDays,
        advanceTimeHm: '09:00',
        sameDayTimeHm: '18:30',
        note: '预定餐厅',
      ),
      ListEvent(
        id: 'j5_goal',
        title: '季度OKR复盘',
        baseDate: d,
        tagId: 'goal',
        isPinned: true,
        repeatRule: EventRepeatRule.none,
        reminderType: EventReminderType.advanceAndSameDay,
        advanceDaysOption: EventAdvanceDaysOption.oneWeek,
        advanceTimeHm: '09:00',
        sameDayTimeHm: '14:00',
        note: '准备汇报材料',
      ),
      ListEvent(
        id: 'j5_idol',
        title: '偶像空降直播',
        baseDate: d,
        tagId: 'idol',
        repeatRule: EventRepeatRule.none,
        reminderType: EventReminderType.sameDayOnly,
        sameDayTimeHm: '20:00',
        note: '备好应援灯牌',
      ),
      ListEvent(
        id: 'j5_weekly',
        title: '团队周会',
        baseDate: d,
        tagId: 'goal',
        isPinned: true,
        repeatRule: EventRepeatRule.weekly,
        reminderType: EventReminderType.advanceAndSameDay,
        advanceDaysOption: EventAdvanceDaysOption.oneDay,
        advanceTimeHm: '09:00',
        sameDayTimeHm: '10:00',
        note: '带好电脑',
      ),
      ListEvent(
        id: 'j5_card',
        title: '还信用卡',
        baseDate: d,
        tagId: 'partner',
        repeatRule: EventRepeatRule.monthly,
        reminderType: EventReminderType.advanceOnly,
        advanceDaysOption: EventAdvanceDaysOption.oneDay,
        advanceTimeHm: '09:00',
        sameDayTimeHm: '11:00',
        note: '核对本期账单',
      ),
      ListEvent(
        id: 'j5_run',
        title: '晨跑打卡',
        baseDate: d,
        tagId: 'goal',
        repeatRule: EventRepeatRule.daily,
        reminderType: EventReminderType.sameDayOnly,
        sameDayTimeHm: '07:00',
        note: '带好跑鞋',
      ),
    ];
  }
}
