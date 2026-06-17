import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_calendar/main.dart' show appNavigatorKey;
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/pages/memory_store_sheet.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/widgets/event_photo_paths_preview.dart';

/// 清单页事件详情底部弹层。
class EventDetailSheet extends StatelessWidget {
  const EventDetailSheet({
    super.key,
    required this.event,
    this.onEdit,
    this.onDismiss,
  });

  final ListEvent event;
  final VoidCallback? onEdit;
  final VoidCallback? onDismiss;

  static const Color _titleBarText = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF64748B);
  static const Color _labelMuted = Color(0xFF94A3B8);
  static const Color _divider = Color(0xFFF1F5F9);
  static const Color _lunarBg = Color(0xFFFFF7ED);
  static const Color _lunarFg = Color(0xFFF97316);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _modifiedHint = Color(0xFF9CA3AF);
  static const Color _sheetBg = Color(0xFFFFFFFF);
  static const Color _infoCardBg = Color(0xFFFAFBFC);

  /// 与 [EventAddPage] 纪念照片预览区一致（100:133）。
  static const double _kEventPhotoBoxWidth = 100;
  static const double _kEventPhotoBoxHeight = 133;
  static const double _kEventPhotoBoxRadius = 16;

  static String _repeatLabel(EventRepeatRule r) {
    switch (r) {
      case EventRepeatRule.none:
        return '不重复';
      case EventRepeatRule.daily:
        return '每天';
      case EventRepeatRule.weekly:
        return '每周';
      case EventRepeatRule.monthly:
        return '每月';
      case EventRepeatRule.yearly:
        return '每年';
    }
  }

  static bool _showAdvanceReminder(EventReminderType t) =>
      t == EventReminderType.advanceAndSameDay ||
      t == EventReminderType.advanceOnly;

  static bool _showSameDayReminder(EventReminderType t) =>
      t == EventReminderType.advanceAndSameDay ||
      t == EventReminderType.sameDayOnly;

  Widget _pinnedTitleStar() {
    return SvgPicture.asset(
      'assets/images/ic_star.svg',
      width: 28,
      height: 28,
      fit: BoxFit.contain,
    );
  }

  static String _formatModifiedAt(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}月${dt.day}日 $hour:$minute';
  }

  String? _partnerModifiedLabel(ListEvent event) {
    final name = event.lastModifiedByName?.trim();
    final at = event.lastModifiedAt;
    if (name == null || name.isEmpty || at == null) return null;
    final currentName = UserSession.instance.nickname.trim();
    if (name == currentName) return null;
    return '$name ${_formatModifiedAt(at)} 修改';
  }

  Widget _partnerShareTitleMarker(String tagId) {
    if (!TagService.shouldShowPartnerShareMarker(tagId)) {
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

  Widget _infoChip(double width, String label, String value) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _infoCardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _labelMuted,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _titleBarText,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom;
    final accentColor = TagService.accentForDisplay(event.tagId);
    final displayDay = effectiveDate(event);
    final anchorDay = anchorDateOnly(event);

    final gridItemWidth = (mq.size.width - 40 - 12) / 2;
    final photoPathsExisting = event.photoPaths
        .where((p) => File(p).existsSync())
        .take(9)
        .toList();
    final advanceLine = _showAdvanceReminder(event.reminderType)
        ? event.advanceTimeHm
        : '无';
    final sameDayLine = _showSameDayReminder(event.reminderType)
        ? event.sameDayTimeHm
        : '无';
    final modifiedLabel = _partnerModifiedLabel(event);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) onDismiss?.call();
      },
      child: SizedBox(
        height: mq.size.height * 0.85,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: ColoredBox(
            color: _sheetBg,
            child: Column(
              children: [
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Text(
                          '事件详情',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _titleBarText,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).pop(),
                            child: const SizedBox(
                              width: 24,
                              height: 24,
                              child: Icon(
                                Icons.close,
                                size: 24,
                                color: _labelMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(height: 1, color: _divider),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              TagIconHelper.build(
                                tagId: event.tagId,
                                color: accentColor,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        event.title,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: _titleBarText,
                                        ),
                                      ),
                                    ),
                                    _partnerShareTitleMarker(event.tagId),
                                  ],
                                ),
                              ),
                              if (event.isPinned) ...[
                                const SizedBox(width: 8),
                                _pinnedTitleStar(),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      formatGregorianDateLongZh(displayDay),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: _muted,
                                      ),
                                    ),
                                  ),
                                  if (modifiedLabel != null)
                                    Text(
                                      modifiedLabel,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _modifiedHint,
                                      ),
                                    ),
                                ],
                              ),
                              if (event.isLunarRecurring) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _lunarBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    formatLunarMonthDayFromSolar(displayDay),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _lunarFg,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 16,
                            children: [
                              _infoChip(
                                gridItemWidth,
                                '循环起始',
                                formatGregorianDateLongZh(anchorDay),
                              ),
                              _infoChip(
                                gridItemWidth,
                                '重复',
                                _repeatLabel(event.repeatRule),
                              ),
                              _infoChip(
                                gridItemWidth,
                                '前置提醒',
                                advanceLine,
                              ),
                              _infoChip(gridItemWidth, '当天提醒', sameDayLine),
                            ],
                          ),
                        ),
                        if (photoPathsExisting.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '纪念照片',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _titleBarText,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.start,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < photoPathsExisting.length;
                                      i++
                                    )
                                      GestureDetector(
                                        onTap: () {
                                          showEventPhotoPathsPreview(
                                            context,
                                            photoPaths: photoPathsExisting,
                                            initialIndex: i,
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            _kEventPhotoBoxRadius,
                                          ),
                                          child: SizedBox(
                                            width: _kEventPhotoBoxWidth,
                                            height: _kEventPhotoBoxHeight,
                                            child: Image.file(
                                              File(photoPathsExisting[i]),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            24,
                            20,
                            20 + bottomInset,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _themeBlue,
                                      side: const BorderSide(
                                        color: _themeBlue,
                                        width: 1,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            final ctx =
                                                appNavigatorKey.currentContext;
                                            if (ctx != null) {
                                              showMemoryStoreSheet(
                                                ctx,
                                                listEvent: event,
                                              );
                                            }
                                          });
                                    },
                                    child: const Text(
                                      '存入时光集',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _themeBlue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      onEdit?.call();
                                    },
                                    child: const Text(
                                      '修改事件设置',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 打开清单事件详情底部弹层。
Future<void> showEventDetailSheet(
  BuildContext context,
  ListEvent event, {
  VoidCallback? onEdit,
  VoidCallback? onDismiss,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) =>
        EventDetailSheet(event: event, onEdit: onEdit, onDismiss: onDismiss),
  );
}
