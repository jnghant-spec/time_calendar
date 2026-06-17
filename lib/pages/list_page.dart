import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lunar/lunar.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/models/share_contact.dart';
import 'package:time_calendar/pages/event_add_page.dart';
import 'package:time_calendar/pages/event_detail_sheet.dart';
import 'package:time_calendar/services/event_service.dart';
import 'package:time_calendar/services/event_usage_service.dart';
import 'package:time_calendar/services/membership_service.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/tag_bar_state.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/theme/app_theme.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/utils/partner_test_data.dart';
import 'package:time_calendar/widgets/confirm_delete_dialog.dart';
import 'package:time_calendar/widgets/membership_soft_paywall.dart';
import 'package:time_calendar/widgets/pinned_star_badge.dart';
import 'package:time_calendar/widgets/tag_circle_widget.dart';
import 'package:time_calendar/widgets/tag_editor_sheet.dart';
import 'package:time_calendar/widgets/unified_tag_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<BoxShadow> _pinnedCardShadows() => [
      BoxShadow(
        color: kPinnedStarGold.withValues(alpha: 0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];

Widget _listCardShell({
  required bool isPinned,
  required List<BoxShadow> shadows,
  required Widget child,
}) {
  const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  if (!isPinned) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 0.75),
        boxShadow: shadows,
      ),
      padding: padding,
      child: child,
    );
  }
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _pinnedCardShadows(),
        ),
        padding: padding,
        child: child,
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
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
    ],
  );
}
const _kLunarTagBg = Color(0xFFFFF7ED);
const _kLunarTagFg = Color(0xFFF97316);
const _kExpiredGrey = Color(0xFFC7C7CC);

double _listCardDateRowTopOffset() =>
    (48 - (16 * 1.25 + 8 + 14 * 1.2)) / 2 + (16 * 1.25) + 8;

double _measureListCardTextWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

double _listCardCountdownReservedWidth(int daysDiff, bool expired) {
  if (expired) {
    final n = daysDiff.abs();
    final numberWidth = _measureListCardTextWidth(
      '$n',
      const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
    final unitWidth = _measureListCardTextWidth(
      '天前',
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    );
    return numberWidth + 4 + unitWidth;
  }
  if (daysDiff == 0) {
    return _measureListCardTextWidth(
      '今天',
      const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }
  final n = daysDiff.abs();
  final unit = daysDiff > 0 ? '天后' : '天前';
  final numberWidth = _measureListCardTextWidth(
    '$n',
    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
  );
  final unitWidth = _measureListCardTextWidth(
    unit,
    const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
  );
  return numberWidth + 4 + unitWidth;
}

double _measureLunarTagWidth(String lunarLine) {
  const horizontalPadding = 4.0;
  return horizontalPadding +
      _measureListCardTextWidth(
        lunarLine,
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      );
}

class _ListCardDateRow extends StatelessWidget {
  const _ListCardDateRow({
    required this.displayDate,
    required this.weekdayTextBuilder,
    required this.lunarLine,
    required this.dateStyle,
    required this.expiredVisual,
    required this.mutedArchived,
    required this.daysDiff,
  });

  final DateTime displayDate;
  final String Function(int weekday) weekdayTextBuilder;
  final String? lunarLine;
  final TextStyle dateStyle;
  final bool expiredVisual;
  final bool mutedArchived;
  final int daysDiff;

  static const double _weekdayGap = 4;
  static const double _lunarGap = 2;
  static const double _countdownRightInset = 6;

  @override
  Widget build(BuildContext context) {
    final solarText =
        '${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}-${displayDate.day.toString().padLeft(2, '0')}';
    final weekdayText = '周${weekdayTextBuilder(displayDate.weekday)}';
    final countdownReserve =
        _listCardCountdownReservedWidth(daysDiff, expiredVisual) +
            _countdownRightInset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dateAreaWidth = constraints.maxWidth - countdownReserve;
        final solarWidth = _measureListCardTextWidth(solarText, dateStyle);
        final weekdayWidth = _measureListCardTextWidth(weekdayText, dateStyle);
        final lunarWidth = lunarLine != null
            ? _lunarGap + 4 + _measureLunarTagWidth(lunarLine!)
            : 0;
        final showWeekday =
            solarWidth + _weekdayGap + weekdayWidth + lunarWidth <=
                dateAreaWidth - 2;

        return Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(solarText, style: dateStyle, maxLines: 1),
                if (showWeekday) ...[
                  const SizedBox(width: _weekdayGap),
                  Text(weekdayText, style: dateStyle, maxLines: 1),
                ],
              ],
            ),
            if (lunarLine != null) ...[
              const SizedBox(width: _lunarGap),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: expiredVisual || mutedArchived
                      ? Colors.grey.shade100
                      : _kLunarTagBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  lunarLine!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: expiredVisual || mutedArchived
                        ? _kExpiredGrey
                        : _kLunarTagFg,
                    height: 1.2,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
            SizedBox(width: countdownReserve),
          ],
        );
      },
    );
  }
}

/// FAB bottom(16) + FAB height(56) + breathing space(8)
const _kListScrollBottomPadding = 16.0 + 56.0 + 8.0;


class ListPage extends StatefulWidget {
  const ListPage({
    super.key,
    required this.initialEvents,
    required this.onEventsChanged,
  });

  final List<ListEvent> initialEvents;
  final ValueChanged<List<ListEvent>> onEventsChanged;

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  static const List<BoxShadow> _cardShadows = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 8,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  late List<ListEvent> _events;

  Timer? _deleteSnackDismissTimer;
  int _deleteSnackSeq = 0;

  final Map<String, Timer> _eventPhotoDeletionTimers = {};

  Set<String> _archivedIds = {};

  Future<void> _reloadArchivedIds() async {
    final s = await MembershipService.loadArchivedEventIds();
    if (mounted) setState(() => _archivedIds = s);
  }

  @override
  void dispose() {
    _deleteSnackDismissTimer?.cancel();
    for (final t in _eventPhotoDeletionTimers.values) {
      t.cancel();
    }
    _eventPhotoDeletionTimers.clear();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _events = List.from(widget.initialEvents);
    EventUsageService.updateCount(_events.length);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await MemoryService.repairOrphanTagAssociations();
      if (!mounted) return;
      await TagBarState().loadTags();
      if (!mounted) return;
      final bootstrap = MemoryService.consumeBootstrapListEvents();
      if (bootstrap != null && bootstrap.isNotEmpty) {
        _events = List.from(bootstrap);
      }
      final repaired = await MemoryService.repairListEvents(_events);
      if (!mounted) return;
      if (!identical(repaired, _events)) {
        _events = repaired;
        widget.onEventsChanged(_events);
        EventUsageService.updateCount(_events.length);
      } else if (bootstrap != null && bootstrap.isNotEmpty) {
        widget.onEventsChanged(_events);
        EventUsageService.updateCount(_events.length);
      }
      if (!mounted) return;
      setState(() {});
      if (!mounted) return;
      widget.onEventsChanged(_events);
      _reloadArchivedIds();
      // TODO: 测试完成后删除此行
      await PartnerTestData.generate();
      if (!mounted) return;
      await TagBarState().loadTags();
      if (!mounted) return;
      final refreshed = await EventService.loadAllEvents();
      _events = refreshed;
      widget.onEventsChanged(_events);
      EventUsageService.updateCount(_events.length);
      if (!mounted) return;
      setState(() {});
    });
    _reloadArchivedIds();
  }

  @override
  void didUpdateWidget(ListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.initialEvents, oldWidget.initialEvents)) {
      _events = List.from(widget.initialEvents);
      EventUsageService.updateCount(_events.length);
      _reloadArchivedIds();
    }
  }

  static String _weekdayZh(int weekday) {
    const w = ['一', '二', '三', '四', '五', '六', '日'];
    return w[weekday - 1];
  }

  String _lunarLine(DateTime solarDate) {
    final lunar = Lunar.fromDate(solarDate);
    return '农历 ${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
  }

  static void _purgeEventPhotoFilesSilently(Iterable<String> paths) {
    for (final p in paths) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
  }

  void _scheduleEventPhotoDeletion(String eventId, List<String> paths) {
    if (paths.isEmpty) return;
    _eventPhotoDeletionTimers[eventId]?.cancel();
    final copy = List<String>.from(paths);
    _eventPhotoDeletionTimers[eventId] = Timer(
      const Duration(milliseconds: 2800),
      () {
        _purgeEventPhotoFilesSilently(copy);
        _eventPhotoDeletionTimers.remove(eventId);
      },
    );
  }

  void _cancelScheduledEventPhotoDeletion(String eventId) {
    _eventPhotoDeletionTimers[eventId]?.cancel();
    _eventPhotoDeletionTimers.remove(eventId);
  }

  /// 排序：tier0 置顶未过期 → tier1 非置顶未过期 → tier2 置顶已过期 → tier3 非置顶已过期；已过期区域内按日期倒序（近先）。
  int _sortTier(ListEvent e) {
    final expired = isEventExpired(e);
    if (!expired) {
      return e.isPinned ? 0 : 1;
    }
    return e.isPinned ? 2 : 3;
  }

  List<ListEvent> _sortedEvents() {
    final filterTagId = TagBarState().selectedTagId;
    final source = _events.where((e) {
      if (filterTagId == null) return true;
      return e.tagId == filterTagId;
    }).toList();

    source.sort((a, b) {
      final ta = _sortTier(a);
      final tb = _sortTier(b);
      if (ta != tb) return ta.compareTo(tb);
      final da = effectiveDate(a);
      final db = effectiveDate(b);
      if (ta >= 2) {
        return db.compareTo(da);
      }
      return da.compareTo(db);
    });
    return source;
  }

  void _togglePin(String id) {
    final index = _events.indexWhere((e) => e.id == id);
    if (index < 0) return;
    setState(() {
      _events[index] = _events[index].copyWith(
        isPinned: !_events[index].isPinned,
      );
    });
    widget.onEventsChanged(_events);
  }

  Future<void> _confirmDeleteEvent(ListEvent event) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: '删除「${event.title}」？',
    );
    if (!confirmed || !mounted) return;
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index < 0) return;
    final backup = _events[index];
    _scheduleEventPhotoDeletion(backup.id, backup.photoPaths);
    setState(() {
      _events.removeAt(index);
      EventUsageService.updateCount(_events.length);
    });
    widget.onEventsChanged(_events);
    if (!mounted) return;
    final seq = ++_deleteSnackSeq;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();

    _deleteSnackDismissTimer?.cancel();

    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
    deleteSnackCtrl;
    deleteSnackCtrl = messenger.showSnackBar(
      SnackBar(
        content: Text('「${backup.title}」已删除'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.fixed,
        dismissDirection: DismissDirection.down,
        onVisible: () {
          if (!mounted || seq != _deleteSnackSeq) return;
          _deleteSnackDismissTimer?.cancel();
          _deleteSnackDismissTimer = Timer(const Duration(seconds: 2), () {
            if (!mounted || seq != _deleteSnackSeq) return;
            deleteSnackCtrl.close();
            _deleteSnackDismissTimer = null;
          });
        },
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            if (!mounted) return;
            _cancelScheduledEventPhotoDeletion(backup.id);
            _deleteSnackDismissTimer?.cancel();
            _deleteSnackDismissTimer = null;
            _deleteSnackSeq++;
            setState(() {
              final insertAt = index.clamp(0, _events.length);
              _events.insert(insertAt, backup);
              EventUsageService.updateCount(_events.length);
            });
            widget.onEventsChanged(_events);
            messenger.removeCurrentSnackBar();
          },
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted || seq != _deleteSnackSeq) return;
      deleteSnackCtrl.close();
    });
  }

  void _shareEvent(ListEvent event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _ShareEventSheet(parentContext: context),
        );
      },
    );
  }

  void _onSlideAction(ListEvent event, SwipeAction action) {
    _handleSwipeAction(event, action);
  }

  Color _pinActionColor(ListEvent event) {
    return const Color(0xFFFFB800);
  }

  Color _shareActionColor(ListEvent event) {
    return AppColors.primary;
  }

  Widget _buildSlideAction({
    required Color backgroundColor,
    required IconData icon,
    required String label,
    required bool roundLeft,
    required bool roundRight,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    BorderRadius borderRadius;
    if (roundLeft && roundRight) {
      borderRadius = BorderRadius.circular(12);
    } else if (roundLeft) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(12),
        bottomLeft: Radius.circular(12),
      );
    } else if (roundRight) {
      borderRadius = const BorderRadius.only(
        topRight: Radius.circular(12),
        bottomRight: Radius.circular(12),
      );
    } else {
      borderRadius = BorderRadius.zero;
    }
    return CustomSlidableAction(
      autoClose: true,
      padding: EdgeInsets.zero,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      onPressed: (_) => onTap(),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSwipeAction(ListEvent event, SwipeAction action) {
    switch (action) {
      case SwipeAction.onTogglePin:
        _togglePin(event.id);
        return;
      case SwipeAction.onShare:
        _shareEvent(event);
        return;
      case SwipeAction.onDelete:
        _confirmDeleteEvent(event);
        return;
    }
  }

  Future<void> _openCreateSheet() async {
    final tier = await MembershipService.currentTier();
    if (!mounted) return;
    if (!MembershipService.canCreateReminder(tier, _events.length)) {
      await showReminderQuotaPaywall(
        context,
        onTierChanged: () {
          if (!mounted) return;
          EventUsageService.updateCount(_events.length);
          setState(() {});
        },
      );
      if (!mounted) return;
      EventUsageService.updateCount(_events.length);
      setState(() {});
      return;
    }
    final result = await Navigator.push<ListEvent>(
      context,
      MaterialPageRoute(
        builder: (_) => EventAddPage(
          customReminderCountForNewEvent: _events.length,
          initialTagId: TagBarState().selectedTagId,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _events.add(result.copyWith(pendingShareAfterAdd: false));
      EventUsageService.updateCount(_events.length);
    });
    widget.onEventsChanged(_events);
  }

  Future<void> _openEditSheet(ListEvent event) async {
    final result = await Navigator.push<ListEvent>(
      context,
      MaterialPageRoute(builder: (_) => EventAddPage(initialEvent: event)),
    );
    if (result == null) return;
    setState(() {
      final index = _events.indexWhere((e) => e.id == result.id);
      if (index >= 0) {
        _events[index] = result;
        EventUsageService.updateCount(_events.length);
      }
    });
    widget.onEventsChanged(_events);
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56 + MediaQuery.paddingOf(context).top,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: MediaQuery.paddingOf(context).top,
            ),
            child: Row(
              children: [
                Text(
                  '所有提醒',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _deleteTagFromEditor(ReminderTag tag) async {
    if (!mounted) return false;
    final ok = await confirmUnlinkDeleteTag(context, tag);
    if (!ok || !mounted) return false;
    if (TagBarState().selectedTagId == tag.id) {
      TagBarState().selectTag(null);
    }
    await TagBarState().loadTags();
    if (mounted) setState(() {});
    return true;
  }

  Future<void> _openTagManage() async {
    await showTagManageSheet(
      context,
      onTagsChanged: () async {
        await TagBarState().loadTags();
        if (mounted) setState(() {});
      },
      onDeleteTag: _deleteTagFromEditor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _ListFab(onPressed: _openCreateSheet),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          UnifiedTagBar(
            onManagePressed: _openTagManage,
            horizontalPadding: 16,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListenableBuilder(
              listenable: TagBarState(),
              builder: (context, _) {
                final cards = _sortedEvents();
                if (cards.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无提醒',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击右下角按钮添加',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    _kListScrollBottomPadding,
                  ),
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final event = cards[index];
                    final displayDate = effectiveDate(event);
                    final diff = daysUntil(event);
                    final subline = eventSubline(event, diff);
                    final expired = isEventExpired(event);
                    final tag = TagService.getTagById(event.tagId);
                    final accent = tag != null
                        ? (tag.accentColor ?? TagCircleWidget.kDefaultTagColor)
                        : TagService.accentForDisplay(event.tagId);

                    return _ListEventCard(
                      event: event,
                      tag: tag,
                      accent: accent,
                      displayDate: displayDate,
                      daysDiff: diff,
                      subline: subline,
                      expiredVisual: expired,
                      archivedDowngrade: _archivedIds.contains(event.id),
                      weekdayTextBuilder: _weekdayZh,
                      lunarLine: event.isLunarRecurring
                          ? _lunarLine(displayDate)
                          : null,
                      cardShadows: _cardShadows,
                      onTap: () {
                        showEventDetailSheet(
                          context,
                          event,
                          onEdit: () => _openEditSheet(event),
                        );
                      },
                      onTogglePin: () => _togglePin(event.id),
                      slideActionsBuilder: (_) {
                        return [
                          _buildSlideAction(
                            backgroundColor: _pinActionColor(event),
                            icon: event.isPinned
                                ? Icons.star_border
                                : Icons.star,
                            label: event.isPinned ? '取消' : '置顶',
                            roundLeft: true,
                            roundRight: false,
                            iconColor: Colors.white,
                            onTap: () => _onSlideAction(
                              event,
                              SwipeAction.onTogglePin,
                            ),
                          ),
                          _buildSlideAction(
                            backgroundColor: _shareActionColor(event),
                            icon: Icons.share_outlined,
                            label: '分享',
                            roundLeft: false,
                            roundRight: false,
                            onTap: () =>
                                _onSlideAction(event, SwipeAction.onShare),
                          ),
                          _buildSlideAction(
                            backgroundColor: const Color(0xFFF04444),
                            icon: Icons.delete_outline,
                            label: '删除',
                            roundLeft: false,
                            roundRight: true,
                            onTap: () =>
                                _onSlideAction(event, SwipeAction.onDelete),
                          ),
                        ];
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


/// 每日分享人数累计（跨事件），按自然日 key 存储，次日自动换 key 即重置。
class _ShareDailyQuota {
  static String _keyFor(DateTime d) =>
      'share_daily_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<int> getTodayCount() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyFor(DateTime.now())) ?? 0;
  }

  static Future<void> addToToday(int n) async {
    if (n <= 0) return;
    final p = await SharedPreferences.getInstance();
    final k = _keyFor(DateTime.now());
    await p.setInt(k, (p.getInt(k) ?? 0) + n);
  }
}

class _ShareResultEntry {
  const _ShareResultEntry({required this.phone, required this.registered});
  final String phone;
  final bool registered;
}

/// 清单页底部分享 Sheet。
class _ShareEventSheet extends StatefulWidget {
  const _ShareEventSheet({required this.parentContext});

  final BuildContext parentContext;

  @override
  State<_ShareEventSheet> createState() => _ShareEventSheetState();
}

class _ShareEventSheetState extends State<_ShareEventSheet> {
  static const _kThemeBlue = Color(0xFF1A73E8);
  static const _kBorderColor = Color(0xFFE2E8F0);
  static const _kTitleColor = Color(0xFF0F172A);
  static const _kMutedGrey = Color(0xFF94A3B8);
  static const _kPrefsContacts = 'tc.share_management.contacts_v1';
  static const _kMaxShare = 5;
  static const _kMaxShareSnack =
      '本 app 现阶段仅支持同一事件单次分享给 5 人，如需分享超过 5 人，请再次点击分享';
  static const _kAvatarColors = <int>[
    0xFF8B5CF6,
    0xFFF59E0B,
    0xFFEF4444,
    0xFF10B981,
    0xFF06B6D4,
    0xFFEC4899,
    0xFF6366F1,
    0xFF14B8A6,
  ];
  static final _phoneMobile = RegExp(r'^1[3-9]\d{9}$');

  final List<ShareContact> _selectedContacts = [];
  List<ShareContact> _appContacts = [];
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final FocusNode _nicknameFocusNode = FocusNode();
  final PageController _gridPageController = PageController();
  int _gridPageIndex = 0;

  bool _showNicknameInput = false;
  String _currentPhoneForNickname = '';

  bool _resultsPhase = false;
  List<_ShareResultEntry> _results = [];
  int _registeredCount = 0;
  int _smsCount = 0;

  bool get _canConfirm => _selectedContacts.isNotEmpty && !_resultsPhase;

  bool get _phoneValid => _phoneMobile.hasMatch(_phoneController.text.trim());

  bool get _isFull => _selectedContacts.length >= _kMaxShare;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
    _loadAppContacts();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nicknameController.dispose();
    _nicknameFocusNode.dispose();
    _gridPageController.dispose();
    super.dispose();
  }

  void _showMaxShareSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(_kMaxShareSnack)),
    );
  }

  Future<void> _loadAppContacts() async {
    final contacts = <ShareContact>[];
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kPrefsContacts);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            contacts.add(ShareContact.fromJson(e));
          } else if (e is Map) {
            contacts.add(
              ShareContact.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ),
            );
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _appContacts = contacts);
    }
  }

  Future<void> _persistContact(ShareContact contact) async {
    final updated = [
      contact,
      ..._appContacts.where((c) => c.phone != contact.phone),
    ];
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kPrefsContacts,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
    if (mounted) {
      setState(() => _appContacts = updated);
    }
  }

  bool _isSelected(ShareContact contact) =>
      _selectedContacts.any((c) => c.phone == contact.phone);

  bool _isAtMaxShare() => _selectedContacts.length >= _kMaxShare;

  bool _tryAddSelected(ShareContact contact) {
    if (_isSelected(contact)) return true;
    if (_isAtMaxShare()) {
      _showMaxShareSnackBar();
      return false;
    }
    setState(() => _selectedContacts.add(contact));
    return true;
  }

  void _removeSelected(ShareContact contact) {
    setState(() {
      _selectedContacts.removeWhere((c) => c.phone == contact.phone);
    });
  }

  void _toggleContact(ShareContact contact) {
    if (_isSelected(contact)) {
      _removeSelected(contact);
      return;
    }
    _tryAddSelected(contact);
  }

  Color _avatarColor(int index) => Color(_kAvatarColors[index % _kAvatarColors.length]);

  int _colorIndexForContact(ShareContact contact) {
    final appIndex = _appContacts.indexWhere((c) => c.phone == contact.phone);
    if (appIndex >= 0) return appIndex;
    final phone = contact.phone;
    var hash = 0;
    for (var i = 0; i < phone.length; i++) {
      hash = (hash + phone.codeUnitAt(i)) % _kAvatarColors.length;
    }
    return hash;
  }

  static const double _kAvatarInnerSize = 56;
  static const double _kAvatarOuterSelectedSize = 64;

  bool _isDirectShareNumber(String name) => RegExp(r'^\d{4}$').hasMatch(name);

  String _avatarDisplayText(ShareContact contact) {
    final name = contact.name.trim();
    if (name.isNotEmpty) {
      if (name.length >= 2) return name.substring(0, 2);
      return name;
    }
    final phone = contact.phone.trim();
    if (phone.length >= 4) return phone.substring(phone.length - 4);
    if (phone.isNotEmpty) return phone;
    return '?';
  }

  bool _avatarTextIsPhoneDigits(ShareContact contact, String text) {
    return contact.name.trim().isEmpty && RegExp(r'^\d+$').hasMatch(text);
  }

  Widget _buildColoredAvatar({
    required Color color,
    required ShareContact contact,
  }) {
    final text = _avatarDisplayText(contact);
    final fontSize = _avatarTextIsPhoneDigits(contact, text) ? 14.0 : 16.0;
    return Container(
      width: _kAvatarInnerSize,
      height: _kAvatarInnerSize,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedAvatar({
    required Color color,
    required ShareContact contact,
  }) {
    final isDirectShare = _isDirectShareNumber(contact.name.trim());
    final text =
        isDirectShare ? contact.name.trim() : _avatarDisplayText(contact);
    final fontSize = isDirectShare ? 12.0 : 16.0;

    return Container(
      width: _kAvatarInnerSize,
      height: _kAvatarInnerSize,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildGridAvatar({
    required Color color,
    required ShareContact contact,
    required bool selected,
  }) {
    if (!selected) {
      return SizedBox(
        width: _kAvatarOuterSelectedSize,
        height: _kAvatarOuterSelectedSize,
        child: Center(
          child: _buildColoredAvatar(color: color, contact: contact),
        ),
      );
    }
    return SizedBox(
      width: _kAvatarOuterSelectedSize,
      height: _kAvatarOuterSelectedSize,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: _kThemeBlue, width: 2),
        ),
        child: _buildColoredAvatar(color: color, contact: contact),
      ),
    );
  }

  void _directShare() {
    if (_showNicknameInput) {
      setState(() => _showNicknameInput = false);
    }
    if (!_phoneValid) return;
    if (_isAtMaxShare()) {
      _showMaxShareSnackBar();
      return;
    }
    final phone = _phoneController.text.trim();
    final suffix = phone.substring(phone.length - 4);
    final contact = ShareContact(name: suffix, phone: phone);
    if (_tryAddSelected(contact)) {
      _phoneController.clear();
    }
  }

  void _addAsAppContactAndShare() {
    if (!_phoneValid) return;
    final phone = _phoneController.text.trim();
    setState(() {
      _showNicknameInput = true;
      _currentPhoneForNickname = phone;
      _nicknameController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nicknameFocusNode.requestFocus();
    });
  }

  void _cancelNicknameInput() {
    setState(() => _showNicknameInput = false);
  }

  Future<void> _confirmNicknameInput() async {
    final name = _nicknameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入称呼')),
      );
      return;
    }
    if (_isAtMaxShare()) {
      _showMaxShareSnackBar();
      return;
    }
    final contact = ShareContact(name: name, phone: _currentPhoneForNickname);
    await _persistContact(contact);
    await _loadAppContacts();
    if (!mounted) return;
    if (_tryAddSelected(contact)) {
      setState(() {
        _showNicknameInput = false;
        _phoneController.clear();
        _nicknameController.clear();
      });
    }
  }

  Future<void> _submitShare() async {
    if (!_canConfirm) return;
    final phones = _selectedContacts.map((c) => c.phone).toList();

    final daily = await _ShareDailyQuota.getTodayCount();
    if (!mounted) return;
    if (daily + phones.length > 20) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const Text('今日分享名额已满（每日最多 20 人），请明天再试'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    final results = <_ShareResultEntry>[];
    var reg = 0;
    var sms = 0;
    for (final p in phones) {
      final registered = _appContacts.any((c) => c.phone == p);
      results.add(_ShareResultEntry(phone: p, registered: registered));
      if (registered) {
        reg++;
      } else {
        sms++;
      }
    }

    await _ShareDailyQuota.addToToday(phones.length);

    setState(() {
      _results = results;
      _registeredCount = reg;
      _smsCount = sms;
      _resultsPhase = true;
    });
  }

  void _finishSheet() {
    final n = _results.length;
    final m = _registeredCount;
    final k = _smsCount;
    Navigator.of(context).pop();
    if (!widget.parentContext.mounted) return;
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(content: Text('已分享给 $n 位，$m 位等待确认，$k 位将收到短信（免费）')),
    );
  }

  Widget _buildSelectedContacts() {
    if (_selectedContacts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            itemCount: _selectedContacts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final contact = _selectedContacts[index];
              return GestureDetector(
                onTap: () => _removeSelected(contact),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: _kAvatarInnerSize,
                  height: 64,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      _buildSelectedAvatar(
                        color: _avatarColor(_colorIndexForContact(contact)),
                        contact: contact,
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: _kBorderColor, width: 0.7),
                          ),
                          child: const Icon(Icons.close, size: 16, color: _kTitleColor),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildGridCell(ShareContact contact, int colorIndex) {
    final selected = _isSelected(contact);
    final disabled = _isFull && !selected;
    final nameColor = selected
        ? _kThemeBlue
        : (disabled ? Colors.grey.shade400 : _kTitleColor);

    return GestureDetector(
      onTap: disabled ? null : () => _toggleContact(contact),
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGridAvatar(
              color: _avatarColor(colorIndex),
              contact: contact,
              selected: selected,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 22,
              width: double.infinity,
              child: Text(
                contact.name.trim().isNotEmpty ? contact.name : contact.phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.0,
                  color: nameColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactGridPage(
    List<ShareContact> pageItems,
    int startIndex, {
    bool shrinkWrap = true,
  }) {
    return GridView.count(
      crossAxisCount: 4,
      childAspectRatio: 0.88,
      mainAxisSpacing: 4.0,
      crossAxisSpacing: 12.0,
      padding: EdgeInsets.zero,
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(pageItems.length, (i) {
        return _buildGridCell(pageItems[i], startIndex + i);
      }),
    );
  }

  Widget _buildContactGrid() {
    if (_appContacts.isEmpty) return const SizedBox.shrink();

    if (_appContacts.length <= 8) {
      return _buildContactGridPage(_appContacts, 0);
    }

    final pageCount = (_appContacts.length / 8).ceil();
    return SizedBox(
      height: 210,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _gridPageController,
              onPageChanged: (index) => setState(() => _gridPageIndex = index),
              itemCount: pageCount,
              itemBuilder: (context, pageIndex) {
                final start = pageIndex * 8;
                final pageItems = _appContacts.skip(start).take(8).toList();
                return _buildContactGridPage(
                  pageItems,
                  start,
                  shrinkWrap: false,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pageCount, (index) {
                  final active = index == _gridPageIndex;
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active ? _kThemeBlue : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    final borderColor = _isFull ? Colors.grey.shade300 : _kBorderColor;
    final hintColor = _isFull ? Colors.grey.shade400 : const Color(0xFFCBD5E1);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 0.7),
        color: _isFull ? Colors.grey.shade50 : Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 72,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Text(
              '+86',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _isFull ? Colors.grey.shade400 : _kMutedGrey,
              ),
            ),
          ),
          Container(width: 0.7, height: 48, color: borderColor),
          Expanded(
            child: TextField(
              controller: _phoneController,
              enabled: !_isFull,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '输入手机号',
                hintStyle: TextStyle(color: hintColor),
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameInput() {
    final hintColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _kBorderColor, width: 0.7),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          '为 +86 $_currentPhoneForNickname 设置称呼',
          style: TextStyle(fontSize: 14, color: hintColor),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _nicknameController,
                focusNode: _nicknameFocusNode,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: '称呼',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _kThemeBlue, width: 0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _cancelNicknameInput,
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _confirmNicknameInput,
              style: FilledButton.styleFrom(
                backgroundColor: _kThemeBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('确定'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutlineAction({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    final disabledColor = cs.onSurface.withValues(alpha: 0.3);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _kThemeBlue,
        disabledForegroundColor: disabledColor,
        side: BorderSide(
          color: onPressed != null ? _kThemeBlue : disabledColor,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            primary: false,
            itemCount: _results.length,
            itemBuilder: (context, i) {
              final r = _results[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      r.registered ? Icons.check_circle : Icons.sms_outlined,
                      color: r.registered
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF97316),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.phone,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.registered
                                ? '已发送至对方账号，等待确认'
                                : '已发送邀请短信（免费）',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _finishSheet,
            style: FilledButton.styleFrom(
              backgroundColor: _kThemeBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '完成',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '分享给…',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _kTitleColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.close, color: _kMutedGrey, size: 22),
                  ),
                ],
              ),
              if (_resultsPhase)
                _buildResultsPhase()
              else ...[
                _buildSelectedContacts(),
                const Text(
                  'App 内联系人',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kTitleColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildContactGrid(),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.person_add_alt_1_outlined, size: 20, color: _kTitleColor),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '从手机通讯录选择',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: _kTitleColor,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 20, color: _kMutedGrey),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '手动输入手机号',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kTitleColor,
                  ),
                ),
                if (_isFull) ...[
                  const SizedBox(height: 4),
                  Text(
                    '已选满 5 人，如需添加请先删除已选联系人',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _buildPhoneInput(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildOutlineAction(
                        label: '添加联系人并分享',
                        icon: Icons.person_add_outlined,
                        onPressed: _isFull
                            ? null
                            : (_phoneValid ? _addAsAppContactAndShare : null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOutlineAction(
                        label: '直接分享',
                        icon: Icons.send_outlined,
                        onPressed: _isFull
                            ? null
                            : (_phoneValid ? _directShare : null),
                      ),
                    ),
                  ],
                ),
                if (_showNicknameInput && !_isFull) _buildNicknameInput(),
                const SizedBox(height: 12),
                const Text(
                  '该事件单次最多可分享给 5 人',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _kMutedGrey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _canConfirm ? _submitShare : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kThemeBlue,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: _kMutedGrey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      '确认分享',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _canConfirm ? Colors.white : _kMutedGrey,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ListFab extends StatefulWidget {
  const _ListFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ListFab> createState() => _ListFabState();
}

class _ListFabState extends State<_ListFab> {
  double _scale = 1;

  void _setPressed(bool pressed) {
    setState(() => _scale = pressed ? 0.95 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: FloatingActionButton(
          shape: const CircleBorder(),
          onPressed: widget.onPressed,
          backgroundColor: const Color(0xFF1A73E8),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

class _ListEventCard extends StatelessWidget {
  const _ListEventCard({
    required this.event,
    required this.tag,
    required this.accent,
    required this.displayDate,
    required this.daysDiff,
    this.subline,
    required this.expiredVisual,
    required this.archivedDowngrade,
    required this.weekdayTextBuilder,
    required this.lunarLine,
    required this.cardShadows,
    this.onTap,
    required this.onTogglePin,
    required this.slideActionsBuilder,
  });

  final ListEvent event;
  final ReminderTag? tag;
  final Color accent;
  final DateTime displayDate;
  final int daysDiff;
  final String? subline;
  final bool expiredVisual;
  final bool archivedDowngrade;
  final String Function(int weekday) weekdayTextBuilder;
  final String? lunarLine;
  final List<BoxShadow> cardShadows;
  final VoidCallback? onTap;
  final VoidCallback onTogglePin;
  final List<Widget> Function(BuildContext slidableContext) slideActionsBuilder;

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

  @override
  Widget build(BuildContext context) {
    final mutedArchived = archivedDowngrade;
    final titleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: expiredVisual || mutedArchived
          ? _kExpiredGrey
          : const Color(0xFF0F172A),
      height: 1.25,
      letterSpacing: -0.31,
    );
    final dateStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: expiredVisual || mutedArchived
          ? _kExpiredGrey
          : const Color(0xFF64748B),
      height: 1.2,
    );

    final opacityFactor = mutedArchived ? 0.6 : (expiredVisual ? 0.38 : 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.hardEdge,
      child: Slidable(
        key: ValueKey(event.id),
        closeOnScroll: true,
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.48,
          children: slideActionsBuilder(context),
        ),
        child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: _listCardShell(
          isPinned: event.isPinned,
          shadows: cardShadows,
          child: Opacity(
            opacity: opacityFactor,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (tag != null)
                      TagCircleWidget(tag: tag!, size: 48, showLabel: false)
                    else
                      const SizedBox(width: 48, height: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: titleStyle,
                                ),
                              ),
                              _partnerShareTitleMarker(event.tagId),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _ListCardDateRow(
                            displayDate: displayDate,
                            weekdayTextBuilder: weekdayTextBuilder,
                            lunarLine: lunarLine,
                            dateStyle: dateStyle,
                            expiredVisual: expiredVisual,
                            mutedArchived: mutedArchived,
                            daysDiff: daysDiff,
                          ),
                          if (mutedArchived) ...[
                            const SizedBox(height: 6),
                            const Text(
                              '已归档 · 当前档位仅显示部分活跃提醒，升级后可恢复',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Color(0xFF94A3B8),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (event.isPinned)
                  Positioned(
                    top: kPinnedStarBadgeTop,
                    right: kPinnedStarBadgeRight,
                    child: SvgPicture.asset(
                      'assets/images/ic_star.svg',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                  ),
                if (daysDiff == 0)
                  Positioned(
                    right: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ListCardCountdown(
                        daysDiff: daysDiff,
                        subline: subline,
                        accent: accent,
                        expired: expiredVisual,
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 6,
                    top: _listCardDateRowTopOffset() - 17.0 - (subline != null ? 2.0 : 0.0),
                    child: _ListCardCountdown(
                      daysDiff: daysDiff,
                      subline: subline,
                      accent: accent,
                      expired: expiredVisual,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _ListCardCountdown extends StatelessWidget {
  const _ListCardCountdown({
    required this.daysDiff,
    this.subline,
    required this.accent,
    required this.expired,
  });

  final int daysDiff;
  final String? subline;
  final Color accent;
  final bool expired;

  static const TextStyle _sublineStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF94A3B8),
    fontWeight: FontWeight.w500,
    height: 1.1,
  );

  Widget _wrapWithSubline(Widget mainLine) {
    if (subline == null) return mainLine;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        mainLine,
        SizedBox(height: daysDiff == 0 ? 2 : 1),
        Text(subline!, style: _sublineStyle, textAlign: TextAlign.right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (expired) {
      final n = daysDiff.abs();
      final tagColor = Colors.grey.shade500;
      return _wrapWithSubline(
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$n',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tagColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '天前',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: tagColor.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final numberColor = Color.lerp(accent, Colors.black, 0.15)!;
    if (daysDiff == 0) {
      return _wrapWithSubline(
        Text(
          '今天',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: numberColor,
          ),
        ),
      );
    }

    final n = daysDiff.abs();
    final unit = daysDiff > 0 ? '天后' : '天前';
    return _wrapWithSubline(
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$n',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: numberColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            unit,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
