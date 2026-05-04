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
    this.color = const Color(0xFF10B981),
  });

  final String id;
  final String name;
  final String category;
  final DateTime gregorianDate;
  final String? lunarDate;
  final String? ethnicCalendar;
  final String? religiousCalendar;
  final Color color;
}
