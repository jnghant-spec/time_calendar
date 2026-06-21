import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lunar/lunar.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/utils/partner_share_detail_ui.dart';

/// 日历页半屏事件详情（底部 Modal）。
class EventDetailSheet extends StatelessWidget {
  const EventDetailSheet({
    super.key,
    required this.event,
    this.displaySolarDate,
  });

  final ListEvent event;

  /// 本次在日历上展示的公历发生日（循环事件）；为 null 则用 [event.baseDate]。
  final DateTime? displaySolarDate;

  static const Color _titleColor = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _star = Color(0xFFFFB800);
  static const Color _lunarBg = Color(0xFFFFF7ED);
  static const Color _lunarFg = Color(0xFFF97316);
  static const Color _modifiedHint = Color(0xFF9CA3AF);

  static String _weekdayZh(int weekday) {
    const w = ['一', '二', '三', '四', '五', '六', '日'];
    return w[weekday - 1];
  }

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

  static String _reminderLabel(EventReminderType t) {
    switch (t) {
      case EventReminderType.advanceAndSameDay:
        return '前置+当天';
      case EventReminderType.advanceOnly:
        return '仅前置';
      case EventReminderType.sameDayOnly:
        return '仅当天';
    }
  }

  static String _advanceDaysPhrase(EventAdvanceDaysOption o) {
    switch (o) {
      case EventAdvanceDaysOption.oneDay:
        return '前1天';
      case EventAdvanceDaysOption.threeDays:
        return '前3天';
      case EventAdvanceDaysOption.oneWeek:
        return '前7天';
      case EventAdvanceDaysOption.oneMonth:
        return '前30天';
    }
  }

  static bool _showAdvance(EventReminderType t) =>
      t == EventReminderType.advanceAndSameDay || t == EventReminderType.advanceOnly;

  static bool _showSameDay(EventReminderType t) =>
      t == EventReminderType.advanceAndSameDay || t == EventReminderType.sameDayOnly;

  Widget _tagIcon(String tagId, Color accent) {
    if (tagId == 'birthday') {
      return Icon(Icons.cake, color: accent, size: 20);
    }
    if (tagId == 'partner') {
      return SvgPicture.asset(
        'assets/images/ic_couple_hearts.svg',
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
      );
    }
    return Icon(Icons.label, color: accent, size: 20);
  }

  Widget _summaryRow(String label, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: _muted),
          ),
        ),
        Expanded(child: right),
      ],
    );
  }

  Widget _summaryText(String value) {
    return Text(
      value,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _titleColor),
      textAlign: TextAlign.right,
    );
  }

  static String _formatSolarLine(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day 周${_weekdayZh(d.weekday)}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = TagService.accentForDisplay(event.tagId);
    final baseD = DateTime(event.baseDate.year, event.baseDate.month, event.baseDate.day);
    final d = displaySolarDate != null
        ? DateTime(
            displaySolarDate!.year,
            displaySolarDate!.month,
            displaySolarDate!.day,
          )
        : baseD;
    final solarLine = _formatSolarLine(d);
    final modifiedLabel = buildPartnerModifiedLabel(
      lastModifiedByName: event.lastModifiedByName,
      lastModifiedAt: event.lastModifiedAt,
    );
    final partnerShareInfo = resolvePartnerShareDetail(event);

    final lunar = Lunar.fromDate(d);
    final lunarPillText = '农历 ${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    const Expanded(
                      child: Text(
                        '事件详情',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _titleColor,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, color: _muted, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: _tagIcon(event.tagId, accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    event.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _titleColor,
                                    ),
                                  ),
                                ),
                                buildPartnerShareTitleMarker(
                                  partnerShareInfo,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                          if (event.isPinned) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.star, size: 16, color: _star),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              solarLine,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
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
                          if (event.isLunarRecurring) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _lunarBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lunarPillText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _lunarFg,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      buildPartnerShareStatusRow(
                        partnerShareInfo,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          color: _modifiedHint,
                          height: 20 / 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (displaySolarDate != null &&
                          (event.repeatRule != EventRepeatRule.none || event.isLunarRecurring) &&
                          (d.year != baseD.year ||
                              d.month != baseD.month ||
                              d.day != baseD.day)) ...[
                        _summaryRow('循环起始', _summaryText(_formatSolarLine(baseD))),
                        const SizedBox(height: 12),
                      ],
                      _summaryRow('重复', _summaryText(_repeatLabel(event.repeatRule))),
                      const SizedBox(height: 12),
                      _summaryRow('提醒', _summaryText(_reminderLabel(event.reminderType))),
                      if (_showAdvance(event.reminderType)) ...[
                        const SizedBox(height: 12),
                        _summaryRow(
                          '前置提醒',
                          _summaryText(
                            '${_advanceDaysPhrase(event.advanceDaysOption)} ${event.advanceTimeHm}',
                          ),
                        ),
                      ],
                      if (_showSameDay(event.reminderType)) ...[
                        const SizedBox(height: 12),
                        _summaryRow('当天提醒', _summaryText(event.sameDayTimeHm)),
                      ],
                      if (event.isPinned) ...[
                        const SizedBox(height: 12),
                        _summaryRow(
                          '已置顶',
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(Icons.star, size: 16, color: _star),
                              const SizedBox(width: 4),
                              Text(
                                '已置顶',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _titleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '如需修改事件设置，请前往清单页长按卡片编辑',
                                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
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
    );
  }
}
