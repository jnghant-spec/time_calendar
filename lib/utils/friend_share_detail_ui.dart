import 'package:flutter/material.dart';
import 'package:time_calendar/models/event_share_record.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/services/event_share_service.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/utils/event_owner_filter.dart';
import 'package:time_calendar/utils/partner_share_detail_ui.dart';

String buildOutgoingShareRecordLine(ShareOutgoingRecord record) {
  final name = record.recipientName.trim().isNotEmpty
      ? record.recipientName.trim()
      : record.recipientPhone;
  final time = formatPartnerModifiedAt(record.sharedAt);
  switch (record.status) {
    case ShareRecipientStatus.accepted:
      final at = record.acceptedAt ?? record.sharedAt;
      return '$name · ${formatPartnerModifiedAt(at)} 已接收';
    case ShareRecipientStatus.dismissed:
      return '$name · $time 已忽略';
    case ShareRecipientStatus.pending:
      return '$name · $time 等待确认';
  }
}

List<ShareOutgoingRecord> dedupeOutgoingRecordsByRecipient(
  List<ShareOutgoingRecord> records,
) {
  final latestByPhone = <String, ShareOutgoingRecord>{};
  for (final record in records) {
    final phone = record.recipientPhone.trim();
    if (phone.isEmpty) continue;
    final existing = latestByPhone[phone];
    if (existing == null || record.sharedAt.isAfter(existing.sharedAt)) {
      latestByPhone[phone] = record;
    }
  }
  return latestByPhone.values.toList()
    ..sort((a, b) => a.sharedAt.compareTo(b.sharedAt));
}

String buildOutgoingShareSummary(List<ShareOutgoingRecord> records) {
  final deduped = dedupeOutgoingRecordsByRecipient(records);
  if (deduped.isEmpty) return '';
  return deduped.map(buildOutgoingShareRecordLine).join('、');
}

String? buildIncomingShareDetailLine(ListEvent event) {
  if (!event.isShareIncoming) return null;
  final name = event.sharedFromUserName?.trim();
  if (name == null || name.isEmpty) return null;
  final at = event.sharedAt;
  if (at == null) {
    return '来自 $name 的分享';
  }
  return '来自 $name 的分享 · 已于 ${formatPartnerModifiedAt(at)} 接收';
}

Widget buildFriendShareStatusRow({
  List<ShareOutgoingRecord>? outgoingRecords,
  ListEvent? incomingEvent,
  TextStyle? textStyle,
}) {
  final style = textStyle ??
      const TextStyle(
        fontSize: 12,
        color: Color(0xFF9CA3AF),
        height: 20 / 12,
      );

  final incomingLine =
      incomingEvent != null ? buildIncomingShareDetailLine(incomingEvent) : null;
  if (incomingLine != null) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(incomingLine, style: style),
    );
  }

  final outgoing = outgoingRecords ?? const <ShareOutgoingRecord>[];
  if (outgoing.isEmpty) {
    return const SizedBox.shrink();
  }

  final summary = buildOutgoingShareSummary(outgoing);
  if (summary.isEmpty) {
    return const SizedBox.shrink();
  }

  return Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text('分享状态：$summary', style: style),
  );
}

/// 详情页异步加载好友分享记录并展示。
class FriendShareDetailSection extends StatefulWidget {
  const FriendShareDetailSection({super.key, required this.event});

  final ListEvent event;

  @override
  State<FriendShareDetailSection> createState() =>
      _FriendShareDetailSectionState();
}

class _FriendShareDetailSectionState extends State<FriendShareDetailSection> {
  List<ShareOutgoingRecord> _outgoing = const [];
  bool _loaded = false;

  static const _hintStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF9CA3AF),
    height: 20 / 12,
  );

  @override
  void initState() {
    super.initState();
    _load();
    EventShareService.revision.addListener(_onRevision);
  }

  @override
  void didUpdateWidget(FriendShareDetailSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id) {
      _load();
    }
  }

  @override
  void dispose() {
    EventShareService.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() => _load();

  Future<void> _load() async {
    if (widget.event.isShareIncoming) {
      if (mounted) {
        setState(() {
          _outgoing = const [];
          _loaded = true;
        });
      }
      return;
    }
    await UserSession.instance.ensureInitialized();
    if (!isEventOwnedByCurrentUser(widget.event)) {
      if (mounted) {
        setState(() {
          _outgoing = const [];
          _loaded = true;
        });
      }
      return;
    }
    final records =
        await EventShareService.loadOutgoingRecords(widget.event.id);
    if (!mounted) return;
    setState(() {
      _outgoing = records;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return buildFriendShareStatusRow(
      outgoingRecords: widget.event.isShareIncoming ? null : _outgoing,
      incomingEvent: widget.event.isShareIncoming ? widget.event : null,
      textStyle: _hintStyle,
    );
  }
}
