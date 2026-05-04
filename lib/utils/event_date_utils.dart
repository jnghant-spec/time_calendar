import 'package:lunar/lunar.dart';
import 'package:time_calendar/models/list_event.dart';

/// 计算事件下一个即将到来的日期（用于排序和倒计时）
DateTime effectiveDate(ListEvent event) {
  final base = event.baseDate;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  if (event.repeatRule == EventRepeatRule.none) {
    return DateTime(base.year, base.month, base.day);
  }

  if (event.isLunarRecurring) {
    try {
      final lunar = Lunar.fromDate(base);
      final month = lunar.getMonth();
      final day = lunar.getDay();

      final thisYearLunar = Lunar.fromYmd(today.year, month, day);
      final solar = thisYearLunar.getSolar();
      var candidate = DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
      if (!candidate.isBefore(today)) {
        return candidate;
      }

      final nextYearLunar = Lunar.fromYmd(today.year + 1, month, day);
      final nextSolar = nextYearLunar.getSolar();
      return DateTime(nextSolar.getYear(), nextSolar.getMonth(), nextSolar.getDay());
    } catch (_) {
      return DateTime(base.year, base.month, base.day);
    }
  }

  switch (event.repeatRule) {
    case EventRepeatRule.daily:
      return today.add(const Duration(days: 1));
    case EventRepeatRule.weekly:
      var daysDiff = base.weekday - today.weekday;
      if (daysDiff < 0) daysDiff += 7;
      if (daysDiff == 0) return today;
      return today.add(Duration(days: daysDiff));
    case EventRepeatRule.monthly:
      var candidate = DateTime(today.year, today.month, base.day);
      if (candidate.isBefore(today)) {
        candidate = DateTime(today.year, today.month + 1, base.day);
      }
      return candidate;
    case EventRepeatRule.yearly:
      var candidate = DateTime(today.year, base.month, base.day);
      if (candidate.isBefore(today)) {
        candidate = DateTime(today.year + 1, base.month, base.day);
      }
      return candidate;
    case EventRepeatRule.none:
      return DateTime(base.year, base.month, base.day);
  }
}

/// 统一过期判断：重复事件永不过期
bool isEventExpired(ListEvent event) {
  if (event.repeatRule != EventRepeatRule.none) {
    return false;
  }
  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final baseOnly = DateTime(event.baseDate.year, event.baseDate.month, event.baseDate.day);
  return baseOnly.isBefore(today);
}

/// 倒计时天数（基于下一个日期）
int daysUntil(ListEvent event) {
  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final target = effectiveDate(event);
  final targetDate = DateTime(target.year, target.month, target.day);
  return targetDate.difference(today).inDays;
}
