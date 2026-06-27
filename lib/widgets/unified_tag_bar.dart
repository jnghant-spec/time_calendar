import 'package:flutter/material.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/services/tag_bar_state.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/widgets/tag_circle_widget.dart';

/// 清单页 / 时光集页统一的标签筛选栏（不含标题、搜索或视图切换）。
class UnifiedTagBar extends StatelessWidget {
  const UnifiedTagBar({
    super.key,
    this.onManagePressed,
    this.horizontalPadding = 0,
  });

  final VoidCallback? onManagePressed;
  final double horizontalPadding;

  static const Color _pageBg = Color(0xFFFAFBFC);
  static const Color _divider = Color(0xFFF1F5F9);
  static const Color _allAccent = Color(0xFF5C9CE6);
  static const Color _allAccentSelected = Color(0xFF4A85D6);
  static const Color _allIdleBg = Color(0xFFEAF3FF);
  static const Color _allSelectedBg = Color(0xFFDBEAFE);
  static const Color _manageIdleBg = Color(0xFFF8FAFC);
  static const Color _manageBorder = Color(0xFFE2E8F0);
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
        final allTags = List<ReminderTag>.from(state.tags)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        final sharedIncomingId = TagService.sharedIncomingTagId;
        ReminderTag? sharedIncomingTag;
        final userTags = <ReminderTag>[];
        for (final tag in allTags) {
          if (tag.id == sharedIncomingId) {
            sharedIncomingTag = tag;
          } else {
            userTags.add(tag);
          }
        }

        final sharedCount =
            TagService.reminderCountForTag?.call(sharedIncomingId) ?? 0;
        final tags = <ReminderTag>[...userTags];
        if (sharedCount > 0 && sharedIncomingTag != null) {
          tags.insert(0, sharedIncomingTag);
        }

        final selectedId = state.selectedTagId;

        return Container(
          height: _barHeight,
          color: _pageBg,
          clipBehavior: Clip.none,
          child: Column(
            children: [
              const _BarDivider(),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        right: _fixedSlotWidth,
                        child: ClipRect(
                          clipBehavior: Clip.hardEdge,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            clipBehavior: Clip.hardEdge,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: _scrollInset,
                                right: _scrollInset,
                              ),
                              child: Row(
                                children: [
                                  for (var i = 0; i < tags.length; i++) ...[
                                    if (i > 0)
                                      const SizedBox(width: _tagSpacing),
                                    _TagItem(
                                      tag: tags[i],
                                      selected: selectedId == tags[i].id,
                                      badgeCount: tags[i].id == sharedIncomingId
                                          ? sharedCount
                                          : null,
                                      onTap: () => state.selectTag(tags[i].id),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: _fixedSlotWidth,
                        child: ColoredBox(
                          color: _pageBg,
                          child: Align(
                            alignment: Alignment.center,
                            child: _AllTagItem(
                              selected: selectedId == null,
                              onTap: () => state.selectTag(null),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: _fixedSlotWidth,
                        child: ColoredBox(
                          color: _pageBg,
                          child: Align(
                            alignment: Alignment.center,
                            child: _ManageTagItem(
                              onPressed: onManagePressed,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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

class _AllTagItem extends StatelessWidget {
  const _AllTagItem({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected
        ? UnifiedTagBar._allAccentSelected
        : UnifiedTagBar._allAccent;
    final circle = Container(
      width: UnifiedTagBar._circleSize,
      height: UnifiedTagBar._circleSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? UnifiedTagBar._allSelectedBg : UnifiedTagBar._allIdleBg,
        boxShadow: selected
            ? [
                BoxShadow(
                  blurRadius: 2,
                  color: UnifiedTagBar._allAccentSelected.withValues(alpha: 0.15),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Icon(
        Icons.format_list_bulleted_rounded,
        size: 22,
        color: accent,
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
          Text(
            '全部',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: accent,
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
    this.badgeCount,
  });

  final ReminderTag tag;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

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
            Stack(
              clipBehavior: Clip.none,
              children: [
                _ScaledCircle(selected: selected, child: circle),
                if (badgeCount != null && badgeCount! > 0)
                  Positioned(
                    top: -2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount! > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: UnifiedTagBar._manageIdleBg,
        border: Border.all(
          color: UnifiedTagBar._manageBorder,
          width: 1,
        ),
      ),
      child: const Icon(
        Icons.settings_outlined,
        size: 20,
        color: UnifiedTagBar._labelIdle,
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
