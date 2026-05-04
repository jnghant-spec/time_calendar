import 'package:flutter/material.dart';
import 'package:time_calendar/utils/size_config.dart';
import 'package:time_calendar/widgets/calendar/calendar_models.dart';
import 'package:time_calendar/widgets/calendar/event_reminder_card.dart';

class EventTimelineList extends StatelessWidget {
  const EventTimelineList({
    super.key,
    required this.title,
    required this.events,
    this.isDayDetailMode = false,
    this.onBackToOverview,
    this.onTogglePin,
    this.onEventTap,
    this.scrollController,
    this.shrinkWrapList = false,
  });

  static const Color _titleColor = Color(0xFF1D293D);
  static const Color _subtitleColor = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFF1F5F9);
  /// 节日时间线卡片：与用户事件卡片区分，且仅保留一枚「节日」标签（不叠用 EventReminderCard 的尾部「节日」文案）。
  static const Color _festivalGreen = Color(0xFF10B981);

  final String title;
  final List<EventReminderData> events;
  final bool isDayDetailMode;
  final VoidCallback? onBackToOverview;
  final ValueChanged<EventReminderData>? onTogglePin;
  final void Function(EventReminderData reminder)? onEventTap;
  final ScrollController? scrollController;
  final bool shrinkWrapList;

  static const double _headerBandH = 40;
  static const double _titleFont = 18;
  static const double _subtitleFont = 12;

  @override
  Widget build(BuildContext context) {
    final g = SizeConfig.contentGutter(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const topPad = 4.0;
    const sectionGap = 8.0;

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: const Border(
          left: BorderSide(color: _borderColor, width: 0.75),
          right: BorderSide(color: _borderColor, width: 0.75),
          bottom: BorderSide(color: _borderColor, width: 0.75),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(g, topPad, g, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _headerBandH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: _titleFont,
                            fontWeight: FontWeight.w700,
                            color: _titleColor,
                            height: 1.15,
                            letterSpacing: -0.44,
                          ),
                        ),
                        if (events.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '共 ${events.length} 条',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: _subtitleFont,
                              fontWeight: FontWeight.w400,
                              color: _subtitleColor,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isDayDetailMode)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.symmetric(horizontal: SizeConfig.sp(context, 6)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onBackToOverview,
                      child: Text(
                        '返回总览',
                        style: TextStyle(
                          fontSize: SizeConfig.sp(context, 13),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: sectionGap),
            if (events.isEmpty)
              shrinkWrapList
                  ? SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: SizeConfig.sp(context, 44).clamp(36.0, 52.0),
                              color: _subtitleColor,
                            ),
                            SizedBox(height: SizeConfig.sp(context, 12)),
                            Text(
                              '暂无日程',
                              style: TextStyle(
                                fontSize: SizeConfig.sp(context, 15).clamp(13.0, 17.0),
                                fontWeight: FontWeight.w400,
                                color: _subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: SizeConfig.sp(context, 44).clamp(36.0, 52.0),
                              color: _subtitleColor,
                            ),
                            SizedBox(height: SizeConfig.sp(context, 12)),
                            Text(
                              '暂无日程',
                              style: TextStyle(
                                fontSize: SizeConfig.sp(context, 15).clamp(13.0, 17.0),
                                fontWeight: FontWeight.w400,
                                color: _subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
            else if (shrinkWrapList)
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: bottomInset + SizeConfig.sp(context, 56)),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onEventTap?.call(event),
                    child: event.isFestival
                        ? _FestivalTimelineCard(event: event)
                        : EventReminderCard(
                            event: event,
                            onTogglePin: onTogglePin != null ? () => onTogglePin!(event) : null,
                            onCardTap: null,
                          ),
                  );
                },
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: bottomInset + SizeConfig.sp(context, 56)),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onEventTap?.call(event),
                      child: event.isFestival
                          ? _FestivalTimelineCard(event: event)
                          : EventReminderCard(
                              event: event,
                              onTogglePin: onTogglePin != null ? () => onTogglePin!(event) : null,
                              onCardTap: null,
                            ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 节日专用时间线卡片：与用户事件卡片同构（左条 + 中栏 + 右侧倒计时），标题行含「节日」标签。
class _FestivalTimelineCard extends StatelessWidget {
  const _FestivalTimelineCard({required this.event});

  final EventReminderData event;

  /// 与 [EventReminderCard] / [CalendarPage] 农历行标记一致。
  static const String _kLunarDateLineMarker = '\u200e';

  static const List<BoxShadow> _cardShadows = [
    BoxShadow(
      color: Color(0x19000000),
      blurRadius: 2,
      offset: Offset(0, 1),
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x19000000),
      blurRadius: 3,
      offset: Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dateDisplay =
        event.dateText.replaceAll(_kLunarDateLineMarker, '').trim();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      event.eventDate.year,
      event.eventDate.month,
      event.eventDate.day,
    );
    final daysUntil = target.difference(today).inDays;
    const barW = 4.0;
    const barH = 36.0;
    const titleSize = 16.0;
    const dateSize = 14.0;
    const green = EventTimelineList._festivalGreen;

    Widget countdownTrailing() {
      const w = 80.0;
      Widget band(Widget child) {
        return SizedBox(width: w, child: child);
      }

      if (daysUntil == 0) {
        return band(
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '今天',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: green,
                  height: 1.0,
                ),
              ),
            ],
          ),
        );
      }
      if (daysUntil < 0) {
        return band(
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '已过去',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                  height: 1.0,
                ),
              ),
            ],
          ),
        );
      }
      return band(
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$daysUntil',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: green,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '天后',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF94A3B8),
                height: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: event.title,
      hint: daysUntil == 0
          ? '今天'
          : (daysUntil > 0 ? '$daysUntil天后' : '已过去'),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EventTimelineList._borderColor, width: 0.75),
            boxShadow: _cardShadows,
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: barW,
                    height: barH,
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                        height: 1.25,
                                        letterSpacing: -0.31,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  EventReminderCard.festivalTypeTag(event),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dateDisplay,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: dateSize,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF64748B),
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        countdownTrailing(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
