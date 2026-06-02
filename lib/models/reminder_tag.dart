import 'package:flutter/material.dart';

/// 清单页动态标签（持久化于 [TagService]）。
class ReminderTag {
  const ReminderTag({
    required this.id,
    required this.name,
    this.accentColor,
    required this.iconBgColor,
    required this.sortOrder,
    required this.isDefault,
    required this.createdAt,
    this.photoPath,
    this.iconName,
    this.isSystemTag = false,
  });

  final String id;
  final String name;
  /// 主题色；`null` 表示使用默认灰（无主题色）。
  final Color? accentColor;
  final Color iconBgColor;
  final int sortOrder;
  final bool isDefault;
  final DateTime createdAt;
  final String? photoPath;
  /// 系统图标标识（如 `star`）；与 [photoPath] 互斥展示，数据可并存。
  final String? iconName;
  /// 系统预置标签（如「生日」）：可编辑，不可删除。
  final bool isSystemTag;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (accentColor != null) 'accentColor': accentColor!.toARGB32(),
        'iconBgColor': iconBgColor.toARGB32(),
        'sortOrder': sortOrder,
        'isDefault': isDefault,
        'createdAt': createdAt.toIso8601String(),
        if (photoPath != null) 'photoPath': photoPath,
        if (iconName != null && iconName!.isNotEmpty) 'iconName': iconName,
        if (isSystemTag) 'isSystemTag': true,
      };

  factory ReminderTag.fromJson(Map<String, dynamic> m) {
    final id = m['id'] as String;
    return ReminderTag(
      id: id,
      name: m['name'] as String,
      accentColor: m['accentColor'] != null
          ? Color(m['accentColor'] as int)
          : null,
      iconBgColor: Color(m['iconBgColor'] as int),
      sortOrder: m['sortOrder'] as int,
      isDefault: m['isDefault'] as bool? ?? false,
      createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      photoPath: m['photoPath'] as String?,
      iconName: m['iconName'] as String?,
      isSystemTag: m['isSystemTag'] as bool? ?? id == 'birthday',
    );
  }

  ReminderTag copyWith({
    String? id,
    String? name,
    Color? accentColor,
    Color? iconBgColor,
    int? sortOrder,
    bool? isDefault,
    DateTime? createdAt,
    String? photoPath,
    String? iconName,
    bool? isSystemTag,
    bool clearPhotoPath = false,
    bool clearIconName = false,
    bool clearAccentColor = false,
  }) {
    return ReminderTag(
      id: id ?? this.id,
      name: name ?? this.name,
      accentColor: clearAccentColor ? null : (accentColor ?? this.accentColor),
      iconBgColor: iconBgColor ?? this.iconBgColor,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
      iconName: clearIconName ? null : (iconName ?? this.iconName),
      isSystemTag: isSystemTag ?? this.isSystemTag,
    );
  }
}
