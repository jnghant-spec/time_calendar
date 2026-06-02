import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:time_calendar/models/calendar_festival.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/widgets/pinned_star_badge.dart';

/// 周视图提醒卡片。
class WeekViewEventCard extends StatelessWidget {
  const WeekViewEventCard({
    super.key,
    required this.event,
    required this.occurrenceDate,
    required this.today,
    this.onTap,
    this.onEdit,
    this.onDelete,
  }) : festival = null;

  const WeekViewEventCard.festival({
    super.key,
    required this.festival,
    required this.occurrenceDate,
    required this.today,
  })  : event = null,
        onTap = null,
        onEdit = null,
        onDelete = null;

  final ListEvent? event;
  final CalendarFestival? festival;
  final DateTime occurrenceDate;
  final DateTime today;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static const Color _titleColor = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _hint = Color(0xFF94A3B8);
  static const Color _noteColor = Color(0xFFFFB800);
  static const Color _themeBlue = Color(0xFF1A73E8);

  static int _advanceDayCount(EventAdvanceDaysOption o) {
    switch (o) {
      case EventAdvanceDaysOption.oneDay:
        return 1;
      case EventAdvanceDaysOption.threeDays:
        return 3;
      case EventAdvanceDaysOption.oneWeek:
        return 7;
      case EventAdvanceDaysOption.oneMonth:
        return 30;
    }
  }

  static DateTime _atHm(String hm, DateTime day) {
    final parts = hm.split(':');
    final h = int.tryParse(parts.first) ?? 9;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  static List<DateTime> _reminderTimes(ListEvent e, DateTime occurrenceDay) {
    final day = DateTime(occurrenceDay.year, occurrenceDay.month, occurrenceDay.day);
    final out = <DateTime>[];
    final t = e.reminderType;
    if (t == EventReminderType.advanceAndSameDay || t == EventReminderType.advanceOnly) {
      final advDay = day.subtract(Duration(days: _advanceDayCount(e.advanceDaysOption)));
      out.add(_atHm(e.advanceTimeHm, advDay));
    }
    if (t == EventReminderType.advanceAndSameDay || t == EventReminderType.sameDayOnly) {
      out.add(_atHm(e.sameDayTimeHm, day));
    }
    out.sort();
    return out;
  }

  static String _nearestReminderLabel(ListEvent e, DateTime occurrenceDay) {
    final times = _reminderTimes(e, occurrenceDay);
    if (times.isEmpty) return '';
    final now = DateTime.now();
    DateTime pick = times.last;
    for (final t in times) {
      if (!t.isBefore(now)) {
        pick = t;
        break;
      }
    }
    final hh = pick.hour.toString().padLeft(2, '0');
    final mm = pick.minute.toString().padLeft(2, '0');
    return '${pick.month}月${pick.day}日 $hh:$mm';
  }

  static String _festivalTagLabel(CalendarFestival f) {
    final preset = f.sourceLabel?.trim();
    if (preset != null && preset.isNotEmpty) return preset;
    switch (f.category) {
      case 'gregorian':
        return '公历节日';
      case 'lunar':
        return '农历节日';
      case 'ethnic':
        return '民族节日';
      case 'religious':
        return '宗教节日';
      default:
        return '节日';
    }
  }

  static int _daysDiff(DateTime occurrence, DateTime today) {
    return DateTime(occurrence.year, occurrence.month, occurrence.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  Widget _photoArea(Color accent) {
    const w = 100.0;
    const h = 133.0;
    if (festival != null) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.celebration_outlined, color: accent, size: 40),
      );
    }
    final e = event!;
    final path = e.photoPaths.isNotEmpty ? e.photoPaths.first : e.photoUrl;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(path),
          width: w,
          height: h,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: TagIconHelper.build(tagId: e.tagId, color: accent, size: 48),
    );
  }

  Widget _countdownColumn(Color accent, int daysDiff) {
    const w = 56.0;
    if (daysDiff == 0) {
      return SizedBox(
        width: w,
        child: Center(
          child: Text(
            '今天',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: accent,
              height: 1.0,
            ),
          ),
        ),
      );
    }
    final numberColor = Color.lerp(accent, Colors.black, 0.15)!;
    return SizedBox(
      width: w,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$daysDiff',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: numberColor,
              height: 1.0,
            ),
          ),
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
    );
  }

  Widget _cardInner(
    Color accent,
    String tagName,
    int daysDiff,
    String reminderTime, {
    required bool pinned,
  }) {
    final title = festival?.name ?? event!.title;
    const note = '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderCard, width: 0.75),
        boxShadow: pinned
            ? const [
                BoxShadow(
                  color: Color(0x33FFB800),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                  spreadRadius: -1,
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _photoArea(accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tagName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (reminderTime.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: _hint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          reminderTime,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: _muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _noteColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _countdownColumn(accent, daysDiff),
        ],
      ),
    );
  }

  Widget _pinnedChrome(Widget child, {required bool pinned}) {
    if (!pinned) {
      return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: child);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: child),
        const Positioned(
          top: 0,
          left: 16,
          right: 16,
          child: SizedBox(
            height: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kPinnedStarGold,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          top: kPinnedStarBadgeTop,
          right: kPinnedStarBadgeRight,
          child: PinnedStarBadge(),
        ),
      ],
    );
  }

  static const Color _borderCard = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final accent = festival != null
        ? festival!.color
        : TagService.accentForDisplay(event!.tagId);
    final tagName = festival != null ? _festivalTagLabel(festival!) : (TagService.getTagById(event!.tagId)?.name ?? '提醒');
    final daysDiff = _daysDiff(occurrenceDate, today);
    final reminderTime = event != null
        ? _nearestReminderLabel(event!, occurrenceDate)
        : '${occurrenceDate.month}月${occurrenceDate.day}日 09:00';

    final pinned = event?.isPinned ?? false;
    final inner = _cardInner(
      accent,
      tagName,
      daysDiff,
      reminderTime,
      pinned: pinned,
    );

    if (festival != null || onEdit == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _pinnedChrome(inner, pinned: pinned),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Slidable(
            key: ValueKey(event!.id),
            closeOnScroll: true,
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.36,
              children: [
                SlidableAction(
                  onPressed: (_) => onEdit?.call(),
                  backgroundColor: _themeBlue,
                  foregroundColor: Colors.white,
                  icon: Icons.edit_outlined,
                  label: '编辑',
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                SlidableAction(
                  onPressed: (_) => onDelete?.call(),
                  backgroundColor: const Color(0xFFF04444),
                  foregroundColor: Colors.white,
                  icon: Icons.delete_outline,
                  label: '删除',
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ],
            ),
            child: inner,
          ),
          if (pinned) ...[
            const Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: SizedBox(
                height: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kPinnedStarGold,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              top: kPinnedStarBadgeTop,
              right: kPinnedStarBadgeRight,
              child: PinnedStarBadge(),
            ),
          ],
        ],
      ),
    );
  }
}
