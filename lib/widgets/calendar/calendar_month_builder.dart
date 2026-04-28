import 'package:flutter/material.dart';
import 'package:lunar/lunar.dart';
import 'package:time_calendar/widgets/calendar/calendar_models.dart';

/// 公历月网格 + 农历/节气/节日文案（基于 `lunar` 包，适用于任意年份公历月）。
List<CalendarDayCellData> buildCalendarMonthGrid({
  required int year,
  required int month,
  DateTime? selectedDate,
  required DateTime today,
  Map<String, List<Color>> markerByDay = const {},
}) {
  final first = DateTime(year, month, 1);
  final lead = first.weekday % 7;
  final start = first.subtract(Duration(days: lead));
  const totalCells = 42;
  final out = <CalendarDayCellData>[];
  for (int i = 0; i < totalCells; i++) {
    final d = start.add(Duration(days: i));
    final inMonth = d.year == year && d.month == month;
    out.add(
      _cell(
        d,
        isCurrentMonth: inMonth,
        selected: selectedDate,
        today: today,
        markerByDay: markerByDay,
      ),
    );
  }
  return out;
}

CalendarDayCellData _cell(
  DateTime d, {
  required bool isCurrentMonth,
  required DateTime today,
  DateTime? selected,
  required Map<String, List<Color>> markerByDay,
}) {
  final lunar = Lunar.fromDate(d);
  final jq = lunar.getJieQi();
  var label = '';
  if (jq.isNotEmpty) {
    label = jq;
  } else {
    final fs = lunar.getFestivals();
    if (fs.isNotEmpty) {
      label = fs.first;
    } else {
      final ofs = lunar.getOtherFestivals();
      if (ofs.isNotEmpty) {
        label = ofs.first;
      } else {
        label = lunar.getDayInChinese();
      }
    }
  }
  final key = '${d.year}-${d.month}-${d.day}';
  return CalendarDayCellData(
    dayNumber: '${d.day}',
    lunarLabel: label,
    calendarDate: d,
    isCurrentMonth: isCurrentMonth,
    isSelected: selected != null && _sameDay(d, selected),
    isToday: _sameDay(d, today),
    markerColors: markerByDay[key] ?? const [],
  );
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
