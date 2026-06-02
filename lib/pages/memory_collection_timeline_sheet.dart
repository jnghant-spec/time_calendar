import 'dart:io';

import 'package:flutter/material.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/pages/memory_create_sheet.dart';
import 'package:time_calendar/pages/memory_event_detail_sheet.dart';
import 'package:time_calendar/pages/memory_event_sheet.dart';
import 'package:time_calendar/pages/memory_photo_stream_sheet.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/widgets/memory_collection_detail_parts.dart';

Future<void> showMemoryCollectionTimelineSheet(
  BuildContext context, {
  required MemoryCollection collection,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => MemoryCollectionTimelineSheet(
        collection: collection,
        scrollController: scrollController,
      ),
    ),
  );
}

class MemoryCollectionTimelineSheet extends StatefulWidget {
  const MemoryCollectionTimelineSheet({
    super.key,
    required this.collection,
    required this.scrollController,
  });

  final MemoryCollection collection;
  final ScrollController scrollController;

  @override
  State<MemoryCollectionTimelineSheet> createState() =>
      _MemoryCollectionTimelineSheetState();
}

class _MemoryCollectionTimelineSheetState
    extends State<MemoryCollectionTimelineSheet> {
  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _sheetBg = Color(0xFFFAFBFC);

  List<MemoryEvent> _events = [];
  late MemoryCollection _collection;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    _reload();
  }

  Future<void> _reload() async {
    final col =
        await MemoryService.getCollectionById(widget.collection.id) ??
            widget.collection;
    final ev = await MemoryService.getEventsSorted(widget.collection.id);
    if (!mounted) return;
    setState(() {
      _collection = col;
      _events = ev;
    });
  }

  void _switchToHorizontal() {
    final col = _collection;
    final nav = Navigator.of(context);
    nav.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!nav.context.mounted) return;
      showMemoryPhotoStreamSheet(nav.context, collection: col);
    });
  }

  Future<void> _openDetail(MemoryEvent e) async {
    await showMemoryEventDetailSheet(
      context,
      event: e,
      collection: _collection,
      onChanged: _reload,
    );
    await _reload();
  }

  Future<void> _createEvent() async {
    await showMemoryEventSheet(context, collectionId: _collection.id);
    await _reload();
  }

  Future<void> _editCollection() async {
    final resolved =
        await MemoryService.getCollectionById(_collection.id) ?? _collection;
    if (!mounted) return;
    await showMemoryCollectionEditSheet(context, collection: resolved);
    await _reload();
  }

  void _onShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能开发中')),
    );
  }

  Widget _timelineItem(MemoryEvent e, {required bool isLast}) {
    final loc = e.location?.trim();
    final thumbs = MemoryService.existingPhotoPaths(e).take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${e.date.month}月',
                  style: const TextStyle(fontSize: 12, color: _themeBlue),
                ),
                const SizedBox(height: 2),
                Text(
                  e.date.day.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _titleColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _themeBlue,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 80,
                  color: const Color(0xFFE2E8F0),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _openDetail(e),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _titleColor,
                    ),
                  ),
                  if (loc != null && loc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: _muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            loc,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (thumbs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: thumbs
                          .map(
                            (p) => ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(p),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: _sheetBg,
        child: Stack(
          children: [
            Column(
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
                  child: ListView.builder(
                    controller: widget.scrollController,
                    padding: EdgeInsets.only(bottom: 88 + bottom),
                    itemCount: _events.length + 2,
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                        return MemoryCollectionDetailHeader(
                          collection: _collection,
                          events: _events,
                          isListViewActive: true,
                          onShare: _onShare,
                          onEditCollection: _editCollection,
                          onSwitchToList: () {},
                          onSwitchToGrid: _switchToHorizontal,
                        );
                      }
                      if (i == _events.length + 1) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              '— 已展示全部 ${_events.length} 个事件 —',
                              style: TextStyle(
                                fontSize: 14,
                                color: _muted,
                              ),
                            ),
                          ),
                        );
                      }
                      final e = _events[i - 1];
                      return _timelineItem(
                        e,
                        isLast: i == _events.length,
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16 + bottom,
              child: FloatingActionButton(
                onPressed: _createEvent,
                backgroundColor: _themeBlue,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
