import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:time_calendar/utils/size_config.dart';
import 'package:time_calendar/widgets/calendar/calendar_models.dart';
import 'package:time_calendar/widgets/calendar_day_cell.dart';

/// 日历网格：星期行固定 26px，日期行高为 [targetCellMainExtent]，总高度随当月行数变化。
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.weekDayLabels,
    required this.dayCells,
    required this.maxWidth,
    required this.today,
    this.selectedDate,
    this.targetCellMainExtent = 38.0,
    this.onDateSelected,
  });

  final List<String> weekDayLabels;
  final List<CalendarDayCellData> dayCells;
  final double maxWidth;
  final DateTime today;
  final DateTime? selectedDate;
  /// 日期行高度；列表上滑时可在 38→30 间插值以压缩日历。
  final double targetCellMainExtent;
  final void Function(CalendarDayCellData day)? onDateSelected;

  static const double _weekdayBand = 26.0;

  @override
  Widget build(BuildContext context) {
    final rows = math.max(1, (dayCells.length / 7).ceil());
    final outerH = SizeConfig.sp(context, 0.5).clamp(0.0, 1.0);
    final cellW = (maxWidth - outerH * 2) / 7.0;
    final cellMain = targetCellMainExtent.clamp(30.0, 38.0);
    final aspect = (cellW / cellMain).clamp(0.48, 1.45);
    final actualCellHeight = cellW / aspect;
    final gridH = rows * actualCellHeight;

    return SizedBox(
      width: maxWidth,
      height: 3 + _weekdayBand + gridH,
      child: Padding(
        padding: EdgeInsets.fromLTRB(outerH, 3, outerH, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            SizedBox(
              height: gridH,
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
                  final date = day.calendarDate;
                  if (date == null) {
                    return const SizedBox.shrink();
                  }
                  return CalendarDayCell(
                    date: date,
                    selectedDate: selectedDate,
                    today: today,
                    events: day.events,
                    festivals: day.festivals,
                    isInCurrentMonth: day.isCurrentMonth,
                    onTap: onDateSelected != null
                        ? () => onDateSelected!(day)
                        : () {},
                    selectedBackgroundColor: const Color(0xFF93C5FD),
                    selectedTextColor: const Color(0xFF1A73E8),
                    todayBackgroundColor: const Color(0xFFE8F0FE),
                    todayTextColor: const Color(0xFF1A73E8),
                    highlightLunarOnFestival: false,
                    lunarTextStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF94A3B8),
                    ),
                    cellPadding: 6,
                    dayFontSize: 15,
                    showSelectedShadow: false,
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
