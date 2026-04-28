import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lunar/lunar.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/pages/event_edit_page.dart';
import 'package:time_calendar/services/event_usage_service.dart';
import 'package:time_calendar/theme/app_theme.dart';

const _kListStarColor = Color(0xFFF59E0B);
const _kLunarTagBg = Color(0xFFEBF5FF);
const _kLunarTagFg = Color(0xFF1E40AF);

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  static const List<ListCategory> _chipCategories = [
    ListCategory.birthday,
    ListCategory.partner,
    ListCategory.goal,
    ListCategory.idol,
  ];

  /// 与日历页事件色一致
  static const Color _partnerAccent = Color(0xFFF43F5E);
  static const Color _birthdayAccent = Color(0xFFF97316);
  static const Color _goalAccent = Color(0xFF3B82F6);
  static const Color _idolAccent = Color(0xFFA855F7);

  static const List<BoxShadow> _cardShadows = [
    BoxShadow(
      color: Color(0x19000000),
      blurRadius: 2,
      offset: Offset(0, 1),
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x19000000),
      blurRadius: 3,
      offset: Offset(0, 1),
      spreadRadius: 0,
    ),
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
    ListEvent(
      id: 'exp1',
      title: '参加老同学聚会',
      baseDate: DateTime(2026, 4, 5),
      category: ListCategory.partner,
      isExpired: true,
    ),
    ListEvent(
      id: 'exp2',
      title: '提交年度报告',
      baseDate: DateTime(2026, 3, 31),
      category: ListCategory.goal,
      isExpired: true,
    ),
    ListEvent(
      id: 'exp3',
      title: '办理信用卡',
      baseDate: DateTime(2026, 4, 2),
      category: ListCategory.idol,
      isExpired: true,
    ),
    ListEvent(
      id: 'exp4',
      title: '爷爷生日',
      baseDate: DateTime(2026, 4, 10),
      category: ListCategory.birthday,
      isLunarRecurring: true,
      isExpired: true,
    ),
  ];

  ListCategory? _activeFilter;

  @override
  void initState() {
    super.initState();
    EventUsageService.updateCount(_events.length);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static Color _categoryAccent(ListCategory category) {
    switch (category) {
      case ListCategory.partner:
        return _partnerAccent;
      case ListCategory.birthday:
        return _birthdayAccent;
      case ListCategory.goal:
        return _goalAccent;
      case ListCategory.idol:
        return _idolAccent;
    }
  }

  static Color _categoryIconBg(ListCategory category) {
    switch (category) {
      case ListCategory.partner:
        return const Color(0xFFFCE7F3);
      case ListCategory.birthday:
        return const Color(0xFFFFEDD5);
      case ListCategory.goal:
        return const Color(0xFFDBEAFE);
      case ListCategory.idol:
        return const Color(0xFFF3E8FF);
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
    if (event.isExpired) {
      return _dateOnly(event.baseDate);
    }
    DateTime candidate = DateTime(
      today.year,
      event.baseDate.month,
      event.baseDate.day,
    );
    if (event.isLunarRecurring) {
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

  DateTime _displayDate(ListEvent event) {
    if (event.isExpired) {
      return _dateOnly(event.baseDate);
    }
    return _dateOnly(_nextOccurrence(event));
  }

  String _lunarLine(DateTime solarDate) {
    final lunar = Lunar.fromDate(solarDate);
    return '农历 ${lunar.getMonthInChinese()}${lunar.getDayInChinese()}';
  }

  /// 排序：置顶（含过期）最前 → 未过期按日期升序 → 已过期最后，按过期由近到远（近先）
  int _sortTier(ListEvent e, DateTime today) {
    if (e.isPinned) return 0;
    final d = _displayDate(e);
    if (!d.isBefore(today)) return 1;
    return 2;
  }

  List<ListEvent> _sortedEvents() {
    final today = _dateOnly(DateTime.now());
    final source = _events.where((e) {
      if (_activeFilter == null) return true;
      return e.category == _activeFilter;
    }).toList();

    source.sort((a, b) {
      final ta = _sortTier(a, today);
      final tb = _sortTier(b, today);
      if (ta != tb) return ta.compareTo(tb);
      final da = _displayDate(a);
      final db = _displayDate(b);
      if (ta == 2) return db.compareTo(da);
      if (ta == 0) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
      }
      return da.compareTo(db);
    });
    return source;
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
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
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
      EventUsageService.updateCount(_events.length);
    });
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
              right: 8,
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
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.search, size: 24, color: Colors.grey.shade600),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('搜索（占位）')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
      ],
    );
  }

  Widget _buildFilterChips() {
    final primary = Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _PillFilterChip(
            label: '全部',
            selected: _activeFilter == null,
            selectedColor: primary,
            onTap: () => setState(() => _activeFilter = null),
          ),
          ..._chipCategories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _PillFilterChip(
                label: _categoryLabel(c),
                selected: _activeFilter == c,
                selectedColor: primary,
                onTap: () => setState(() => _activeFilter = c),
              ),
            ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: _buildFilterChips(),
          ),
          const SizedBox(height: 12),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 94),
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = cards[index];
                      final displayDate = _displayDate(event);
                      final today = _dateOnly(DateTime.now());
                      final diff = _dateOnly(displayDate).difference(today).inDays;
                      final expired = diff < 0;
                      final accent = _categoryAccent(event.category);

                      return _ListEventCard(
                        event: event,
                        accent: accent,
                        iconBg: _categoryIconBg(event.category),
                        displayDate: displayDate,
                        daysDiff: diff,
                        expiredVisual: expired,
                        weekdayTextBuilder: _weekdayZh,
                        lunarLine: event.isLunarRecurring ? _lunarLine(displayDate) : null,
                        cardShadows: _cardShadows,
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
    return Material(
      color: selected ? selectedColor : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: selected ? null : Border.all(color: Colors.grey.shade300, width: 1),
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
    required this.weekdayTextBuilder,
    required this.lunarLine,
    required this.cardShadows,
    required this.onTogglePin,
    required this.slideActionsBuilder,
  });

  final ListEvent event;
  final Color accent;
  final Color iconBg;
  final DateTime displayDate;
  final int daysDiff;
  final bool expiredVisual;
  final String Function(int weekday) weekdayTextBuilder;
  final String? lunarLine;
  final List<BoxShadow> cardShadows;
  final VoidCallback onTogglePin;
  final List<Widget> Function(BuildContext slidableContext) slideActionsBuilder;

  static const Color _border = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final greyText = Color.lerp(Colors.grey.shade600, Colors.grey.shade700, 0.2)!;
    final titleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: expiredVisual ? greyText : const Color(0xFF0F172A),
      height: 1.25,
      letterSpacing: -0.31,
    );
    final dateStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: expiredVisual ? greyText : const Color(0xFF64748B),
      height: 1.2,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final actionWidth = (constraints.maxWidth * 0.36).clamp(72.0, 112.0);
        final ratio = ((actionWidth * 3) / constraints.maxWidth).clamp(0.60, 0.84);
        return Slidable(
          key: ValueKey(event.id),
          closeOnScroll: true,
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: ratio,
            children: slideActionsBuilder(context)
                .map((w) => SizedBox(width: actionWidth, child: w))
                .toList(),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: expiredVisual ? Colors.grey.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border, width: 0.75),
              boxShadow: cardShadows,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Opacity(
                  opacity: expiredVisual ? 0.5 : 1,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _categoryLeadingIcon(event.category, accent, expiredVisual),
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
                            const SizedBox(width: 4),
                            Icon(Icons.star, size: 16, color: _kListStarColor),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            '${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}-${displayDate.day.toString().padLeft(2, '0')} 周${weekdayTextBuilder(displayDate.weekday)}',
                            style: dateStyle,
                          ),
                          if (lunarLine != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kLunarTagBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lunarLine!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _kLunarTagFg,
                                  height: 1.2,
                                ),
                              ),
                            ),
                        ],
                      ),
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
        );
      },
    );
  }

  Widget _categoryLeadingIcon(ListCategory category, Color accent, bool expired) {
    final c = expired ? Colors.grey.shade600 : accent;
    switch (category) {
      case ListCategory.partner:
        return SvgPicture.asset(
          'assets/images/ic_couple_hearts.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
        );
      case ListCategory.birthday:
        return Icon(Icons.cake, color: c, size: 24);
      case ListCategory.goal:
        return Icon(Icons.track_changes, color: c, size: 24);
      case ListCategory.idol:
        return Icon(Icons.star, color: c, size: 24);
    }
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
    const labelStyle = TextStyle(
      fontSize: 12,
      color: Color(0xFF64748B),
      height: 1.0,
    );
    final greyAccent = Colors.grey.shade600;

    if (expired) {
      final n = daysDiff.abs();
      return SizedBox(
        width: 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('已过', style: labelStyle),
            const SizedBox(height: 2),
            Text(
              '-$n',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: greyAccent,
                height: 1.0,
              ),
            ),
            Text(
              '天',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: greyAccent.withValues(alpha: 0.8),
                height: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    final sub = accent.withValues(alpha: 0.8);
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('还有', style: labelStyle),
          const SizedBox(height: 2),
          Text(
            '${daysDiff.abs()}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: accent,
              height: 1.0,
            ),
          ),
          Text(
            '天',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: sub,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
