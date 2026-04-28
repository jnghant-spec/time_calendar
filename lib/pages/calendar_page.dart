import 'package:flutter/material.dart';
import 'package:time_calendar/utils/size_config.dart';
import 'package:time_calendar/widgets/calendar/calendar_grid.dart';
import 'package:time_calendar/widgets/calendar/calendar_models.dart';
import 'package:time_calendar/widgets/calendar/calendar_month_builder.dart';
import 'package:time_calendar/widgets/calendar/event_timeline_list.dart';
import 'package:time_calendar/widgets/calendar/month_selector.dart';
import 'package:time_calendar/widgets/calendar/year_month_picker_sheet.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  static const List<String> _weekDays = ['日', '一', '二', '三', '四', '五', '六'];

  static const List<String> _kWeekdayZh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  static String _zhWeekday(DateTime d) => _kWeekdayZh[d.weekday - 1];

  static String _formatEventDateLine(DateTime date, {bool lunar = false}) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final base = '$y-$m-$day ${_zhWeekday(date)}';
    if (lunar) return '$base (农历)';
    return '$base ';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 示例数据：以 [anchor] 为「今天」，按天偏移；`daysRemaining` 与差值一致。
  static List<EventReminderData> _buildAllMockEvents(DateTime anchor) {
    const partner = Color(0xFFF43F5E);
    const birthday = Color(0xFFF97316);
    const goal = Color(0xFF3B82F6);
    const idol = Color(0xFFA855F7);
    const festival = Color(0xFF10B981);

    final t0 = _dateOnly(anchor);

    EventReminderData ev(
      String title,
      int daysFromToday,
      Color color, {
      bool isPinned = false,
      bool lunar = false,
    }) {
      final d = t0.add(Duration(days: daysFromToday));
      return EventReminderData(
        eventDate: d,
        dateText: _formatEventDateLine(d, lunar: lunar),
        title: title,
        daysRemaining: _dateOnly(d).difference(t0).inDays,
        accentColor: color,
        isPinned: isPinned,
      );
    }

    // 与原先 2026-04-26 锚定时的相对关系对齐（今起 0~15 天窗 + 置顶/长尾）
    return [
      ev('恋爱纪念日（两周年）', 1, partner, isPinned: true),
      ev('考研倒计时', 242, goal, isPinned: true),
      ev('项目交付截止', 13, goal, isPinned: true),
      ev('清明节踏青', 0, festival),
      ev('父亲生日', 3, birthday, lunar: true),
      ev('劳动节', 4, festival),
      ev('周杰伦演唱会', 4, idol),
      ev('闺蜜生日', 8, birthday),
      ev('偶像新剧开播', 11, idol),
      ev('结婚3周年提醒', 23, partner),
      ev('母亲生日', 18, birthday),
      ev('端午节', 48, festival, lunar: true),
      ev('高考倒计时', 41, goal),
    ];
  }

  static bool _isVisibleOnCalendarTimeline(EventReminderData e, DateTime today) {
    final days = _dateOnly(e.eventDate).difference(_dateOnly(today)).inDays;
    if (days < 0) return false;
    if (e.isPinned) return true;
    return days <= 15;
  }

  static int _eventSort(EventReminderData a, EventReminderData b) {
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }
    final c = a.eventDate.compareTo(b.eventDate);
    if (c != 0) return c;
    return a.title.compareTo(b.title);
  }

  static List<EventReminderData> _filteredCalendarEvents(
    Iterable<EventReminderData> source,
    DateTime today,
  ) {
    final list = source.where((e) => _isVisibleOnCalendarTimeline(e, today)).toList()..sort(_eventSort);
    return list;
  }

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime? _selectedDate;

  late int _viewYear;
  late int _viewMonth;

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
    _listController = ScrollController()..addListener(_compressFromScroll);
    _pageScrollController = ScrollController()..addListener(_compressFromScroll);
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

  String get _monthLabel => '$_viewYear年$_viewMonth月';

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _backToOverview() {
    if (_selectedDate == null) return;
    setState(() => _selectedDate = null);
  }

  List<EventReminderData> get _allMock {
    return CalendarPage._buildAllMockEvents(_calendarToday);
  }

  Map<String, List<Color>> _markerByDay() {
    final m = <String, List<Color>>{};
    for (final e in _allMock) {
      final k = '${e.eventDate.year}-${e.eventDate.month}-${e.eventDate.day}';
      m.putIfAbsent(k, () => []);
      if (m[k]!.length < 2 && !m[k]!.contains(e.accentColor)) {
        m[k]!.add(e.accentColor);
      }
    }
    return m;
  }

  List<CalendarDayCellData> _buildDayCells() {
    return buildCalendarMonthGrid(
      year: _viewYear,
      month: _viewMonth,
      selectedDate: _selectedDate,
      today: _calendarToday,
      markerByDay: _markerByDay(),
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
    if (_viewMonth <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已是最早月份'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() {
      _viewMonth--;
      _selectedDate = null;
      _applyScrollReset();
    });
  }

  void _onNextMonth() {
    if (_viewMonth >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已是最晚月份'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() {
      _viewMonth++;
      _selectedDate = null;
      _applyScrollReset();
    });
  }

  Future<void> _onTitleTap() async {
    final r = await showYearMonthPicker(
      context,
      initialYear: _viewYear,
      initialMonth: _viewMonth,
    );
    if (!mounted || r == null) return;
    if (r.year != 2026) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('提示'),
          content: const Text('该年份数据待补充，请先使用2026年'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() {
        _viewYear = 2026;
        _viewMonth = 4;
        _selectedDate = null;
        _applyScrollReset();
      });
      return;
    }
    setState(() {
      _viewYear = r.year;
      _viewMonth = r.month;
      _selectedDate = null;
      _applyScrollReset();
    });
  }

  List<EventReminderData> _visibleEvents() {
    final today = _calendarToday;
    if (_selectedDate != null) {
      return _allMock
          .where((e) => _isSameDay(e.eventDate, _selectedDate!))
          .toList()
        ..sort(CalendarPage._eventSort);
    }
    return CalendarPage._filteredCalendarEvents(_allMock, today);
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
    final timelineEvents = _visibleEvents();

    Widget calendarColumn(double maxWidth) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: dayMode ? _backToOverview : null,
            child: MonthSelector(
              monthLabel: _monthLabel,
              compact: true,
              onPreviousMonth: _onPrevMonth,
              onNextMonth: _onNextMonth,
              onTitleTap: _onTitleTap,
            ),
          ),
          CalendarGrid(
            weekDayLabels: CalendarPage._weekDays,
            dayCells: cells,
            maxWidth: maxWidth,
            targetCellMainExtent: cellExtent,
            onDateSelected: _onDateSelected,
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
      );
    }

    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final maxH = constraints.maxHeight;
            final calBlockH = _calendarBlockHeight(rowCount, cellExtent, dayGutter);
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
        ),
      ),
    );
  }
}
