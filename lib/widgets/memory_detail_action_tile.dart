import 'package:flutter/material.dart';

/// 详情页操作按钮设计 token。
abstract final class MemoryDetailActionTokens {
  static const double actionTileSize = 40;
  static const double actionTileRadius = 8;
  static const double primaryCtaRadius = 16;
  static const Color actionSecondaryBg = Color(0xFFF1F5F9);
  static const Color actionSecondaryIcon = Color(0xFF64748B);
  static const Color actionActiveBg = Color(0xFF1A73E8);
  static const Color actionActiveIcon = Color(0xFFFFFFFF);
  static const Color actionDestructiveIcon = Color(0xFFEF4444);
  static const double actionSpacing = 8;
  static const Color actionBorder = Color(0xFFE2E8F0);
  static const double viewSegmentMinWidth = 60;
  static const double headerActionRowWidth =
      actionTileSize * 2 + actionSpacing;
}

enum MemoryDetailIconTileVariant { secondary, destructive, active }

/// 详情页统一 icon 操作块（40×40，r8）。
class MemoryDetailIconTile extends StatelessWidget {
  const MemoryDetailIconTile({
    super.key,
    required this.icon,
    required this.onTap,
    this.variant = MemoryDetailIconTileVariant.secondary,
    this.semanticsLabel,
    this.showBorder = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final MemoryDetailIconTileVariant variant;
  final String? semanticsLabel;
  final bool showBorder;

  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final opacity = enabled ? 1.0 : 0.35;

    Color background;
    Color iconColor;
    switch (variant) {
      case MemoryDetailIconTileVariant.secondary:
        background = MemoryDetailActionTokens.actionSecondaryBg;
        iconColor = MemoryDetailActionTokens.actionSecondaryIcon;
      case MemoryDetailIconTileVariant.destructive:
        background = MemoryDetailActionTokens.actionSecondaryBg;
        iconColor = MemoryDetailActionTokens.actionDestructiveIcon;
      case MemoryDetailIconTileVariant.active:
        background = MemoryDetailActionTokens.actionActiveBg;
        iconColor = MemoryDetailActionTokens.actionActiveIcon;
    }

    Widget tile = Container(
      width: MemoryDetailActionTokens.actionTileSize,
      height: MemoryDetailActionTokens.actionTileSize,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MemoryDetailActionTokens.actionTileRadius),
        border: showBorder
            ? Border.all(color: MemoryDetailActionTokens.actionBorder)
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: _iconSize,
        color: iconColor.withValues(alpha: opacity),
      ),
    );

    if (!enabled) {
      tile = Opacity(opacity: opacity, child: tile);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: tile,
      ),
    );
  }
}

/// 竖向 / 横向视图连体分段切换。
class MemoryDetailViewSegmentedControl extends StatelessWidget {
  const MemoryDetailViewSegmentedControl({
    super.key,
    required this.isListViewActive,
    required this.onSwitchToList,
    required this.onSwitchToGrid,
  });

  final bool isListViewActive;
  final VoidCallback onSwitchToList;
  final VoidCallback onSwitchToGrid;

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(MemoryDetailActionTokens.actionTileRadius);

    return Container(
      height: MemoryDetailActionTokens.actionTileSize,
      decoration: BoxDecoration(
        color: MemoryDetailActionTokens.actionSecondaryBg,
        borderRadius: BorderRadius.all(radius),
        border: Border.all(color: MemoryDetailActionTokens.actionBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            icon: Icons.view_timeline_outlined,
            label: '时间线',
            semanticsLabel: '时间线视图',
            isActive: isListViewActive,
            onTap: onSwitchToList,
            borderRadius: BorderRadius.only(topLeft: radius, bottomLeft: radius),
          ),
          Container(
            width: 1,
            height: MemoryDetailActionTokens.actionTileSize,
            color: MemoryDetailActionTokens.actionBorder,
          ),
          _segment(
            icon: Icons.view_carousel_outlined,
            label: '卡片',
            semanticsLabel: '卡片视图',
            isActive: !isListViewActive,
            onTap: onSwitchToGrid,
            borderRadius: BorderRadius.only(topRight: radius, bottomRight: radius),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required IconData icon,
    required String label,
    required String semanticsLabel,
    required bool isActive,
    required VoidCallback onTap,
    required BorderRadius borderRadius,
  }) {
    final fg = isActive
        ? MemoryDetailActionTokens.actionActiveIcon
        : MemoryDetailActionTokens.actionSecondaryIcon;

    return Semantics(
      button: true,
      selected: isActive,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: MemoryDetailActionTokens.viewSegmentMinWidth,
          ),
          height: MemoryDetailActionTokens.actionTileSize,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? MemoryDetailActionTokens.actionActiveBg
                : MemoryDetailActionTokens.actionSecondaryBg,
            borderRadius: borderRadius,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fg,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 详情页底部主操作「添加事件」。
class MemoryDetailPrimaryCta extends StatelessWidget {
  const MemoryDetailPrimaryCta({
    super.key,
    required this.onTap,
    this.label = '添加事件',
  });

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MemoryDetailActionTokens.actionActiveBg,
      elevation: 2,
      shadowColor: MemoryDetailActionTokens.actionActiveBg.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(MemoryDetailActionTokens.primaryCtaRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MemoryDetailActionTokens.primaryCtaRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 20, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
