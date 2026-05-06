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

enum EventRepeatRule {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

enum EventReminderType {
  advanceAndSameDay,
  advanceOnly,
  sameDayOnly,
}

enum EventAdvanceDaysOption {
  oneDay,
  threeDays,
  oneWeek,
  oneMonth,
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
    this.repeatRule = EventRepeatRule.none,
    this.reminderType = EventReminderType.sameDayOnly,
    this.advanceDaysOption = EventAdvanceDaysOption.oneDay,
    this.advanceTimeHm = '09:00',
    this.sameDayTimeHm = '09:00',
    this.isLunarDate = false,
    this.photoUrl,
    this.pendingShareAfterAdd = false,
  });

  final String id;
  final String title;
  /// 事件日历日；一次性事件为唯一发生日，循环事件同时为 **循环起始锚点**（编辑起始日即更新本字段）。
  final DateTime baseDate;
  final ListCategory category;
  final bool isPinned;
  /// 农历循环生日等：展示农历标签文案。
  final bool isLunarRecurring;
  /// 一次性已过期事项：固定按 [baseDate] 展示，不参与“roll”到下一年。
  final bool isExpired;

  final EventRepeatRule repeatRule;
  final EventReminderType reminderType;
  final EventAdvanceDaysOption advanceDaysOption;
  final String advanceTimeHm;
  final String sameDayTimeHm;
  /// 用户在添加页是否按农历选择日期。
  final bool isLunarDate;
  final String? photoUrl;
  /// FAB 添加成功后是否立刻打开分享 Sheet（由 ListPage 消费后应还原为 false）。
  final bool pendingShareAfterAdd;

  /// 循环起始日（与 [baseDate] 同日，仅保留年月日语义）。
  DateTime get anchorDate => DateTime(baseDate.year, baseDate.month, baseDate.day);

  ListEvent copyWith({
    String? id,
    String? title,
    DateTime? baseDate,
    ListCategory? category,
    bool? isPinned,
    bool? isLunarRecurring,
    bool? isExpired,
    EventRepeatRule? repeatRule,
    EventReminderType? reminderType,
    EventAdvanceDaysOption? advanceDaysOption,
    String? advanceTimeHm,
    String? sameDayTimeHm,
    bool? isLunarDate,
    String? photoUrl,
    bool? pendingShareAfterAdd,
  }) {
    return ListEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      baseDate: baseDate ?? this.baseDate,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      isLunarRecurring: isLunarRecurring ?? this.isLunarRecurring,
      isExpired: isExpired ?? this.isExpired,
      repeatRule: repeatRule ?? this.repeatRule,
      reminderType: reminderType ?? this.reminderType,
      advanceDaysOption: advanceDaysOption ?? this.advanceDaysOption,
      advanceTimeHm: advanceTimeHm ?? this.advanceTimeHm,
      sameDayTimeHm: sameDayTimeHm ?? this.sameDayTimeHm,
      isLunarDate: isLunarDate ?? this.isLunarDate,
      photoUrl: photoUrl ?? this.photoUrl,
      pendingShareAfterAdd: pendingShareAfterAdd ?? this.pendingShareAfterAdd,
    );
  }
}
