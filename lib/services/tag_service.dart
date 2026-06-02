import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/reminder_tag.dart';

/// 清单标签持久化与查询。
class TagService {
  TagService._();

  static const String prefsKey = 'reminder_tags_v1';
  static const int maxTagCount = 10;

  static List<ReminderTag>? _cache;

  static const Color _kMissingAccent = Color(0xFF94A3B8);

  static List<ReminderTag> _seedDefaults() {
    final now = DateTime.now();
    return [
      ReminderTag(
        id: 'birthday',
        name: '生日',
        accentColor: const Color(0xFFF97316),
        iconBgColor: const Color(0xFFFFEDD5),
        sortOrder: 0,
        isDefault: true,
        createdAt: now,
      ),
      ReminderTag(
        id: 'partner',
        name: '伴侣',
        accentColor: const Color(0xFFF43F5E),
        iconBgColor: const Color(0xFFFCE7F3),
        sortOrder: 1,
        isDefault: true,
        createdAt: now,
      ),
      ReminderTag(
        id: 'goal',
        name: '目标',
        accentColor: const Color(0xFF3B82F6),
        iconBgColor: const Color(0xFFDBEAFE),
        sortOrder: 2,
        isDefault: true,
        createdAt: now,
      ),
      ReminderTag(
        id: 'idol',
        name: '偶像',
        accentColor: const Color(0xFFA855F7),
        iconBgColor: const Color(0xFFF3E8FF),
        sortOrder: 3,
        isDefault: true,
        createdAt: now,
      ),
    ];
  }

  static Future<void> _persist(List<ReminderTag> tags) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tags.map((e) => e.toJson()).toList());
    await prefs.setString(prefsKey, encoded);
    _cache = List<ReminderTag>.from(tags);
  }

  /// 首次为空时写入 4 个默认标签并返回排序后的列表。
  static Future<List<ReminderTag>> loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      final seed = _seedDefaults();
      await _persist(seed);
      return List<ReminderTag>.from(_cache!);
    }
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => ReminderTag.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _cache = list;
      return List<ReminderTag>.from(list);
    } catch (_) {
      final seed = _seedDefaults();
      await _persist(seed);
      return List<ReminderTag>.from(_cache!);
    }
  }

  static Future<void> saveTags(List<ReminderTag> tags) async {
    final sorted = List<ReminderTag>.from(tags)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    await _persist(sorted);
  }

  static Future<void> addTag(ReminderTag tag) async {
    final list = await loadTags();
    if (list.length >= maxTagCount) return;
    list.add(tag);
    await saveTags(list);
  }

  static Future<void> updateTag(ReminderTag updated) async {
    final list = await loadTags();
    final i = list.indexWhere((t) => t.id == updated.id);
    if (i < 0) return;
    list[i] = updated;
    await saveTags(list);
  }

  static Future<void> deleteTagById(String id) async {
    final list = await loadTags();
    list.removeWhere((t) => t.id == id);
    await saveTags(list);
  }

  static ReminderTag? getTagById(String id) {
    final c = _cache;
    if (c == null) return null;
    for (final t in c) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 清单卡片等：找不到标签时使用灰色。
  static Color accentForDisplay(String tagId) {
    return getTagById(tagId)?.accentColor ?? _kMissingAccent;
  }

  static Color iconBgForDisplay(String tagId) {
    final t = getTagById(tagId);
    if (t != null) return t.iconBgColor;
    return _kMissingAccent.withValues(alpha: 0.15);
  }

  static String newTagId() =>
      'tag_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';
}

/// 清单/详情等处统一的标签前导图标（内置 id 用素材图标，其余用标签形）。
class TagIconHelper {
  TagIconHelper._();

  static Widget build({
    required String tagId,
    required Color color,
    double size = 20,
  }) {
    if (tagId == 'birthday') {
      return Icon(Icons.cake, color: color, size: size);
    }
    if (tagId == 'partner') {
      return SvgPicture.asset(
        'assets/images/ic_couple_hearts.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(Icons.label, color: color, size: size);
  }
}
