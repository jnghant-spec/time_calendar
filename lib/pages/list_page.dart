import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/pages/event_edit_page.dart';
import 'package:time_calendar/services/event_usage_service.dart';
import 'package:time_calendar/theme/app_theme.dart';
import 'package:time_calendar/utils/size_config.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage>
    with SingleTickerProviderStateMixin {
  static const List<ListCategory> _categoryOrder = [
    ListCategory.birthday,
    ListCategory.partner,
    ListCategory.goal,
    ListCategory.idol,
  ];

  final List<ListEvent> _events = [
    ListEvent(
      id: '1',
      title: '妈妈的生日',
      baseDate: DateTime(2026, 4, 20),
      category: ListCategory.birthday,
      isPinned: true,
      isLunarRecurring: true,
    ),
    ListEvent(
      id: '2',
      title: '父亲生日',
      baseDate: DateTime(2026, 4, 20),
      category: ListCategory.birthday,
      isPinned: true,
      isLunarRecurring: true,
    ),
    ListEvent(
      id: '3',
      title: '周杰伦演唱会',
      baseDate: DateTime(2026, 5, 1),
      category: ListCategory.idol,
    ),
    ListEvent(
      id: '4',
      title: '考研倒计时',
      baseDate: DateTime(2026, 12, 25),
      category: ListCategory.goal,
    ),
    ListEvent(
      id: '5',
      title: '恋爱纪念日（两周年）',
      baseDate: DateTime(2026, 4, 18),
      category: ListCategory.partner,
    ),
  ];

  ListCategory? _activeFilter;
  final Set<ListCategory> _deletedFilterChips = {};
  bool _chipEditing = false;
  late final AnimationController _chipShakeController;

  @override
  void initState() {
    super.initState();
    _chipShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    EventUsageService.updateCount(_events.length);
  }

  @override
  void dispose() {
    _chipShakeController.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static Color _categoryColor(ListCategory category) {
    switch (category) {
      case ListCategory.partner:
        return Colors.red;
      case ListCategory.birthday:
        return Colors.orange;
      case ListCategory.goal:
        return const Color(0xFF60A5FA);
      case ListCategory.idol:
        return Colors.purple;
    }
  }

  static String _categoryLabel(ListCategory category) {
    switch (category) {
      case ListCategory.birthday:
        return '生日';
      case ListCategory.partner:
        return '伴侣';
      case ListCategory.goal:
        return '目标';
      case ListCategory.idol:
        return '偶像';
    }
  }

  static String _weekdayZh(int weekday) {
    const w = ['一', '二', '三', '四', '五', '六', '日'];
    return w[weekday - 1];
  }

  DateTime _nextOccurrence(ListEvent event) {
    final today = _dateOnly(DateTime.now());
    DateTime candidate = DateTime(
      today.year,
      event.baseDate.month,
      event.baseDate.day,
    );
    if (event.isLunarRecurring) {
      // TODO(lunar_calendar): 使用 lunar_calendar 按农历年换算下一次提醒公历日期。
      // 现阶段先用同月同日公历兜底，保证排序和展示链路可用。
      candidate = DateTime(
        today.year,
        event.baseDate.month,
        event.baseDate.day,
      );
    }
    if (candidate.isBefore(today)) {
      candidate = DateTime(
        today.year + 1,
        event.baseDate.month,
        event.baseDate.day,
      );
    }
    return candidate;
  }

  List<ListCategory> _visibleChips() {
    final hasData = _events.map((e) => e.category).toSet();
    return _categoryOrder
        .where(hasData.contains)
        .where((c) => !_deletedFilterChips.contains(c))
        .toList();
  }

  List<ListEvent> _sortedEvents() {
    final source = _events.where((e) {
      if (_activeFilter == null) return true;
      return e.category == _activeFilter;
    }).toList();

    source.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return _nextOccurrence(a).compareTo(_nextOccurrence(b));
    });
    return source;
  }

  void _enterChipEditMode() {
    if (_chipEditing) return;
    setState(() => _chipEditing = true);
    _chipShakeController.repeat(reverse: true);
  }

  void _exitChipEditMode() {
    if (!_chipEditing) return;
    _chipShakeController.stop();
    _chipShakeController.reset();
    setState(() => _chipEditing = false);
  }

  void _removeChip(ListCategory category) {
    setState(() {
      _deletedFilterChips.add(category);
      if (_activeFilter == category) {
        _activeFilter = null;
      }
    });
  }

  void _togglePin(String id) {
    setState(() {
      final index = _events.indexWhere((e) => e.id == id);
      if (index < 0) return;
      _events[index] = _events[index].copyWith(
        isPinned: !_events[index].isPinned,
      );
    });
  }

  void _deleteEvent(String id) {
    setState(() {
      _events.removeWhere((e) => e.id == id);
      final existed = _events.map((e) => e.category).toSet();
      _deletedFilterChips.removeWhere((chip) => !existed.contains(chip));
      if (_activeFilter != null && !existed.contains(_activeFilter)) {
        _activeFilter = null;
      }
      EventUsageService.updateCount(_events.length);
    });
  }

  void _shareEvent(ListEvent event) {
    final phoneController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '分享「${event.title}」',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '手机号码',
                  hintText: '请输入接收方手机号',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('分享流程已触发（预留后端接口）')),
                    );
                  },
                  child: const Text('下一步'),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(phoneController.dispose);
  }

  void _onSlideAction(
    ListEvent event,
    SwipeAction action,
    BuildContext slidableContext,
  ) {
    Slidable.of(slidableContext)?.close();
    // TODO(storage): 在接入本地数据库/缓存后，同步持久化置顶、分享、删除动作。
    _handleSwipeAction(event, action);
  }

  Color _pinActionColor(ListEvent event) {
    if (event.category == ListCategory.partner) {
      return Colors.red;
    }
    return const Color(0xFF2441A7);
  }

  Color _shareActionColor(ListEvent event) {
    if (event.category == ListCategory.partner) {
      return Colors.red.withValues(alpha: 0.88);
    }
    return AppColors.primary;
  }

  Widget _buildSlideAction({
    required Color backgroundColor,
    required IconData icon,
    required String label,
    required bool roundRight,
    required VoidCallback onTap,
  }) {
    return CustomSlidableAction(
      autoClose: true,
      padding: EdgeInsets.zero,
      backgroundColor: backgroundColor,
      borderRadius: roundRight
          ? const BorderRadius.only(
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
            )
          : BorderRadius.zero,
      onPressed: (_) => onTap(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
        _deleteEvent(event.id);
        return;
    }
  }

  Future<void> _openCreateSheet() async {
    final result = await showEventEditSheet(context, isVip: false);
    if (result == null) return;
    setState(() {
      _events.add(result);
      // 自动恢复：新建了已被删除分类时，立刻恢复对应筛选标签。
      _deletedFilterChips.remove(result.category);
      EventUsageService.updateCount(_events.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sidePadding = SizeConfig.contentGutter(context);
    final chips = _visibleChips();
    final cards = _sortedEvents();
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _exitChipEditMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(sidePadding, 8, sidePadding, 0),
                child: const Text(
                  '所有清单',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(sidePadding, 8, sidePadding, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ListFilterChip(
                        label: '全部',
                        selected: _activeFilter == null,
                        color: const Color(0xFF2563EB),
                        onTap: () {
                          setState(() => _activeFilter = null);
                          _exitChipEditMode();
                        },
                      ),
                      ...chips.map(
                        (chip) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _EditableListFilterChip(
                            label: _categoryLabel(chip),
                            selected: _activeFilter == chip,
                            color: _categoryColor(chip),
                            editing: _chipEditing,
                            shake: _chipShakeController,
                            onTap: () => setState(() => _activeFilter = chip),
                            onLongPress: _enterChipEditMode,
                            onDelete: () => _removeChip(chip),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: cards.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无事件',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          sidePadding,
                          2,
                          sidePadding,
                          94,
                        ),
                        itemCount: cards.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: math.max(10, width * 0.022)),
                        itemBuilder: (context, index) {
                          final event = cards[index];
                          return _ListEventCard(
                            event: event,
                            color: _categoryColor(event.category),
                            nextDate: _nextOccurrence(event),
                            weekdayTextBuilder: _weekdayZh,
                            onTogglePin: () => _togglePin(event.id),
                            slideActionsBuilder: (slidableContext) {
                              return [
                                _buildSlideAction(
                                  backgroundColor: _pinActionColor(event),
                                  icon: Icons.push_pin,
                                  label: event.isPinned ? '取消' : '置顶',
                                  roundRight: false,
                                  onTap: () => _onSlideAction(
                                    event,
                                    SwipeAction.onTogglePin,
                                    slidableContext,
                                  ),
                                ),
                                _buildSlideAction(
                                  backgroundColor: _shareActionColor(event),
                                  icon: Icons.share_outlined,
                                  label: '分享',
                                  roundRight: false,
                                  onTap: () => _onSlideAction(
                                    event,
                                    SwipeAction.onShare,
                                    slidableContext,
                                  ),
                                ),
                                _buildSlideAction(
                                  backgroundColor: const Color(0xFFF04444),
                                  icon: Icons.delete_outline,
                                  label: '删除',
                                  roundRight: true,
                                  onTap: () => _onSlideAction(
                                    event,
                                    SwipeAction.onDelete,
                                    slidableContext,
                                  ),
                                ),
                              ];
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListFilterChip extends StatelessWidget {
  const _ListFilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableListFilterChip extends StatelessWidget {
  const _EditableListFilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.editing,
    required this.shake,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  final String label;
  final bool selected;
  final Color color;
  final bool editing;
  final Animation<double> shake;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shake,
      builder: (context, child) {
        final angle = editing
            ? math.sin(shake.value * math.pi * 4) * 0.03
            : 0.0;
        return Transform.rotate(angle: angle, child: child);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: selected ? color.withValues(alpha: 0.14) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : const Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          if (editing)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 11, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListEventCard extends StatelessWidget {
  const _ListEventCard({
    required this.event,
    required this.color,
    required this.nextDate,
    required this.weekdayTextBuilder,
    required this.onTogglePin,
    required this.slideActionsBuilder,
  });

  final ListEvent event;
  final Color color;
  final DateTime nextDate;
  final String Function(int weekday) weekdayTextBuilder;
  final VoidCallback onTogglePin;
  final List<Widget> Function(BuildContext slidableContext) slideActionsBuilder;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final diff = DateTime(
      nextDate.year,
      nextDate.month,
      nextDate.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    final stateText = diff >= 0 ? '还有' : '已过';
    final dayText = '${diff.abs()}天';

    return LayoutBuilder(
      builder: (context, constraints) {
        final actionWidth = (constraints.maxWidth * 0.36).clamp(72.0, 112.0);
        final ratio = ((actionWidth * 3) / constraints.maxWidth).clamp(
          0.60,
          0.84,
        );
        return Slidable(
          key: ValueKey(event.id),
          closeOnScroll: true,
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: ratio,
            children: slideActionsBuilder(
              context,
            ).map((w) => SizedBox(width: actionWidth, child: w)).toList(),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    event.category == ListCategory.goal
                        ? Icons.gps_fixed
                        : event.category == ListCategory.idol
                        ? Icons.auto_awesome
                        : event.category == ListCategory.partner
                        ? Icons.favorite
                        : Icons.cake_outlined,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (event.isPinned)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.push_pin,
                                color: Colors.red,
                                size: 15,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}  周${weekdayTextBuilder(nextDate.weekday)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (event.isLunarRecurring) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '农历循环',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      stateText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      dayText,
                      style: TextStyle(
                        fontSize: 33 / 2,
                        color: diff >= 0 ? color : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: onTogglePin,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          event.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color: event.isPinned
                              ? Colors.red
                              : const Color(0xFF94A3B8),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
