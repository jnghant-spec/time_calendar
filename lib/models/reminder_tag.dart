import 'package:flutter/material.dart';

/// 清单页动态标签（持久化于 [TagService]）。
class ReminderTag {
  const ReminderTag({
    required this.id,
    required this.name,
    required this.accentColor,
    required this.iconBgColor,
    required this.sortOrder,
    required this.isDefault,
    required this.createdAt,
  });

  final String id;
  final String name;
  final Color accentColor;
  final Color iconBgColor;
  final int sortOrder;
  final bool isDefault;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'accentColor': accentColor.toARGB32(),
        'iconBgColor': iconBgColor.toARGB32(),
        'sortOrder': sortOrder,
        'isDefault': isDefault,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReminderTag.fromJson(Map<String, dynamic> m) {
    return ReminderTag(
      id: m['id'] as String,
      name: m['name'] as String,
      accentColor: Color(m['accentColor'] as int),
      iconBgColor: Color(m['iconBgColor'] as int),
      sortOrder: m['sortOrder'] as int,
      isDefault: m['isDefault'] as bool? ?? false,
      createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
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
  }) {
    return ReminderTag(
      id: id ?? this.id,
      name: name ?? this.name,
      accentColor: accentColor ?? this.accentColor,
      iconBgColor: iconBgColor ?? this.iconBgColor,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
