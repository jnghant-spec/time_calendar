import 'package:time_calendar/models/list_event.dart';

enum ShareRecipientStatus { pending, accepted, dismissed }

ShareRecipientStatus shareRecipientStatusFromJson(String? raw) {
  return ShareRecipientStatus.values.asNameMap()[raw] ??
      ShareRecipientStatus.pending;
}

/// 分享方：单条对外分享记录（按 eventId 索引）。
class ShareOutgoingRecord {
  const ShareOutgoingRecord({
    required this.recipientPhone,
    required this.recipientName,
    required this.sharedAt,
    this.status = ShareRecipientStatus.pending,
    this.acceptedAt,
    this.incomingShareId,
  });

  final String recipientPhone;
  final String recipientName;
  final DateTime sharedAt;
  final ShareRecipientStatus status;
  final DateTime? acceptedAt;
  /// 关联接收方 pending 记录 id，便于接受后回写状态。
  final String? incomingShareId;

  ShareOutgoingRecord copyWith({
    String? recipientPhone,
    String? recipientName,
    DateTime? sharedAt,
    ShareRecipientStatus? status,
    DateTime? acceptedAt,
    String? incomingShareId,
    bool clearAcceptedAt = false,
  }) {
    return ShareOutgoingRecord(
      recipientPhone: recipientPhone ?? this.recipientPhone,
      recipientName: recipientName ?? this.recipientName,
      sharedAt: sharedAt ?? this.sharedAt,
      status: status ?? this.status,
      acceptedAt: clearAcceptedAt ? null : (acceptedAt ?? this.acceptedAt),
      incomingShareId: incomingShareId ?? this.incomingShareId,
    );
  }

  Map<String, dynamic> toJson() => {
        'recipientPhone': recipientPhone,
        'recipientName': recipientName,
        'sharedAt': sharedAt.toIso8601String(),
        'status': status.name,
        if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
        if (incomingShareId != null) 'incomingShareId': incomingShareId,
      };

  factory ShareOutgoingRecord.fromJson(Map<String, dynamic> m) {
    return ShareOutgoingRecord(
      recipientPhone: m['recipientPhone'] as String? ?? '',
      recipientName: m['recipientName'] as String? ?? '',
      sharedAt: DateTime.tryParse(m['sharedAt'] as String? ?? '') ??
          DateTime.now(),
      status: shareRecipientStatusFromJson(m['status'] as String?),
      acceptedAt: m['acceptedAt'] != null
          ? DateTime.tryParse(m['acceptedAt'] as String)
          : null,
      incomingShareId: m['incomingShareId'] as String?,
    );
  }
}

/// 接收方：待处理 / 已处理的分享载荷。
class IncomingSharePayload {
  const IncomingSharePayload({
    required this.id,
    required this.sourceEventId,
    required this.eventSnapshot,
    required this.senderUserId,
    required this.senderName,
    required this.senderPhone,
    required this.recipientPhone,
    required this.sharedAt,
    this.status = ShareRecipientStatus.pending,
    this.acceptedAt,
  });

  final String id;
  final String sourceEventId;
  final ListEvent eventSnapshot;
  final String senderUserId;
  final String senderName;
  final String senderPhone;
  final String recipientPhone;
  final DateTime sharedAt;
  final ShareRecipientStatus status;
  final DateTime? acceptedAt;

  IncomingSharePayload copyWith({
    String? id,
    String? sourceEventId,
    ListEvent? eventSnapshot,
    String? senderUserId,
    String? senderName,
    String? senderPhone,
    String? recipientPhone,
    DateTime? sharedAt,
    ShareRecipientStatus? status,
    DateTime? acceptedAt,
    bool clearAcceptedAt = false,
  }) {
    return IncomingSharePayload(
      id: id ?? this.id,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      eventSnapshot: eventSnapshot ?? this.eventSnapshot,
      senderUserId: senderUserId ?? this.senderUserId,
      senderName: senderName ?? this.senderName,
      senderPhone: senderPhone ?? this.senderPhone,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      sharedAt: sharedAt ?? this.sharedAt,
      status: status ?? this.status,
      acceptedAt: clearAcceptedAt ? null : (acceptedAt ?? this.acceptedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceEventId': sourceEventId,
        'eventSnapshot': eventSnapshot.toJson(),
        'senderUserId': senderUserId,
        'senderName': senderName,
        'senderPhone': senderPhone,
        'recipientPhone': recipientPhone,
        'sharedAt': sharedAt.toIso8601String(),
        'status': status.name,
        if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
      };

  factory IncomingSharePayload.fromJson(Map<String, dynamic> m) {
    return IncomingSharePayload(
      id: m['id'] as String,
      sourceEventId: m['sourceEventId'] as String,
      eventSnapshot: ListEvent.fromJson(
        Map<String, dynamic>.from(m['eventSnapshot'] as Map),
      ),
      senderUserId: m['senderUserId'] as String? ?? '',
      senderName: m['senderName'] as String? ?? '',
      senderPhone: m['senderPhone'] as String? ?? '',
      recipientPhone: m['recipientPhone'] as String? ?? '',
      sharedAt: DateTime.tryParse(m['sharedAt'] as String? ?? '') ??
          DateTime.now(),
      status: shareRecipientStatusFromJson(m['status'] as String?),
      acceptedAt: m['acceptedAt'] != null
          ? DateTime.tryParse(m['acceptedAt'] as String)
          : null,
    );
  }
}

class OutgoingShareBundle {
  const OutgoingShareBundle({
    required this.eventId,
    required this.records,
  });

  final String eventId;
  final List<ShareOutgoingRecord> records;

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'records': records.map((e) => e.toJson()).toList(),
      };

  factory OutgoingShareBundle.fromJson(Map<String, dynamic> m) {
    final raw = m['records'] as List<dynamic>? ?? const [];
    return OutgoingShareBundle(
      eventId: m['eventId'] as String,
      records: [
        for (final item in raw)
          ShareOutgoingRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
      ],
    );
  }
}
