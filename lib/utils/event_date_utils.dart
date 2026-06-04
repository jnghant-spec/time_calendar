import 'package:lunar/lunar.dart';
import 'package:time_calendar/models/list_event.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysInGregorianMonth(int year, int month) =>
    DateTime(year, month + 1, 0).day;

bool sameGregorianDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 循环起始日（仅比较年月日）：即 [ListEvent.anchorDate]。
DateTime anchorDateOnly(ListEvent event) => event.anchorDate;

List<DateTime> _keepOnOrAfterAnchor(ListEvent event, List<DateTime> dates) {
  final anchor = anchorDateOnly(event);
  return [
    for (final d in dates)
      if (!_dateOnly(d).isBefore(anchor)) _dateOnly(d),
  ];
}

/// 该事件在公历 [viewYear] 年 [viewMonth] 月的每一次发生日（用于日历格打点）。
///
/// 存储的 [ListEvent.baseDate] 为循环起始锚点：仅返回 **不早于该日** 的发生日。
List<DateTime> occurrenceDatesInGregorianMonth(
  ListEvent event,
  int viewYear,
  int viewMonth,
) {
  final base = event.baseDate;

  if (event.isLunarRecurring) {
    return _keepOnOrAfterAnchor(
      event,
      _lunarRepeatOccurrencesInGregorianMonth(event, viewYear, viewMonth),
    );
  }

  if (event.repeatRule == EventRepeatRule.none) {
    final b = _dateOnly(base);
    if (b.year == viewYear && b.month == viewMonth) {
      return [b];
    }
    return const [];
  }

  final List<DateTime> raw;
  switch (event.repeatRule) {
    case EventRepeatRule.none:
      return const [];
    case EventRepeatRule.daily:
      final dim = _daysInGregorianMonth(viewYear, viewMonth);
      raw = [
        for (var day = 1; day <= dim; day++) DateTime(viewYear, viewMonth, day),
      ];
      break;
    case EventRepeatRule.weekly:
      final targetWd = base.weekday;
      final dim = _daysInGregorianMonth(viewYear, viewMonth);
      raw = [];
      for (var day = 1; day <= dim; day++) {
        final d = DateTime(viewYear, viewMonth, day);
        if (d.weekday == targetWd) raw.add(d);
      }
      break;
    case EventRepeatRule.monthly:
      final dim = _daysInGregorianMonth(viewYear, viewMonth);
      final dd = base.day.clamp(1, dim);
      raw = [DateTime(viewYear, viewMonth, dd)];
      break;
    case EventRepeatRule.yearly:
      if (base.month != viewMonth) return const [];
      final dim = _daysInGregorianMonth(viewYear, viewMonth);
      final dd = base.day.clamp(1, dim);
      raw = [DateTime(viewYear, viewMonth, dd)];
      break;
  }
  return _keepOnOrAfterAnchor(event, raw);
}

List<DateTime> _lunarRepeatOccurrencesInGregorianMonth(
  ListEvent event,
  int viewYear,
  int viewMonth,
) {
  final base = event.baseDate;
  final seen = <String>{};
  final out = <DateTime>[];
  try {
    final lunarBase = Lunar.fromDate(base);
    final lm = lunarBase.getMonth();
    final ld = lunarBase.getDay();
    for (final lunarYear in [viewYear - 1, viewYear, viewYear + 1]) {
      if (lunarYear < 1900 || lunarYear > 2100) continue;
      try {
        final lunar = Lunar.fromYmd(lunarYear, lm, ld);
        final solar = lunar.getSolar();
        final g = DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
        if (g.year == viewYear && g.month == viewMonth) {
          final key = '${g.year}-${g.month}-${g.day}';
          if (seen.add(key)) out.add(g);
        }
      } catch (_) {}
    }
  } catch (_) {}
  out.sort();
  return out;
}

/// 是否在指定公历日发生（用于点选某日筛选）。
bool eventOccursOnGregorianDay(ListEvent event, DateTime gregorianDay) {
  final target = _dateOnly(gregorianDay);
  if (!event.isLunarRecurring && event.repeatRule == EventRepeatRule.none) {
    return _dateOnly(event.baseDate) == target;
  }
  final y = target.year;
  final m = target.month;
  final d = target.day;
  return occurrenceDatesInGregorianMonth(
    event,
    y,
    m,
  ).any((od) => od.year == y && od.month == m && od.day == d);
}

/// 计算事件下一个用于展示/倒计时的日期（≥ 起始日 [anchorDateOnly]）。
DateTime effectiveDate(ListEvent event) {
  final base = event.baseDate;
  final now = DateTime.now();
  final today = _dateOnly(now);
  final a = anchorDateOnly(event);

  if (event.repeatRule == EventRepeatRule.none && !event.isLunarRecurring) {
    return DateTime(base.year, base.month, base.day);
  }

  if (event.isLunarRecurring) {
    try {
      final start = today.isBefore(a) ? a : today;
      final lunar = Lunar.fromDate(base);
      final month = lunar.getMonth();
      final day = lunar.getDay();
      DateTime? best;
      for (var ly = start.year - 1; ly <= start.year + 5; ly++) {
        try {
          final lun = Lunar.fromYmd(ly, month, day);
          final solar = lun.getSolar();
          final g = DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
          if (!g.isBefore(a) && !g.isBefore(start)) {
            if (best == null || g.isBefore(best)) best = g;
          }
        } catch (_) {}
      }
      if (best != null) return best;
    } catch (_) {}
    return DateTime(base.year, base.month, base.day);
  }

  switch (event.repeatRule) {
    case EventRepeatRule.daily:
      return today.isBefore(a) ? a : today;
    case EventRepeatRule.weekly:
      var d = today.isBefore(a) ? a : today;
      while (d.weekday != base.weekday) {
        d = d.add(const Duration(days: 1));
      }
      while (d.isBefore(a)) {
        d = d.add(const Duration(days: 7));
      }
      return d;
    case EventRepeatRule.monthly:
      final start = today.isBefore(a) ? a : today;
      var y = start.year;
      var m = start.month;
      for (var i = 0; i < 480; i++) {
        final dim = _daysInGregorianMonth(y, m);
        final dd = base.day.clamp(1, dim);
        final cand = DateTime(y, m, dd);
        if (!cand.isBefore(a) && !cand.isBefore(start)) return cand;
        if (m == 12) {
          y++;
          m = 1;
        } else {
          m++;
        }
      }
      return a;
    case EventRepeatRule.yearly:
      final start = today.isBefore(a) ? a : today;
      for (var y = start.year; y <= start.year + 400; y++) {
        final dim = _daysInGregorianMonth(y, base.month);
        final dd = base.day.clamp(1, dim);
        final cand = DateTime(y, base.month, dd);
        if (!cand.isBefore(a) && !cand.isBefore(start)) return cand;
      }
      return a;
    case EventRepeatRule.none:
      return DateTime(base.year, base.month, base.day);
  }
}

/// 统一过期判断：重复事件永不过期
bool isEventExpired(ListEvent event) {
  if (event.repeatRule != EventRepeatRule.none) {
    return false;
  }
  final today = _dateOnly(DateTime.now());
  final baseOnly = _dateOnly(event.baseDate);
  return baseOnly.isBefore(today);
}

/// 倒计时天数（基于下一个日期）
int daysUntil(ListEvent event) {
  final today = _dateOnly(DateTime.now());
  final target = effectiveDate(event);
  final targetDate = _dateOnly(target);
  return targetDate.difference(today).inDays;
}

/// 周一～周日 → 「一」…「日」（用于清单/详情日期文案）。
String weekdayZhShort(int weekday) {
  const w = ['一', '二', '三', '四', '五', '六', '日'];
  return w[weekday - 1];
}

/// 公历「YYYY年M月D日 周x」。
String formatGregorianDateLongZh(DateTime d) {
  return '${d.year}年${d.month}月${d.day}日 周${weekdayZhShort(d.weekday)}';
}

/// 由公历日计算农历月日展示串（与清单农历 pill 一致）。
String formatLunarMonthDayFromSolar(DateTime solar) {
  final lunar = Lunar.fromDate(solar);
  return '农历 ${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
}

/// 「2023.05」格式（时光集卡片时间范围）。
String formatYearMonthDot(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  return '${d.year}.$m';
}

/// 照片流底部文案：「2023年5月1日」。
String formatMemoryStreamDayZh(DateTime d) {
  return '${d.year}年${d.month}月${d.day}日';
}

/// 「2023年5月1日」完整日期（同 [formatMemoryStreamDayZh]）。
String formatFullDate(DateTime d) => formatMemoryStreamDayZh(d);

/// 「周一」～「周日」。
String formatWeekdayZh(DateTime d) => '周${weekdayZhShort(d.weekday)}';

/// 横向事件卡片：「3月10日」。
String formatMonthDayZh(DateTime d) => '${d.month}月${d.day}日';
