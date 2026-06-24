import 'package:flutter/material.dart';
import 'package:time_calendar/utils/event_date_utils.dart';

enum MemoryEventDateLabelVariant {
  editChip,
  detailMuted,
  cardOverlay,
  timelineInline,
}

/// 时光集子事件日期展示：公历 + 可选农历 pill。
class MemoryEventDateLabel extends StatelessWidget {
  const MemoryEventDateLabel({
    super.key,
    required this.date,
    required this.isLunarDate,
    this.variant = MemoryEventDateLabelVariant.editChip,
    this.weekdaySuffix,
  });

  static const Color lunarPillBg = Color(0xFFFFF7ED);
  static const Color lunarPillFg = Color(0xFFF97316);
  static const Color themeBlue = Color(0xFF1A73E8);

  final DateTime date;
  final bool isLunarDate;
  final MemoryEventDateLabelVariant variant;
  final String? weekdaySuffix;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case MemoryEventDateLabelVariant.editChip:
        return _buildEditChip();
      case MemoryEventDateLabelVariant.detailMuted:
        return _buildDetailMuted();
      case MemoryEventDateLabelVariant.cardOverlay:
        return _buildCardOverlay();
      case MemoryEventDateLabelVariant.timelineInline:
        return _buildTimelineInline();
    }
  }

  Widget _lunarPill({
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 4,
      vertical: 2,
    ),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? lunarPillBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        formatMemoryEventLunarPill(date),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: foregroundColor ?? lunarPillFg,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildEditChip() {
    final solar = Text(
      formatMemoryStreamDayZh(date),
      style: const TextStyle(
        fontSize: 14,
        color: themeBlue,
        fontWeight: FontWeight.w600,
      ),
    );
    if (!isLunarDate) return solar;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        solar,
        _lunarPill(),
      ],
    );
  }

  Widget _buildDetailMuted() {
    final solarText = weekdaySuffix != null
        ? '${formatFullDate(date)} $weekdaySuffix'
        : formatFullDate(date);
    final solar = Text(
      solarText,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF64748B),
      ),
    );
    if (!isLunarDate) return solar;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        solar,
        _lunarPill(),
      ],
    );
  }

  Widget _buildCardOverlay() {
    final solar = Text(
      formatMemoryStreamDayZh(date),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
    if (!isLunarDate) return solar;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        solar,
        _lunarPill(
          backgroundColor: lunarPillBg.withValues(alpha: 0.92),
        ),
      ],
    );
  }

  Widget _buildTimelineInline() {
    if (!isLunarDate) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: _lunarPill(),
    );
  }
}
