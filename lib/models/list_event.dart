// 清单页行数据与侧滑操作枚举；标签通过 ListEvent.tagId 关联 ReminderTag。

import 'dart:convert';

/// 侧滑项操作（与清单卡片 Slidable 一致）
enum SwipeAction {
  onTogglePin,
  onShare,
  onDelete,
}

enum EventType {
  birthday,
  generic,
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

/// 测试种子事件共用的公历发生日（2026-06-05）。
final DateTime kListEventJune5TestDate = DateTime(2026, 6, 5);

class ListEvent {
  const ListEvent({
    required this.id,
    required this.title,
    required this.baseDate,
    required this.tagId,
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
    this.photoPaths = const [],
    this.pendingShareAfterAdd = false,
    this.note,
    this.leapMonthPreference,
    this.eventType = EventType.generic,
    this.lastModifiedByName,
    this.lastModifiedAt,
  });

  final String id;
  final String title;
  /// 事件日历日；一次性事件为唯一发生日，循环事件同时为 **循环起始锚点**（编辑起始日即更新本字段）。
  final DateTime baseDate;
  /// 关联 [ReminderTag.id]；默认与历史枚举名一致如 `birthday`。
  final String tagId;
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
  /// 本地持久化的照片文件路径列表。
  final List<String> photoPaths;
  /// FAB 添加成功后是否立刻打开分享 Sheet（由 ListPage 消费后应还原为 false）。
  final bool pendingShareAfterAdd;
  /// 用户备注（添加/编辑页「备注」输入框）。
  final String? note;
  /// 闰月生日提醒方式：0=自动匹配，1=仅正本月，2=闰月年过两个生日；仅农历闰月有效。
  final int? leapMonthPreference;
  final EventType eventType;
  /// 伴侣共享场景下最后修改者称呼。
  final String? lastModifiedByName;
  /// 伴侣共享场景下最后修改时间。
  final DateTime? lastModifiedAt;

  /// 循环起始日（与 [baseDate] 同日，仅保留年月日语义）。
  DateTime get anchorDate => DateTime(baseDate.year, baseDate.month, baseDate.day);

  ListEvent copyWith({
    String? id,
    String? title,
    DateTime? baseDate,
    String? tagId,
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
    List<String>? photoPaths,
    bool? pendingShareAfterAdd,
    String? note,
    int? leapMonthPreference,
    EventType? eventType,
    String? lastModifiedByName,
    DateTime? lastModifiedAt,
    bool clearLastModifiedByName = false,
    bool clearLastModifiedAt = false,
  }) {
    return ListEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      baseDate: baseDate ?? this.baseDate,
      tagId: tagId ?? this.tagId,
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
      photoPaths: photoPaths ?? this.photoPaths,
      pendingShareAfterAdd: pendingShareAfterAdd ?? this.pendingShareAfterAdd,
      note: note ?? this.note,
      leapMonthPreference: leapMonthPreference ?? this.leapMonthPreference,
      eventType: eventType ?? this.eventType,
      lastModifiedByName: clearLastModifiedByName
          ? null
          : (lastModifiedByName ?? this.lastModifiedByName),
      lastModifiedAt:
          clearLastModifiedAt ? null : (lastModifiedAt ?? this.lastModifiedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'baseDate': baseDate.toIso8601String(),
        'tagId': tagId,
        'isPinned': isPinned,
        'isLunarRecurring': isLunarRecurring,
        'isExpired': isExpired,
        'repeatRule': repeatRule.name,
        'reminderType': reminderType.name,
        'advanceDaysOption': advanceDaysOption.name,
        'advanceTimeHm': advanceTimeHm,
        'sameDayTimeHm': sameDayTimeHm,
        'isLunarDate': isLunarDate,
        'photoUrl': photoUrl,
        'photoPaths': jsonEncode(photoPaths),
        'pendingShareAfterAdd': pendingShareAfterAdd,
        if (note != null) 'note': note,
        if (leapMonthPreference != null) 'leapMonthPreference': leapMonthPreference,
        'eventType': eventType.name,
        if (lastModifiedByName != null && lastModifiedByName!.isNotEmpty)
          'lastModifiedByName': lastModifiedByName,
        if (lastModifiedAt != null)
          'lastModifiedAt': lastModifiedAt!.toIso8601String(),
      };

  factory ListEvent.fromJson(Map<String, dynamic> json) {
    return ListEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      baseDate: DateTime.parse(json['baseDate'] as String),
      tagId: json['tagId'] as String,
      isPinned: json['isPinned'] as bool? ?? false,
      isLunarRecurring: json['isLunarRecurring'] as bool? ?? false,
      isExpired: json['isExpired'] as bool? ?? false,
      repeatRule: EventRepeatRule.values.firstWhere(
        (e) => e.name == json['repeatRule'],
        orElse: () => EventRepeatRule.none,
      ),
      reminderType: EventReminderType.values.firstWhere(
        (e) => e.name == json['reminderType'],
        orElse: () => EventReminderType.sameDayOnly,
      ),
      advanceDaysOption: EventAdvanceDaysOption.values.firstWhere(
        (e) => e.name == json['advanceDaysOption'],
        orElse: () => EventAdvanceDaysOption.oneDay,
      ),
      advanceTimeHm: json['advanceTimeHm'] as String? ?? '09:00',
      sameDayTimeHm: json['sameDayTimeHm'] as String? ?? '09:00',
      isLunarDate: json['isLunarDate'] as bool? ?? false,
      photoUrl: json['photoUrl'] as String?,
      photoPaths: _decodePhotoPaths(json['photoPaths']),
      pendingShareAfterAdd: json['pendingShareAfterAdd'] as bool? ?? false,
      note: json['note'] as String?,
      leapMonthPreference: (json['leapMonthPreference'] as num?)?.toInt(),
      eventType: EventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => EventType.generic,
      ),
      lastModifiedByName: json['lastModifiedByName'] as String?,
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.tryParse(json['lastModifiedAt'] as String)
          : null,
    );
  }
}

List<String> _decodePhotoPaths(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw.map((e) => e.toString()).toList();
  }
  if (raw is String) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }
  return const [];
}
