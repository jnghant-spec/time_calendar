import 'dart:convert';

import 'package:flutter/services.dart';

/// 民族 / 宗教节日 JSON 加载与字段安全读取（带内存缓存）。
///
/// `years`（2026–2035 公历日期占位）由 `tool/generate_festival_dates.py` 离线批量写入。
class FestivalDataLoader {
  FestivalDataLoader._();

  static List<Map<String, dynamic>>? _ethnicCache;
  static List<Map<String, dynamic>>? _religiousCache;

  /// 预热缓存；失败时写入空列表，避免反复读盘抛错。
  static Future<void> ensureLoaded() async {
    await loadEthnicFestivals();
    await loadReligiousFestivals();
  }

  static List<Map<String, dynamic>> ethnicFestivalsOrEmpty() =>
      _ethnicCache ?? const [];

  static List<Map<String, dynamic>> religiousFestivalsOrEmpty() =>
      _religiousCache ?? const [];

  /// 测试或极端场景下清空缓存。
  static void clearCache() {
    _ethnicCache = null;
    _religiousCache = null;
  }

  static Future<List<Map<String, dynamic>>> loadEthnicFestivals() async {
    if (_ethnicCache != null) return _ethnicCache!;
    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/ethnic_festivals.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final list = json['festivals'];
      if (list is! List) {
        _ethnicCache = [];
        return _ethnicCache!;
      }
      _ethnicCache = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return _ethnicCache!;
    } catch (_) {
      _ethnicCache = [];
      return _ethnicCache!;
    }
  }

  static Future<List<Map<String, dynamic>>> loadReligiousFestivals() async {
    if (_religiousCache != null) return _religiousCache!;
    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/religious_festivals.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final list = json['festivals'];
      if (list is! List) {
        _religiousCache = [];
        return _religiousCache!;
      }
      _religiousCache =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return _religiousCache!;
    } catch (_) {
      _religiousCache = [];
      return _religiousCache!;
    }
  }

  /// 获取指定年份的公历日期
  static DateTime? getGregorianDate(Map<String, dynamic> festival, int year) {
    final years = festival['years'];
    if (years is! Map) return null;
    final dateStr = years[year.toString()];
    if (dateStr is! String || dateStr.isEmpty) return null;
    final parts = dateStr.split('-');
    if (parts.length != 3) return null;
    try {
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  /// 安全获取字符串字段（防止 JSON 字段缺失导致崩溃）
  static String? safeString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    return value.toString();
  }

  /// 安全获取字符串列表字段
  static List<String> safeStringList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// 安全获取布尔字段
  static bool safeBool(
    Map<String, dynamic> json,
    String key, {
    bool defaultValue = false,
  }) {
    final value = json[key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    return defaultValue;
  }

  /// 节日 `description`：缺失或非字符串为 null；空白串为 null（详情区可不展示）。
  static String? safeDescription(Map<String, dynamic> json) {
    final s = safeString(json, 'description');
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
