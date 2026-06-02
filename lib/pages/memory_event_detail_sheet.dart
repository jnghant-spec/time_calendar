import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/pages/memory_event_sheet.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/widgets/share_card_widget.dart';

Future<void> showMemoryEventDetailSheet(
  BuildContext context, {
  required MemoryEvent event,
  required MemoryCollection collection,
  VoidCallback? onChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => MemoryEventDetailSheet(
        event: event,
        collection: collection,
        scrollController: scrollController,
        onChanged: onChanged,
      ),
    ),
  );
}

class MemoryEventDetailSheet extends StatefulWidget {
  const MemoryEventDetailSheet({
    super.key,
    required this.event,
    required this.collection,
    required this.scrollController,
    this.onChanged,
  });

  final MemoryEvent event;
  final MemoryCollection collection;
  final ScrollController scrollController;
  final VoidCallback? onChanged;

  @override
  State<MemoryEventDetailSheet> createState() => _MemoryEventDetailSheetState();
}

class _MemoryEventDetailSheetState extends State<MemoryEventDetailSheet> {
  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _sheetBg = Color(0xFFFAFBFC);

  late MemoryEvent _event;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  List<String> get _photos => MemoryService.existingPhotoPaths(_event);

  String? get _heroPath =>
      _photos.isNotEmpty ? _photos.first : MemoryService.firstSlotPhotoPath(_event);

  Future<void> _reloadEvent() async {
    final all = await MemoryService.loadEvents();
    for (final e in all) {
      if (e.id == _event.id) {
        if (!mounted) return;
        setState(() => _event = e);
        widget.onChanged?.call();
        return;
      }
    }
  }

  void _openEdit() {
    final nav = Navigator.of(context);
    final collectionId = widget.collection.id;
    final initial = _event;
    nav.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showMemoryEventSheet(
        nav.context,
        collectionId: collectionId,
        initial: initial,
      );
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '确认删除',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '删除后不可恢复，是否继续？',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      '删除',
                      style: TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await MemoryService.deleteEvent(_event.id);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onChanged?.call();
  }

  Future<void> _shareCard() async {
    final paths = _photos;
    final card = ShareCardWidget(
      title: _event.title,
      primaryDateLine: formatGregorianDateLongZh(_event.date),
      secondaryLines: [
        if (_event.location?.trim().isNotEmpty ?? false)
          _event.location!.trim(),
      ],
      descriptionExcerpt: '用时光集记录每一个值得记住的日子。',
      backgroundColor: const Color(0xFF1A73E8),
      photoPaths: paths,
    );
    final bytes = await _captureCardToPng(card);
    if (bytes == null || !mounted) return;
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/memory_event_share_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: '${_event.title} · 时光集',
      ),
    );
  }

  Future<Uint8List?> _captureCardToPng(Widget card) async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return null;

    final boundaryKey = GlobalKey();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: -10000,
        top: 0,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 1080,
              height: 1920,
              child: card,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    Uint8List? out;
    try {
      final ro = boundaryKey.currentContext?.findRenderObject();
      if (ro is RenderRepaintBoundary) {
        final img = await ro.toImage(pixelRatio: 1);
        final bd = await img.toByteData(format: ui.ImageByteFormat.png);
        if (bd != null) out = bd.buffer.asUint8List();
        img.dispose();
      }
    } finally {
      entry.remove();
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final loc = _event.location?.trim();
    final photos = _photos;
    final hero = _heroPath;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: _sheetBg,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                padding: EdgeInsets.only(bottom: 16 + bottom),
                children: [
                  Container(
                    height: 280,
                    margin: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          hero != null
                              ? Image.file(File(hero), fit: BoxFit.cover)
                              : Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: const Icon(
                                    Icons.photo,
                                    size: 48,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                          if (photos.isNotEmpty)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '1/${photos.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _event.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _titleColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              size: 14,
                              color: _muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${formatFullDate(_event.date)} ${formatWeekdayZh(_event.date)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        if (loc != null && loc.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 14,
                                color: _muted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  loc,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '纪念照片（${photos.length}张）',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: photos.length > 4 ? 4 : photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        if (index == 3 && photos.length > 4) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(photos[3]),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '+${photos.length - 3}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(photos[index]),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openEdit,
                            icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                            label: const Text(
                              '编辑事件',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _themeBlue,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _shareCard,
                            icon: const Icon(
                              Icons.share_outlined,
                              size: 16,
                              color: _themeBlue,
                            ),
                            label: const Text(
                              '分享卡片',
                              style: TextStyle(color: _themeBlue),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _themeBlue),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _confirmDelete,
                          child: const Text(
                            '删除',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
