import 'package:flutter/material.dart';
import 'package:time_calendar/models/event_share_record.dart';
import 'package:time_calendar/services/event_share_service.dart';
import 'package:time_calendar/services/tag_bar_state.dart';

/// 分享提醒文案 + 等宽忽略/接受按钮，供顶部横幅与共享管理页复用。
class IncomingShareActionPanel extends StatelessWidget {
  const IncomingShareActionPanel({
    super.key,
    required this.payload,
    required this.onAccept,
    required this.onDismiss,
  });

  final IncomingSharePayload payload;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  static const Color themeBlue = Color(0xFF1A73E8);
  static const Color border = Color(0xFFE2E8F0);

  static String senderLabel(IncomingSharePayload payload) {
    return payload.senderName.trim().isNotEmpty
        ? payload.senderName.trim()
        : payload.senderPhone;
  }

  @override
  Widget build(BuildContext context) {
    final sender = senderLabel(payload);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$sender 向你分享了「${payload.eventSnapshot.title}」',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('忽略'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: themeBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('接受'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 顶部浮动横幅：展示待接受的他人分享。
class IncomingShareBanner extends StatelessWidget {
  const IncomingShareBanner({
    super.key,
    required this.payload,
    required this.onAccept,
    required this.onDismiss,
  });

  final IncomingSharePayload payload;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      elevation: 5,
      color: Colors.white,
      shadowColor: Colors.black26,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, top + 10, 16, 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: IncomingShareActionPanel.border, width: 0.7),
          ),
        ),
        child: IncomingShareActionPanel(
          payload: payload,
          onAccept: onAccept,
          onDismiss: onDismiss,
        ),
      ),
    );
  }
}

/// 在页面顶部浮动挂载横幅；由 [MainNavigationPage] 驱动。
class IncomingShareBannerHost extends StatefulWidget {
  const IncomingShareBannerHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<IncomingShareBannerHost> createState() =>
      _IncomingShareBannerHostState();
}

class _IncomingShareBannerHostState extends State<IncomingShareBannerHost> {
  IncomingSharePayload? _current;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    EventShareService.revision.addListener(_onShareRevision);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBanner());
  }

  @override
  void dispose() {
    EventShareService.revision.removeListener(_onShareRevision);
    super.dispose();
  }

  void _onShareRevision() => _refreshBanner();

  Future<void> _refreshBanner() async {
    if (!mounted) return;
    final next = await EventShareService.getPendingIncomingForBanner();
    if (!mounted) return;
    setState(() => _current = next);
  }

  Future<void> _accept() async {
    if (_busy) return;
    final payload = _current;
    if (payload == null) return;
    setState(() => _busy = true);
    try {
      final event = await EventShareService.acceptIncoming(payload.id);
      if (!mounted) return;
      if (event != null) {
        await TagBarState().loadTags();
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refreshBanner();
      }
    }
  }

  Future<void> _dismiss() async {
    if (_busy) return;
    final payload = _current;
    if (payload == null) return;
    setState(() => _busy = true);
    try {
      await EventShareService.dismissIncoming(payload.id);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refreshBanner();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = _current;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (banner != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IncomingShareBanner(
              payload: banner,
              onAccept: _busy ? () {} : _accept,
              onDismiss: _busy ? () {} : _dismiss,
            ),
          ),
      ],
    );
  }
}
