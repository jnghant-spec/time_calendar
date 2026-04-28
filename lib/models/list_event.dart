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
  });

  final String id;
  final String title;
  final DateTime baseDate;
  final ListCategory category;
  final bool isPinned;
  final bool isLunarRecurring;

  ListEvent copyWith({
    String? id,
    String? title,
    DateTime? baseDate,
    ListCategory? category,
    bool? isPinned,
    bool? isLunarRecurring,
  }) {
    return ListEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      baseDate: baseDate ?? this.baseDate,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      isLunarRecurring: isLunarRecurring ?? this.isLunarRecurring,
    );
  }
}
