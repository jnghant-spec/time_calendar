import 'package:flutter/material.dart';
import 'package:time_calendar/models/calendar_festival.dart';
import 'package:time_calendar/models/list_event.dart';

// TODO(lunar_calendar): 农历文案 [lunarLabel] 当前为 UI 占位。接入 `lunar_calendar`（或同等能力包）后，
// 请根据 [calendarDate] 对应的「上海日历日」换算农历并注入展示，替换模板中的静态字符串。

class CalendarDayCellData {
  const CalendarDayCellData({
    required this.dayNumber,
    required this.lunarLabel,
    this.calendarDate,
    this.isCurrentMonth = true,
    this.isSelected = false,
    this.isToday = false,
    this.markerColors = const [],
  });

  final String dayNumber;
  final String lunarLabel;
  /// 该单元格对应的公历日期；用于点击选中与事件过滤。
  final DateTime? calendarDate;
  final bool isCurrentMonth;
  final bool isSelected;
  /// 是否为「上海」当前日历日（与 [isSelected] 可同时为 true，选中态优先绘制）。
  final bool isToday;
  final List<Color> markerColors;
}

class EventReminderData {
  const EventReminderData({
    required this.id,
    required this.eventDate,
    required this.dateText,
    required this.title,
    required this.daysRemaining,
    required this.accentColor,
    required this.tagId,
    this.isPinned = false,
    this.repeatRule,
    this.reminderType,
    this.advanceDaysOption,
    this.advanceTimeHm,
    this.sameDayTimeHm,
    this.isLunarDate,
    this.isLunarRecurring,
    this.sourceListEvent,
    this.isFestival = false,
    this.festivalCategoryKey,
    this.festivalCategory,
    this.festivalLunarLine,
    this.festivalEthnicLine,
    this.festivalReligiousLine,
    this.festivalDescription,
  });

  factory EventReminderData.forTimeline(
    ListEvent source, {
    required DateTime effectiveSolarDate,
    required String dateText,
    required int daysRemaining,
    required Color accentColor,
  }) {
    return EventReminderData(
      id: source.id,
      eventDate: effectiveSolarDate,
      dateText: dateText,
      title: source.title,
      daysRemaining: daysRemaining,
      accentColor: accentColor,
      tagId: source.tagId,
      isPinned: source.isPinned,
      repeatRule: source.repeatRule,
      reminderType: source.reminderType,
      advanceDaysOption: source.advanceDaysOption,
      advanceTimeHm: source.advanceTimeHm,
      sameDayTimeHm: source.sameDayTimeHm,
      isLunarDate: source.isLunarDate,
      isLunarRecurring: source.isLunarRecurring,
      sourceListEvent: source,
    );
  }

  factory EventReminderData.forFestival(
    CalendarFestival f, {
    required DateTime today,
    required String dateText,
  }) {
    final ed = DateTime(f.gregorianDate.year, f.gregorianDate.month, f.gregorianDate.day);
    final todayD = DateTime(today.year, today.month, today.day);
    final daysRemaining = ed.difference(todayD).inDays;
    return EventReminderData(
      id: 'festival_${f.id}_${ed.year}_${ed.month}_${ed.day}',
      eventDate: ed,
      dateText: dateText,
      title: f.name,
      daysRemaining: daysRemaining,
      accentColor: f.color,
      tagId: '',
      isFestival: true,
      festivalCategoryKey: f.category,
      festivalLunarLine: f.lunarDate,
      festivalEthnicLine: f.ethnicCalendar,
      festivalReligiousLine: f.religiousCalendar,
      sourceListEvent: null,
      festivalCategory: _festivalTimelineCategoryLabel(f),
      festivalDescription: f.description,
    );
  }

  /// 时间线卡片右侧标签文案（民族 / 宗教为具体名称）；详情中公历 / 农历仍用「节日来源」。
  static String _festivalTimelineCategoryLabel(CalendarFestival f) {
    switch (f.category) {
      case 'gregorian':
        return '公历节日';
      case 'lunar':
        return '农历节日';
      case 'ethnic':
        final s = f.sourceLabel?.trim();
        return (s != null && s.isNotEmpty) ? s : '民族节日';
      case 'religious':
        final s = f.sourceLabel?.trim();
        return (s != null && s.isNotEmpty) ? s : '宗教节日';
      default:
        return '节日';
    }
  }

  /// 事件发生日（仅比较年月日）。
  final DateTime eventDate;
  final String dateText;
  final String title;
  final int daysRemaining;
  final Color accentColor;
  final bool isPinned;

  final String id;
  /// 用户事件对应 [ListEvent.tagId]；节日行为空字符串。
  final String tagId;

  final EventRepeatRule? repeatRule;
  final EventReminderType? reminderType;
  final EventAdvanceDaysOption? advanceDaysOption;
  final String? advanceTimeHm;
  final String? sameDayTimeHm;
  final bool? isLunarDate;
  final bool? isLunarRecurring;

  /// 时间线由 [ListEvent] 转换而来时保留原件，供详情 Sheet 使用。
  final ListEvent? sourceListEvent;

  /// 日历页节日行（非用户事件）。
  final bool isFestival;

  /// `gregorian` / `lunar` / `ethnic` / `religious`
  final String? festivalCategoryKey;

  /// 展示用类别文案，如「公历节日」「农历节日」。
  final String? festivalCategory;
  final String? festivalLunarLine;
  final String? festivalEthnicLine;
  final String? festivalReligiousLine;

  /// 民族 / 宗教节日 JSON `description`，供详情「节日简介」。
  final String? festivalDescription;

  /// 供详情 Sheet 等与清单页共用 [ListEvent] 语义。
  ListEvent toListEvent() {
    if (isFestival) {
      throw UnsupportedError('Festival timeline rows cannot convert to ListEvent');
    }
    if (sourceListEvent != null) return sourceListEvent!;
    return ListEvent(
      id: id,
      title: title,
      baseDate: DateTime(eventDate.year, eventDate.month, eventDate.day),
      tagId: tagId,
      isPinned: isPinned,
      isLunarRecurring: isLunarRecurring ?? false,
      repeatRule: repeatRule ?? EventRepeatRule.none,
      reminderType: reminderType ?? EventReminderType.sameDayOnly,
      advanceDaysOption: advanceDaysOption ?? EventAdvanceDaysOption.oneDay,
      advanceTimeHm: advanceTimeHm ?? '09:00',
      sameDayTimeHm: sameDayTimeHm ?? '09:00',
      isLunarDate: isLunarDate ?? false,
    );
  }
}
