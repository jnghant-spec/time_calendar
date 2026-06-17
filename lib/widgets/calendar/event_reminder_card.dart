import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/widgets/calendar/calendar_models.dart';
import 'package:time_calendar/widgets/pinned_star_badge.dart';

/// 日历事件卡片：标题在上、日期在下；左侧色条；右侧倒计时。
/// 农历 pill 依赖 [CalendarPage._formatEventDateLine] 写入的不可见标记 `\u200e`。
class EventReminderCard extends StatelessWidget {
  const EventReminderCard({
    super.key,
    required this.event,
    this.onTogglePin,
    this.onCardTap,
  });

  /// 须与 `calendar_page.dart` 中 `_kLunarDateLineMarker` 一致。
  static const String _kLunarDateLineMarker = '\u200e';

  static const Color _titleColorCal = Color(0xFF0F172A);
  static const Color _dateColorCal = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFF1F5F9);
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
  final VoidCallback? onCardTap;

  static bool _shouldShowPartnerShareMarker(String tagId) =>
      TagService.shouldShowPartnerShareMarker(tagId);

  static Widget _partnerShareTitleMarker(String tagId) {
    if (!_shouldShowPartnerShareMarker(tagId)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: SvgPicture.asset(
        'assets/images/ic_couple_hearts.svg',
        width: 16,
        height: 16,
      ),
    );
  }

  static String _stripLunarMarker(String raw) =>
      raw.replaceAll(_kLunarDateLineMarker, '').trim();

  static bool _hasLunarMarker(String raw) =>
      raw.contains(_kLunarDateLineMarker);

  /// 从 `festival_${core}_${y}_${m}_${d}` 解析节日核心 id（与日历页逻辑一致）。
  static String? festivalCoreIdFromReminderId(String reminderId) {
    if (!reminderId.startsWith('festival_')) return null;
    final parts = reminderId.substring('festival_'.length).split('_');
    if (parts.length < 4) return null;
    final y = int.tryParse(parts[parts.length - 3]);
    final m = int.tryParse(parts[parts.length - 2]);
    final d = int.tryParse(parts[parts.length - 1]);
    if (y == null || m == null || d == null) return null;
    return parts.sublist(0, parts.length - 3).join('_');
  }

  /// `religious_${教派}_${序号}` → 「道教节日」等。
  static String? religiousDenominationLabel(String coreId) {
    if (!coreId.startsWith('religious_')) return null;
    final rest = coreId.substring('religious_'.length);
    final parts = rest.split('_');
    if (parts.isEmpty || parts.first.isEmpty) return null;
    final denom = parts.first;
    switch (denom) {
      case 'taoism':
        return '道教节日';
      case 'buddhism':
        return '佛教节日';
      case 'christianity':
        return '基督教节日';
      case 'islam':
        return '伊斯兰教节日';
      case 'hinduism':
        return '印度教节日';
      default:
        return '宗教节日';
    }
  }

  static String festivalTypeTagLabel(EventReminderData event) {
    assert(event.isFestival);
    final preset = (event.festivalCategory ?? '').trim();
    if (preset.isNotEmpty) return preset;
    switch (event.festivalCategoryKey) {
      case 'gregorian':
        return '公历节日';
      case 'lunar':
        return '农历节日';
      case 'ethnic':
        return '民族节日';
      case 'religious':
        final core = festivalCoreIdFromReminderId(event.id);
        if (core != null) {
          final sub = religiousDenominationLabel(core);
          if (sub != null) return sub;
        }
        return '宗教节日';
      default:
        return '节日';
    }
  }

  static (Color bg, Color fg) festivalTypeTagColors(EventReminderData event) {
    assert(event.isFestival);
    switch (event.festivalCategoryKey) {
      case 'gregorian':
        return (const Color(0xFFDBEAFE), const Color(0xFF1E40AF));
      case 'lunar':
        return (const Color(0xFFFFF7ED), const Color(0xFFF97316));
      case 'ethnic':
        return (const Color(0xFFF5F3FF), const Color(0xFF8B5CF6));
      case 'religious':
        return (const Color(0xFFF0F9FF), const Color(0xFF0EA5E9));
      default:
        return (const Color(0xFFF1F5F9), const Color(0xFF64748B));
    }
  }

  /// 日历时间线/清单卡片标题右侧的节日细分标签。
  static Widget festivalTypeTag(EventReminderData event) {
    final (bg, fg) = festivalTypeTagColors(event);
    final label = festivalTypeTagLabel(event);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }

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
    return accent.toARGB32() == festivalGreen.toARGB32()
        ? festivalGreen
        : accent;
  }

  /// 日历时间线卡片（含节日卡）右侧倒计时区域。
  static Widget countdownTrailing(EventReminderData event) {
    const w = 80.0;
    final accent = event.accentColor;
    final daysRemaining = event.daysRemaining;
    const festivalGreen = Color(0xFF10B981);

    Widget band(Widget child) {
      return SizedBox(width: w, child: child);
    }

    if (daysRemaining == 0) {
      if (event.isFestival) {
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
                  color: festivalGreen,
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
      if (event.isFestival) {
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
    final numberColor = Color.lerp(accent, Colors.black, 0.15)!;
    return band(
      Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$daysRemaining',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: numberColor,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '天后',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: accent,
                height: 1.0,
              ),
            ),
          ],
        ),
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
    final showLunar = !event.isFestival && _hasLunarMarker(rawDate);
    final dateDisplay = _stripLunarMarker(rawDate);
    final barColor = event.isFestival ? const Color(0xFFF59E0B) : accent;

    final showPinnedChrome = event.isPinned && !event.isFestival;

    final cardBody = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: innerPadH,
        vertical: innerPadV,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: barW,
            height: barH,
            decoration: BoxDecoration(
              color: barColor,
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
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
                                _partnerShareTitleMarker(event.tagId),
                              ],
                            ),
                          ),
                          if (event.isFestival) ...[
                            const SizedBox(width: 8),
                            EventReminderCard.festivalTypeTag(event),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
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
                countdownTrailing(event),
              ],
            ),
          ),
        ],
      ),
    );

    Widget cardSurface;
    if (showPinnedChrome) {
      cardSurface = Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor, width: 0.75),
              boxShadow: _cardShadows,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  onTap: onCardTap,
                  onLongPress: onTogglePin,
                  child: cardBody,
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                color: kPinnedStarGold,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
          ),
          const Positioned(top: 0, right: 6, child: PinnedStarBadge()),
        ],
      );
    } else {
      cardSurface = Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor, width: 0.75),
          boxShadow: _cardShadows,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onCardTap,
          onLongPress: onTogglePin,
          child: cardBody,
        ),
      );
    }

    return Semantics(
      label: event.title,
      hint: event.isFestival ? '节日' : countdownText(event.daysRemaining),
      child: Material(color: Colors.transparent, child: cardSurface),
    );
  }
}
