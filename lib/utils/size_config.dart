import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 响应式布局与字号：统一基于 [MediaQuery.sizeOf]，避免散落固定像素与魔法数。
abstract final class SizeConfig {
  SizeConfig._();

  /// 设计稿参考宽度（用于 [sp] 缩放）。
  static const double designWidth = 390;

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// 水平主边距 ≈ 屏宽 5%（随屏幕缩放）。
  static double horizontalMargin(BuildContext context) =>
      screenWidth(context) * 0.05;

  /// 表单 / 主内容区宽度 ≈ 屏宽 88%。
  static double formWidth(BuildContext context) =>
      screenWidth(context) * 0.88;

  /// 列表、卡片区域水平留白（略大于 [horizontalMargin]，偏 Apple 留白）。
  static double contentGutter(BuildContext context) =>
      math.max(16.0, screenWidth(context) * 0.06);

  /// 字号相对设计稿缩放，限制区间减轻小屏重叠。
  static double sp(BuildContext context, double size) {
    final scale = (screenWidth(context) / designWidth).clamp(0.82, 1.12);
    return size * scale;
  }

  /// 日历网格子项宽高比（child 的 width / height），略竖以容纳公历+农历。
  static double calendarGridChildAspectRatio(BuildContext context) {
    final w = screenWidth(context);
    if (w < 330) return 0.96;
    if (w < 380) return 0.90;
    if (w < 430) return 0.84;
    return 0.80;
  }

  /// 自定义数字键盘高度：随屏高比例并限制上下界。
  static double numericKeyboardHeight(BuildContext context) {
    final h = screenHeight(context);
    return (h * 0.30).clamp(236.0, 304.0);
  }

  /// Logo 边长：随屏宽比例并限制区间。
  static double logoSize(BuildContext context) {
    return (screenWidth(context) * 0.21).clamp(72.0, 96.0);
  }
}
