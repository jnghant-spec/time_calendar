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

DateTime? _lunarYmdToGregorian(int lunarYear, int month, int day) {
  try {
    final lun = Lunar.fromYmd(lunarYear, month, day);
    final solar = lun.getSolar();
    return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
  } catch (_) {
    return null;
  }
}

LunarMonth? _findLeapMonthEntry(int lunarYear, int monthSigned) {
  for (final monthEntry in LunarYear.fromYear(lunarYear).getMonths()) {
    if (monthEntry.getMonth() == monthSigned) {
      return monthEntry;
    }
  }
  return null;
}

/// 闰月生日：按 [leapMonthPreference] 收集某一农历年的公历候选发生日。
List<DateTime> _leapMonthOccurrencesForLunarYear(
  int lunarYear,
  int monthSigned,
  int day,
  int leapMonthPreference,
) {
  final candidates = <DateTime>[];
  final normalMonth = monthSigned.abs();
  final leapMonth = _findLeapMonthEntry(lunarYear, monthSigned);
  final hasValidLeapMonth = leapMonth != null && day <= leapMonth.getDayCount();

  void addNormal() {
    final g = _lunarYmdToGregorian(lunarYear, normalMonth, day);
    if (g != null) candidates.add(g);
  }

  void addLeap() {
    if (!hasValidLeapMonth) return;
    final g = _lunarYmdToGregorian(lunarYear, monthSigned, day);
    if (g != null) candidates.add(g);
  }

  switch (leapMonthPreference) {
    case 1:
      addNormal();
      break;
    case 2:
      addNormal();
      addLeap();
      break;
    case 0:
    default:
      if (hasValidLeapMonth) {
        addLeap();
      } else {
        addNormal();
      }
      break;
  }

  return candidates;
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
        if (lm >= 0) {
          final lunar = Lunar.fromYmd(lunarYear, lm, ld);
          final solar = lunar.getSolar();
          final g = DateTime(
            solar.getYear(),
            solar.getMonth(),
            solar.getDay(),
          );
          if (g.year == viewYear && g.month == viewMonth) {
            final key = '${g.year}-${g.month}-${g.day}';
            if (seen.add(key)) out.add(g);
          }
        } else {
          final pref = event.leapMonthPreference ?? 0;
          final yearCandidates = _leapMonthOccurrencesForLunarYear(
            lunarYear,
            lm,
            ld,
            pref,
          );
          for (final g in yearCandidates) {
            if (g.year == viewYear && g.month == viewMonth) {
              final key = '${g.year}-${g.month}-${g.day}';
              if (seen.add(key)) out.add(g);
            }
          }
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
      final pref = event.leapMonthPreference ?? 0;
      final candidates = <DateTime>[];
      for (var ly = start.year - 1; ly <= start.year + 5; ly++) {
        try {
          if (month >= 0) {
            final lun = Lunar.fromYmd(ly, month, day);
            final solar = lun.getSolar();
            final g = DateTime(
              solar.getYear(),
              solar.getMonth(),
              solar.getDay(),
            );
            if (!g.isBefore(a) && !g.isBefore(start)) {
              candidates.add(g);
            }
          } else {
            final yearCandidates = _leapMonthOccurrencesForLunarYear(
              ly,
              month,
              day,
              pref,
            );
            for (final g in yearCandidates) {
              if (!g.isBefore(a) && !g.isBefore(start)) {
                candidates.add(g);
              }
            }
          }
        } catch (_) {}
      }
      if (candidates.isNotEmpty) {
        candidates.sort();
        return candidates.reduce((x, y) => x.isBefore(y) ? x : y);
      }
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

/// 清单卡片倒计时下方的副文案（循环事件专用）。
String? eventSubline(ListEvent event, int daysDiff) {
  final today = _dateOnly(DateTime.now());
  final baseDate = _dateOnly(event.baseDate);

  if (event.repeatRule == EventRepeatRule.none) {
    return null;
  }

  if (event.repeatRule == EventRepeatRule.yearly) {
    if (daysDiff < 0) return null;
    final age = effectiveDate(event).year - event.baseDate.year;
    if (event.eventType == EventType.birthday) {
      if (daysDiff == 0) return '满$age岁';
      if (daysDiff > 0) return '将满$age岁';
    } else {
      if (daysDiff == 0) return '满$age周年';
      if (daysDiff > 0) return '将满$age周年';
    }
    return null;
  }

  if (event.repeatRule == EventRepeatRule.daily) {
    return '已坚持${today.difference(baseDate).inDays}天';
  }

  if (event.repeatRule == EventRepeatRule.weekly) {
    return '已坚持${today.difference(baseDate).inDays ~/ 7}周';
  }

  if (event.repeatRule == EventRepeatRule.monthly) {
    var months = (today.year - baseDate.year) * 12 + (today.month - baseDate.month);
    if (today.day < baseDate.day) months--;
    return '已坚持$months月';
  }

  return null;
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

/// 时光集子事件农历 pill 文案：「农历 四月十九」。
String formatMemoryEventLunarPill(DateTime solarDate) {
  final lunar = Lunar.fromDate(solarDate);
  return '农历 ${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
}
