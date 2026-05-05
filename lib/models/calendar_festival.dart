import 'package:flutter/material.dart';

class CalendarFestival {
  const CalendarFestival({
    required this.id,
    required this.name,
    required this.category,
    required this.gregorianDate,
    this.lunarDate,
    this.ethnicCalendar,
    this.religiousCalendar,
    /// 卡片标签与详情「节日来源」：民族名称（如藏族）、宗教名称（如佛教）；公历/农历可为 null。
    this.sourceLabel,
    /// 民族 / 宗教节日详情简介（来自 JSON `description`）。
    this.description,
    this.color = const Color(0xFF10B981),
  });

  final String id;
  final String name;
  final String category;
  final DateTime gregorianDate;
  final String? lunarDate;
  final String? ethnicCalendar;
  final String? religiousCalendar;
  final String? sourceLabel;
  final String? description;
  final Color color;
}
