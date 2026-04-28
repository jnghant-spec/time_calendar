// 清单页（ListPage）分类、行数据与侧滑操作枚举；与 UI 引用名保持一致。

/// 侧滑项操作（与清单卡片 Slidable 一致）
enum SwipeAction {
  onTogglePin,
  onShare,
  onDelete,
}

enum ListCategory {
  birthday,
  partner,
  goal,
  idol,
}

class ListEvent {
  const ListEvent({
    required this.id,
    required this.title,
    required this.baseDate,
    required this.category,
    this.isPinned = false,
    this.isLunarRecurring = false,
    this.isExpired = false,
  });

  final String id;
  final String title;
  final DateTime baseDate;
  final ListCategory category;
  final bool isPinned;
  /// 农历循环生日等：展示农历标签文案。
  final bool isLunarRecurring;
  /// 一次性已过期事项：固定按 [baseDate] 展示，不参与“roll”到下一年。
  final bool isExpired;

  ListEvent copyWith({
    String? id,
    String? title,
    DateTime? baseDate,
    ListCategory? category,
    bool? isPinned,
    bool? isLunarRecurring,
    bool? isExpired,
  }) {
    return ListEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      baseDate: baseDate ?? this.baseDate,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      isLunarRecurring: isLunarRecurring ?? this.isLunarRecurring,
      isExpired: isExpired ?? this.isExpired,
    );
  }
}
