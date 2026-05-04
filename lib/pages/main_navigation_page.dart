import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/pages/calendar_page.dart';
import 'package:time_calendar/pages/list_page.dart';
import 'package:time_calendar/pages/profile_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key, this.initialIndex = 0})
      : assert(initialIndex >= 0 && initialIndex < 3);

  /// 0: 日历, 1: 清单, 2: 我的
  final int initialIndex;

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

List<ListEvent> _initialGlobalMockEvents() {
  // 基准日期：2026-05-02（周六）。ListEvent 字段均为非空，不适用提醒项使用占位默认值。
  return [
    ListEvent(
      id: '1',
      title: '妈妈的生日',
      baseDate: DateTime(2026, 4, 25),
      category: ListCategory.birthday,
      isPinned: true,
      isLunarRecurring: true,
      isLunarDate: true,
      repeatRule: EventRepeatRule.yearly,
      reminderType: EventReminderType.advanceAndSameDay,
      advanceDaysOption: EventAdvanceDaysOption.oneDay,
      advanceTimeHm: '09:00',
      sameDayTimeHm: '09:00',
      isExpired: false,
    ),
    ListEvent(
      id: '2',
      title: '恋爱纪念日',
      baseDate: DateTime(2026, 5, 3),
      category: ListCategory.partner,
      isPinned: true,
      isLunarRecurring: false,
      isLunarDate: false,
      repeatRule: EventRepeatRule.yearly,
      reminderType: EventReminderType.sameDayOnly,
      advanceDaysOption: EventAdvanceDaysOption.oneDay,
      advanceTimeHm: '09:00',
      sameDayTimeHm: '09:00',
      isExpired: false,
    ),
    ListEvent(
      id: '3',
      title: '考研倒计时',
      baseDate: DateTime(2026, 12, 25),
      category: ListCategory.goal,
      isPinned: false,
      isLunarRecurring: false,
      isLunarDate: false,
      repeatRule: EventRepeatRule.none,
      reminderType: EventReminderType.sameDayOnly,
      advanceDaysOption: EventAdvanceDaysOption.oneDay,
      advanceTimeHm: '09:00',
      sameDayTimeHm: '09:00',
      isExpired: false,
    ),
    ListEvent(
      id: '4',
      title: '周杰伦演唱会',
      baseDate: DateTime(2026, 4, 28),
      category: ListCategory.idol,
      isPinned: false,
      isLunarRecurring: false,
      isLunarDate: false,
      repeatRule: EventRepeatRule.none,
      reminderType: EventReminderType.sameDayOnly,
      advanceDaysOption: EventAdvanceDaysOption.oneDay,
      advanceTimeHm: '09:00',
      sameDayTimeHm: '18:00',
      isExpired: true,
    ),
    ListEvent(
      id: '5',
      title: '父亲生日',
      baseDate: DateTime(2026, 4, 20),
      category: ListCategory.birthday,
      isPinned: false,
      isLunarRecurring: true,
      isLunarDate: true,
      repeatRule: EventRepeatRule.yearly,
      reminderType: EventReminderType.advanceAndSameDay,
      advanceDaysOption: EventAdvanceDaysOption.threeDays,
      advanceTimeHm: '09:00',
      sameDayTimeHm: '09:00',
      isExpired: false,
    ),
    ListEvent(
      id: '6',
      title: '项目交付截止',
      baseDate: DateTime(2026, 5, 15),
      category: ListCategory.goal,
      isPinned: true,
      isLunarRecurring: false,
      isLunarDate: false,
      repeatRule: EventRepeatRule.none,
      reminderType: EventReminderType.advanceAndSameDay,
      advanceDaysOption: EventAdvanceDaysOption.oneWeek,
      advanceTimeHm: '09:00',
      sameDayTimeHm: '09:00',
      isExpired: false,
    ),
    ListEvent(
      id: '7',
      title: '晨跑打卡',
      baseDate: DateTime(2026, 5, 2),
      category: ListCategory.goal,
      isPinned: false,
      isLunarRecurring: false,
      isLunarDate: false,
      repeatRule: EventRepeatRule.daily,
      reminderType: EventReminderType.sameDayOnly,
      advanceDaysOption: EventAdvanceDaysOption.oneDay,
      advanceTimeHm: '09:00',
      sameDayTimeHm: '07:00',
      isExpired: false,
    ),
    ListEvent(
      id: '8',
      title: '团队周会',
      baseDate: DateTime(2026, 5, 5),
      category: ListCategory.goal,
      isPinned: false,
      isLunarRecurring: false,
      isLunarDate: false,
      repeatRule: EventRepeatRule.weekly,
      reminderType: EventReminderType.sameDayOnly,
      advanceDaysOption: EventAdvanceDaysOption.oneDay,
      advanceTimeHm: '09:00',
      sameDayTimeHm: '09:00',
      isExpired: false,
    ),
    ListEvent(
      id: '9',
      title: '还信用卡',
      baseDate: DateTime(2026, 5, 10),
      category: ListCategory.partner,
      isPinned: false,
      isLunarRecurring: false,
      isLunarDate: false,
      repeatRule: EventRepeatRule.monthly,
      reminderType: EventReminderType.advanceOnly,
      advanceDaysOption: EventAdvanceDaysOption.oneDay,
      advanceTimeHm: '09:00',
      sameDayTimeHm: '09:00',
      isExpired: false,
    ),
    ListEvent(
      id: '10',
      title: '爷爷生日',
      baseDate: DateTime(2026, 3, 15),
      category: ListCategory.birthday,
      isPinned: false,
      isLunarRecurring: true,
      isLunarDate: true,
      repeatRule: EventRepeatRule.yearly,
      reminderType: EventReminderType.advanceAndSameDay,
      advanceDaysOption: EventAdvanceDaysOption.oneDay,
      advanceTimeHm: '09:00',
      sameDayTimeHm: '09:00',
      isExpired: false,
    ),
  ];
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late int _currentIndex;
  late List<ListEvent> _globalEvents;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _globalEvents = _initialGlobalMockEvents();
  }

  final List<String> _labels = const ['日历', '清单', '我的'];

  static const List<String> _tabIcons = [
    'assets/images/tab/ic_calendar.svg',
    'assets/images/tab/ic_list.svg',
    'assets/images/tab/ic_profile.svg',
  ];

  Widget _pageAt(int index) {
    switch (index) {
      case 0:
        return CalendarPage(events: _globalEvents);
      case 1:
        return ListPage(
          initialEvents: _globalEvents,
          onEventsChanged: (updated) => setState(() => _globalEvents = updated),
        );
      case 2:
        return const ProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: null,
      body: _pageAt(_currentIndex),
      bottomNavigationBar: _MainTabBar(
        currentIndex: _currentIndex,
        labels: _labels,
        iconAssets: _tabIcons,
        colorScheme: cs,
        onChanged: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _MainTabBar extends StatelessWidget {
  const _MainTabBar({
    required this.currentIndex,
    required this.labels,
    required this.iconAssets,
    required this.colorScheme,
    required this.onChanged,
  });

  final int currentIndex;
  final List<String> labels;
  final List<String> iconAssets;
  final ColorScheme colorScheme;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      elevation: 0,
      child: SafeArea(
        top: false,
        left: true,
        right: true,
        bottom: true,
        child: Container(
          height: 57,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: cs.outline, width: 0.7),
            ),
          ),
          child: Row(
            children: List.generate(3, (i) {
              final selected = currentIndex == i;
              return Expanded(
                child: _TabItem(
                  asset: iconAssets[i],
                  label: labels[i],
                  selected: selected,
                  colorScheme: cs,
                  onTap: () => onChanged(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.asset,
    required this.label,
    required this.selected,
    required this.colorScheme,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final active = cs.primary;
    final idle = cs.onSurfaceVariant;
    final color = selected ? active : idle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: cs.primary.withValues(alpha: 0.08),
        highlightColor: cs.primary.withValues(alpha: 0.04),
        child: SizedBox(
          height: 57,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: SvgPicture.asset(
                  asset,
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  letterSpacing: 0.06,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 2,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: selected ? 24 : 0,
                    height: 2,
                    decoration: BoxDecoration(
                      color: selected ? active : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
