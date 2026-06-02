import 'dart:io';

import 'package:flutter/material.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/services/tag_service.dart';

/// 预设系统图标（[ReminderTag.iconName] 存储 key）。
class TagPresetIcons {
  TagPresetIcons._();

  static const List<MapEntry<String, IconData>> entries = [
    MapEntry('star', Icons.star),
    MapEntry('favorite', Icons.favorite),
    MapEntry('home', Icons.home),
    MapEntry('work', Icons.work),
    MapEntry('celebration', Icons.celebration),
    MapEntry('school', Icons.school),
    MapEntry('flight', Icons.flight),
    MapEntry('pets', Icons.pets),
    MapEntry('sports', Icons.sports),
    MapEntry('music_note', Icons.music_note),
  ];

  static IconData? dataFor(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final e in entries) {
      if (e.key == name) return e.value;
    }
    return null;
  }
}

/// 全应用统一的圆形标签图标（照片 > 图标 > 纯色；名称在圆形下方）。
class TagCircleWidget extends StatelessWidget {
  const TagCircleWidget({
    super.key,
    required this.tag,
    this.isSelected = false,
    this.size = 48.0,
    this.onTap,
    this.showLabel = true,
    this.labelFontSize = 12.0,
    this.twoLineLabel = false,
    this.brandBlueSelectedLabel = false,
    this.showSelectionRing = false,
  });

  final ReminderTag tag;
  final bool isSelected;
  final double size;
  final VoidCallback? onTap;
  final bool showLabel;
  final double labelFontSize;
  /// 时光集等：标签名最多两行居中换行。
  final bool twoLineLabel;
  /// 选中时标签文字用主题蓝，而非标签主题色。
  final bool brandBlueSelectedLabel;
  /// 选中时圆形头像外圈 2px 主题蓝描边。
  final bool showSelectionRing;

  static const Color _idleBorder = Color(0xFFE2E8F0);
  static const Color _allIdleBg = Color(0xFFF8FAFC);
  static const Color _allUnselectedBg = Color(0xFFDBEAFE);
  static const Color _allUnselectedBorder = Color(0xFF93C5FD);
  static const Color _allUnselectedLabel = Color(0xFF2563EB);
  static const Color _labelColor = Color(0xFF64748B);
  static const Color _inactiveFilterLabel = Color(0xFF666666);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _pillMutedBg = Color(0xFFF1F5F9);
  static const Color _pillMutedText = Color(0xFF94A3B8);

  static const double itemHeight = 80.0;
  static const double barHeight = 80.0;
  /// 两行标签名时的筛选栏总高（52 + 6 + 28 + 8 = 94，留 6px 安全边距）。
  static const double memoryFilterBarHeight = 100.0;
  static const double memoryFilterItemWidth = 56.0;
  static const double _circleSize = 48.0;
  static const double _circleSlotHeight = 52.0;
  static const double _labelGap = 6.0;
  static const double _labelLineHeight = 14.0;
  static const double _bottomSafe = 8.0;
  static const double _tonalAlpha = 0.18;
  static const Color kDefaultTagColor = Color(0xFF9CA3AF);

  static String get defaultIconKey => TagPresetIcons.entries.first.key;

  static IconData get defaultIconData =>
      TagPresetIcons.entries.first.value;
  static const Color kPageBackground = Color(0xFFFAFBFC);
  static const double kFixedTagSlotWidth = 72.0;

  /// 全 App 统一柔和主题色板（7 色）；无主题色见 [kTagNoThemeIndex]。
  static const List<Color> kTagPresetColors = [
    Color(0xFFFF7A7A),
    Color(0xFFFF9F68),
    Color(0xFFFFCC5C),
    Color(0xFF4DCC99),
    Color(0xFF5C9CE6),
    Color(0xFF7B88FF),
    Color(0xFFFF99C2),
  ];

  /// 色板第 8 项：无主题色（`accentColor == null`）。
  static const int kTagNoThemeIndex = 7;

  /// 解析标签主题色（`null` → 默认灰）。
  static Color themeColorOrDefault(Color? color) => color ?? kDefaultTagColor;

  static List<BoxShadow> _circleShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.15),
          blurRadius: 2,
          spreadRadius: 0,
          offset: const Offset(0, 1),
        ),
      ];

  static String displayInitials(String name) {
    if (name.isEmpty) return '';
    final trimmed = name.trim();
    return trimmed.length > 4 ? trimmed.substring(0, 4) : trimmed;
  }

  /// 事件集卡片彩色底白字 Pill。
  static Widget cardTagPill({ReminderTag? tag, String? tagId}) {
    final resolved = tag ?? (tagId != null ? TagService.getTagById(tagId) : null);
    final isUncategorized = resolved == null ||
        tagId == null ||
        tagId.isEmpty ||
        tagId == TagService.uncategorizedTagId;

    Widget pillContent;
    if (isUncategorized) {
      pillContent = Text(
        '未分类',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _pillMutedText,
          height: 1.0,
        ),
      );
    } else {
      pillContent = Text(
        resolved.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          height: 1.0,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 24,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isUncategorized
                ? _pillMutedBg
                : themeColorOrDefault(resolved.accentColor)
                    .withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: pillContent,
        ),
      ],
    );
  }

  /// 「全部」筛选器（固定左侧区域使用）。
  static Widget allFilterChip({
    required bool selected,
    required VoidCallback? onTap,
    bool memoryStyle = false,
  }) {
    final Widget circle;
    if (memoryStyle) {
      circle = Container(
        width: _circleSize,
        height: _circleSize,
        decoration: BoxDecoration(
          color: _allIdleBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? _themeBlue : _idleBorder,
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.grid_view_rounded,
          size: 22,
          color: selected ? _themeBlue : _inactiveFilterLabel,
        ),
      );
    } else {
      circle = Container(
        width: _circleSize,
        height: _circleSize,
        decoration: BoxDecoration(
          color: selected ? _themeBlue : _allUnselectedBg,
          shape: BoxShape.circle,
          border: selected
              ? null
              : Border.all(color: _allUnselectedBorder, width: 1),
          boxShadow: selected ? _circleShadow(_themeBlue) : null,
        ),
      );
    }
    final twoLine = memoryStyle;
    return _TagItemShell(
      isSelected: selected,
      onTap: onTap,
      circle: circle,
      itemWidth: memoryStyle ? memoryFilterItemWidth : null,
      barItemHeight: memoryStyle ? memoryFilterBarHeight : null,
      label: Text(
        '全部',
        textAlign: TextAlign.center,
        maxLines: twoLine ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: selected
              ? _themeBlue
              : (memoryStyle ? _inactiveFilterLabel : _allUnselectedLabel),
          height: twoLine ? 1.15 : _labelLineHeight / 12,
        ),
      ),
    );
  }

  /// 标签栏右侧固定操作项（48px 圆 + 下方文字，与筛选标签一致）。
  static Widget scrollActionPill({
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
    double? barItemHeight,
    double? itemWidth,
  }) {
    final iconData = icon ??
        (label == '管理' ? Icons.settings_outlined : Icons.add);
    final circle = Container(
      width: _circleSize,
      height: _circleSize,
      decoration: BoxDecoration(
        color: _allIdleBg,
        shape: BoxShape.circle,
        border: Border.all(color: _idleBorder, width: 1),
      ),
      alignment: Alignment.center,
      child: Icon(iconData, size: 20, color: _labelColor),
    );
    return _TagItemShell(
      isSelected: false,
      onTap: onTap,
      circle: circle,
      itemWidth: itemWidth,
      barItemHeight: barItemHeight,
      label: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: barItemHeight != null ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: barItemHeight != null ? _inactiveFilterLabel : _labelColor,
          height: barItemHeight != null ? 1.15 : _labelLineHeight / 12,
        ),
      ),
    );
  }

  /// 左侧固定「全部」+ 中间滚动 + 右侧固定操作（Stack 遮罩防覆盖）。
  static Widget partitionedFilterBar({
    required Widget allChip,
    required List<Widget> scrollChildren,
    Widget? trailingPill,
    double height = barHeight,
  }) {
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                left: kFixedTagSlotWidth,
                right: kFixedTagSlotWidth,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < scrollChildren.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    scrollChildren[i],
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: kFixedTagSlotWidth,
              height: height,
              color: kPageBackground,
              alignment: Alignment.center,
              child: allChip,
            ),
          ),
          if (trailingPill != null)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: kFixedTagSlotWidth,
                height: height,
                color: kPageBackground,
                alignment: Alignment.center,
                child: trailingPill,
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasPhoto {
    final path = tag.photoPath;
    return path != null && path.isNotEmpty && File(path).existsSync();
  }

  IconData? get _presetIcon => TagPresetIcons.dataFor(tag.iconName);

  Color get _resolvedTheme => themeColorOrDefault(tag.accentColor);

  Widget _tonalCircle({required Widget center, List<BoxShadow>? shadow}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _resolvedTheme.withValues(alpha: _tonalAlpha),
        shape: BoxShape.circle,
        border: Border.all(color: _idleBorder, width: 1),
        boxShadow: shadow,
      ),
      alignment: Alignment.center,
      child: center,
    );
  }

  Widget _wrapSelectionRing(Widget inner, {List<BoxShadow>? shadow}) {
    if (!showSelectionRing || !isSelected) {
      return inner;
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          inner,
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _themeBlue, width: 2.5),
                boxShadow: shadow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircle() {
    final shadow =
        isSelected && !showSelectionRing ? _circleShadow(_resolvedTheme) : null;

    if (_hasPhoto) {
      final photo = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: showSelectionRing && isSelected ? Colors.transparent : _idleBorder,
            width: 1,
          ),
          boxShadow: shadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          File(tag.photoPath!),
          fit: BoxFit.cover,
          width: size,
          height: size,
        ),
      );
      return _wrapSelectionRing(photo, shadow: shadow);
    }
    final icon = _presetIcon ?? defaultIconData;
    return _wrapSelectionRing(
      _tonalCircle(
        shadow: shadow,
        center: Icon(icon, size: 24, color: _resolvedTheme),
      ),
      shadow: shadow,
    );
  }

  /// 编辑弹窗 80px 预览圆（照片优先，否则图标 Tonal）。
  static Widget buildEditorPreview({
    required double size,
    Color? themeColor,
    String? photoPath,
    String? iconName,
  }) {
    final resolved = themeColorOrDefault(themeColor);
    final hasPhoto = photoPath != null &&
        photoPath.isNotEmpty &&
        File(photoPath).existsSync();
    if (hasPhoto) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _idleBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          File(photoPath),
          fit: BoxFit.cover,
          width: size,
          height: size,
        ),
      );
    }
    final icon = TagPresetIcons.dataFor(iconName) ?? defaultIconData;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: _tonalAlpha),
        shape: BoxShape.circle,
        border: Border.all(color: _idleBorder, width: 1),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 40, color: resolved),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = tag.name;

    if (!showLabel) {
      return _TagItemShell(
        isSelected: isSelected,
        onTap: onTap,
        circle: _buildCircle(),
        compactSize: size,
      );
    }

    final selectedLabelColor = brandBlueSelectedLabel && isSelected
        ? _themeBlue
        : (isSelected ? themeColorOrDefault(tag.accentColor) : _labelColor);
    final inactiveColor =
        brandBlueSelectedLabel ? _inactiveFilterLabel : _labelColor;

    return _TagItemShell(
      isSelected: isSelected,
      onTap: onTap,
      circle: _buildCircle(),
      itemWidth: twoLineLabel ? memoryFilterItemWidth : null,
      barItemHeight: twoLineLabel ? memoryFilterBarHeight : null,
      label: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: twoLineLabel ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: labelFontSize,
          fontWeight: FontWeight.w500,
          color: isSelected ? selectedLabelColor : inactiveColor,
          height: twoLineLabel ? 1.15 : _labelLineHeight / labelFontSize,
        ),
      ),
    );
  }
}

class _TagItemShell extends StatelessWidget {
  const _TagItemShell({
    required this.isSelected,
    required this.circle,
    this.onTap,
    this.label,
    this.compactSize,
    this.itemWidth,
    this.barItemHeight,
  });

  final bool isSelected;
  final Widget circle;
  final VoidCallback? onTap;
  final Widget? label;
  final double? compactSize;
  final double? itemWidth;
  final double? barItemHeight;

  @override
  Widget build(BuildContext context) {
    final scaledCircle = SizedBox(
      width: TagCircleWidget._circleSize,
      height: TagCircleWidget._circleSize,
      child: Center(
        child: Transform.scale(
          scale: isSelected ? 1.05 : 1.0,
          alignment: Alignment.center,
          child: circle,
        ),
      ),
    );

    Widget body;
    if (compactSize != null) {
      body = SizedBox(
        width: compactSize,
        height: compactSize,
        child: Center(child: scaledCircle),
      );
    } else {
      final w = itemWidth ?? 56.0;
      final h = barItemHeight ?? TagCircleWidget.itemHeight;
      body = SizedBox(
        width: w,
        height: h,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: TagCircleWidget._circleSlotHeight,
              child: Center(child: scaledCircle),
            ),
            if (label != null) ...[
              const SizedBox(height: TagCircleWidget._labelGap),
              SizedBox(width: w, child: label),
              const SizedBox(height: TagCircleWidget._bottomSafe),
            ],
          ],
        ),
      );
    }

    if (onTap != null) {
      body = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: body,
      );
    }

    return body;
  }
}
