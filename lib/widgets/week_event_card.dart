import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_calendar/models/calendar_festival.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/widgets/pinned_star_badge.dart';

/// 周视图提醒卡片。
class WeekViewEventCard extends StatelessWidget {
  WeekViewEventCard({
    super.key,
    required ListEvent event,
    required this.occurrenceDate,
    required this.today,
    this.onTap,
    this.onEdit,
    this.onDelete,
  })  : event = event,
        festival = null,
        isFestivalCard = false,
        accent = TagService.accentForDisplay(event.tagId),
        tagName = TagService.getTagById(event.tagId)?.name ?? '提醒',
        daysDiff = _daysDiff(occurrenceDate, today),
        reminderLabels = _reminderLabels(event, occurrenceDate),
        pinned = event.isPinned,
        title = event.title,
        noteText = _trimNote(event.note),
        numberColor = _numberColorFor(TagService.accentForDisplay(event.tagId)),
        photoPath = _firstPhotoPath(event),
        tagId = event.tagId;

  WeekViewEventCard.festival({
    super.key,
    required CalendarFestival festival,
    required this.occurrenceDate,
    required this.today,
  })  : event = null,
        festival = festival,
        onTap = null,
        onEdit = null,
        onDelete = null,
        isFestivalCard = true,
        accent = festival.color,
        tagName = _festivalTagLabel(festival),
        daysDiff = _daysDiff(occurrenceDate, today),
        reminderLabels = _festivalReminderLabels(occurrenceDate),
        pinned = false,
        title = festival.name,
        noteText = '',
        numberColor = _numberColorFor(festival.color),
        photoPath = null,
        tagId = '';

  final ListEvent? event;
  final CalendarFestival? festival;
  final DateTime occurrenceDate;
  final DateTime today;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  final bool isFestivalCard;
  final Color accent;
  final String tagName;
  final int daysDiff;
  final List<String> reminderLabels;
  final bool pinned;
  final String title;
  final String noteText;
  final Color numberColor;
  final String? photoPath;
  final String tagId;

  static const Color _titleColor = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _hint = Color(0xFF94A3B8);
  static const Color _noteColor = Color(0xFFFFB800);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _borderCard = Color(0xFFF1F5F9);

  static const double _photoW = 100;
  static const double _photoH = 133;

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

  static String _trimNote(String? note) => note?.trim() ?? '';

  static Color _numberColorFor(Color accent) =>
      Color.lerp(accent, Colors.black, 0.15)!;

  static String? _firstPhotoPath(ListEvent e) {
    final path = e.photoPaths.isNotEmpty ? e.photoPaths.first : e.photoUrl;
    if (path == null || path.isEmpty) return null;
    return path;
  }

  static List<String> _festivalReminderLabels(DateTime occurrenceDate) => [
        '${occurrenceDate.month}月${occurrenceDate.day}日 09:00',
      ];

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

  static String _formatReminderLabel(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${t.month}月${t.day}日 $hh:$mm';
  }

  static List<String> _reminderLabels(ListEvent e, DateTime occurrenceDay) =>
      _reminderTimes(e, occurrenceDay).map(_formatReminderLabel).toList();

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

  Widget _tagIconPhotoFallback() {
    return Container(
      width: _photoW,
      height: _photoH,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: TagIconHelper.build(tagId: tagId, color: accent, size: 48),
    );
  }

  Widget _photoArea() {
    if (isFestivalCard) {
      return Container(
        width: _photoW,
        height: _photoH,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.celebration_outlined, color: accent, size: 40),
      );
    }
    final path = photoPath;
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(path),
          width: _photoW,
          height: _photoH,
          fit: BoxFit.cover,
          cacheWidth: 200,
          cacheHeight: 266,
          errorBuilder: (_, _, _) => _tagIconPhotoFallback(),
        ),
      );
    }
    return _tagIconPhotoFallback();
  }

  Widget _reminderTimeList() {
    if (reminderLabels.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < reminderLabels.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: _hint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  reminderLabels[i],
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
      ],
    );
  }

  Widget _cardInner() {
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _photoArea(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _titleColor,
                                  ),
                                ),
                              ),
                              _partnerShareTitleMarker(tagId),
                            ],
                          ),
                        ),
                        if (pinned) ...[
                          const SizedBox(width: 8),
                          const PinnedStarBadge(),
                        ],
                        const SizedBox(width: 6),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 62),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 24,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tagName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (reminderLabels.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _reminderTimeList(),
                          ],
                          if (noteText.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.note, size: 14, color: _noteColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    noteText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: _noteColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: daysDiff == 0
                  ? Text(
                      '今天',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        height: 1.0,
                      ),
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$daysDiff',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: numberColor,
                              height: 1.0,
                            ),
                          ),
                          TextSpan(
                            text: '天后',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinnedChrome(Widget child) {
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inner = _cardInner();

    if (isFestivalCard || onEdit == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _pinnedChrome(inner),
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
          ],
        ],
      ),
    );
  }
}
