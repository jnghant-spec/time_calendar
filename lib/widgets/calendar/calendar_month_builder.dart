import 'package:lunar/lunar.dart';
import 'package:time_calendar/models/calendar_festival.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/widgets/calendar/calendar_models.dart';

/// 月网格可见范围（含上月末尾、下月开头的补格日期），首尾均为公历日 0 点。
({DateTime start, DateTime end, int cellCount}) monthGridGregorianBounds({
  required int year,
  required int month,
}) {
  final first = DateTime(year, month, 1);
  final lead = first.weekday % 7;
  final dim = DateTime(year, month + 1, 0).day;
  final rowsNeeded = ((lead + dim) / 7).ceil();
  final cellCount = rowsNeeded * 7;
  final start = first.subtract(Duration(days: lead));
  final end = start.add(Duration(days: cellCount - 1));
  return (start: start, end: end, cellCount: cellCount);
}

/// 公历月网格 + 农历/节气/节日文案（基于 `lunar` 包，适用于任意年份公历月）。
List<CalendarDayCellData> buildCalendarMonthGrid({
  required int year,
  required int month,
  DateTime? selectedDate,
  required DateTime today,
  Map<String, List<ListEvent>> eventsByDay = const {},
  Map<String, List<CalendarFestival>> festivalsByDay = const {},
}) {
  final bounds = monthGridGregorianBounds(year: year, month: month);
  final start = bounds.start;
  final out = <CalendarDayCellData>[];
  for (int i = 0; i < bounds.cellCount; i++) {
    final d = start.add(Duration(days: i));
    final inMonth = d.year == year && d.month == month;
    out.add(
      _cell(
        d,
        isCurrentMonth: inMonth,
        selected: selectedDate,
        today: today,
        eventsByDay: eventsByDay,
        festivalsByDay: festivalsByDay,
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
  required Map<String, List<ListEvent>> eventsByDay,
  required Map<String, List<CalendarFestival>> festivalsByDay,
}) {
  final lunar = Lunar.fromDate(d);
  final jq = lunar.getJieQi();
  // 仅展示节气或农历日：不使用 Lunar.getFestivals/getOtherFestivals，避免「天穿节」等与订阅无关的节日名占据网格。
  final String label =
      jq.isNotEmpty ? jq : lunar.getDayInChinese();
  final key = '${d.year}-${d.month}-${d.day}';
  return CalendarDayCellData(
    dayNumber: '${d.day}',
    lunarLabel: label,
    calendarDate: d,
    isCurrentMonth: isCurrentMonth,
    isSelected: selected != null && _sameDay(d, selected),
    isToday: _sameDay(d, today),
    events: eventsByDay[key] ?? const [],
    festivals: festivalsByDay[key] ?? const [],
  );
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
