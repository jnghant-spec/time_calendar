import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/collection_sub_event.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';

/// 子事件已在目标事件集中关联。
class SubEventAlreadyInCollectionException implements Exception {
  SubEventAlreadyInCollectionException(this.collectionId);
  final String collectionId;
}

/// 时光集与纪念事件的本地持久化（JSON 数组，v2/v3 key）。
class MemoryService {
  MemoryService._();

  static const String prefsKeyCollections = 'memory_collections_v2';
  static const String prefsKeyEvents = 'memory_events_v2';
  static const String prefsKeyLinks = 'memory_collection_sub_events_v3';
  static const String _legacyCollectionsKey = 'memory_collections_v1';
  static const String _legacyEventsKey = 'memory_events_v1';
  static const String _v3MigrationFlag = 'memory_association_v3_migrated';

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
        m.remove('collectionId');
        list.add(MemoryEvent.fromJson(m));
      }
      await prefs.setString(
        prefsKeyEvents,
        jsonEncode(list.map((x) => x.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// 将 v2 单 collectionId 迁移为多对多关联表（幂等）。
  static Future<void> _migrateToAssociationV3IfNeeded(
    SharedPreferences prefs,
  ) async {
    if (prefs.getBool(_v3MigrationFlag) == true) return;

    await _migrateFromV1IfNeeded(prefs);

    final raw = prefs.getString(prefsKeyEvents);
    if (raw == null || raw.isEmpty) {
      await prefs.setString(prefsKeyLinks, '[]');
      await prefs.setBool(_v3MigrationFlag, true);
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await prefs.setBool(_v3MigrationFlag, true);
        return;
      }

      final links = <CollectionSubEvent>[];
      final cleanEvents = <MemoryEvent>[];
      final seen = <String>{};
      final sortCounters = <String, int>{};
      final now = DateTime.now();

      for (final e in decoded) {
        final m = Map<String, dynamic>.from(e as Map);
        final collectionId = m.remove('collectionId') as String?;
        m.remove('sortIndex');
        final event = MemoryEvent.fromJson(m);
        cleanEvents.add(event);

        if (collectionId == null || collectionId.isEmpty) continue;
        final key = '$collectionId|${event.id}';
        if (seen.contains(key)) continue;
        seen.add(key);
        final order = sortCounters[collectionId] ?? 0;
        sortCounters[collectionId] = order + 1;
        links.add(
          CollectionSubEvent(
            id: generateId('cse'),
            collectionId: collectionId,
            subEventId: event.id,
            sortOrder: order,
            addedAt: now,
          ),
        );
      }

      await prefs.setString(
        prefsKeyEvents,
        jsonEncode(cleanEvents.map((x) => x.toJson()).toList()),
      );
      await prefs.setString(
        prefsKeyLinks,
        jsonEncode(links.map((x) => x.toJson()).toList()),
      );
    } catch (_) {}

    await prefs.setBool(_v3MigrationFlag, true);
  }

  static Future<void> _ensureV3Migrated() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateToAssociationV3IfNeeded(prefs);
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
    final links = await loadLinks();
    final removedLinks =
        links.where((l) => l.collectionId == id).toList(growable: false);
    links.removeWhere((l) => l.collectionId == id);
    await saveLinks(links);

    final events = await loadEvents();
    for (final link in removedLinks) {
      final stillLinked =
          links.any((l) => l.subEventId == link.subEventId);
      if (!stillLinked) {
        events.removeWhere((e) => e.id == link.subEventId);
      }
    }
    await saveEvents(events);

    final collections = await loadCollections();
    collections.removeWhere((c) => c.id == id);
    await saveCollections(collections);
  }

  static Future<List<CollectionSubEvent>> loadLinks() async {
    await _ensureV3Migrated();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKeyLinks);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map(
            (e) => CollectionSubEvent.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLinks(List<CollectionSubEvent> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKeyLinks,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<List<MemoryEvent>> loadEvents() async {
    await _ensureV3Migrated();
    final prefs = await SharedPreferences.getInstance();
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

  static Future<MemoryEvent?> getEventById(String id) async {
    final all = await loadEvents();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  static Future<void> addEvent(MemoryEvent event) async {
    final list = await loadEvents();
    list.add(event);
    await saveEvents(list);
  }

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

  static Future<void> addEventToCollection(
    MemoryEvent event,
    String collectionId,
  ) async {
    await upsertEvent(event);
    await _ensureLink(
      subEventId: event.id,
      collectionId: collectionId,
    );
  }

  static Future<void> _ensureLink({
    required String subEventId,
    required String collectionId,
    bool failIfExists = false,
  }) async {
    final collections = await loadCollections();
    if (!collections.any((c) => c.id == collectionId)) {
      throw StateError('target collection not found');
    }
    final event = await getEventById(subEventId);
    if (event == null) {
      throw StateError('sub event not found');
    }

    final links = await loadLinks();
    final exists = links.any(
      (l) => l.collectionId == collectionId && l.subEventId == subEventId,
    );
    if (exists) {
      if (failIfExists) {
        throw SubEventAlreadyInCollectionException(collectionId);
      }
      return;
    }

    final sortOrder = links
        .where((l) => l.collectionId == collectionId)
        .length;

    links.add(
      CollectionSubEvent(
        id: generateId('cse'),
        collectionId: collectionId,
        subEventId: subEventId,
        sortOrder: sortOrder,
        addedAt: DateTime.now(),
      ),
    );
    await saveLinks(links);
  }

  static Future<void> joinSubEvent(
    String subEventId,
    String targetCollectionId,
  ) async {
    await _ensureLink(
      subEventId: subEventId,
      collectionId: targetCollectionId,
      failIfExists: true,
    );
  }

  static Future<void> deleteEvent(
    String id, {
    String? fromCollectionId,
  }) async {
    final links = await loadLinks();
    if (fromCollectionId != null) {
      links.removeWhere(
        (l) => l.subEventId == id && l.collectionId == fromCollectionId,
      );
      await saveLinks(links);
      final stillLinked = links.any((l) => l.subEventId == id);
      if (!stillLinked) {
        final events = await loadEvents();
        events.removeWhere((e) => e.id == id);
        await saveEvents(events);
      }
    } else {
      links.removeWhere((l) => l.subEventId == id);
      await saveLinks(links);
      final events = await loadEvents();
      events.removeWhere((e) => e.id == id);
      await saveEvents(events);
    }
  }

  static Future<List<MemoryEvent>> getEventsByCollection(
    String collectionId,
  ) async {
    final links = await loadLinks();
    final events = await loadEvents();
    final eventMap = {for (final e in events) e.id: e};
    final items = <MemoryEvent>[];
    final collectionLinks = links
        .where((l) => l.collectionId == collectionId)
        .toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        return a.addedAt.compareTo(b.addedAt);
      });
    for (final link in collectionLinks) {
      final event = eventMap[link.subEventId];
      if (event != null) items.add(event);
    }
    return items;
  }

  static Future<List<MemoryEvent>> getEventsSorted(String collectionId) async {
    final items = await getEventsByCollection(collectionId);
    items.sort((a, b) {
      final c = a.date.compareTo(b.date);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });
    return items;
  }

  static Future<List<String>> getCollectionIdsBySubEventId(
    String subEventId,
  ) async {
    final links = await loadLinks();
    return links
        .where((l) => l.subEventId == subEventId)
        .map((l) => l.collectionId)
        .toList();
  }

  static Future<int> getSubEventCountByCollectionId(String collectionId) async {
    final links = await loadLinks();
    return links.where((l) => l.collectionId == collectionId).length;
  }

  static Future<int> countPhotosForCollectionId(String collectionId) async {
    final events = await getEventsByCollection(collectionId);
    return countPhotosInCollection(events);
  }

  static DateTime _latestChildDate(
    String collectionId,
    List<MemoryEvent> collectionEvents,
  ) {
    DateTime? max;
    for (final e in collectionEvents) {
      if (max == null || e.date.isAfter(max)) max = e.date;
    }
    return max ?? DateTime.utc(1970);
  }

  static Future<List<MemoryCollection>> getSortedCollections() async {
    final collections = await loadCollections();
    final decorated = <({MemoryCollection c, DateTime latest})>[];
    for (final c in collections) {
      final ev = await getEventsByCollection(c.id);
      decorated.add((c: c, latest: _latestChildDate(c.id, ev)));
    }
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

  static MemoryEvent cloneFromListEvent(ListEvent event) {
    final paths = event.photoPaths;
    final slots = List<String?>.filled(9, null);
    for (var i = 0; i < paths.length && i < 9; i++) {
      slots[i] = paths[i];
    }
    return MemoryEvent(
      id: _newId('mev'),
      title: event.title,
      location: null,
      date: effectiveDate(event),
      photoPaths: encodePhotoGridSlots(slots),
    );
  }

  static Future<bool> updateCollection(MemoryCollection collection) async {
    final list = await loadCollections();
    final i = list.indexWhere((c) => c.id == collection.id);
    if (i >= 0) {
      list[i] = collection;
      await saveCollections(list);
      return true;
    }
    return false;
  }

  /// 删除标签时解除事件集关联（tagId 置空字符串，非级联删除）。
  static Future<int> clearTagIdFromCollections(String tagId) async {
    final list = await loadCollections();
    var count = 0;
    for (var i = 0; i < list.length; i++) {
      if (list[i].tagId == tagId) {
        list[i] = list[i].copyWith(tagId: '');
        count++;
      }
    }
    if (count > 0) {
      await saveCollections(list);
    }
    return count;
  }

  static int countPhotosInEvent(MemoryEvent e) {
    return decodePhotoGridSlots(e.photoPaths)
        .where((s) => s != null && s.trim().isNotEmpty)
        .length;
  }

  static int countPhotosInCollection(List<MemoryEvent> events) {
    var sum = 0;
    for (final e in events) {
      sum += countPhotosInEvent(e);
    }
    return sum;
  }

  static int gridSlotLabel(int gridIndex) {
    if (gridIndex == 4) return 1;
    return gridIndex < 4 ? gridIndex + 2 : gridIndex + 1;
  }

  static bool eventHasCoverPhoto(MemoryEvent e) {
    final slots = decodePhotoGridSlots(e.photoPaths);
    final center = slots[4];
    return center != null &&
        center.trim().isNotEmpty &&
        File(center).existsSync();
  }

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

  static List<String> existingPhotoPaths(MemoryEvent e) {
    final slots = decodePhotoGridSlots(e.photoPaths);
    final items = <({int slot, String path})>[];
    for (var i = 0; i < slots.length; i++) {
      final p = slots[i];
      if (p == null || p.trim().isEmpty || !File(p).existsSync()) continue;
      items.add((slot: gridSlotLabel(i), path: p));
    }
    items.sort((a, b) => a.slot.compareTo(b.slot));
    return items.map((item) => item.path).toList();
  }

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

  static List<ListEvent>? _pendingBootstrapListEvents;

  static const String defaultOtherTagId = 'other';
  static const Color _kDefaultTagColor = Color(0xFF9CA3AF);

  /// 确保存在「其他」默认标签；若已有同名或同 id 则复用。
  static Future<String> ensureDefaultOtherTag() async {
    final tags = await TagService.loadTags();
    for (final t in tags) {
      if (t.id == defaultOtherTagId || t.name.trim() == '其他') {
        return t.id;
      }
    }
    if (tags.length >= TagService.maxTagCount) {
      return tags.isNotEmpty ? tags.first.id : defaultOtherTagId;
    }
    final now = DateTime.now();
    final other = ReminderTag(
      id: defaultOtherTagId,
      name: '其他',
      accentColor: _kDefaultTagColor,
      iconBgColor: const Color(0xFFF1F5F9),
      sortOrder: tags.length,
      isDefault: false,
      createdAt: now,
      iconName: 'star',
    );
    tags.add(other);
    await TagService.saveTags(tags);
    return defaultOtherTagId;
  }

  /// 修复事件集等持久化数据中的无效 [tagId]（幂等）。
  static Future<void> repairOrphanTagAssociations() async {
    final defaultId = await ensureDefaultOtherTag();
    final tags = await TagService.loadTags();
    final validIds = tags.map((t) => t.id).toSet();

    final collections = await loadCollections();
    var colsChanged = false;
    final fixedCols = collections.map((c) {
      if (c.tagId.isEmpty || !validIds.contains(c.tagId)) {
        colsChanged = true;
        return c.copyWith(tagId: defaultId);
      }
      return c;
    }).toList();
    if (colsChanged) {
      await saveCollections(fixedCols);
    }
  }

  /// 将清单提醒中无效 [tagId] 关联到默认「其他」标签（幂等）。
  static Future<List<ListEvent>> repairListEvents(List<ListEvent> events) async {
    final defaultId = await ensureDefaultOtherTag();
    await TagService.loadTags();
    var changed = false;
    final fixed = <ListEvent>[];
    for (final e in events) {
      if (e.tagId.isEmpty || TagService.getTagById(e.tagId) == null) {
        fixed.add(e.copyWith(tagId: defaultId));
        changed = true;
      } else {
        fixed.add(e);
      }
    }
    if (!changed) return events;
    return fixed;
  }

  /// 清单页首帧消费预设提醒（仅 [ensureDemoSeedIfEmpty] 写入一次）。
  static List<ListEvent>? consumeBootstrapListEvents() {
    final list = _pendingBootstrapListEvents;
    _pendingBootstrapListEvents = null;
    return list;
  }

  /// 标签表为空时写入 7 个预设标签、示例提醒与时光集数据（幂等：仅空表触发）。
  static Future<void> ensureDemoSeedIfEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    final tagsRaw = prefs.getString(TagService.prefsKey);
    if (tagsRaw != null && tagsRaw.isNotEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final tags = _buildPresetTags(now);
    await prefs.setString(
      TagService.prefsKey,
      jsonEncode(tags.map((e) => e.toJson()).toList()),
    );

    if ((prefs.getString(prefsKeyCollections) ?? '').isEmpty) {
      await _seedPresetMemoryData(now);
    }

    _pendingBootstrapListEvents = _buildPresetListEvents(today);
  }

  static List<ReminderTag> _buildPresetTags(DateTime now) {
    return [
      ReminderTag(
        id: 'birthday',
        name: '生日',
        accentColor: const Color(0xFFFF9F43),
        iconBgColor: const Color(0xFFFFF3E6),
        sortOrder: 0,
        isDefault: true,
        createdAt: now,
        iconName: 'celebration',
        isSystemTag: true,
      ),
      ReminderTag(
        id: 'work',
        name: '工作',
        accentColor: const Color(0xFF54A0FF),
        iconBgColor: const Color(0xFFEAF3FF),
        sortOrder: 1,
        isDefault: true,
        createdAt: now,
        iconName: 'work',
      ),
      ReminderTag(
        id: 'travel',
        name: '旅行',
        accentColor: const Color(0xFF10B981),
        iconBgColor: const Color(0xFFECFDF5),
        sortOrder: 2,
        isDefault: true,
        createdAt: now,
        iconName: 'flight',
      ),
      ReminderTag(
        id: 'health',
        name: '健康',
        accentColor: const Color(0xFFEF4444),
        iconBgColor: const Color(0xFFFEE2E2),
        sortOrder: 3,
        isDefault: true,
        createdAt: now,
        iconName: 'sports',
      ),
      ReminderTag(
        id: 'study',
        name: '学习',
        accentColor: const Color(0xFFA29BFE),
        iconBgColor: const Color(0xFFF3F0FF),
        sortOrder: 4,
        isDefault: true,
        createdAt: now,
        iconName: 'school',
      ),
      ReminderTag(
        id: 'family',
        name: '家庭',
        accentColor: const Color(0xFFFD79A8),
        iconBgColor: const Color(0xFFFFF0F6),
        sortOrder: 5,
        isDefault: true,
        createdAt: now,
        iconName: 'home',
      ),
      ReminderTag(
        id: 'other',
        name: '其他',
        accentColor: const Color(0xFF9CA3AF),
        iconBgColor: const Color(0xFFF1F5F9),
        sortOrder: 6,
        isDefault: true,
        createdAt: now,
        iconName: 'star',
      ),
    ];
  }

  static List<ListEvent> _buildPresetListEvents(DateTime today) {
    DateTime onDay(int offset) =>
        DateTime(today.year, today.month, today.day + offset);

    return [
      ListEvent(
        id: 'demo_mom_birthday',
        title: '妈妈的生日',
        baseDate: onDay(300),
        tagId: 'birthday',
        isPinned: true,
        isLunarRecurring: true,
        isLunarDate: true,
        repeatRule: EventRepeatRule.yearly,
        reminderType: EventReminderType.advanceAndSameDay,
        advanceDaysOption: EventAdvanceDaysOption.oneDay,
      ),
      ListEvent(
        id: 'demo_exam',
        title: '考研倒计时',
        baseDate: onDay(200),
        tagId: 'study',
        repeatRule: EventRepeatRule.none,
        reminderType: EventReminderType.sameDayOnly,
      ),
      ListEvent(
        id: 'demo_run',
        title: '晨跑打卡',
        baseDate: today,
        tagId: 'health',
        repeatRule: EventRepeatRule.daily,
        reminderType: EventReminderType.sameDayOnly,
        sameDayTimeHm: '07:00',
      ),
      ListEvent(
        id: 'demo_weekly',
        title: '团队周会',
        baseDate: onDay(2),
        tagId: 'work',
        repeatRule: EventRepeatRule.weekly,
        reminderType: EventReminderType.sameDayOnly,
      ),
      ListEvent(
        id: 'demo_card',
        title: '还信用卡',
        baseDate: onDay(10),
        tagId: 'other',
        repeatRule: EventRepeatRule.monthly,
        reminderType: EventReminderType.advanceOnly,
      ),
    ];
  }

  static Future<void> _seedPresetMemoryData(DateTime now) async {
    const collectionId = 'demo_col_beijing_2026';
    const subTam = 'demo_ev_tiananmen';
    const subGugong = 'demo_ev_gugong';
    const subChangcheng = 'demo_ev_changcheng';

    final collection = MemoryCollection(
      id: collectionId,
      name: '2026 北京之旅',
      tagId: 'travel',
      isPinned: true,
      createdAt: now,
    );

    final events = [
      MemoryEvent(
        id: subTam,
        title: '天安门',
        location: '北京',
        date: DateTime(2026, 10, 1),
        photoPaths: const ['', '', '', '', 'demo_photo_tiananmen', '', '', '', ''],
      ),
      MemoryEvent(
        id: subGugong,
        title: '故宫',
        location: '北京',
        date: DateTime(2026, 10, 2),
        photoPaths: const ['', '', '', '', 'demo_photo_gugong', '', '', '', ''],
      ),
      MemoryEvent(
        id: subChangcheng,
        title: '长城',
        location: '北京',
        date: DateTime(2026, 10, 3),
        photoPaths: const ['', '', '', '', 'demo_photo_changcheng', '', '', '', ''],
      ),
    ];

    final links = [
      CollectionSubEvent(
        id: 'demo_link_tam',
        collectionId: collectionId,
        subEventId: subTam,
        sortOrder: 0,
        addedAt: now,
      ),
      CollectionSubEvent(
        id: 'demo_link_gugong',
        collectionId: collectionId,
        subEventId: subGugong,
        sortOrder: 1,
        addedAt: now,
      ),
      CollectionSubEvent(
        id: 'demo_link_changcheng',
        collectionId: collectionId,
        subEventId: subChangcheng,
        sortOrder: 2,
        addedAt: now,
      ),
    ];

    await saveCollections([collection]);
    await saveEvents(events);
    await saveLinks(links);
  }
}
