import 'package:flutter/material.dart';

/// 节日设置页分类图标与周视图节日卡片共用映射。
IconData festivalCategoryIcon(String categoryId) {
  switch (categoryId) {
    case 'gregorian':
      return Icons.public;
    case 'lunar':
      return Icons.nightlight_round;
    case 'ethnic':
      return Icons.diversity_3;
    case 'religious':
      return Icons.mosque;
    default:
      return Icons.event;
  }
}
