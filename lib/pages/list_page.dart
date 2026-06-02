import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lunar/lunar.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/pages/event_add_page.dart';
import 'package:time_calendar/pages/event_detail_sheet.dart';
import 'package:time_calendar/services/event_usage_service.dart';
import 'package:time_calendar/services/membership_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/theme/app_theme.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/widgets/event_photo_paths_preview.dart';
import 'package:time_calendar/widgets/membership_soft_paywall.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 与日历节日类 accent（0xFF10B981）一致时「今天」用绿色，否则用事件自身 accent。
Color _todayLabelColorFromAccent(Color accent) {
  const festivalGreen = Color(0xFF10B981);
  return accent.toARGB32() == festivalGreen.toARGB32() ? festivalGreen : accent;
}

const _kListStarColor = Color(0xFFFFB800);
const _kLunarTagBg = Color(0xFFFFF7ED);
const _kLunarTagFg = Color(0xFFF97316);
const _kExpiredGrey = Color(0xFFC7C7CC);

/// 「新建 / 编辑标签」预设主题色（与规范一致）。
const List<Color> _kTagPresetColors = [
  Color(0xFFF97316),
  Color(0xFFF43F5E),
  Color(0xFF3B82F6),
  Color(0xFFA855F7),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEC4899),
  Color(0xFF6366F1),
];

Widget _tagLeadingIcon(String tagId, Color accent, bool expired) {
  final c = expired ? _kExpiredGrey : accent;
  if (tagId == 'birthday') {
    return Icon(Icons.cake, color: c, size: 20);
  }
  if (tagId == 'partner') {
    return SvgPicture.asset(
      'assets/images/ic_couple_hearts.svg',
      width: 20,
      height: 20,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
  return Icon(Icons.label, color: c, size: 20);
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

  List<ReminderTag> _tags = [];
  String? _activeFilterTagId;

  /// 长按标签 Pill 后进入删除/改名模式。
  String? _pillEditTagId;

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
      final tags = await TagService.loadTags();
      if (!mounted) return;
      setState(() => _tags = tags);
      if (!mounted) return;
      widget.onEventsChanged(_events);
      _reloadArchivedIds();
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
    final source = _events.where((e) {
      if (_activeFilterTagId == null) return true;
      return e.tagId == _activeFilterTagId;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除「${event.title}」吗？该操作不可撤销。'),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF04444),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
    return const Color(0xFF2441A7);
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
          initialTagId: _activeFilterTagId,
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
                  '所有清单',
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
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
      ],
    );
  }

  void _onTagPillTap(ReminderTag tag) {
    if (_pillEditTagId != null) {
      if (_pillEditTagId == tag.id) {
        setState(() => _pillEditTagId = null);
        return;
      }
      setState(() {
        _pillEditTagId = null;
        _activeFilterTagId = tag.id;
      });
      return;
    }
    setState(() => _activeFilterTagId = tag.id);
  }

  Future<void> _handleDeleteTag(ReminderTag tag) async {
    final affected = _events.where((e) => e.tagId == tag.id).toList();
    if (affected.isEmpty) {
      setState(() {
        _tags.removeWhere((t) => t.id == tag.id);
        if (_activeFilterTagId == tag.id) _activeFilterTagId = null;
        _pillEditTagId = null;
      });
      await TagService.saveTags(_tags);
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('删除「${tag.name}」标签'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...affected
                    .take(5)
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('· ${e.title}'),
                      ),
                    ),
                if (affected.length > 5) Text('等共 ${affected.length} 条'),
                const SizedBox(height: 12),
                const Text('删除标签将同时删除以上提醒事项（含已过期），此操作不可撤销。'),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF04444),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    for (final e in affected) {
      _purgeEventPhotoFilesSilently(e.photoPaths);
    }
    setState(() {
      _events.removeWhere((e) => e.tagId == tag.id);
      EventUsageService.updateCount(_events.length);
      _tags.removeWhere((t) => t.id == tag.id);
      if (_activeFilterTagId == tag.id) _activeFilterTagId = null;
      _pillEditTagId = null;
    });
    widget.onEventsChanged(_events);
    await TagService.saveTags(_tags);
  }

  Future<void> _openAddTagSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
          ),
          child: _AddTagSheet(
            nextSortOrder: _tags.length,
            onCreate: (ReminderTag tag) async {
              await TagService.addTag(tag);
              final list = await TagService.loadTags();
              if (!mounted || !sheetCtx.mounted) return;
              setState(() {
                _tags = list;
                _activeFilterTagId = tag.id;
              });
              Navigator.pop(sheetCtx);
            },
          ),
        );
      },
    );
  }

  Future<void> _openEditTagSheet(ReminderTag tag) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
          ),
          child: _EditTagSheet(
            initial: tag,
            onSave: (ReminderTag updated) async {
              await TagService.updateTag(updated);
              final list = await TagService.loadTags();
              if (!mounted || !sheetCtx.mounted) return;
              setState(() {
                _tags = list;
                _pillEditTagId = null;
              });
              Navigator.pop(sheetCtx);
            },
          ),
        );
      },
    );
    if (mounted) setState(() => _pillEditTagId = null);
  }

  Widget _buildAddTagPill() {
    final atMax = _tags.length >= TagService.maxTagCount;
    return Opacity(
      opacity: atMax ? 0.4 : 1,
      child: GestureDetector(
        onTap: () {
          if (atMax) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('最多可创建 10 个标签')));
            return;
          }
          _openAddTagSheet();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: const Text(
            '+',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A73E8),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final primary = Theme.of(context).colorScheme.primary;
    final sorted = List<ReminderTag>.from(_tags)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    const chipBg = Color(0xFFFAFBFC);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 36,
            color: chipBg,
            alignment: Alignment.center,
            child: _PillFilterChip(
              label: '全部',
              selected: _activeFilterTagId == null,
              selectedColor: primary,
              onTap: () => setState(() {
                _activeFilterTagId = null;
                _pillEditTagId = null;
              }),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tag = sorted[index];
                return _TagFilterPill(
                  tag: tag,
                  selected: _activeFilterTagId == tag.id,
                  editing: _pillEditTagId == tag.id,
                  onTap: () => _onTagPillTap(tag),
                  onLongPress: () => setState(() => _pillEditTagId = tag.id),
                  onTapRename: () => _openEditTagSheet(tag),
                  onTapDeleteBadge: () => _handleDeleteTag(tag),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          Container(
            height: 36,
            color: chipBg,
            alignment: Alignment.center,
            child: _buildAddTagPill(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _sortedEvents();

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
          const SizedBox(height: 12),
          SizedBox(height: 36, child: _buildFilterChips()),
          const SizedBox(height: 12),
          Expanded(
            child: cards.isEmpty
                ? Center(
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
                          '暂无事件',
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
                  )
                : ListView.separated(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 94),
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = cards[index];
                      final displayDate = effectiveDate(event);
                      final diff = daysUntil(event);
                      final expired = isEventExpired(event);
                      final accent = TagService.accentForDisplay(event.tagId);
                      final iconBg = TagService.iconBgForDisplay(event.tagId);

                      return _ListEventCard(
                        event: event,
                        accent: accent,
                        iconBg: iconBg,
                        displayDate: displayDate,
                        daysDiff: diff,
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
                              iconColor: _kListStarColor,
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
                  ),
          ),
        ],
      ),
    );
  }
}

class _TagFilterPill extends StatelessWidget {
  const _TagFilterPill({
    required this.tag,
    required this.selected,
    required this.editing,
    required this.onTap,
    required this.onLongPress,
    required this.onTapRename,
    required this.onTapDeleteBadge,
  });

  final ReminderTag tag;
  final bool selected;
  final bool editing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onTapRename;
  final VoidCallback onTapDeleteBadge;

  @override
  Widget build(BuildContext context) {
    final chipCore = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? tag.accentColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? null
              : Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Text(
          tag.name,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.43,
          ),
        ),
      ),
    );

    if (!editing) return chipCore;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        chipCore,
        Positioned(
          top: -6,
          right: -6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onTapRename,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFF64748B),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.edit, size: 10, color: Colors.white),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onTapDeleteBadge,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF04444),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.close, size: 10, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddTagSheet extends StatefulWidget {
  const _AddTagSheet({required this.nextSortOrder, required this.onCreate});

  final int nextSortOrder;
  final Future<void> Function(ReminderTag tag) onCreate;

  @override
  State<_AddTagSheet> createState() => _AddTagSheetState();
}

class _AddTagSheetState extends State<_AddTagSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  int _colorIndex = 0;

  static const List<BoxShadow> _fieldShadow = [
    BoxShadow(color: Color(0x0D111827), blurRadius: 20, offset: Offset(0, 8)),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final color =
        _kTagPresetColors[_colorIndex.clamp(0, _kTagPresetColors.length - 1)];
    final tag = ReminderTag(
      id: TagService.newTagId(),
      name: name,
      accentColor: color,
      iconBgColor: color.withValues(alpha: 0.15),
      sortOrder: widget.nextSortOrder,
      isDefault: false,
      createdAt: DateTime.now(),
    );
    await widget.onCreate(tag);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final nameOk = _nameCtrl.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '新建标签',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECEFF5)),
                boxShadow: _fieldShadow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '输入标签名称，如：旅行、工作、健身',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_nameCtrl.text.length}/8',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '选择主题色',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _kTagPresetColors.length; i++) ...[
                    if (i != 0) const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kTagPresetColors[i],
                          border: Border.all(
                            color: _colorIndex == i
                                ? const Color(0xFF1A73E8)
                                : Colors.transparent,
                            width: _colorIndex == i ? 2 : 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Opacity(
              opacity: nameOk ? 1 : 0.5,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: nameOk ? _submit : null,
                  child: const Text('创建标签'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditTagSheet extends StatefulWidget {
  const _EditTagSheet({required this.initial, required this.onSave});

  final ReminderTag initial;
  final Future<void> Function(ReminderTag tag) onSave;

  @override
  State<_EditTagSheet> createState() => _EditTagSheetState();
}

class _EditTagSheetState extends State<_EditTagSheet> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.initial.name,
  );
  late int _colorIndex;

  static const List<BoxShadow> _fieldShadow = [
    BoxShadow(color: Color(0x0D111827), blurRadius: 20, offset: Offset(0, 8)),
  ];

  @override
  void initState() {
    super.initState();
    final idx = _kTagPresetColors.indexWhere(
      (c) => c.toARGB32() == widget.initial.accentColor.toARGB32(),
    );
    _colorIndex = idx >= 0 ? idx : 0;
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final color =
        _kTagPresetColors[_colorIndex.clamp(0, _kTagPresetColors.length - 1)];
    final accentSame =
        color.toARGB32() == widget.initial.accentColor.toARGB32();
    final updated = widget.initial.copyWith(
      name: name,
      accentColor: color,
      iconBgColor: accentSame
          ? widget.initial.iconBgColor
          : color.withValues(alpha: 0.15),
    );
    await widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final nameOk = _nameCtrl.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '编辑标签',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECEFF5)),
                boxShadow: _fieldShadow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '输入标签名称，如：旅行、工作、健身',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_nameCtrl.text.length}/8',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '选择主题色',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _kTagPresetColors.length; i++) ...[
                    if (i != 0) const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kTagPresetColors[i],
                          border: Border.all(
                            color: _colorIndex == i
                                ? const Color(0xFF1A73E8)
                                : Colors.transparent,
                            width: _colorIndex == i ? 2 : 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Opacity(
              opacity: nameOk ? 1 : 0.5,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: nameOk ? _submit : null,
                  child: const Text('保存'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 清单页底部分享 Sheet（手机号多选、校验、结果展示、每日限额）。
class _ShareResultEntry {
  const _ShareResultEntry({required this.phone, required this.registered});
  final String phone;
  final bool registered;
}

class _ShareEventSheet extends StatefulWidget {
  const _ShareEventSheet({required this.parentContext});

  final BuildContext parentContext;

  @override
  State<_ShareEventSheet> createState() => _ShareEventSheetState();
}

class _ShareEventSheetState extends State<_ShareEventSheet> {
  final List<TextEditingController> _controllers = [];

  bool _resultsPhase = false;
  List<_ShareResultEntry> _results = [];
  int _registeredCount = 0;
  int _smsCount = 0;

  static const BoxDecoration _phoneDecorationNeutral = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(18)),
    boxShadow: [
      BoxShadow(color: Color(0x0D111827), blurRadius: 20, offset: Offset(0, 8)),
    ],
    border: Border.fromBorderSide(BorderSide(color: Color(0xFFECEFF5))),
  );

  static final BoxDecoration _phoneDecorationError = _phoneDecorationNeutral
      .copyWith(border: Border.all(color: Color(0xFFF04444)));

  @override
  void initState() {
    super.initState();
    final c = TextEditingController();
    c.addListener(() => setState(() {}));
    _controllers.add(c);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool _hasFieldError(String text) {
    if (text.isEmpty) return false;
    return !RegExp(r'^\d{11}$').hasMatch(text);
  }

  bool _allEnteredPhonesValid() {
    final phones = _controllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (phones.isEmpty) return false;
    return phones.every((p) => RegExp(r'^\d{11}$').hasMatch(p));
  }

  void _tryAddField() {
    if (_controllers.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该事件单次最多可分享给 5 人')));
      return;
    }
    final c = TextEditingController();
    c.addListener(() => setState(() {}));
    setState(() => _controllers.add(c));
  }

  void _removeField(int index) {
    if (_controllers.length <= 1) return;
    _controllers[index].dispose();
    setState(() => _controllers.removeAt(index));
  }

  Future<void> _submitShare() async {
    if (!_allEnteredPhonesValid()) return;
    final phones = _controllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

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
      final last = int.tryParse(p.substring(p.length - 1)) ?? 0;
      final registered = last.isOdd;
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
    ScaffoldMessenger.of(
      widget.parentContext,
    ).showSnackBar(SnackBar(content: Text('已分享给 $n 位，$m 位等待确认，$k 位将收到短信（免费）')));
  }

  Widget _phoneField(int index) {
    final c = _controllers[index];
    final err = _hasFieldError(c.text);
    return Container(
      decoration: err ? _phoneDecorationError : _phoneDecorationNeutral,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.phone, color: Color(0xFF9CA3AF), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '请输入手机号',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final atMaxFields = _controllers.length >= 5;
    final showMaxHint = atMaxFields;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '分享给…',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (!_resultsPhase) ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _controllers.length,
                  itemBuilder: (context, index) {
                    final c = _controllers[index];
                    final err = _hasFieldError(c.text);
                    final isLast = index == _controllers.length - 1;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _controllers.length - 1 ? 0 : 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: _phoneField(index)),
                              if (_controllers.length >= 2)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.grey.shade600,
                                  onPressed: () => _removeField(index),
                                ),
                              if (isLast)
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  color: atMaxFields
                                      ? Colors.grey
                                      : Theme.of(context).colorScheme.primary,
                                  onPressed: atMaxFields ? null : _tryAddField,
                                ),
                            ],
                          ),
                          if (err)
                            const Padding(
                              padding: EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                '请输入正确的 11 位手机号',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFF04444),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                if (showMaxHint) ...[
                  const SizedBox(height: 8),
                  Text(
                    '该事件单次最多可分享给 5 人',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _allEnteredPhonesValid() ? _submitShare : null,
                    child: const Text('确认分享'),
                  ),
                ),
              ] else ...[
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
                              r.registered
                                  ? Icons.check_circle
                                  : Icons.sms_outlined,
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
                  child: FilledButton(
                    onPressed: _finishSheet,
                    child: const Text('完成'),
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
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

class _PillFilterChip extends StatelessWidget {
  const _PillFilterChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? null
              : Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.43,
          ),
        ),
      ),
    );
  }
}

class _ListEventCard extends StatelessWidget {
  const _ListEventCard({
    required this.event,
    required this.accent,
    required this.iconBg,
    required this.displayDate,
    required this.daysDiff,
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
  final Color accent;
  final Color iconBg;
  final DateTime displayDate;
  final int daysDiff;
  final bool expiredVisual;
  final bool archivedDowngrade;
  final String Function(int weekday) weekdayTextBuilder;
  final String? lunarLine;
  final List<BoxShadow> cardShadows;
  final VoidCallback? onTap;
  final VoidCallback onTogglePin;
  final List<Widget> Function(BuildContext slidableContext) slideActionsBuilder;

  static const Color _border = Color(0xFFF1F5F9);

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

    return Slidable(
      key: ValueKey(event.id),
      closeOnScroll: true,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.45,
        children: slideActionsBuilder(
          context,
        ).map((w) => Expanded(child: w)).toList(),
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border, width: 0.75),
            boxShadow: cardShadows,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Opacity(
            opacity: opacityFactor,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: _tagLeadingIcon(
                    event.tagId,
                    accent,
                    expiredVisual || mutedArchived,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                          ),
                          if (event.isPinned) ...[
                            const SizedBox(width: 2),
                            Icon(
                              Icons.star,
                              size: 16,
                              color: expiredVisual || mutedArchived
                                  ? _kExpiredGrey
                                  : _kListStarColor,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              '${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}-${displayDate.day.toString().padLeft(2, '0')} 周${weekdayTextBuilder(displayDate.weekday)}',
                              style: dateStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lunarLine != null) ...[
                            const SizedBox(width: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 2,
                              ),
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
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (event.photoPaths.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (!event.photoPaths.any(
                              (p) => File(p).existsSync(),
                            )) {
                              return;
                            }
                            showEventPhotoPathsPreview(
                              context,
                              photoPaths: event.photoPaths,
                              initialIndex: 0,
                            );
                          },
                          child: SizedBox(
                            height: 20,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.photo_library,
                                  size: 14,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${event.photoPaths.length}张',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                const SizedBox(width: 8),
                _CountdownColumn(
                  daysDiff: daysDiff,
                  accent: accent,
                  expired: expiredVisual,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownColumn extends StatelessWidget {
  const _CountdownColumn({
    required this.daysDiff,
    required this.accent,
    required this.expired,
  });

  final int daysDiff;
  final Color accent;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    const w = 72.0;

    if (!expired && daysDiff == 0) {
      final todayColor = _todayLabelColorFromAccent(accent);
      return SizedBox(
        width: w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '今天',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: todayColor,
                height: 1,
              ),
            ),
          ],
        ),
      );
    }

    if (expired) {
      final n = daysDiff.abs();
      final topColor = Colors.grey.shade500;
      final bottomColor = topColor.withValues(alpha: 0.8);
      return SizedBox(
        width: w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$n',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: topColor,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '天前',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: bottomColor,
                height: 1,
              ),
            ),
          ],
        ),
      );
    }

    final n = daysDiff.abs();
    final unitColor = accent.withValues(alpha: 0.7);
    return SizedBox(
      width: w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$n',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: accent,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '天后',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: unitColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
