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
    this.scrollController,
  });

  static const Color _titleColor = Color(0xFF1D293D);
  static const Color _subtitleColor = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFF1F5F9);

  final String title;
  final List<EventReminderData> events;
  final bool isDayDetailMode;
  final VoidCallback? onBackToOverview;
  final ValueChanged<EventReminderData>? onTogglePin;
  final ScrollController? scrollController;

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
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _borderColor, width: 0.75),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        shadows: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 24,
            offset: Offset(0, -4),
            spreadRadius: -8,
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
              Expanded(
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
                    return EventReminderCard(
                      event: event,
                      onTogglePin: onTogglePin != null ? () => onTogglePin!(event) : null,
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
