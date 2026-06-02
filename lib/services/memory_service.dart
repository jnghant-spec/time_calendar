import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/utils/event_date_utils.dart';

/// 时光集与纪念事件的本地持久化（JSON 数组，v2 key）。
class MemoryService {
  MemoryService._();

  static const String prefsKeyCollections = 'memory_collections_v2';
  static const String prefsKeyEvents = 'memory_events_v2';
  static const String _legacyCollectionsKey = 'memory_collections_v1';
  static const String _legacyEventsKey = 'memory_events_v1';

  static String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';

  /// 生成新实体 id（封面文件命名等）。
  static String generateId(String prefix) => _newId(prefix);

  static Future<void> _migrateFromV1IfNeeded(SharedPreferences prefs) async {
    await _migrateCollectionsFromV1(prefs);
    await _migrateEventsFromV1(prefs);
  }

  static Future<void> _migrateCollectionsFromV1(SharedPreferences prefs) async {
    if ((prefs.getString(prefsKeyCollections) ?? '').isNotEmpty) return;
    final legacyC = prefs.getString(_legacyCollectionsKey);
    if (legacyC == null || legacyC.isEmpty) return;
    try {
      final decoded = jsonDecode(legacyC);
      if (decoded is! List) return;
      final list = <MemoryCollection>[];
      for (final e in decoded) {
        final m = Map<String, dynamic>.from(e as Map);
        list.add(
          MemoryCollection(
            id: m['id'] as String,
            name: m['name'] as String,
            tagId: m['tagId'] as String,
            coverPhotoPath: null,
            isPinned: m['isPinned'] as bool? ?? false,
            createdAt: DateTime.parse(m['createdAt'] as String),
          ),
        );
      }
      await prefs.setString(
        prefsKeyCollections,
        jsonEncode(list.map((x) => x.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<void> _migrateEventsFromV1(SharedPreferences prefs) async {
    if ((prefs.getString(prefsKeyEvents) ?? '').isNotEmpty) return;
    final legacyE = prefs.getString(_legacyEventsKey);
    if (legacyE == null || legacyE.isEmpty) return;
    try {
      final decoded = jsonDecode(legacyE);
      if (decoded is! List) return;
      final list = <MemoryEvent>[];
      for (final e in decoded) {
        final m = Map<String, dynamic>.from(e as Map);
        m.remove('sortIndex');
        list.add(MemoryEvent.fromJson(m));
      }
      await prefs.setString(
        prefsKeyEvents,
        jsonEncode(list.map((x) => x.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<List<MemoryCollection>> loadCollections() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateFromV1IfNeeded(prefs);
    final raw = prefs.getString(prefsKeyCollections);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        final rawName = map['name'];
        final n = rawName is String ? rawName.trim() : '';
        if (n.isEmpty) {
          map['name'] = '未命名时光集';
        }
        return MemoryCollection.fromJson(map);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 按 id 读取合集（用于弹窗标题等与磁盘一致）。
  static Future<MemoryCollection?> getCollectionById(String id) async {
    final list = await loadCollections();
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  static Future<void> saveCollections(List<MemoryCollection> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(prefsKeyCollections, encoded);
  }

  static Future<void> addCollection(MemoryCollection collection) async {
    final list = await loadCollections();
    list.add(collection);
    await saveCollections(list);
  }

  static Future<void> deleteCollection(String id) async {
    final list = await loadCollections();
    list.removeWhere((c) => c.id == id);
    await saveCollections(list);
    final events = await loadEvents();
    events.removeWhere((e) => e.collectionId == id);
    await saveEvents(events);
  }

  static Future<List<MemoryEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateFromV1IfNeeded(prefs);
    final raw = prefs.getString(prefsKeyEvents);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => MemoryEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveEvents(List<MemoryEvent> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(prefsKeyEvents, encoded);
  }

  static Future<void> addEvent(MemoryEvent event) async {
    final list = await loadEvents();
    list.add(event);
    await saveEvents(list);
  }

  /// 新增或覆盖同 id 事件。
  static Future<void> upsertEvent(MemoryEvent event) async {
    final list = await loadEvents();
    final i = list.indexWhere((e) => e.id == event.id);
    if (i >= 0) {
      list[i] = event;
    } else {
      list.add(event);
    }
    await saveEvents(list);
  }

  static Future<void> deleteEvent(String id) async {
    final list = await loadEvents();
    list.removeWhere((e) => e.id == id);
    await saveEvents(list);
  }

  static Future<List<MemoryEvent>> getEventsByCollection(
    String collectionId,
  ) async {
    final all = await loadEvents();
    return all.where((e) => e.collectionId == collectionId).toList();
  }

  /// 按发生日升序；同日按 id。
  static Future<List<MemoryEvent>> getEventsSorted(String collectionId) async {
    final items = await getEventsByCollection(collectionId);
    items.sort((a, b) {
      final c = a.date.compareTo(b.date);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });
    return items;
  }

  static DateTime _latestChildDate(String collectionId, List<MemoryEvent> all) {
    DateTime? max;
    for (final e in all) {
      if (e.collectionId != collectionId) continue;
      if (max == null || e.date.isAfter(max)) max = e.date;
    }
    return max ?? DateTime.utc(1970);
  }

  /// 置顶在前；同置顶状态按最近子事件时间倒序。
  static Future<List<MemoryCollection>> getSortedCollections() async {
    final collections = await loadCollections();
    final allEvents = await loadEvents();
    final decorated = collections
        .map((c) => (c: c, latest: _latestChildDate(c.id, allEvents)))
        .toList();
    decorated.sort((a, b) {
      if (a.c.isPinned != b.c.isPinned) {
        return a.c.isPinned ? -1 : 1;
      }
      final t = b.latest.compareTo(a.latest);
      if (t != 0) return t;
      return b.c.createdAt.compareTo(a.c.createdAt);
    });
    return decorated.map((x) => x.c).toList();
  }

  static MemoryEvent cloneFromListEvent(ListEvent event, String collectionId) {
    final paths = event.photoPaths;
    final slots = List<String?>.filled(9, null);
    for (var i = 0; i < paths.length && i < 9; i++) {
      slots[i] = paths[i];
    }
    return MemoryEvent(
      id: _newId('mev'),
      collectionId: collectionId,
      title: event.title,
      location: null,
      date: effectiveDate(event),
      photoPaths: encodePhotoGridSlots(slots),
    );
  }

  /// 九宫格持久化：固定 9 槽，空槽存空串。
  static List<String> encodePhotoGridSlots(List<String?> slots) {
    return List.generate(
      9,
      (i) => i < slots.length &&
              slots[i] != null &&
              slots[i]!.trim().isNotEmpty
          ? slots[i]!
          : '',
    );
  }

  /// 从磁盘还原九宫格；兼容旧版紧凑列表（无双占位）。
  static List<String?> decodePhotoGridSlots(List<String> stored) {
    if (stored.isEmpty) return List<String?>.filled(9, null);
    final gridLike =
        stored.length >= 9 || stored.any((s) => s.isEmpty);
    if (gridLike) {
      return List.generate(
        9,
        (i) => i < stored.length && stored[i].trim().isNotEmpty
            ? stored[i]
            : null,
      );
    }
    return List.generate(
      9,
      (i) => i < stored.length && stored[i].trim().isNotEmpty
          ? stored[i]
          : null,
    );
  }

  static Future<void> updateCollection(MemoryCollection collection) async {
    final list = await loadCollections();
    final i = list.indexWhere((c) => c.id == collection.id);
    if (i >= 0) {
      list[i] = collection;
      await saveCollections(list);
    }
  }

  /// 事件内有效照片张数（九宫格槽位中非空路径）。
  static int countPhotosInEvent(MemoryEvent e) {
    return decodePhotoGridSlots(e.photoPaths)
        .where((s) => s != null && s.trim().isNotEmpty)
        .length;
  }

  /// 时光集下所有事件的照片总数。
  static int countPhotosInCollection(List<MemoryEvent> events) {
    var sum = 0;
    for (final e in events) {
      sum += countPhotosInEvent(e);
    }
    return sum;
  }

  /// 九宫格展示位对应的编号（中心格 index 4 为 1 号）。
  static int gridSlotLabel(int gridIndex) {
    if (gridIndex == 4) return 1;
    return gridIndex < 4 ? gridIndex + 2 : gridIndex + 1;
  }

  /// 九宫格 1 号位（中心格 index 4）照片路径；兼容旧紧凑列表。
  static String? firstSlotPhotoPath(MemoryEvent e) {
    final slots = decodePhotoGridSlots(e.photoPaths);
    final center = slots[4];
    if (center != null &&
        center.trim().isNotEmpty &&
        File(center).existsSync()) {
      return center;
    }
    for (final p in slots) {
      if (p != null && p.trim().isNotEmpty && File(p).existsSync()) return p;
    }
    return null;
  }

  /// 事件全部有效照片路径（按九宫格槽位顺序）。
  static List<String> existingPhotoPaths(MemoryEvent e) {
    return decodePhotoGridSlots(e.photoPaths)
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty && File(p).existsSync())
        .toList();
  }

  static int countPhotosForCollectionId(
    String collectionId,
    List<MemoryEvent> allEvents,
  ) {
    var sum = 0;
    for (final e in allEvents) {
      if (e.collectionId == collectionId) {
        sum += countPhotosInEvent(e);
      }
    }
    return sum;
  }
}
