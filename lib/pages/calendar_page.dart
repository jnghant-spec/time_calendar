import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/calendar_festival.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/services/festival_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/services/membership_service.dart';
import 'package:time_calendar/services/share_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/utils/size_config.dart';
import 'package:time_calendar/pages/event_detail_sheet.dart';
import 'package:time_calendar/widgets/calendar/calendar_grid.dart';
import 'package:time_calendar/widgets/calendar/calendar_models.dart';
import 'package:time_calendar/widgets/calendar/calendar_month_builder.dart';
import 'package:time_calendar/pages/event_add_page.dart';
import 'package:time_calendar/widgets/calendar/event_timeline_list.dart';
import 'package:time_calendar/widgets/calendar/year_month_picker_sheet.dart';
import 'package:time_calendar/widgets/calendar_day_cell.dart';
import 'package:time_calendar/widgets/week_event_card.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.events, this.onEventsChanged});

  final List<ListEvent> events;
  final ValueChanged<List<ListEvent>>? onEventsChanged;

  static const List<String> _weekDays = ['日', '一', '二', '三', '四', '五', '六'];

  static const List<String> _kWeekdayZh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  static String _zhWeekday(DateTime d) => _kWeekdayZh[d.weekday - 1];

  /// 标记农历事件（不可见）；须与 [EventReminderCard] 内解析逻辑一致。
  static const String _kLunarDateLineMarker = '\u200e';

  static String _formatEventDateLine(DateTime date, {bool lunar = false}) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final base = '$y-$m-$day ${_zhWeekday(date)}';
    if (lunar) return '$base$_kLunarDateLineMarker';
    return '$base ';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _isVisibleOnCalendarTimeline(ListEvent e, DateTime today) {
    final ed = effectiveDate(e);
    final days = _dateOnly(ed).difference(_dateOnly(today)).inDays;
    return days >= 0 && days <= 15;
  }

  static int _eventSortListEvent(ListEvent a, ListEvent b) {
    final c = effectiveDate(a).compareTo(effectiveDate(b));
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  static List<ListEvent> _filteredCalendarEvents(
    Iterable<ListEvent> source,
    DateTime today, {
    Set<String> archivedIds = const {},
  }) {
    final list = source.where((e) {
      if (archivedIds.contains(e.id)) return false;
      return _isVisibleOnCalendarTimeline(e, today);
    }).toList()
      ..sort(_eventSortListEvent);
    return list;
  }

  static int _compareTimelineReminder(EventReminderData a, EventReminderData b) {
    final da = CalendarPage._dateOnly(a.eventDate);
    final db = CalendarPage._dateOnly(b.eventDate);
    final c = da.compareTo(db);
    if (c != 0) return c;
    if (a.isFestival != b.isFestival) return a.isFestival ? 1 : -1;
    return a.title.compareTo(b.title);
  }

  /// 从 `festival_${f.id}_${y}_${m}_${d}` 解析 [f.id]（可能含下划线）。
  static String? _festivalCoreIdFromReminderId(String reminderId) {
    if (!reminderId.startsWith('festival_')) return null;
    final parts = reminderId.substring('festival_'.length).split('_');
    if (parts.length < 4) return null;
    final y = int.tryParse(parts[parts.length - 3]);
    final m = int.tryParse(parts[parts.length - 2]);
    final d = int.tryParse(parts[parts.length - 1]);
    if (y == null || m == null || d == null) return null;
    return parts.sublist(0, parts.length - 3).join('_');
  }

  /// 节日介绍（不修改 [FestivalService] / [CalendarFestival] 时的本地副本）。
  static const Map<String, String> _kFestivalDescriptions = {
    'labour_day':
        '国际劳动节，又称「五一国际劳动节」，是世界上80多个国家的全国性节日，定在每年的五月一日，它是全世界劳动人民共同拥有的节日。',
    'new_year': '公历新年的第一天，标志着新一年的开始。',
    'valentine': '西方传统节日，恋人们表达爱意的日子。',
    'women_day': '为庆祝妇女在经济、政治和社会等领域作出的重要贡献而设立的节日。',
    'arbor_day': '倡导人民种植树木，鼓励爱护树木，提醒人民重视树木。',
    'children_day': '保障世界各国儿童的生存权、保健权和受教育权，改善儿童生活的节日。',
    'party_day': '纪念中国共产党成立的节日。',
    'army_day': '纪念中国人民解放军成立的节日。',
    'teacher_day': '感谢教师为教育事业所做贡献的节日。',
    'national_day': '纪念中华人民共和国成立的节日。',
    'mothers_day': '感谢母亲的节日，每年5月第二个星期日。',
    'fathers_day': '感恩父亲的节日，每年6月第三个星期日。',
    'spring_festival': '农历正月初一，中华民族最隆重的传统佳节。',
    'lantern_festival': '农历正月十五，赏花灯、吃元宵的传统节日。',
    'dragon_head': '农历二月初二，俗称龙抬头，象征春回大地、万物复苏。',
    'qingming': '清明节气，祭奠先人、踏青迎春的时节。',
    'dragon_boat': '农历五月初五，纪念屈原、赛龙舟、吃粽子的传统节日。',
    'qixi': '农历七月初七，传统意义上的七夕情人节。',
    'ghost_festival': '农历七月十五，祭祖、缅怀先人的传统节日。',
    'mid_autumn': '农历八月十五，团圆赏月的传统节日。',
    'double_ninth': '农历九月初九，登高赏菊、敬老孝亲的节日。',
    'laba': '农历腊月初八，民间喝腊八粥、祈福迎新的习俗日。',
    'xiao_nian': '腊月二十三左右，民间「小年」，辞灶、忙年的开始。',
    'new_year_eve': '农历腊月最后一天，阖家团圆、守岁迎新的除夕夜。',
  };

  static String _festivalDescriptionForReminder(EventReminderData e) {
    final core = _festivalCoreIdFromReminderId(e.id);
    if (core == null) return '';
    return _kFestivalDescriptions[core] ?? '';
  }

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarWeekItem {
  _CalendarWeekItem.user(this.event, this.occurrenceDate) : festival = null;

  _CalendarWeekItem.festival(this.festival, this.occurrenceDate) : event = null;

  final ListEvent? event;
  final CalendarFestival? festival;
  final DateTime occurrenceDate;

  bool get isPinned => event?.isPinned ?? false;
  String get id =>
      event?.id ??
      'festival_${festival!.id}_${occurrenceDate.year}_${occurrenceDate.month}_${occurrenceDate.day}';
}

class _CalendarPageState extends State<CalendarPage> {
  bool _isMonthView = true;

  /// 周视图列表：`false` 本周焦点，`true` 当日焦点。
  bool _weekListDayMode = false;

  DateTime? _selectedDate;

  late int _viewYear;
  late int _viewMonth;

  late List<CalendarFestival> _monthFestivals;

  /// 已订阅节日 id；无持久化时用 [FestivalService.kDefaultSubscribedIds]。
  Set<String> _subscribedIds = {};

  /// 避免重复 setState：节日 prefs + 归档 id 快照一致时跳过。
  String? _cachedFestivalSubsJson;
  String _cachedArchiveKey = '';

  Set<String> _archivedEventIds = {};

  static const double _kScrollToCompress = 500;
  static const double _kCellExtentHi = 38;
  static const double _kCellExtentLo = 30;
  static const double _kMinListBody = 160;
  /// 与 `MonthSelector(compact: true)` 视觉高度近似对齐，用于判断是否启用整页滚动。
  static const double _kMonthSelectorCompactH = 58;
  static const double _kGridTopPad = 3;
  static const double _kWeekdayBand = 26;
  static const double _kCalToListGap = 16;
  static const double _kCalToListDividerH = 1;

  late final ScrollController _listController;
  late final ScrollController _pageScrollController;

  /// 0 = 日期行高 38px；1 = 压至 30px。
  double _compressT = 0;

  DateTime get _calendarToday {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    final t = _calendarToday;
    _viewYear = t.year;
    _viewMonth = t.month;
    _subscribedIds = Set<String>.from(FestivalService.kDefaultSubscribedIds);
    _loadMonthFestivals();
    _listController = ScrollController()..addListener(_compressFromScroll);
    _pageScrollController = ScrollController()..addListener(_compressFromScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await TagService.loadTags();
      if (!mounted) return;
      setState(() {});
      _loadSubscriptions();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) {
      _loadSubscriptions();
    }
  }

  @override
  void dispose() {
    _listController.removeListener(_compressFromScroll);
    _pageScrollController.removeListener(_compressFromScroll);
    _listController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  void _compressFromScroll() {
    ScrollController? c;
    if (_pageScrollController.hasClients) {
      c = _pageScrollController;
    } else if (_listController.hasClients) {
      c = _listController;
    }
    if (c == null) return;
    final o = c.offset;
    if (o < 0) return;
    final t = (o / _kScrollToCompress).clamp(0.0, 1.0);
    if ((t - _compressT).abs() > 0.005) {
      setState(() => _compressT = t);
    }
  }

  void _applyScrollReset() {
    if (_listController.hasClients) {
      _listController.jumpTo(0);
    }
    if (_pageScrollController.hasClients) {
      _pageScrollController.jumpTo(0);
    }
    _compressT = 0;
  }

  static const Color _kWeekLabelFg = Color(0xFF1F2937);
  static const Color _kWeekdayLabelFg = Color(0xFF94A3B8);
  static const Color _kWeekBorderCard = Color(0xFFF1F5F9);

  String get _monthLabel {
    if (_isMonthView) return '$_viewYear年$_viewMonth月';
    final d = _selectedDate ?? _calendarToday;
    return '${d.year}年${d.month}月';
  }

  DateTime get _weekSelectedDate => _selectedDate ?? _calendarToday;

  DateTime _weekStartSunday(DateTime day) {
    final d = CalendarPage._dateOnly(day);
    return d.subtract(Duration(days: d.weekday % 7));
  }

  DateTime get _weekStart => _weekStartSunday(_weekSelectedDate);

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  bool get _isDisplayingTodayWeek =>
      CalendarPage._dateOnly(_weekStart) ==
      CalendarPage._dateOnly(_weekStartSunday(_calendarToday));

  bool get _isDisplayingTodayMonth =>
      _viewYear == _calendarToday.year && _viewMonth == _calendarToday.month;

  bool get _isTodayDateSelected =>
      _selectedDate != null && _isSameDay(_selectedDate!, _calendarToday);

  bool get _todayBtnEnabled {
    if (_isMonthView) {
      return !(_isDisplayingTodayMonth && _isTodayDateSelected);
    }
    return !_isDisplayingTodayWeek;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _backToOverview() {
    if (_selectedDate == null) return;
    setState(() => _selectedDate = null);
  }

  List<ListEvent> _visibleListEventsRaw() {
    final today = _calendarToday;
    if (_selectedDate != null) {
      return widget.events
          .where(
            (e) =>
                !_archivedEventIds.contains(e.id) &&
                eventOccursOnGregorianDay(e, _selectedDate!),
          )
          .toList()
        ..sort(CalendarPage._eventSortListEvent);
    }
    return CalendarPage._filteredCalendarEvents(
      widget.events,
      today,
      archivedIds: _archivedEventIds,
    );
  }

  List<EventReminderData> _timelineReminders(
    List<ListEvent> raw, {
    DateTime? anchorDay,
  }) {
    final today = _calendarToday;
    return raw
        .map(
          (e) {
            final DateTime solar;
            final int dr;
            if (anchorDay != null) {
              solar = CalendarPage._dateOnly(anchorDay);
              dr = solar.difference(today).inDays;
            } else {
              solar = effectiveDate(e);
              dr = daysUntil(e);
            }
            return EventReminderData.forTimeline(
              e,
              effectiveSolarDate: solar,
              dateText: CalendarPage._formatEventDateLine(
                solar,
                lunar: e.isLunarRecurring,
              ),
              daysRemaining: dr,
              accentColor: TagService.accentForDisplay(e.tagId),
            );
          },
        )
        .toList();
  }

  Future<void> _loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(FestivalSubscriptionPrefs.storageKey);
    final hiddenStr = prefs.getString(FestivalSubscriptionPrefs.hiddenSilentKey);
    final archiveSnap =
        await MembershipService.loadArchivedEventIds();
    final archiveKey = (archiveSnap.toList()..sort()).join('|');
    final festivalCacheKey = '$jsonStr|$hiddenStr';
    if (!mounted) return;
    if (festivalCacheKey == _cachedFestivalSubsJson &&
        archiveKey == _cachedArchiveKey) {
      return;
    }
    _cachedFestivalSubsJson = festivalCacheKey;
    _cachedArchiveKey = archiveKey;

    Set<String> activeOnly;
    if (jsonStr != null) {
      try {
        activeOnly =
            (jsonDecode(jsonStr) as List<dynamic>).cast<String>().toSet();
      } catch (_) {
        activeOnly =
            Set<String>.from(FestivalService.kDefaultSubscribedIds);
      }
    } else {
      activeOnly =
          Set<String>.from(FestivalService.kDefaultSubscribedIds);
    }

    final merged =
        await MembershipService.calendarMergedFestivalIds(activeOnly);

    if (!mounted) return;
    setState(() {
      _subscribedIds = merged;
      _archivedEventIds = archiveSnap;
      _loadMonthFestivals();
    });
  }

  void _loadMonthFestivals() {
    _monthFestivals = FestivalService.getFestivalsForMonth(
      _viewYear,
      _viewMonth,
      subscribedIds: _subscribedIds,
    );
  }

  /// 替换下方旧实现
  List<CalendarFestival> _festivalsBetweenInclusive(DateTime start, DateTime end) {
    final out = <CalendarFestival>[];
    final seen = <String>{};
    var y = start.year;
    var m = start.month;
    final endYm = DateTime(end.year, end.month, 1);
    while (true) {
      final ym = DateTime(y, m, 1);
      if (ym.isAfter(endYm)) break;
      for (final f in FestivalService.getFestivalsForMonth(
        y,
        m,
        subscribedIds: _subscribedIds,
      )) {
        final d = CalendarPage._dateOnly(f.gregorianDate);
        if (!d.isBefore(start) && !d.isAfter(end)) {
          final key = '${f.id}_${d.year}_${d.month}_${d.day}';
          if (seen.add(key)) out.add(f);
        }
      }
      if (m == 12) {
        y++;
        m = 1;
      } else {
        m++;
      }
    }
    out.sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));
    return out;
  }

  EventReminderData _reminderForFestival(CalendarFestival f) {
    return EventReminderData.forFestival(
      f,
      today: _calendarToday,
      dateText: CalendarPage._formatEventDateLine(
        CalendarPage._dateOnly(f.gregorianDate),
        lunar: false,
      ),
    );
  }

  List<EventReminderData> _mergedTimelineReminders() {
    final today = _calendarToday;
    if (_selectedDate != null) {
      final raw = _visibleListEventsRaw();
      final user = _timelineReminders(raw, anchorDay: _selectedDate);
      final sel = _selectedDate!;
      final fest = _monthFestivals
          .where((f) => _isSameDay(CalendarPage._dateOnly(f.gregorianDate), sel))
          .map(_reminderForFestival)
          .toList();
      final merged = [...user, ...fest]..sort(CalendarPage._compareTimelineReminder);
      return merged;
    }
    final user = _timelineReminders(
      CalendarPage._filteredCalendarEvents(
        widget.events,
        today,
        archivedIds: _archivedEventIds,
      ),
    );
    final end = today.add(const Duration(days: 15));
    final fest =
        _festivalsBetweenInclusive(today, end).map(_reminderForFestival).toList();
    final merged = [...user, ...fest]..sort(CalendarPage._compareTimelineReminder);
    return merged;
  }

  void _showFestivalDetail(BuildContext context, EventReminderData e) {
    String categoryLabel(String? key) {
      switch (key) {
        case 'gregorian':
          return '公历节日';
        case 'lunar':
          return '农历节日';
        case 'ethnic':
          return '民族节日';
        case 'religious':
          return '宗教节日';
        default:
          return '节日';
      }
    }

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
    }

    final solar = CalendarPage._dateOnly(e.eventDate);
    final solarStr =
        '${solar.year}年${solar.month}月${solar.day}日 ${CalendarPage._zhWeekday(solar)}';
    final legacyIntro = CalendarPage._festivalDescriptionForReminder(e);
    final isEthnicOrReligious = e.festivalCategoryKey == 'ethnic' ||
        e.festivalCategoryKey == 'religious';
    final jsonIntro = (e.festivalDescription ?? '').trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.55;
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height,
            width: double.infinity,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: Container(
                  constraints: BoxConstraints(maxHeight: maxH),
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 28,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -4,
                                right: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                  tooltip: '关闭',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          e.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        row('公历日期', solarStr),
                        if ((e.festivalLunarLine ?? '').trim().isNotEmpty)
                          row('农历', e.festivalLunarLine!.trim()),
                        if ((e.festivalEthnicLine ?? '').trim().isNotEmpty)
                          row('民族历', e.festivalEthnicLine!.trim()),
                        if ((e.festivalReligiousLine ?? '').trim().isNotEmpty)
                          row('宗教历', e.festivalReligiousLine!.trim()),
                        if (!isEthnicOrReligious)
                          row(
                            '节日来源',
                            (e.festivalCategory ?? '').trim().isNotEmpty
                                ? e.festivalCategory!.trim()
                                : categoryLabel(e.festivalCategoryKey),
                          ),
                        if (isEthnicOrReligious && jsonIntro.isNotEmpty)
                          row('节日简介', jsonIntro),
                        if (!isEthnicOrReligious && legacyIntro.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '介绍',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  legacyIntro,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF0F172A),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        FutureBuilder<MembershipTier>(
                          future: MembershipService.currentTier(),
                          builder: (context, snapshot) {
                            final tier = snapshot.data ?? MembershipTier.free;
                            if (!MembershipService.benefits(tier)
                                .festivalShareCard) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A73E8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final navCtx = context;
                                    Navigator.pop(ctx);
                                    await Future<void>.delayed(
                                      const Duration(milliseconds: 120),
                                    );
                                    if (!navCtx.mounted) return;
                                    await ShareService.shareFestivalReminder(
                                      navCtx,
                                      e,
                                      solarStr,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.share_outlined,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    '分享节日卡片',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<CalendarDayCellData> _buildDayCells() {
    return buildCalendarMonthGrid(
      year: _viewYear,
      month: _viewMonth,
      selectedDate: _selectedDate,
      today: _calendarToday,
      eventsByDay: _eventsByDayForMonth(),
      festivalsByDay: _festivalsByDayForMonth(),
    );
  }

  void _onDateSelected(CalendarDayCellData day) {
    final date = day.calendarDate;
    if (date == null) return;
    setState(() {
      if (_selectedDate != null && _isSameDay(_selectedDate!, date)) {
        _selectedDate = null;
      } else {
        _selectedDate = CalendarPage._dateOnly(date);
      }
    });
  }

  void _onPrevMonth() {
    setState(() {
      if (_viewMonth <= 1) {
        _viewYear--;
        _viewMonth = 12;
      } else {
        _viewMonth--;
      }
      _selectedDate = null;
      _applyScrollReset();
      _loadMonthFestivals();
    });
  }

  void _onNextMonth() {
    setState(() {
      if (_viewMonth >= 12) {
        _viewYear++;
        _viewMonth = 1;
      } else {
        _viewMonth++;
      }
      _selectedDate = null;
      _applyScrollReset();
      _loadMonthFestivals();
    });
  }

  void _shiftWeek(int deltaDays) {
    setState(() {
      final next = _weekSelectedDate.add(Duration(days: deltaDays));
      _selectedDate = CalendarPage._dateOnly(next);
      _viewYear = _selectedDate!.year;
      _viewMonth = _selectedDate!.month;
      _applyScrollReset();
    });
  }

  void _onPrevPeriod() {
    if (_isMonthView) {
      _onPrevMonth();
    } else {
      _shiftWeek(-7);
    }
  }

  void _onNextPeriod() {
    if (_isMonthView) {
      _onNextMonth();
    } else {
      _shiftWeek(7);
    }
  }

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Map<String, List<ListEvent>> _eventsByDayForMonth() {
    final bounds = monthGridGregorianBounds(
      year: _viewYear,
      month: _viewMonth,
    );
    final m = <String, List<ListEvent>>{};
    for (final e in widget.events) {
      if (_archivedEventIds.contains(e.id)) continue;
      var d = bounds.start;
      while (!d.isAfter(bounds.end)) {
        if (eventOccursOnGregorianDay(e, d)) {
          final k = _dayKey(d);
          m.putIfAbsent(k, () => []).add(e);
        }
        d = d.add(const Duration(days: 1));
      }
    }
    return m;
  }

  Map<String, List<CalendarFestival>> _festivalsByDayForMonth() {
    final bounds = monthGridGregorianBounds(
      year: _viewYear,
      month: _viewMonth,
    );
    final m = <String, List<CalendarFestival>>{};
    for (final f in _festivalsBetweenInclusive(bounds.start, bounds.end)) {
      final k = _dayKey(CalendarPage._dateOnly(f.gregorianDate));
      m.putIfAbsent(k, () => []).add(f);
    }
    return m;
  }

  List<ListEvent> _eventsOnGregorianDay(DateTime day) {
    final list = <ListEvent>[];
    for (final e in widget.events) {
      if (_archivedEventIds.contains(e.id)) continue;
      if (eventOccursOnGregorianDay(e, day)) list.add(e);
    }
    return list;
  }

  List<CalendarFestival> _festivalsOnGregorianDay(DateTime day) {
    final target = CalendarPage._dateOnly(day);
    if (_isMonthView) {
      return _monthFestivals
          .where((f) => CalendarPage._dateOnly(f.gregorianDate) == target)
          .toList();
    }
    return _festivalsInWeek()
        .where((f) => CalendarPage._dateOnly(f.gregorianDate) == target)
        .toList();
  }

  List<CalendarFestival> _festivalsInWeek() {
    final out = <CalendarFestival>[];
    final seen = <String>{};
    var y = _weekStart.year;
    var m = _weekStart.month;
    final endYm = DateTime(_weekEnd.year, _weekEnd.month, 1);
    while (true) {
      final ym = DateTime(y, m, 1);
      if (ym.isAfter(endYm)) break;
      for (final f in FestivalService.getFestivalsForMonth(
        y,
        m,
        subscribedIds: _subscribedIds,
      )) {
        final d = CalendarPage._dateOnly(f.gregorianDate);
        if (!d.isBefore(_weekStart) && !d.isAfter(_weekEnd)) {
          final key = '${f.id}_${d.year}_${d.month}_${d.day}';
          if (seen.add(key)) out.add(f);
        }
      }
      if (m == 12) {
        y++;
        m = 1;
      } else {
        m++;
      }
    }
    out.sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));
    return out;
  }

  /// 周视图「当日焦点」：未过期置顶→未过期非置顶（均升序）；已过期置底（降序，最近在前）。
  int _compareWeekItem(_CalendarWeekItem a, _CalendarWeekItem b) {
    final today = _calendarToday;
    final aDay = CalendarPage._dateOnly(a.occurrenceDate);
    final bDay = CalendarPage._dateOnly(b.occurrenceDate);
    final aExpired = aDay.isBefore(today);
    final bExpired = bDay.isBefore(today);

    if (aExpired != bExpired) return aExpired ? 1 : -1;

    if (aExpired) {
      final c = bDay.compareTo(aDay);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    }

    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    final c = aDay.compareTo(bDay);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  List<_CalendarWeekItem> _weekDayItems() {
    final focus = CalendarPage._dateOnly(_weekSelectedDate);
    final items = <_CalendarWeekItem>[];
    for (final e in widget.events) {
      if (_archivedEventIds.contains(e.id)) continue;
      if (eventOccursOnGregorianDay(e, focus)) {
        items.add(_CalendarWeekItem.user(e, focus));
      }
    }
    for (final f in _festivalsOnGregorianDay(focus)) {
      items.add(_CalendarWeekItem.festival(f, focus));
    }
    items.sort(_compareWeekItem);
    return items;
  }

  List<_CalendarWeekItem> _weekAllItems() {
    final items = <_CalendarWeekItem>[];
    for (final e in widget.events) {
      if (_archivedEventIds.contains(e.id)) continue;
      for (var i = 0; i < 7; i++) {
        final d = CalendarPage._dateOnly(_weekStart.add(Duration(days: i)));
        if (eventOccursOnGregorianDay(e, d)) {
          items.add(_CalendarWeekItem.user(e, d));
        }
      }
    }
    for (final f in _festivalsInWeek()) {
      items.add(
        _CalendarWeekItem.festival(
          f,
          CalendarPage._dateOnly(f.gregorianDate),
        ),
      );
    }
    items.sort(_compareWeekItem);
    return items;
  }

  List<_CalendarWeekItem> _weekListItems() =>
      _weekListDayMode ? _weekDayItems() : _weekAllItems();

  void _goToToday() {
    setState(() {
      _selectedDate = _calendarToday;
      _viewYear = _calendarToday.year;
      _viewMonth = _calendarToday.month;
      _applyScrollReset();
      _loadMonthFestivals();
    });
  }

  void _notifyEventsChanged(List<ListEvent> updated) {
    widget.onEventsChanged?.call(updated);
  }

  Future<void> _openWeekEventEdit(ListEvent event) async {
    final result = await Navigator.push<ListEvent>(
      context,
      MaterialPageRoute(builder: (_) => EventAddPage(initialEvent: event)),
    );
    if (result == null || !mounted) return;
    final list = List<ListEvent>.from(widget.events);
    final i = list.indexWhere((e) => e.id == result.id);
    if (i >= 0) {
      list[i] = result;
      _notifyEventsChanged(list);
    }
  }

  Future<void> _confirmDeleteWeekEvent(ListEvent event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除提醒'),
        content: Text('确定删除「${event.title}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final list = List<ListEvent>.from(widget.events)..removeWhere((e) => e.id == event.id);
    _notifyEventsChanged(list);
  }

  Widget _monthWeekPill() {
    const themeBlue = Color(0xFF1A73E8);
    const unselectedBg = Color(0xFFF1F5F9);
    const unselectedFg = Color(0xFF64748B);

    Widget segment(String label, {required bool selected, required VoidCallback onTap}) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? themeBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : unselectedFg,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 64,
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: unselectedBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            segment(
              '月',
              selected: _isMonthView,
              onTap: () {
                if (_isMonthView) return;
                setState(() {
                  _isMonthView = true;
                  if (_selectedDate != null) {
                    _viewYear = _selectedDate!.year;
                    _viewMonth = _selectedDate!.month;
                    _loadMonthFestivals();
                  }
                  _applyScrollReset();
                });
              },
            ),
            segment(
              '周',
              selected: !_isMonthView,
              onTap: () {
                if (!_isMonthView) return;
                setState(() {
                  _isMonthView = false;
                  _weekListDayMode = false;
                  _selectedDate ??= _calendarToday;
                  _viewYear = _weekSelectedDate.year;
                  _viewMonth = _weekSelectedDate.month;
                  _applyScrollReset();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerNavChevron({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 24, color: const Color(0xFF64748B)),
      ),
    );
  }

  Widget _weekScopePill() {
    const themeBlue = Color(0xFF1A73E8);
    const unselectedBg = Color(0xFFF1F5F9);
    const unselectedFg = Color(0xFF64748B);

    Widget segment(String label, {required bool selected, required VoidCallback onTap}) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? themeBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : unselectedFg,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 80,
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: unselectedBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            segment(
              '当日',
              selected: _weekListDayMode,
              onTap: () {
                if (_weekListDayMode) return;
                setState(() => _weekListDayMode = true);
              },
            ),
            segment(
              '本周',
              selected: !_weekListDayMode,
              onTap: () {
                if (!_weekListDayMode) return;
                setState(() => _weekListDayMode = false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendarMonthHeader(BuildContext context) {
    const themeBlue = Color(0xFF1A73E8);
    final g = SizeConfig.contentGutter(context);
    final primary = Theme.of(context).colorScheme.primary;
    final titleSize = SizeConfig.sp(context, 20);
    final todayBtnEnabled = _todayBtnEnabled;

    return Padding(
      padding: EdgeInsets.fromLTRB(g, 8, g, 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _onTitleTap,
                borderRadius: BorderRadius.circular(8),
                splashColor: primary.withValues(alpha: 0.12),
                highlightColor: primary.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _monthLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            color: primary,
                            height: 1.4,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _monthWeekPill(),
          const SizedBox(width: 24),
          _headerNavChevron(
            icon: Icons.chevron_left_rounded,
            onTap: _onPrevPeriod,
          ),
          const SizedBox(width: 8),
          _headerNavChevron(
            icon: Icons.chevron_right_rounded,
            onTap: _onNextPeriod,
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: todayBtnEnabled ? _goToToday : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                '今天',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: todayBtnEnabled
                      ? themeBlue
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onTitleTap() async {
    final r = await showYearMonthPicker(
      context,
      initialYear: _viewYear,
      initialMonth: _viewMonth,
    );
    if (!mounted || r == null) return;
    if (r.year < 1900 || r.year > 2050) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择 1900-2050 范围内的年份'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _viewYear = r.year;
      _viewMonth = r.month;
      if (_isMonthView) {
        _selectedDate = null;
      } else {
        _selectedDate = DateTime(r.year, r.month, 1);
      }
      _applyScrollReset();
      _loadMonthFestivals();
    });
  }

  Widget _weekCalendarStrip(BuildContext context) {
    final g = SizeConfig.contentGutter(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(g, 8, g, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kWeekBorderCard, width: 0.75),
          boxShadow: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 2,
              offset: Offset(0, 1),
              spreadRadius: -1,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Row(
              children: CalendarPage._weekDays
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _kWeekdayLabelFg,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(7, (i) {
                final d = CalendarPage._dateOnly(_weekStart.add(Duration(days: i)));
                return Expanded(
                  child: CalendarDayCell(
                    date: d,
                    selectedDate: _selectedDate,
                    today: _calendarToday,
                    events: _eventsOnGregorianDay(d),
                    festivals: _festivalsOnGregorianDay(d),
                    isInCurrentMonth: true,
                    onTap: () => setState(() {
                      _selectedDate = d;
                      _weekListDayMode = true;
                    }),
                    selectedBackgroundColor: const Color(0xFF93C5FD),
                    selectedTextColor: const Color(0xFF1A73E8),
                    todayBackgroundColor: const Color(0xFFE8F0FE),
                    todayTextColor: const Color(0xFF1A73E8),
                    highlightLunarOnFestival: true,
                    lunarTextStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF94A3B8),
                    ),
                    cellPadding: 4,
                    dayFontSize: 16,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekBody(BuildContext context) {
    final dayMode = _weekListDayMode;
    final items = _weekListItems();
    final pinnedCount = items.where((i) => i.isPinned).length;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final listBottom = bottomPad + 100 > 160 ? bottomPad + 100 : 160.0;
    final listDataCount = items.isEmpty ? 1 : items.length;
    final focusTitle = dayMode ? '当日焦点' : '本周焦点';
    final emptyHint = dayMode ? '当日暂无提醒' : '本周暂无提醒';

    return ListView.separated(
      padding: EdgeInsets.only(bottom: listBottom),
      itemCount: listDataCount + 2,
      separatorBuilder: (context, index) {
        if (index == 0) return const SizedBox.shrink();
        if (index == 1) return const SizedBox(height: 12);
        return const SizedBox(height: 12);
      },
      itemBuilder: (context, index) {
        if (index == 0) return _weekCalendarStrip(context);
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        focusTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _kWeekLabelFg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${items.length} 个提醒 · $pinnedCount 个置顶',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: _kWeekdayLabelFg,
                        ),
                      ),
                    ],
                  ),
                ),
                _weekScopePill(),
              ],
            ),
          );
        }
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Center(
              child: Text(
                emptyHint,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          );
        }
        final item = items[index - 2];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: item.festival != null
              ? WeekViewEventCard.festival(
                  festival: item.festival!,
                  occurrenceDate: item.occurrenceDate,
                  today: _calendarToday,
                )
              : WeekViewEventCard(
                  event: item.event!,
                  occurrenceDate: item.occurrenceDate,
                  today: _calendarToday,
                  onTap: () {
                    showEventDetailSheet(
                      context,
                      item.event!,
                      onEdit: () => _openWeekEventEdit(item.event!),
                    );
                  },
                  onEdit: () => _openWeekEventEdit(item.event!),
                  onDelete: () => _confirmDeleteWeekEvent(item.event!),
                ),
        );
      },
    );
  }

  String _timelineTitle() => _selectedDate == null ? '未来15天' : '当日事件';

  double _cellExtentForCompress(double t) => _kCellExtentHi - (_kCellExtentHi - _kCellExtentLo) * t;

  double _calendarBlockHeight(int rowCount, double cellExtent, double dayGutter) {
    final gridH = _kGridTopPad + _kWeekdayBand + rowCount * cellExtent;
    final bridge = _kCalToListGap + _kCalToListDividerH;
    return _kMonthSelectorCompactH + gridH + dayGutter + bridge;
  }

  @override
  Widget build(BuildContext context) {
    final dayMode = _selectedDate != null;
    final gutterH = SizeConfig.screenHeight(context) * 0.01;
    final dayGutter = (dayMode && gutterH > 0) ? gutterH : 0.0;

    final cells = _buildDayCells();
    final rowCount = (cells.length / 7).ceil();
    final cellExtent = _cellExtentForCompress(_compressT);
    final timelineTitle = _timelineTitle();
    final timelineEvents = _mergedTimelineReminders();

    Widget calendarColumn(double maxWidth) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: dayMode ? _backToOverview : null,
            child: CalendarGrid(
              weekDayLabels: CalendarPage._weekDays,
              dayCells: cells,
              maxWidth: maxWidth,
              today: _calendarToday,
              selectedDate: _selectedDate,
              targetCellMainExtent: cellExtent,
              onDateSelected: _onDateSelected,
            ),
          ),
        ],
      );
    }

    Widget calListBridge() => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: _kCalToListGap),
            Divider(
              height: _kCalToListDividerH,
              thickness: 1,
              color: Colors.grey.shade200,
            ),
          ],
        );

    Widget timelineSliver({required bool shrinkWrap}) {
      return EventTimelineList(
        title: timelineTitle,
        events: timelineEvents,
        isDayDetailMode: dayMode,
        onBackToOverview: dayMode ? _backToOverview : null,
        scrollController: shrinkWrap ? null : _listController,
        shrinkWrapList: shrinkWrap,
        onEventTap: (reminder) {
          if (reminder.isFestival) {
            _showFestivalDetail(context, reminder);
          } else {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              barrierColor: Colors.black54,
              builder: (ctx) {
                final src = reminder.sourceListEvent;
                if (src != null) {
                  return EventDetailSheet(event: src);
                }
                return EventDetailSheet(event: reminder.toListEvent());
              },
            );
          }
        },
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _calendarMonthHeader(context),
            Expanded(
              child: _isMonthView
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final maxW = constraints.maxWidth;
                        final maxH = constraints.maxHeight;
                        final calBlockH =
                            _calendarBlockHeight(rowCount, cellExtent, dayGutter);
                        final remaining = maxH - calBlockH;
                        final outerScroll = remaining < _kMinListBody;

                        final afterCalSpacer = dayMode && gutterH > 0
                            ? GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: _backToOverview,
                                child: SizedBox(height: gutterH),
                              )
                            : null;

                        if (outerScroll) {
                          return SingleChildScrollView(
                            controller: _pageScrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                calendarColumn(maxW),
                                ?afterCalSpacer,
                                calListBridge(),
                                timelineSliver(shrinkWrap: true),
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            calendarColumn(maxW),
                            ?afterCalSpacer,
                            calListBridge(),
                            Expanded(
                              child: timelineSliver(shrinkWrap: false),
                            ),
                          ],
                        );
                      },
                    )
                  : _buildWeekBody(context),
            ),
          ],
        ),
      ),
    );
  }
}
