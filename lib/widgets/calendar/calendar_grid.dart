import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:time_calendar/utils/size_config.dart';
import 'package:time_calendar/widgets/calendar/calendar_models.dart';

/// 日历网格：在 [maxWidth]×[maxHeight] 内完整展示所有行，通过计算 [childAspectRatio] 适配小屏。
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.weekDayLabels,
    required this.dayCells,
    required this.maxWidth,
    required this.maxHeight,
    this.onDateSelected,
  });

  final List<String> weekDayLabels;
  final List<CalendarDayCellData> dayCells;
  final double maxWidth;
  final double maxHeight;
  final void Function(CalendarDayCellData day)? onDateSelected;

  static const Duration _selectionDuration = Duration(milliseconds: 220);
  static const Color _todayFill = Color(0xFFE0F2FE);
  static const Color _selectedFill = Color(0xFFEFF6FF);

  static const double _targetCellMainExtent = 38.0;
  static const double _weekdayBand = 26.0;

  @override
  Widget build(BuildContext context) {
    final rows = math.max(1, (dayCells.length / 7).ceil());
    final outerH = SizeConfig.sp(context, 0.5).clamp(0.0, 1.0);
    final availRows = math.max(8.0, maxHeight - _weekdayBand - outerH * 2);
    final cellW = (maxWidth - outerH * 2) / 7.0;
    final rowHFromParent = availRows / rows;
    final cellMain = math.min(_targetCellMainExtent, rowHFromParent);
    final aspect = (cellW / cellMain).clamp(0.48, 1.45);

    const double dayNumSize = 14.0;
    const double lunarSize = 9.0;

    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(outerH, 3, outerH, 0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: _weekdayBand,
              child: Row(
                children: weekDayLabels
                    .map(
                      (label) => Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: SizeConfig.sp(context, 10).clamp(9.0, 12.0),
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dayCells.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 0,
                  crossAxisSpacing: 0,
                  childAspectRatio: aspect,
                ),
                itemBuilder: (context, index) {
                  final day = dayCells[index];
                  final dayColor = day.isSelected
                      ? const Color(0xFF1447E6)
                      : (day.isCurrentMonth ? const Color(0xFF111827) : const Color(0xFFCAD5E2));
                  final lunarColor = day.isSelected
                      ? const Color(0x99155DFC)
                      : (day.isCurrentMonth ? const Color(0xFF6B7280) : const Color(0xFFCAD5E2));

                  final tappable = day.calendarDate != null && onDateSelected != null;

                  Color backgroundColor;
                  List<BoxShadow>? shadows;
                  if (day.isSelected) {
                    backgroundColor = _selectedFill;
                    shadows = const [
                      BoxShadow(
                        color: Color(0x141A73E8),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ];
                  } else if (day.isToday) {
                    backgroundColor = _todayFill;
                    shadows = null;
                  } else {
                    backgroundColor = Colors.transparent;
                    shadows = null;
                  }

                  final inner = AnimatedContainer(
                    duration: _selectionDuration,
                    curve: Curves.easeOut,
                    margin: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: shadows,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          day.dayNumber,
                          style: TextStyle(
                            fontSize: dayNumSize,
                            fontWeight: FontWeight.w500,
                            color: dayColor,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          day.lunarLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: lunarSize,
                            fontWeight: FontWeight.w400,
                            color: lunarColor,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: day.markerColors
                              .map(
                                (color) => Container(
                                  width: 2.5,
                                  height: 2.5,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  );

                  return tappable
                      ? Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => onDateSelected!(day),
                            child: inner,
                          ),
                        )
                      : inner;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
