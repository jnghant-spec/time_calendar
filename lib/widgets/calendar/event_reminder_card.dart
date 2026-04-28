import 'package:flutter/material.dart';
import 'package:time_calendar/widgets/calendar/calendar_models.dart';

/// 日历事件卡片：日期+星标同一行左齐，倒计时右齐；第二行标题；左侧色条。
class EventReminderCard extends StatelessWidget {
  const EventReminderCard({
    super.key,
    required this.event,
    this.onTogglePin,
  });

  static const Color _titleColor = Color(0xFF1D293D);
  static const Color _dateColor = Color(0xFF62748E);
  static const Color _borderColor = Color(0xFFF1F5F9);
  static const Color _starColor = Color(0xFFF59E0B);

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

  final EventReminderData event;
  final VoidCallback? onTogglePin;

  static String countdownText(int daysFromToday) {
    if (daysFromToday == 0) {
      return '今天';
    }
    if (daysFromToday < 0) {
      return '已过去';
    }
    if (daysFromToday == 1) {
      return '1天后';
    }
    return '$daysFromToday天后';
  }

  static Widget _countdownTrailing(int daysRemaining, Color accent) {
    const w = 70.0;
    final subColor = accent.withValues(alpha: 0.8);

    Widget band(Widget child) {
      return SizedBox(
        width: w,
        child: child,
      );
    }

    if (daysRemaining == 0) {
      return band(
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '今天',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: accent,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      );
    }
    if (daysRemaining < 0) {
      return band(
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '已过去',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: accent,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      );
    }
    return band(
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$daysRemaining',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: accent,
              height: 1.0,
            ),
          ),
          Text(
            '天后',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: subColor,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const barW = 3.0;
    const innerPadH = 16.0;
    const innerPadV = 10.0;
    final accent = event.accentColor;
    const titleSize = 16.0;
    const dateSize = 14.0;

    return Semantics(
      label: event.title,
      hint: countdownText(event.daysRemaining),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 0.75),
            boxShadow: _cardShadows,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              // TODO: 待后续注入交互逻辑（进入日程详情）
            },
            onLongPress: onTogglePin,
            child: SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: barW, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(innerPadH, innerPadV, innerPadH, innerPadV),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 18,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          event.dateText.trim(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: dateSize,
                                            fontWeight: FontWeight.w500,
                                            color: _dateColor,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                      if (event.isPinned) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.star,
                                          size: 14,
                                          color: _starColor,
                                          semanticLabel: '已置顶',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 20,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      event.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.w700,
                                        color: _titleColor,
                                        height: 1.25,
                                        letterSpacing: -0.31,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _countdownTrailing(event.daysRemaining, accent),
                        ],
                      ),
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
