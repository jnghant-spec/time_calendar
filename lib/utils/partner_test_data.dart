import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/collection_sub_event.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/models/partner_relation.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/models/share_contact.dart';
import 'package:time_calendar/services/event_service.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/tag_service.dart';

/// 伴侣共享 UI 模拟器验证用测试数据（临时；验证完成后移除 [ListPage] 中的调用）。
/// TODO 验证完成后移除
class PartnerTestData {
  PartnerTestData._();

  static const String _kTagName = '纪念日';
  static const Color _kPartnerAccent = Color(0xFFEF4444);
  static const Color _kPartnerIconBg = Color(0xFFFEE2E2);

  static const String _kEventAnniversary = 'partner_test_anniversary';
  static const String _kEventFirstDate = 'partner_test_first_date';
  static const String _kEventBirthday = 'partner_test_birthday';
  static const String _kCollectionTravel = 'partner_test_travel';
  static const String _kSubBeijing = 'partner_test_beijing';
  static const String _kSubShanghai = 'partner_test_shanghai';
  static const String _kSubGuangzhou = 'partner_test_guangzhou';
  static const String _kPrefsContacts = 'tc.share_management.contacts_v1';
  static const String _kZhangSanPhone = '13800138000';
  static const String _kZhangSanName = '张三';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 写入伴侣标签、关系、3 条清单提醒与 1 个含 3 个子事件的时光集（幂等）。
  static Future<void> generate() async {
    final tagId = await _ensurePartnerTagId();
    await _ensurePartnerRelation();

    await _ensureListEvents(tagId);
    await _ensureTravelCollection(tagId);

    await _ensureZhangSanContact();
    await TagService.setPartnerRelation(
      const PartnerRelation(
        status: PartnerStatus.accepted,
        partnerContactId: _kZhangSanPhone,
        partnerName: _kZhangSanName,
      ),
    );
  }

  static Future<String> _ensurePartnerTagId() async {
    final tags = await TagService.loadTags();
    for (final t in tags) {
      if (t.isPartnerTag && t.name == _kTagName) return t.id;
    }

    ReminderTag? existingPartner;
    for (final t in tags) {
      if (t.isPartnerTag) {
        existingPartner = t;
        break;
      }
    }

    if (existingPartner != null) {
      final updated = existingPartner.copyWith(
        name: _kTagName,
        accentColor: _kPartnerAccent,
        iconBgColor: _kPartnerIconBg,
        isPartnerTag: true,
      );
      await TagService.updateTag(updated);
      return updated.id;
    }

    final now = DateTime.now();
    final tag = ReminderTag(
      id: TagService.newTagId(),
      name: _kTagName,
      accentColor: _kPartnerAccent,
      iconBgColor: _kPartnerIconBg,
      sortOrder: tags.length,
      isDefault: false,
      createdAt: now,
      isPartnerTag: true,
    );
    await TagService.addTag(tag);
    return tag.id;
  }

  static Future<void> _ensurePartnerRelation() async {
    if (TagService.isPartnerRelationAccepted()) return;
    await TagService.setPartnerRelation(
      const PartnerRelation(
        status: PartnerStatus.accepted,
        partnerName: '宝宝',
      ),
    );
  }

  static Future<void> _ensureZhangSanContact() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPrefsContacts);
    final contacts = <ShareContact>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            contacts.add(ShareContact.fromJson(e));
          } else if (e is Map) {
            contacts.add(
              ShareContact.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ),
            );
          }
        }
      } catch (_) {}
    }
    if (contacts.any((c) => c.phone == _kZhangSanPhone)) return;
    contacts.insert(
      0,
      ShareContact(name: _kZhangSanName, phone: _kZhangSanPhone),
    );
    await p.setString(
      _kPrefsContacts,
      jsonEncode(contacts.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> _ensureListEvents(String tagId) async {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final yesterday = now.subtract(const Duration(days: 1));
    final dayBeforeYesterday = now.subtract(const Duration(days: 2));

    final seeds = <ListEvent>[
      ListEvent(
        id: _kEventAnniversary,
        title: '结婚纪念日',
        baseDate: today.add(const Duration(days: 5)),
        tagId: tagId,
        lastModifiedByName: '宝宝',
        lastModifiedAt: yesterday,
      ),
      ListEvent(
        id: _kEventFirstDate,
        title: '第一次约会',
        baseDate: today.add(const Duration(days: 10)),
        tagId: tagId,
        lastModifiedByName: '宝宝',
        lastModifiedAt: dayBeforeYesterday,
      ),
      ListEvent(
        id: _kEventBirthday,
        title: '伴侣生日',
        baseDate: today.add(const Duration(days: 20)),
        tagId: tagId,
        eventType: EventType.birthday,
      ),
    ];

    final existing = await EventService.loadAllEvents();
    final ids = existing.map((e) => e.id).toSet();
    var changed = false;
    for (final seed in seeds) {
      if (!ids.contains(seed.id)) {
        existing.add(seed);
        changed = true;
      }
    }
    if (changed) {
      await EventService.saveAllEvents(existing);
    }
  }

  static Future<void> _ensureTravelCollection(String tagId) async {
    final collections = await MemoryService.loadCollections();
    if (collections.any((c) => c.id == _kCollectionTravel)) return;

    final now = DateTime.now();
    final today = _dateOnly(now);
    final yesterday = now.subtract(const Duration(days: 1));

    final collection = MemoryCollection(
      id: _kCollectionTravel,
      name: '我们的旅行',
      tagId: tagId,
      createdAt: now,
      lastModifiedByName: '宝宝',
      lastModifiedAt: yesterday,
    );

    final events = [
      MemoryEvent(
        id: _kSubBeijing,
        title: '北京站',
        location: '北京',
        date: today.subtract(const Duration(days: 70)),
      ),
      MemoryEvent(
        id: _kSubShanghai,
        title: '上海站',
        location: '上海',
        date: today.subtract(const Duration(days: 35)),
      ),
      MemoryEvent(
        id: _kSubGuangzhou,
        title: '广州站',
        location: '广州',
        date: today.subtract(const Duration(days: 7)),
      ),
    ];

    final links = [
      CollectionSubEvent(
        id: '${_kCollectionTravel}_link_0',
        collectionId: _kCollectionTravel,
        subEventId: _kSubBeijing,
        sortOrder: 0,
        addedAt: yesterday,
      ),
      CollectionSubEvent(
        id: '${_kCollectionTravel}_link_1',
        collectionId: _kCollectionTravel,
        subEventId: _kSubShanghai,
        sortOrder: 1,
        addedAt: yesterday,
      ),
      CollectionSubEvent(
        id: '${_kCollectionTravel}_link_2',
        collectionId: _kCollectionTravel,
        subEventId: _kSubGuangzhou,
        sortOrder: 2,
        addedAt: yesterday,
      ),
    ];

    await MemoryService.addCollection(collection);

    final allEvents = await MemoryService.loadEvents();
    allEvents.addAll(events);
    await MemoryService.saveEvents(allEvents);

    final allLinks = await MemoryService.loadLinks();
    allLinks.addAll(links);
    await MemoryService.saveLinks(allLinks);
  }
}
