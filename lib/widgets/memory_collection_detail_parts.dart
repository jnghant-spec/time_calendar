import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/models/partner_relation.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/widgets/tag_circle_widget.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/utils/partner_share_detail_ui.dart';
import 'package:time_calendar/widgets/memory_detail_action_tile.dart';

/// 时光集详情页设计 token（顶部元信息、横滑卡片、标题栏按钮）。
class MemoryDetailDesignTokens {
  MemoryDetailDesignTokens._();

  static const double metaFontSize = 12;
  static const Color metaColor = Color(0xFF9CA3AF);
  static const double metaLineHeight = 20;

  static const double cardViewportFraction = 0.72;
  static const double cardAspectWidth = 4;
  static const double cardAspectHeight = 5;
  static const double cardMaxHeightFactor = 0.45;
  static const double cardMinHeight = 240;

  static const double actionTileSize = MemoryDetailActionTokens.actionTileSize;
  static const double actionTileRadius = MemoryDetailActionTokens.actionTileRadius;
  static const double primaryCtaRadius = MemoryDetailActionTokens.primaryCtaRadius;
  static const Color actionSecondaryBg = MemoryDetailActionTokens.actionSecondaryBg;
  static const Color actionSecondaryIcon = MemoryDetailActionTokens.actionSecondaryIcon;
  static const Color actionActiveBg = MemoryDetailActionTokens.actionActiveBg;
  static const Color actionActiveIcon = MemoryDetailActionTokens.actionActiveIcon;
  static const Color actionDestructiveIcon = MemoryDetailActionTokens.actionDestructiveIcon;
  static const double actionSpacing = MemoryDetailActionTokens.actionSpacing;
  static const Color actionBorder = MemoryDetailActionTokens.actionBorder;
  static const double headerActionRowWidth =
      MemoryDetailActionTokens.headerActionRowWidth;

  static TextStyle get metaTextStyle => const TextStyle(
        fontSize: metaFontSize,
        color: metaColor,
        height: metaLineHeight / metaFontSize,
      );

  /// 横滑子事件卡片高度：4:5 比例，上限屏高 45%，下限 240。
  static double computeCardPhotoHeight(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final photoWidth = screenWidth * cardViewportFraction;
    final aspectHeight = photoWidth * cardAspectHeight / cardAspectWidth;
    final maxHeight = screenHeight * cardMaxHeightFactor;
    return aspectHeight.clamp(cardMinHeight, maxHeight);
  }
}

/// 时光集详情弹窗（横向/纵向）共用顶部区块。
class MemoryCollectionDetailHeader extends StatelessWidget {
  const MemoryCollectionDetailHeader({
    super.key,
    required this.collection,
    required this.events,
    required this.isListViewActive,
    required this.onShare,
    required this.onEditCollection,
    required this.onSwitchToList,
    required this.onSwitchToGrid,
  });

  final MemoryCollection collection;
  final List<MemoryEvent> events;
  final bool isListViewActive;
  final VoidCallback onShare;
  final VoidCallback onEditCollection;
  final VoidCallback onSwitchToList;
  final VoidCallback onSwitchToGrid;

  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);

  String _rangeLine() {
    if (events.isEmpty) return '暂无事件';
    return '${formatYearMonthDot(events.first.date)} - ${formatYearMonthDot(events.last.date)}';
  }

  Widget _tagMetaPill(ReminderTag tag) {
    final accent = TagCircleWidget.themeColorOrDefault(tag.accentColor);
    final icon = TagPresetIcons.dataFor(tag.iconName) ??
        TagCircleWidget.defaultIconData;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tag.iconBgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 4),
          Text(
            tag.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: accent,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagAndStatsRow(int photoCount) {
    final tag = TagService.getTagById(collection.tagId);
    const statsStyle = TextStyle(
      fontSize: 14,
      color: Color(0xFF64748B),
      height: 1.2,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (tag != null) ...[
          _tagMetaPill(tag),
          const SizedBox(width: 8),
        ],
        Text(
          '共 ${events.length} 个事件 · $photoCount 张照片',
          style: statsStyle,
        ),
      ],
    );
  }

  bool _hasHistoricalCollectionPartnerShare() {
    if (TagService.shouldShowPartnerShareMarker(collection.tagId)) {
      return false;
    }
    if (!TagService.isPartnerTag(collection.tagId)) return false;
    return TagService.getPartnerRelation().status != PartnerStatus.accepted;
  }

  String? _resolveHistoricalPartnerName() {
    final modified = collection.lastModifiedByName?.trim();
    if (modified != null && modified.isNotEmpty) return modified;
    final relation = TagService.getPartnerRelation();
    final name = relation.partnerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  PartnerShareDetailInfo _partnerShareInfo() {
    if (TagService.shouldShowPartnerShareMarker(collection.tagId)) {
      final name = TagService.getPartnerRelation().partnerName?.trim();
      final displayName =
          name == null || name.isEmpty ? '另一半' : name;
      final autoSync = UserSession.instance.autoShareEnabled;
      final text = autoSync
          ? '已与 $displayName 绑定（实时同步）'
          : '已与 $displayName 绑定（修改仅自己可见）';
      return PartnerShareDetailInfo(
        mode: PartnerShareDetailMode.active,
        partnerName: displayName,
        statusText: text,
      );
    }
    if (_hasHistoricalCollectionPartnerShare()) {
      final name = _resolveHistoricalPartnerName();
      final displayName =
          name == null || name.isEmpty ? '另一半' : name;
      return PartnerShareDetailInfo(
        mode: PartnerShareDetailMode.historical,
        partnerName: displayName,
        statusText: '曾与 $displayName 共享',
      );
    }
    return const PartnerShareDetailInfo(mode: PartnerShareDetailMode.none);
  }

  static TextStyle get _metaHintStyle => MemoryDetailDesignTokens.metaTextStyle;

  String? _collectionModifiedLabel() {
    final at = collection.lastModifiedAt;
    if (at == null) return null;

    final currentPhone = UserSession.instance.phone.trim();
    final modifierPhone = collection.lastModifiedByPhone?.trim();
    final String displayName;
    if (modifierPhone != null &&
        modifierPhone.isNotEmpty &&
        modifierPhone == currentPhone) {
      displayName = '我';
    } else {
      final partnerName =
          TagService.getPartnerRelation().partnerName?.trim();
      if (partnerName != null && partnerName.isNotEmpty) {
        displayName = partnerName;
      } else {
        final fallback = collection.lastModifiedByName?.trim();
        if (fallback == null || fallback.isEmpty) return null;
        displayName = fallback;
      }
    }

    return '最新修改：$displayName ${formatPartnerModifiedAt(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final photoCount = MemoryService.countPhotosInCollection(events);
    final partnerShareInfo = _partnerShareInfo();
    final modifiedLabel = _collectionModifiedLabel();
    final showPartnerMeta = partnerShareInfo.mode != PartnerShareDetailMode.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: MemoryDetailDesignTokens.headerActionRowWidth),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          collection.name.isNotEmpty
                              ? collection.name
                              : '未命名时光集',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _titleColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      buildPartnerShareTitleMarker(partnerShareInfo),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: MemoryDetailDesignTokens.headerActionRowWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MemoryDetailIconTile(
                      icon: Icons.share_outlined,
                      onTap: onShare,
                      semanticsLabel: '分享时光集',
                    ),
                    const SizedBox(width: MemoryDetailDesignTokens.actionSpacing),
                    MemoryDetailIconTile(
                      icon: Icons.edit_outlined,
                      onTap: onEditCollection,
                      semanticsLabel: '编辑时光集',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _rangeLine(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
        if (showPartnerMeta || modifiedLabel != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showPartnerMeta)
                  Center(
                    child: buildPartnerShareStatusRow(
                      partnerShareInfo,
                      textStyle: _metaHintStyle,
                    ),
                  ),
                if (showPartnerMeta && modifiedLabel != null)
                  const SizedBox(height: 4),
                if (modifiedLabel != null)
                  Text(
                    modifiedLabel,
                    textAlign: TextAlign.center,
                    style: _metaHintStyle,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Center(child: _tagAndStatsRow(photoCount)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '事件时间线',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _titleColor,
                ),
              ),
              MemoryDetailViewSegmentedControl(
                isListViewActive: isListViewActive,
                onSwitchToList: onSwitchToList,
                onSwitchToGrid: onSwitchToGrid,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 封面图上的磨砂玻璃圆形按钮。
class MemoryGlassIconButton extends StatelessWidget {
  const MemoryGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 时间线节点：主题蓝圆点 + 可选向下细线（与详情列表一致）。
class MemoryTimelineRailMarker extends StatelessWidget {
  const MemoryTimelineRailMarker({super.key, this.showLineBelow = true});

  final bool showLineBelow;

  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _lineColor = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: _themeBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          if (showLineBelow)
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 2,
                  color: _lineColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 时间线地点元数据：浅灰胶囊底，提升可读性。
class MemoryLocationCapsule extends StatelessWidget {
  const MemoryLocationCapsule({super.key, required this.location});

  final String location;

  static const Color _bg = Color(0xFFF5F5F7);
  static const Color _fg = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place_outlined, size: 12, color: _fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _fg,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 详情页底部磨砂工具栏（添加居中，两侧编辑/删除）。
class MemoryDetailBottomToolbar extends StatelessWidget {
  const MemoryDetailBottomToolbar({
    super.key,
    required this.onAdd,
    this.onEdit,
    this.onDelete,
  });

  final VoidCallback onAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static const double barHeight = 56;

  static double totalHeight(BuildContext context) =>
      barHeight + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final tileSize = MemoryDetailActionTokens.actionTileSize;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: barHeight + bottom,
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            border: Border(
              top: BorderSide(
                color: MemoryDetailActionTokens.actionBorder.withValues(alpha: 0.8),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: tileSize,
                child: Center(
                  child: MemoryDetailIconTile(
                    icon: Icons.edit_outlined,
                    onTap: onEdit,
                    semanticsLabel: '编辑当前事件',
                    showBorder: true,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: MemoryDetailPrimaryCta(onTap: onAdd),
                ),
              ),
              SizedBox(
                width: tileSize,
                child: Center(
                  child: MemoryDetailIconTile(
                    icon: Icons.delete_outline,
                    onTap: onDelete,
                    variant: MemoryDetailIconTileVariant.destructive,
                    semanticsLabel: '删除当前事件',
                    showBorder: true,
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
