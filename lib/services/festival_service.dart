import 'package:lunar/lunar.dart';

import 'package:time_calendar/models/calendar_festival.dart';
import 'package:time_calendar/services/festival_data_loader.dart';

/// 与节日设置页 [FestivalSettingsPage] 共用的订阅持久化键。
class FestivalSubscriptionPrefs {
  FestivalSubscriptionPrefs._();

  static const String storageKey = 'festival_subscriptions';
  /// 降级后超出档位名额、仍显示在日历但**不推节日提醒**的节日 id。
  static const String hiddenSilentKey = 'festival_hidden_silent_ids';
}

/// 节日推算（公历固定、公历浮动、农历、民族历种子、宗教历种子）。
class FestivalService {
  FestivalService._();

  /// 预加载民族 / 宗教节日 JSON（须在首次调用 [getFestivalsForMonth] 前完成；[main] 内已 await）。
  static Future<void> ensureFestivalSeedDataLoaded() =>
      FestivalDataLoader.ensureLoaded();

  /// 首次安装推荐订阅（植树节 [arbor_day]、民族、宗教等不在此集合）。
  static const Set<String> kDefaultSubscribedIds = {
    'test_push',
    'new_year',
    'valentine',
    'women_day',
    'labour_day',
    'children_day',
    'party_day',
    'army_day',
    'teacher_day',
    'national_day',
    'mothers_day',
    'fathers_day',
    'spring_festival',
    'lantern_festival',
    'dragon_head',
    'qingming',
    'dragon_boat',
    'qixi',
    'ghost_festival',
    'mid_autumn',
    'double_ninth',
    'laba',
    'xiao_nian',
    'new_year_eve',
  };

  /// 公历固定节日（每年同一天）。
  static final List<Map<String, dynamic>> _gregorianFixed = [
    {
      'id': 'test_push',
      'name': '测试推送节日',
      'month': 5,
      'day': 4,
      'description': '这是一条用于验证推送功能的测试节日',
    },
    {'id': 'new_year', 'name': '元旦', 'month': 1, 'day': 1},
    {'id': 'valentine', 'name': '情人节', 'month': 2, 'day': 14},
    {'id': 'women_day', 'name': '妇女节', 'month': 3, 'day': 8},
    {'id': 'arbor_day', 'name': '植树节', 'month': 3, 'day': 12},
    {'id': 'labour_day', 'name': '劳动节', 'month': 5, 'day': 1},
    {'id': 'children_day', 'name': '儿童节', 'month': 6, 'day': 1},
    {'id': 'party_day', 'name': '建党节', 'month': 7, 'day': 1},
    {'id': 'army_day', 'name': '建军节', 'month': 8, 'day': 1},
    {'id': 'teacher_day', 'name': '教师节', 'month': 9, 'day': 10},
    {'id': 'national_day', 'name': '国庆节', 'month': 10, 'day': 1},
  ];

  static DateTime _mothersDay(int year) {
    var d = DateTime(year, 5, 1);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(const Duration(days: 7));
  }

  static DateTime _fathersDay(int year) {
    var d = DateTime(year, 6, 1);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(const Duration(days: 14));
  }

  /// 农历节日（农历月日）；通过探测相邻农历年映射到公历年 [year]。
  static final List<Map<String, dynamic>> _lunarFestivals = [
    {'id': 'spring_festival', 'name': '春节', 'lunarMonth': 1, 'lunarDay': 1},
    {'id': 'lantern_festival', 'name': '元宵节', 'lunarMonth': 1, 'lunarDay': 15},
    {'id': 'dragon_head', 'name': '龙抬头', 'lunarMonth': 2, 'lunarDay': 2},
    {'id': 'dragon_boat', 'name': '端午节', 'lunarMonth': 5, 'lunarDay': 5},
    {'id': 'qixi', 'name': '七夕节', 'lunarMonth': 7, 'lunarDay': 7},
    {'id': 'ghost_festival', 'name': '中元节', 'lunarMonth': 7, 'lunarDay': 15},
    {'id': 'mid_autumn', 'name': '中秋节', 'lunarMonth': 8, 'lunarDay': 15},
    {'id': 'double_ninth', 'name': '重阳节', 'lunarMonth': 9, 'lunarDay': 9},
    {'id': 'laba', 'name': '腊八节', 'lunarMonth': 12, 'lunarDay': 8},
    {'id': 'xiao_nian', 'name': '小年', 'lunarMonth': 12, 'lunarDay': 23},
  ];

  /// 清明节气公历日。
  ///
  /// `package:lunar` 以精确天文算法计算二十四节气；节气键名见 [Lunar.getJieQiTable]。
  /// 就节气次序而言：立春为正月节起点，依次为雨水、惊蛰、春分、清明（立春起算第 5 个节气）、谷雨…
  /// 此处通过年中锚点日构造 [Lunar]，读取 `'清明'` 条目，与同库 [LunarYear.getJieQiJulianDays]
  /// 与 [Lunar.JIE_QI_IN_USE] 对齐。
  static DateTime? _qingmingSolar(int gregorianYear) {
    try {
      final lunar = Lunar.fromDate(DateTime(gregorianYear, 6, 1));
      final solar = lunar.getJieQiTable()['清明'];
      if (solar == null) return null;
      return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
    } catch (_) {
      return null;
    }
  }

  static String _lunarMonthDayLabel(int lunarMonth, int lunarDay) {
    final m = LunarUtil.MONTH[lunarMonth];
    final d = LunarUtil.DAY[lunarDay];
    return '$m月$d';
  }

  /// 将农历月日落到公历 [gregorianYear] 年的那一次（春节前后可能跨农历年）。
  static DateTime? _solarForLunarMonthDay(
    int gregorianYear,
    int lunarMonth,
    int lunarDay,
  ) {
    for (final lunarYear
        in [gregorianYear - 1, gregorianYear, gregorianYear + 1]) {
      try {
        final lunar = Lunar.fromYmd(lunarYear, lunarMonth, lunarDay);
        final solar = lunar.getSolar();
        final g =
            DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
        if (g.year == gregorianYear) return g;
      } catch (_) {}
    }
    return null;
  }

  static DateTime? _lunarNewYearsEveSolar(int gregorianYear) {
    for (final lunarYear
        in [gregorianYear - 1, gregorianYear, gregorianYear + 1]) {
      try {
        final solar = Lunar.fromYmd(lunarYear, 1, 1).getSolar();
        final ny =
            DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
        final eve = ny.subtract(const Duration(days: 1));
        if (eve.year == gregorianYear) return eve;
      } catch (_) {}
    }
    return null;
  }

  /// 解析民族/宗教种子中的公历描述串；无完整日时返回 null。
  static DateTime? parseGregorianSeedToMonthDay(
    String raw,
    int targetYear,
  ) {
    final t = raw.trim();
    if (t.isEmpty || t == '因人而异') return null;

    final fullZh =
        RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(t);
    if (fullZh != null) {
      final month = int.parse(fullZh.group(2)!);
      final day = int.parse(fullZh.group(3)!);
      return DateTime(targetYear, month, day);
    }

    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(t);
    if (iso != null) {
      final month = int.parse(iso.group(2)!);
      final day = int.parse(iso.group(3)!);
      return DateTime(targetYear, month, day);
    }

    final mdOnly = RegExp(r'^(\d{1,2})月(\d{1,2})日').firstMatch(t);
    if (mdOnly != null) {
      final month = int.parse(mdOnly.group(1)!);
      final day = int.parse(mdOnly.group(2)!);
      return DateTime(targetYear, month, day);
    }

    if (RegExp(r'\d{4}年\d{1,2}月').hasMatch(t) && !t.contains('日')) {
      return null;
    }

    return null;
  }

  static String _jsonEthnicCalendarLine(Map<String, dynamic> f) {
    final ct = FestivalDataLoader.safeString(f, 'calendar_type');
    final cd = FestivalDataLoader.safeString(f, 'calendar_date') ?? '';
    const prefixes = <String, String>{
      'tibetan': '藏历',
      'dai': '傣历',
      'miao': '苗历',
      'yi': '彝历',
      'menggu': '蒙历',
      'hani': '哈尼历',
      'lunar': '农历',
      'gregorian': '公历',
      'islamic': '伊斯兰历',
      'solar': '',
    };
    if (cd.trim().isEmpty) return '';
    final p = prefixes[ct ?? ''] ?? '';
    return p.isEmpty ? cd : '$p $cd';
  }

  static String _jsonReligiousCalendarLine(Map<String, dynamic> f) {
    final ct = FestivalDataLoader.safeString(f, 'calendar_type');
    final cd = FestivalDataLoader.safeString(f, 'calendar_date') ?? '';
    const prefixes = <String, String>{
      'lunar': '农历',
      'gregorian': '公历',
      'islamic': '伊斯兰历',
      'computus': '教历',
      'hindu': '印历',
    };
    if (cd.trim().isEmpty) {
      return ct == null ? '' : (prefixes[ct] ?? ct);
    }
    final p = prefixes[ct ?? ''] ?? '';
    return p.isEmpty ? cd : '$p $cd';
  }

  static List<CalendarFestival> _parseEthnicFestivals(
    int year,
    int month,
    Set<String>? subscribedIds,
  ) {
    final festivals = FestivalDataLoader.ethnicFestivalsOrEmpty();
    final results = <CalendarFestival>[];
    for (final f in festivals) {
      final id = FestivalDataLoader.safeString(f, 'id');
      if (id == null || id.isEmpty) continue;
      if (FestivalDataLoader.festivalDisplayHidden(f)) continue;
      if (subscribedIds != null && !subscribedIds.contains(id)) continue;

      final date = FestivalDataLoader.getGregorianDate(f, year);
      if (date == null || date.month != month) continue;

      final name = FestivalDataLoader.safeString(f, 'name') ?? '未知节日';
      final calLine = _jsonEthnicCalendarLine(f);
      final ethnicName = FestivalDataLoader.safeString(f, 'ethnic_name');
      final descTrim = FestivalDataLoader.safeDescription(f);
      results.add(
        CalendarFestival(
          id: id,
          name: name,
          category: 'ethnic',
          gregorianDate: date,
          ethnicCalendar: calLine.isEmpty ? null : calLine,
          sourceLabel:
              (ethnicName != null && ethnicName.isNotEmpty) ? ethnicName : null,
          description:
              (descTrim != null && descTrim.isNotEmpty) ? descTrim : null,
        ),
      );
    }
    return results;
  }

  static List<CalendarFestival> _parseReligiousFestivals(
    int year,
    int month,
    Set<String>? subscribedIds,
  ) {
    final festivals = FestivalDataLoader.religiousFestivalsOrEmpty();
    final results = <CalendarFestival>[];
    for (final f in festivals) {
      final id = FestivalDataLoader.safeString(f, 'id');
      if (id == null || id.isEmpty) continue;
      if (FestivalDataLoader.festivalDisplayHidden(f)) continue;
      if (subscribedIds != null && !subscribedIds.contains(id)) continue;

      final date = FestivalDataLoader.getGregorianDate(f, year);
      if (date == null || date.month != month) continue;

      final name = FestivalDataLoader.safeString(f, 'name') ?? '未知节日';
      final calLine = _jsonReligiousCalendarLine(f);
      final relType = FestivalDataLoader.safeString(f, 'religious_type');
      final descTrim = FestivalDataLoader.safeDescription(f);
      results.add(
        CalendarFestival(
          id: id,
          name: name,
          category: 'religious',
          gregorianDate: date,
          religiousCalendar: calLine.isEmpty ? null : calLine,
          sourceLabel:
              (relType != null && relType.isNotEmpty) ? relType : null,
          description:
              (descTrim != null && descTrim.isNotEmpty) ? descTrim : null,
        ),
      );
    }
    return results;
  }

  /// 指定公历年月中出现的节日（含农历转换与民族/宗教种子按月筛选）。
  /// [subscribedIds] 非 null 时仅保留 id 落在该集合中的节日。
  static List<CalendarFestival> getFestivalsForMonth(
    int year,
    int month, {
    Set<String>? subscribedIds,
  }) {
    final results = <CalendarFestival>[];

    for (final f in _gregorianFixed) {
      if (f['month'] == month) {
        results.add(
          CalendarFestival(
            id: f['id'] as String,
            name: f['name'] as String,
            category: 'gregorian',
            gregorianDate:
                DateTime(year, f['month'] as int, f['day'] as int),
          ),
        );
      }
    }

    final mothersDay = _mothersDay(year);
    if (mothersDay.month == month) {
      results.add(
        CalendarFestival(
          id: 'mothers_day',
          name: '母亲节',
          category: 'gregorian',
          gregorianDate: mothersDay,
        ),
      );
    }
    final fathersDay = _fathersDay(year);
    if (fathersDay.month == month) {
      results.add(
        CalendarFestival(
          id: 'fathers_day',
          name: '父亲节',
          category: 'gregorian',
          gregorianDate: fathersDay,
        ),
      );
    }

    final qm = _qingmingSolar(year);
    if (qm != null && qm.month == month) {
      results.add(
        CalendarFestival(
          id: 'qingming',
          name: '清明节',
          category: 'lunar',
          gregorianDate: qm,
          lunarDate: '清明（节气）',
        ),
      );
    }

    for (final f in _lunarFestivals) {
      final lunarMonth = f['lunarMonth'] as int;
      final lunarDay = f['lunarDay'] as int;
      final g = _solarForLunarMonthDay(year, lunarMonth, lunarDay);
      if (g != null && g.month == month) {
        results.add(
          CalendarFestival(
            id: f['id'] as String,
            name: f['name'] as String,
            category: 'lunar',
            gregorianDate: g,
            lunarDate: _lunarMonthDayLabel(lunarMonth, lunarDay),
          ),
        );
      }
    }

    final eve = _lunarNewYearsEveSolar(year);
    if (eve != null && eve.month == month) {
      results.add(
        CalendarFestival(
          id: 'new_year_eve',
          name: '除夕',
          category: 'lunar',
          gregorianDate: eve,
          lunarDate: '腊月最后一天（正月初一前一日）',
        ),
      );
    }

    results.addAll(_parseEthnicFestivals(year, month, subscribedIds));
    results.addAll(_parseReligiousFestivals(year, month, subscribedIds));

    results.sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));
    if (subscribedIds != null) {
      results.removeWhere((f) => !subscribedIds.contains(f.id));
    }
    return results;
  }
}
