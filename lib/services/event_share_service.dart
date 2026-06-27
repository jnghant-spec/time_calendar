import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/event_share_record.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/share_contact.dart';
import 'package:time_calendar/services/event_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/services/user_session.dart';

/// 好友分享提醒：本地持久化（SharedPreferences），待后端对接后可替换。
class EventShareService {
  EventShareService._();

  static const String outgoingPrefsKey = 'tc.outgoing_shares_v1';
  static const String incomingPrefsKey = 'tc.incoming_shares_v1';

  static List<OutgoingShareBundle> _outgoing = [];
  static List<IncomingSharePayload> _incoming = [];
  static bool _loaded = false;
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void _notifyChanged() {
    revision.value++;
  }

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _outgoing = _decodeOutgoing(prefs.getString(outgoingPrefsKey));
    _incoming = _decodeIncoming(prefs.getString(incomingPrefsKey));
    _loaded = true;
  }

  static Future<void> resetForTests() async {
    _outgoing = [];
    _incoming = [];
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(outgoingPrefsKey);
    await prefs.remove(incomingPrefsKey);
  }

  static List<OutgoingShareBundle> _decodeOutgoing(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          OutgoingShareBundle.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  static List<IncomingSharePayload> _decodeIncoming(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          IncomingSharePayload.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      outgoingPrefsKey,
      jsonEncode(_outgoing.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      incomingPrefsKey,
      jsonEncode(_incoming.map((e) => e.toJson()).toList()),
    );
  }

  static String _newIncomingId() =>
      'incoming_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';

  static String _newAcceptedEventId() =>
      'accepted_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';

  static String _normalizePhone(String phone) => phone.trim();

  static bool _phonesMatch(String a, String b) =>
      _normalizePhone(a) == _normalizePhone(b);

  static OutgoingShareBundle? _bundleForEvent(String eventId) {
    for (final b in _outgoing) {
      if (b.eventId == eventId) return b;
    }
    return null;
  }

  static void _upsertBundle(OutgoingShareBundle bundle) {
    final i = _outgoing.indexWhere((b) => b.eventId == bundle.eventId);
    if (i >= 0) {
      _outgoing[i] = bundle;
    } else {
      _outgoing.add(bundle);
    }
  }

  /// 分享方：创建对外分享记录，并为 App 内联系人写入 incoming pending。
  static Future<void> createOutgoingShare({
    required ListEvent event,
    required List<ShareContact> recipients,
    required Set<String> registeredPhones,
  }) async {
    await ensureLoaded();
    await UserSession.instance.ensureInitialized();

    final now = DateTime.now();
    final senderName = UserSession.instance.nickname.trim();
    final senderPhone = UserSession.instance.phone.trim();
    final senderUserId = senderPhone;

    final existing = _bundleForEvent(event.id);
    final records = List<ShareOutgoingRecord>.from(existing?.records ?? const []);

    for (final contact in recipients) {
      final phone = _normalizePhone(contact.phone);
      if (phone.isEmpty) continue;

      final name = contact.name.trim().isNotEmpty ? contact.name.trim() : phone;
      String? incomingId;

      if (registeredPhones.contains(phone)) {
        final pendingIdx = _incoming.indexWhere(
          (p) =>
              p.sourceEventId == event.id &&
              _phonesMatch(p.recipientPhone, phone) &&
              p.status == ShareRecipientStatus.pending,
        );
        if (pendingIdx >= 0) {
          incomingId = _incoming[pendingIdx].id;
          _incoming[pendingIdx] = _incoming[pendingIdx].copyWith(
            eventSnapshot: event,
            sharedAt: now,
            senderUserId: senderUserId,
            senderName: senderName,
            senderPhone: senderPhone,
          );
        } else {
          incomingId = _newIncomingId();
          _incoming.add(
            IncomingSharePayload(
              id: incomingId,
              sourceEventId: event.id,
              eventSnapshot: event,
              senderUserId: senderUserId,
              senderName: senderName,
              senderPhone: senderPhone,
              recipientPhone: phone,
              sharedAt: now,
            ),
          );
        }
      }

      final pendingRecordIdx = records.indexWhere(
        (r) =>
            _phonesMatch(r.recipientPhone, phone) &&
            r.status == ShareRecipientStatus.pending,
      );
      if (pendingRecordIdx >= 0) {
        records[pendingRecordIdx] = records[pendingRecordIdx].copyWith(
          recipientName: name,
          sharedAt: now,
          incomingShareId: incomingId ?? records[pendingRecordIdx].incomingShareId,
        );
      } else {
        records.add(
          ShareOutgoingRecord(
            recipientPhone: phone,
            recipientName: name,
            sharedAt: now,
            incomingShareId: incomingId,
          ),
        );
      }
    }

    _upsertBundle(OutgoingShareBundle(eventId: event.id, records: records));
    await _persist();
    _notifyChanged();
  }

  static List<ShareOutgoingRecord> listOutgoingRecords(String eventId) {
    final bundle = _bundleForEvent(eventId);
    if (bundle == null) return const [];
    return List<ShareOutgoingRecord>.from(bundle.records);
  }

  static Future<List<ShareOutgoingRecord>> loadOutgoingRecords(
    String eventId,
  ) async {
    await ensureLoaded();
    return listOutgoingRecords(eventId);
  }

  static int _incomingIndex(String id) =>
      _incoming.indexWhere((e) => e.id == id);

  static void _updateOutgoingStatus({
    required String sourceEventId,
    required String recipientPhone,
    required ShareRecipientStatus status,
    DateTime? acceptedAt,
    String? incomingShareId,
  }) {
    final bundle = _bundleForEvent(sourceEventId);
    if (bundle == null) return;

    final updated = bundle.records.map((r) {
      if (incomingShareId != null &&
          r.incomingShareId != null &&
          r.incomingShareId == incomingShareId) {
        return r.copyWith(
          status: status,
          acceptedAt: acceptedAt,
        );
      }
      if (incomingShareId == null &&
          _phonesMatch(r.recipientPhone, recipientPhone)) {
        return r.copyWith(
          status: status,
          acceptedAt: acceptedAt,
        );
      }
      return r;
    }).toList();

    _upsertBundle(OutgoingShareBundle(eventId: sourceEventId, records: updated));
  }

  static List<IncomingSharePayload> _pendingForCurrentUser() {
    final phone = UserSession.instance.phone.trim();
    if (phone.isEmpty) return const [];
    return _incoming
        .where(
          (e) =>
              _phonesMatch(e.recipientPhone, phone) &&
              e.status == ShareRecipientStatus.pending,
        )
        .toList()
      ..sort((a, b) => a.sharedAt.compareTo(b.sharedAt));
  }

  static Future<List<IncomingSharePayload>> getPendingForShareManagement() async {
    await ensureLoaded();
    await UserSession.instance.ensureInitialized();
    return _pendingForCurrentUser();
  }

  static Future<IncomingSharePayload?> getPendingIncomingForBanner() async {
    await ensureLoaded();
    await UserSession.instance.ensureInitialized();
    if (!UserSession.instance.acceptOthersShareDefault) return null;
    final pending = _pendingForCurrentUser();
    return pending.isEmpty ? null : pending.first;
  }

  /// 接受分享：生成本地 ListEvent 并回写 outgoing / incoming 状态。
  static Future<ListEvent?> acceptIncoming(String incomingId) async {
    await ensureLoaded();
    await UserSession.instance.ensureInitialized();

    final index = _incomingIndex(incomingId);
    if (index < 0) return null;

    final payload = _incoming[index];
    final currentPhone = UserSession.instance.phone.trim();
    final events = await EventService.loadAllEvents();

    ListEvent? findExistingAccepted() {
      for (final existing in events) {
        if (!existing.isShareIncoming) continue;
        if (existing.sharedSourceEventId != payload.sourceEventId) continue;
        final owner = existing.ownerPhone?.trim() ?? '';
        if (!_phonesMatch(owner, currentPhone)) continue;
        return existing;
      }
      return null;
    }

    if (payload.status != ShareRecipientStatus.pending) {
      return findExistingAccepted();
    }

    final existingAccepted = findExistingAccepted();
    if (existingAccepted != null) {
      final acceptedAt = DateTime.now();
      _incoming[index] = payload.copyWith(
        status: ShareRecipientStatus.accepted,
        acceptedAt: acceptedAt,
      );
      _updateOutgoingStatus(
        sourceEventId: payload.sourceEventId,
        recipientPhone: payload.recipientPhone,
        incomingShareId: payload.id,
        status: ShareRecipientStatus.accepted,
        acceptedAt: acceptedAt,
      );
      await _persist();
      _notifyChanged();
      return existingAccepted;
    }

    final acceptedAt = DateTime.now();
    _incoming[index] = payload.copyWith(
      status: ShareRecipientStatus.accepted,
      acceptedAt: acceptedAt,
    );

    _updateOutgoingStatus(
      sourceEventId: payload.sourceEventId,
      recipientPhone: payload.recipientPhone,
      incomingShareId: payload.id,
      status: ShareRecipientStatus.accepted,
      acceptedAt: acceptedAt,
    );

    await _persist();

    final snapshot = payload.eventSnapshot;
    final newEvent = snapshot.copyWith(
      id: _newAcceptedEventId(),
      tagId: TagService.sharedIncomingTagId,
      isShareIncoming: true,
      sharedFromUserId: payload.senderUserId,
      sharedFromUserName: payload.senderName,
      sharedFromUserPhone: payload.senderPhone,
      sharedAt: acceptedAt,
      sharedSourceEventId: payload.sourceEventId,
      ownerPhone: currentPhone,
      pendingShareAfterAdd: false,
    );

    events.add(newEvent);
    await EventService.saveAllEvents(events);
    _notifyChanged();
    return newEvent;
  }

  static Future<bool> dismissIncoming(String incomingId) async {
    await ensureLoaded();
    final index = _incomingIndex(incomingId);
    if (index < 0) return false;

    final payload = _incoming[index];
    if (payload.status != ShareRecipientStatus.pending) return false;

    _incoming[index] = payload.copyWith(status: ShareRecipientStatus.dismissed);

    _updateOutgoingStatus(
      sourceEventId: payload.sourceEventId,
      recipientPhone: payload.recipientPhone,
      incomingShareId: payload.id,
      status: ShareRecipientStatus.dismissed,
    );

    await _persist();
    _notifyChanged();
    return true;
  }
}
