import 'package:time_calendar/models/membership_tier.dart';

/// 与清单 / 日历 / 分享一致的事件业务分类
enum EventCategory {
  birthday,
  partner,
  goal,
  idol,
}

/// 重复与农历（农历年循环保存在模型层，具体换算在业务层 / lunar_calendar TODO）
enum EventRecurrence {
  none,
  daily,
  weekly,
  monthly,
  yearly,
  lunarYearly,
}

/// 提醒：前置+当天 / 仅前置 / 仅当天
enum ReminderMode {
  preAndDay,
  preOnly,
  dayOnly,
}

/// 一天内的时间点（不依赖 `flutter/material.dart`，方便 JSON 与单测）
class DayTime {
  const DayTime({required this.hour, required this.minute})
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  int get totalMinutes => hour * 60 + minute;

  Map<String, int> toJson() => {'hour': hour, 'minute': minute};

  static DayTime? fromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    final h = (m['hour'] as num?)?.toInt();
    final min = (m['minute'] as num?)?.toInt();
    if (h == null || min == null) return null;
    if (h < 0 || h > 23 || min < 0 || min > 59) return null;
    return DayTime(hour: h, minute: min);
  }
}

/// 时光集中的「事件」领域模型（日程 / 提醒 / 共享载体）。
///
/// 与 UI 中旧名 `ListEvent` 可逐步对齐迁移；**本类为权威结构定义**。
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.baseDate,
    this.category = EventCategory.birthday,
    this.isPinned = false,
    this.isLunarRecurring = false,
    this.recurrence = EventRecurrence.none,
    this.reminderMode = ReminderMode.preAndDay,
    this.preReminderOffsetDays = 1,
    this.preReminderTime,
    this.sameDayTime,
    this.sharedToPhoneNumbers = const [],
    this.note,
    this.colorArgb,
    this.createdAt,
    this.updatedAt,
    this.isShareIncoming = false,
    this.sharedFromUserId,
  });

  final String id;
  final String title;

  /// 基准日（公历；若 [isLunarRecurring] 为 true，业务层用农历换算下一次触发）
  final DateTime baseDate;
  final EventCategory category;
  final bool isPinned;
  final bool isLunarRecurring;
  final EventRecurrence recurrence;
  final ReminderMode reminderMode;
  final int preReminderOffsetDays;
  final DayTime? preReminderTime;
  final DayTime? sameDayTime;
  final List<String> sharedToPhoneNumbers;
  final String? note;
  final int? colorArgb;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 是否为「他人共享给我」的事件
  final bool isShareIncoming;
  final String? sharedFromUserId;

  /// 创建/更新前可与 [MembershipService.canCreateReminder] 组合校验
  static int eventQuotaByTier(MembershipTier tier) =>
      MembershipConfig.benefits[tier]!.reminderQuota;

  Event copyWith({
    String? id,
    String? title,
    DateTime? baseDate,
    EventCategory? category,
    bool? isPinned,
    bool? isLunarRecurring,
    EventRecurrence? recurrence,
    ReminderMode? reminderMode,
    int? preReminderOffsetDays,
    DayTime? preReminderTime,
    DayTime? sameDayTime,
    List<String>? sharedToPhoneNumbers,
    String? note,
    int? colorArgb,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isShareIncoming,
    String? sharedFromUserId,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      baseDate: baseDate ?? this.baseDate,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      isLunarRecurring: isLunarRecurring ?? this.isLunarRecurring,
      recurrence: recurrence ?? this.recurrence,
      reminderMode: reminderMode ?? this.reminderMode,
      preReminderOffsetDays: preReminderOffsetDays ?? this.preReminderOffsetDays,
      preReminderTime: preReminderTime ?? this.preReminderTime,
      sameDayTime: sameDayTime ?? this.sameDayTime,
      sharedToPhoneNumbers: sharedToPhoneNumbers ?? this.sharedToPhoneNumbers,
      note: note ?? this.note,
      colorArgb: colorArgb ?? this.colorArgb,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isShareIncoming: isShareIncoming ?? this.isShareIncoming,
      sharedFromUserId: sharedFromUserId ?? this.sharedFromUserId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'baseDate': baseDate.toIso8601String(),
      'category': category.name,
      'isPinned': isPinned,
      'isLunarRecurring': isLunarRecurring,
      'recurrence': recurrence.name,
      'reminderMode': reminderMode.name,
      'preReminderOffsetDays': preReminderOffsetDays,
      'preReminderTime': preReminderTime?.toJson(),
      'sameDayTime': sameDayTime?.toJson(),
      'sharedToPhoneNumbers': sharedToPhoneNumbers,
      'note': note,
      'colorArgb': colorArgb,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isShareIncoming': isShareIncoming,
      'sharedFromUserId': sharedFromUserId,
    };
  }

  static Event fromJson(Map<String, dynamic> m) {
    return Event(
      id: m['id'] as String,
      title: m['title'] as String,
      baseDate: DateTime.parse(m['baseDate'] as String),
      category: EventCategory.values.asNameMap()[m['category'] as String?] ?? EventCategory.birthday,
      isPinned: m['isPinned'] as bool? ?? false,
      isLunarRecurring: m['isLunarRecurring'] as bool? ?? false,
      recurrence: EventRecurrence.values.asNameMap()[m['recurrence'] as String?] ?? EventRecurrence.none,
      reminderMode: ReminderMode.values.asNameMap()[m['reminderMode'] as String?] ?? ReminderMode.preAndDay,
      preReminderOffsetDays: (m['preReminderOffsetDays'] as num?)?.toInt() ?? 1,
      preReminderTime: DayTime.fromJson(
        m['preReminderTime'] != null
            ? Map<String, dynamic>.from(m['preReminderTime'] as Map)
            : null,
      ),
      sameDayTime: DayTime.fromJson(
        m['sameDayTime'] != null
            ? Map<String, dynamic>.from(m['sameDayTime'] as Map)
            : null,
      ),
      sharedToPhoneNumbers: (m['sharedToPhoneNumbers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      note: m['note'] as String?,
      colorArgb: (m['colorArgb'] as num?)?.toInt(),
      createdAt: (m['createdAt'] as String?) != null
          ? DateTime.tryParse(m['createdAt'] as String)
          : null,
      updatedAt: (m['updatedAt'] as String?) != null
          ? DateTime.tryParse(m['updatedAt'] as String)
          : null,
      isShareIncoming: m['isShareIncoming'] as bool? ?? false,
      sharedFromUserId: m['sharedFromUserId'] as String?,
    );
  }
}
