import 'package:flutter/material.dart';
import 'package:lunar/lunar.dart';
import 'package:time_calendar/models/calendar_festival.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/services/tag_service.dart';

/// 月/周视图共用的日期单元格（圆角矩形选中态，非圆形）。
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.date,
    required this.today,
    required this.events,
    required this.festivals,
    required this.onTap,
    this.selectedDate,
    this.isInCurrentMonth = true,
    this.selectedBackgroundColor = _defaultSelectedBackground,
    this.selectedTextColor = _defaultSelectedText,
    this.todayBackgroundColor = _defaultTodayBackground,
    this.todayTextColor = _defaultTodayText,
    this.lunarTextStyle = _defaultLunarTextStyle,
    this.highlightLunarOnFestival = true,
    this.cellPadding = 4,
    this.dayToLunarGap = 0,
    this.lunarToMarkerGap = 1,
    this.markerSize = 4,
    this.markerSpacing = 2,
    this.dayFontSize = 16,
    this.dayFontWeight = FontWeight.w500,
    this.showSelectedShadow = true,
  });

  final DateTime date;
  final DateTime? selectedDate;
  final DateTime today;
  final List<ListEvent> events;
  final List<CalendarFestival> festivals;
  final VoidCallback onTap;
  final bool isInCurrentMonth;

  final Color? selectedBackgroundColor;
  final Color? selectedTextColor;
  final Color? todayBackgroundColor;
  final Color? todayTextColor;
  final TextStyle lunarTextStyle;
  final bool highlightLunarOnFestival;
  final double cellPadding;
  final double dayToLunarGap;
  final double lunarToMarkerGap;
  final double markerSize;
  final double markerSpacing;
  final double dayFontSize;
  final FontWeight dayFontWeight;
  final bool showSelectedShadow;

  static const Duration _selectionDuration = Duration(milliseconds: 220);
  static const double _cornerRadius = 10;

  static const Color _defaultSelectedBackground = Color(0xFF1A73E8);
  static const Color _defaultSelectedText = Colors.white;
  static const Color _defaultTodayBackground = Color(0xFFE8F0FE);
  static const Color _defaultTodayText = Color(0xFF1A73E8);
  static const TextStyle _defaultLunarTextStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF94A3B8),
  );

  static const Color _inMonthFg = Color(0xFF1F2937);
  static const Color _outMonthFg = Color(0xFF94A3B8);
  static const Color _festivalGreen = Color(0xFF10B981);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    final isToday = _sameDay(dayOnly, today);
    final isSelected =
        selectedDate != null && _sameDay(dayOnly, selectedDate!);

    final selBg = selectedBackgroundColor ?? _defaultSelectedBackground;
    final selFg = selectedTextColor ?? _defaultSelectedText;
    final todayBg = todayBackgroundColor ?? _defaultTodayBackground;
    final todayFg = todayTextColor ?? _defaultTodayText;

    Color backgroundColor;
    Color dayColor;

    if (isSelected) {
      backgroundColor = selBg;
      dayColor = selFg;
    } else if (isToday) {
      backgroundColor = todayBg;
      dayColor = todayFg;
    } else {
      backgroundColor = Colors.transparent;
      dayColor = isInCurrentMonth ? _inMonthFg : _outMonthFg;
    }

    final lunarColor = _lunarColor(
      dayOnly,
      isSelected: isSelected,
      selectedForeground: selFg,
    );
    final lunarLabel = _lunarLabelFor(dayOnly);

    final useShadow = showSelectedShadow && isSelected && !isToday;
    final hasUserReminders = events.isNotEmpty;
    final hasFestivals = festivals.isNotEmpty;
    final hasMarkers = hasFestivals || hasUserReminders;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_cornerRadius),
            child: AnimatedContainer(
              duration: _selectionDuration,
              curve: Curves.easeOut,
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth,
                maxHeight: constraints.maxHeight,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(_cornerRadius),
                boxShadow: useShadow
                    ? const [
                        BoxShadow(
                          color: Color(0x141A73E8),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              padding: EdgeInsets.all(cellPadding),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${dayOnly.day}',
                      style: TextStyle(
                        fontSize: dayFontSize,
                        fontWeight: dayFontWeight,
                        color: dayColor,
                        height: 1.0,
                      ),
                    ),
                    if (dayToLunarGap > 0) SizedBox(height: dayToLunarGap),
                    Text(
                      lunarLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: lunarTextStyle.copyWith(
                        color: lunarColor,
                        height: 1.0,
                      ),
                    ),
                    if (hasMarkers) SizedBox(height: lunarToMarkerGap),
                    if (hasMarkers)
                      _MarkerRow(
                        showFestivalDot: hasFestivals,
                        events: events,
                        markerSize: markerSize,
                        markerSpacing: markerSpacing,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _lunarColor(
    DateTime d, {
    required bool isSelected,
    required Color selectedForeground,
  }) {
    if (!highlightLunarOnFestival) {
      return lunarTextStyle.color ?? const Color(0xFF94A3B8);
    }
    if (festivals.isNotEmpty || _lunarIsSolarTerm(d)) {
      if (isSelected && selectedForeground == Colors.white) {
        return const Color(0xFFB8F0D8);
      }
      return _festivalGreen;
    }
    if (isSelected && selectedForeground == Colors.white) {
      return Colors.white.withValues(alpha: 0.85);
    }
    return lunarTextStyle.color ?? const Color(0xFF94A3B8);
  }

  static String _lunarLabelFor(DateTime d) {
    final lunar = Lunar.fromDate(d);
    final jq = lunar.getJieQi();
    return jq.isNotEmpty ? jq : lunar.getDayInChinese();
  }

  static bool _lunarIsSolarTerm(DateTime d) {
    return Lunar.fromDate(d).getJieQi().isNotEmpty;
  }
}

class _MarkerRow extends StatelessWidget {
  const _MarkerRow({
    required this.showFestivalDot,
    required this.events,
    required this.markerSize,
    required this.markerSpacing,
  });

  static const int _maxDots = 3;
  static const Color _festivalDotColor = Color(0xFF10B981);
  static const Color _fallbackReminderColor = Color(0xFF94A3B8);

  final bool showFestivalDot;
  final List<ListEvent> events;
  final double markerSize;
  final double markerSpacing;

  static int _markerEventPriority(ListEvent a, ListEvent b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    final c = a.baseDate.compareTo(b.baseDate);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  List<Color> _reminderDotColors(int maxCount) {
    if (maxCount <= 0 || events.isEmpty) return const [];
    final sorted = List<ListEvent>.from(events)..sort(_markerEventPriority);
    final colors = <Color>[];
    final seenColorKeys = <int>{};
    for (final e in sorted) {
      if (colors.length >= maxCount) break;
      final color = e.tagId.isNotEmpty
          ? TagService.accentForDisplay(e.tagId)
          : _fallbackReminderColor;
      if (seenColorKeys.add(color.toARGB32())) {
        colors.add(color);
      }
    }
    return colors;
  }

  @override
  Widget build(BuildContext context) {
    final festivalSlots = showFestivalDot ? 1 : 0;
    final reminderSlots = _maxDots - festivalSlots;
    final reminderColors = _reminderDotColors(reminderSlots);

    final children = <Widget>[];
    if (showFestivalDot) {
      children.add(_dot(_festivalDotColor));
    }
    for (final color in reminderColors) {
      if (children.isNotEmpty) {
        children.add(SizedBox(width: markerSpacing));
      }
      children.add(_dot(color));
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: markerSize,
      height: markerSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
