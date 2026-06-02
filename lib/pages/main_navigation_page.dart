import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/pages/calendar_page.dart';
import 'package:time_calendar/pages/list_page.dart';
import 'package:time_calendar/pages/memory_page.dart';
import 'package:time_calendar/pages/membership_sheet.dart';
import 'package:time_calendar/pages/profile_page.dart';
import 'package:time_calendar/services/event_usage_service.dart';
import 'package:time_calendar/services/membership_service.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key, this.initialIndex = 0})
    : assert(initialIndex >= 0 && initialIndex < 4);

  /// 0: 日历, 1: 清单, 2: 时光集, 3: 我的
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
      tagId: 'birthday',
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
      tagId: 'partner',
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
      tagId: 'goal',
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
      tagId: 'idol',
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
      tagId: 'birthday',
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
      tagId: 'goal',
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
      tagId: 'goal',
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
      tagId: 'goal',
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
      tagId: 'partner',
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
      tagId: 'birthday',
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
    EventUsageService.updateCount(_globalEvents.length);
    MembershipService.syncArchivedEventsForTier(_globalEvents);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowTrialEndedSnack(),
    );
  }

  Future<void> _maybeShowTrialEndedSnack() async {
    if (!mounted) return;
    if (!await MembershipService.consumeTrialEndedBannerFlag()) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('高级体验已结束，已为你保留全部订阅设置，升级即可恢复提醒'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '查看会员',
          textColor: const Color(0xFF60A5FA),
          onPressed: () {
            showMembershipSheet(context);
          },
        ),
      ),
    );
  }

  void _onEventsChanged(List<ListEvent> updated) {
    setState(() => _globalEvents = updated);
    MembershipService.syncArchivedEventsForTier(updated);
    EventUsageService.updateCount(updated.length);
  }

  void _onMembershipTierChanged() {
    MembershipService.syncArchivedEventsForTier(_globalEvents);
    MembershipService.reconcileFestivalSubscriptions();
    if (!mounted) return;
    setState(() {});
  }

  final List<String> _labels = const ['日历', '清单', '时光集', '我的'];

  static const Color _tabSelected = Color(0xFF1A73E8);
  static const Color _tabIdle = Color(0xFF94A3B8);

  Widget _pageAt(int index) {
    switch (index) {
      case 0:
        return CalendarPage(events: _globalEvents);
      case 1:
        return ListPage(
          initialEvents: _globalEvents,
          onEventsChanged: _onEventsChanged,
        );
      case 2:
        return const MemoryPage();
      case 3:
        return ProfilePage(
          existingEvents: _globalEvents,
          onBirthdaysImported: (imported) {
            _onEventsChanged([..._globalEvents, ...imported]);
          },
          onMembershipTierChanged: _onMembershipTierChanged,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: _pageAt(_currentIndex),
      bottomNavigationBar: _MainTabBar(
        currentIndex: _currentIndex,
        labels: _labels,
        selectedColor: _tabSelected,
        idleColor: _tabIdle,
        onChanged: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _MainTabBar extends StatelessWidget {
  const _MainTabBar({
    required this.currentIndex,
    required this.labels,
    required this.selectedColor,
    required this.idleColor,
    required this.onChanged,
  });

  final int currentIndex;
  final List<String> labels;
  final Color selectedColor;
  final Color idleColor;
  final ValueChanged<int> onChanged;

  Widget _tabIcon(int index, Color color) {
    switch (index) {
      case 0:
        return SvgPicture.asset(
          'assets/images/tab/ic_calendar.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      case 1:
        return SvgPicture.asset(
          'assets/images/tab/ic_list.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      case 2:
        return Icon(Icons.photo_album, size: 24, color: color);
      case 3:
        return SvgPicture.asset(
          'assets/images/tab/ic_profile.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      default:
        return const SizedBox(width: 24, height: 24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
            border: Border(top: BorderSide(color: cs.outline, width: 0.7)),
          ),
          child: Row(
            children: List.generate(4, (i) {
              final selected = currentIndex == i;
              final color = selected ? selectedColor : idleColor;
              return Expanded(
                child: _TabItem(
                  icon: _tabIcon(i, color),
                  label: labels[i],
                  selected: selected,
                  selectedColor: selectedColor,
                  idleColor: idleColor,
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
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.idleColor,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color idleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : idleColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: selectedColor.withValues(alpha: 0.08),
        highlightColor: selectedColor.withValues(alpha: 0.04),
        child: SizedBox(
          height: 57,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 24, height: 24, child: icon),
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
                      color: selected ? selectedColor : Colors.transparent,
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
