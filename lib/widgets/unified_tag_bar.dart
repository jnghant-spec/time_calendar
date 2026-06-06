import 'package:flutter/material.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/services/tag_bar_state.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/widgets/tag_circle_widget.dart';

/// 清单页 / 时光集页统一的标签筛选栏（不含标题、搜索或视图切换）。
class UnifiedTagBar extends StatelessWidget {
  const UnifiedTagBar({super.key, this.onManagePressed});

  final VoidCallback? onManagePressed;

  static const Color _pageBg = Color(0xFFFAFBFC);
  static const Color _divider = Color(0xFFF1F5F9);
  static const Color _mutedIcon = Color(0xFF94A3B8);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _allIdleBg = Color(0xFFE8F0FE);
  static const Color _labelIdle = Color(0xFF64748B);

  static const double _barHeight = 80;
  static const double _fixedSlotWidth = 56;
  static const double _circleSize = 48;
  static const double _tagItemWidth = 56;
  static const double _tagSpacing = 12;
  static const double _scrollInset =
      _fixedSlotWidth / 2 + _circleSize / 2 + _tagSpacing;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TagBarState(),
      builder: (context, child) {
        final state = TagBarState();
        final tags = List<ReminderTag>.from(state.tags)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final selectedId = state.selectedTagId;

        return Container(
          height: _barHeight,
          color: _pageBg,
          clipBehavior: Clip.none,
          child: Column(
            children: [
              const _BarDivider(),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.none,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: _scrollInset,
                            right: _scrollInset,
                          ),
                          child: Row(
                            children: [
                              for (var i = 0; i < tags.length; i++) ...[
                                if (i > 0) const SizedBox(width: _tagSpacing),
                                _TagItem(
                                  tag: tags[i],
                                  selected: selectedId == tags[i].id,
                                  onTap: () => state.selectTag(tags[i].id),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: _fixedSlotWidth,
                      child: Container(
                        color: _pageBg,
                        alignment: Alignment.center,
                        child: _AllTagItem(
                          selected: selectedId == null,
                          onTap: () => state.selectTag(null),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: _fixedSlotWidth,
                      child: Container(
                        color: _pageBg,
                        alignment: Alignment.center,
                        child: _ManageTagItem(
                          onPressed: onManagePressed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const _BarDivider(),
            ],
          ),
        );
      },
    );
  }
}

class _BarDivider extends StatelessWidget {
  const _BarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: UnifiedTagBar._divider);
  }
}

/// 2×2 方块网格（24px）。
class _AllGridIcon extends StatelessWidget {
  const _AllGridIcon({required this.cellColor});

  final Color cellColor;

  static const double _size = 24;
  static const double _cell = 10;

  @override
  Widget build(BuildContext context) {
    Widget cell() => Container(
          width: _cell,
          height: _cell,
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(2),
          ),
        );

    return SizedBox(
      width: _size,
      height: _size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [cell(), cell()],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [cell(), cell()],
          ),
        ],
      ),
    );
  }
}

class _AllTagItem extends StatelessWidget {
  const _AllTagItem({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: UnifiedTagBar._circleSize,
      height: UnifiedTagBar._circleSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? UnifiedTagBar._themeBlue : UnifiedTagBar._allIdleBg,
        boxShadow: selected
            ? [
                BoxShadow(
                  blurRadius: 2,
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: _AllGridIcon(
        cellColor: selected ? Colors.white : UnifiedTagBar._themeBlue,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScaledCircle(selected: selected, child: circle),
          const SizedBox(height: 4),
          const Text(
            '全部',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: UnifiedTagBar._themeBlue,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagItem extends StatelessWidget {
  const _TagItem({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final ReminderTag tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = TagCircleWidget.themeColorOrDefault(tag.accentColor);
    final circle = Container(
      width: UnifiedTagBar._circleSize,
      height: UnifiedTagBar._circleSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tag.iconBgColor,
        boxShadow: selected
            ? [
                BoxShadow(
                  blurRadius: 2,
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: TagIconHelper.build(
        tagId: tag.id,
        color: accent,
        size: UnifiedTagBar._circleSize,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: UnifiedTagBar._tagItemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ScaledCircle(selected: selected, child: circle),
            const SizedBox(height: 4),
            Text(
              TagService.displayTagName(tag.name),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? accent : UnifiedTagBar._labelIdle,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaledCircle extends StatelessWidget {
  const _ScaledCircle({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: child,
    );
  }
}

class _ManageTagItem extends StatelessWidget {
  const _ManageTagItem({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: UnifiedTagBar._circleSize,
      height: UnifiedTagBar._circleSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: UnifiedTagBar._divider,
      ),
      child: const Icon(
        Icons.settings_outlined,
        size: 24,
        color: UnifiedTagBar._mutedIcon,
      ),
    );

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          const SizedBox(height: 4),
          const Text(
            '管理',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: UnifiedTagBar._labelIdle,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
