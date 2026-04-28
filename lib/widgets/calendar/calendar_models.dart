import 'package:flutter/material.dart';

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
    required this.eventDate,
    required this.dateText,
    required this.title,
    required this.daysRemaining,
    required this.accentColor,
    this.isPinned = false,
  });

  /// 事件发生日（仅比较年月日）。
  final DateTime eventDate;
  final String dateText;
  final String title;
  final int daysRemaining;
  final Color accentColor;
  final bool isPinned;
}
