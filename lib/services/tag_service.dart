import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/widgets/tag_circle_widget.dart';

/// 清单标签持久化与查询。
class TagService {
  TagService._();

  static const String prefsKey = 'reminder_tags_v1';
  static const int maxTagCount = 10;

  /// 解除标签关联后提醒/事件集使用的占位 id（模型字段仍为 String）。
  static const String uncategorizedTagId = '';

  static List<ReminderTag>? _cache;

  /// 由 [MainNavigationPage] 注入，用于统计/解除清单提醒关联。
  static int Function(String tagId)? reminderCountForTag;
  static Future<void> Function(String tagId)? unlinkRemindersForTag;

  static const Color _kMissingAccent = Color(0xFF94A3B8);

  static List<ReminderTag> _seedDefaults() {
    final now = DateTime.now();
    return [
      ReminderTag(
        id: 'birthday',
        name: '生日',
        accentColor: const Color(0xFFFF9F43),
        iconBgColor: const Color(0xFFFFF3E6),
        sortOrder: 0,
        isDefault: true,
        createdAt: now,
      ),
      ReminderTag(
        id: 'partner',
        name: '伴侣',
        accentColor: const Color(0xFFFD79A8),
        iconBgColor: const Color(0xFFFFF0F6),
        sortOrder: 1,
        isDefault: true,
        createdAt: now,
      ),
      ReminderTag(
        id: 'goal',
        name: '目标',
        accentColor: const Color(0xFF54A0FF),
        iconBgColor: const Color(0xFFEAF3FF),
        sortOrder: 2,
        isDefault: true,
        createdAt: now,
      ),
      ReminderTag(
        id: 'idol',
        name: '偶像',
        accentColor: const Color(0xFFA29BFE),
        iconBgColor: const Color(0xFFF3F0FF),
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
    final old = list[i];
    if (old.photoPath != null &&
        old.photoPath != updated.photoPath &&
        old.photoPath!.isNotEmpty) {
      await deleteTagPhotoFile(old.photoPath);
    }
    list[i] = updated;
    await saveTags(list);
  }

  /// 系统预置「生日」标签：`id == 'birthday'`（种子数据固定 id，名称通常为「生日」）。
  static bool isProtectedSystemTag(ReminderTag tag) => tag.id == 'birthday';

  static String displayTagName(String name, {int maxLen = 4}) {
    final trimmed = name.trim();
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen)}...';
  }

  static Future<({int reminders, int collections})> countTagAssociations(
    String tagId,
  ) async {
    final collections = await MemoryService.loadCollections();
    final collectionCount =
        collections.where((c) => c.tagId == tagId).length;
    final reminderCount = reminderCountForTag?.call(tagId) ?? 0;
    return (reminders: reminderCount, collections: collectionCount);
  }

  /// 解除关联后删除标签（非级联删除内容）。
  static Future<void> unlinkAndDeleteTag(String tagId) async {
    await MemoryService.clearTagIdFromCollections(tagId);
    if (unlinkRemindersForTag != null) {
      await unlinkRemindersForTag!(tagId);
    }
    await deleteTagById(tagId);
  }

  static Future<void> deleteTagById(String id) async {
    final list = await loadTags();
    ReminderTag? target;
    for (final t in list) {
      if (t.id == id) {
        target = t;
        break;
      }
    }
    if (target?.photoPath != null) {
      await deleteTagPhotoFile(target!.photoPath);
    }
    list.removeWhere((t) => t.id == id);
    await saveTags(list);
  }

  static Future<void> deleteTagPhotoFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<String?> persistTagPhoto(Uint8List bytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final tagsDir = Directory('${dir.path}/tag_icons');
      if (!tagsDir.existsSync()) {
        tagsDir.createSync(recursive: true);
      }
      final path =
          '${tagsDir.path}/tag_${DateTime.now().microsecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } catch (_) {
      return null;
    }
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

/// 清单/详情等处统一的标签前导图标（委托 [TagCircleWidget]）。
class TagIconHelper {
  TagIconHelper._();

  static Widget build({
    required String tagId,
    required Color color,
    double size = 20,
  }) {
    final tag = TagService.getTagById(tagId);
    if (tag != null) {
      return TagCircleWidget(tag: tag, size: size, showLabel: false);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(Icons.label, color: color, size: size * 0.5),
    );
  }
}
