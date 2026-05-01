import 'package:flutter/material.dart';
import 'package:time_calendar/widgets/calendar/calendar_models.dart';

/// 日历事件卡片：标题在上、日期在下；左侧色条；右侧倒计时。
/// 农历 pill 依赖 [CalendarPage._formatEventDateLine] 写入的不可见标记 `\u200e`。
class EventReminderCard extends StatelessWidget {
  const EventReminderCard({
    super.key,
    required this.event,
    this.onTogglePin,
  });

  /// 须与 `calendar_page.dart` 中 `_kLunarDateLineMarker` 一致。
  static const String _kLunarDateLineMarker = '\u200e';

  static const Color _titleColorCal = Color(0xFF0F172A);
  static const Color _dateColorCal = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFF1F5F9);
  static const Color _starColor = Color(0xFFFFB800);
  static const Color _lunarPillBg = Color(0xFFFFF7ED);
  static const Color _lunarPillFg = Color(0xFFF97316);

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

  static String _stripLunarMarker(String raw) =>
      raw.replaceAll(_kLunarDateLineMarker, '').trim();

  static bool _hasLunarMarker(String raw) => raw.contains(_kLunarDateLineMarker);

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

  static Color _todayTextColor(Color accent) {
    const festivalGreen = Color(0xFF10B981);
    return accent.toARGB32() == festivalGreen.toARGB32() ? festivalGreen : accent;
  }

  static Widget _countdownTrailing(EventReminderData event) {
    const w = 80.0;
    final accent = event.accentColor;
    final daysRemaining = event.daysRemaining;

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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '今天',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _todayTextColor(accent),
                height: 1.0,
              ),
            ),
          ],
        ),
      );
    }
    if (daysRemaining < 0) {
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
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: accent,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            const SizedBox(height: 12),
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
            '$daysRemaining',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: accent,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '天后',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: accent.withValues(alpha: 0.7),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const barW = 4.0;
    const barH = 36.0;
    const innerPadH = 16.0;
    const innerPadV = 12.0;
    final accent = event.accentColor;
    const titleSize = 16.0;
    const dateSize = 14.0;
    final rawDate = event.dateText;
    final showLunar = _hasLunarMarker(rawDate);
    final dateDisplay = _stripLunarMarker(rawDate);

    return Semantics(
      label: event.title,
      hint: countdownText(event.daysRemaining),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor, width: 0.75),
            boxShadow: _cardShadows,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              // TODO: 待后续注入交互逻辑（进入日程详情）
            },
            onLongPress: onTogglePin,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: innerPadH, vertical: innerPadV),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: barW,
                      height: barH,
                      decoration: BoxDecoration(
                        color: accent,
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
                                          fontWeight: FontWeight.w700,
                                          color: _titleColorCal,
                                          height: 1.25,
                                          letterSpacing: -0.31,
                                        ),
                                      ),
                                    ),
                                    if (event.isPinned) ...[
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.star,
                                        size: 16,
                                        color: _starColor,
                                        semanticLabel: '已置顶',
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dateDisplay,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: dateSize,
                                          fontWeight: FontWeight.w400,
                                          color: _dateColorCal,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                    if (showLunar) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _lunarPillBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          '农历',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: _lunarPillFg,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _countdownTrailing(event),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
