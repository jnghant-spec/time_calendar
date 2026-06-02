import 'dart:io';

import 'package:flutter/material.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/pages/memory_create_sheet.dart';
import 'package:time_calendar/pages/memory_photo_stream_sheet.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _viewIdleBg = Color(0xFFE2E8F0);
  static const Color _pageBg = Color(0xFFFAFBFC);
  static const Color _star = Color(0xFFFFB800);
  static const List<BoxShadow> _cardShadow = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  bool _narrowCardsSelected = true;
  List<MemoryCollection> _collections = [];
  Map<String, List<MemoryEvent>> _eventsByCol = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await TagService.loadTags();
    final cols = await MemoryService.getSortedCollections();
    final map = <String, List<MemoryEvent>>{};
    for (final c in cols) {
      map[c.id] = await MemoryService.getEventsSorted(c.id);
    }
    if (!mounted) return;
    setState(() {
      _collections = cols;
      _eventsByCol = map;
      _loading = false;
    });
  }

  String _rangeLine(List<MemoryEvent> ev) {
    if (ev.isEmpty) return '暂无事件';
    return '${formatYearMonthDot(ev.first.date)} - ${formatYearMonthDot(ev.last.date)}';
  }

  String? _coverPath(MemoryCollection c, List<MemoryEvent> ev) {
    final custom = c.coverPhotoPath;
    if (custom != null &&
        custom.isNotEmpty &&
        File(custom).existsSync()) {
      return custom;
    }
    for (var i = ev.length - 1; i >= 0; i--) {
      final p = MemoryService.firstSlotPhotoPath(ev[i]);
      if (p != null) return p;
    }
    return null;
  }

  Widget _coverThumb(MemoryCollection c, List<MemoryEvent> ev) {
    final path = _coverPath(c, ev);
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: 72,
          height: 72,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.photo_album_outlined,
        color: MemoryPage._muted,
        size: 28,
      ),
    );
  }

  Widget? _tagPill(MemoryCollection c) {
    final tag = TagService.getTagById(c.tagId);
    if (tag == null) return null;
    final color = tag.accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _cardInfoColumn(MemoryCollection c, List<MemoryEvent> ev) {
    final pill = _tagPill(c);
    final photoCount = MemoryService.countPhotosInCollection(ev);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            c.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MemoryPage._titleColor,
            ),
          ),
          if (pill != null) ...[
            const SizedBox(height: 6),
            pill,
          ],
          const SizedBox(height: 6),
          Text(
            _rangeLine(ev),
            style: const TextStyle(
              fontSize: 13,
              color: MemoryPage._muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '共 ${ev.length} 个事件 · $photoCount 张照片',
            style: const TextStyle(
              fontSize: 12,
              color: MemoryPage._muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardHeaderRow(MemoryCollection c, List<MemoryEvent> ev) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _coverThumb(c, ev),
        const SizedBox(width: 12),
        _cardInfoColumn(c, ev),
      ],
    );
  }

  Widget _viewModeButton({
    required bool selected,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? MemoryPage._themeBlue : MemoryPage._viewIdleBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        width: 36,
        height: 36,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(
            icon,
            size: 20,
            color: selected ? Colors.white : MemoryPage._muted,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Future<void> _openCollection(
    BuildContext context,
    MemoryCollection c,
  ) async {
    final resolved = await MemoryService.getCollectionById(c.id) ?? c;
    if (!context.mounted) return;
    await showMemoryPhotoStreamSheet(context, collection: resolved);
    _refresh();
  }

  Widget _buildHighlightPhoto({MemoryEvent? event}) {
    const photoHeight = 120.0;

    if (event == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: photoHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.photo,
            color: Color(0xFFCBD5E1),
            size: 24,
          ),
        ),
      );
    }

    final path = MemoryService.firstSlotPhotoPath(event);
    final hasPhoto = path != null && File(path).existsSync();

    if (!hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: photoHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.photo,
            color: Color(0xFFCBD5E1),
            size: 24,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: photoHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(path), fit: BoxFit.cover),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatYearMonthDot(event.date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrowArea() {
    return const SizedBox(
      width: 44,
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.arrow_forward,
            size: 14,
            color: MemoryPage._muted,
          ),
          SizedBox(height: 2),
          Text(
            '时光流逝',
            style: TextStyle(
              fontSize: 9,
              color: MemoryPage._muted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightsSection(List<MemoryEvent> ev) {
    if (ev.isEmpty) return const SizedBox.shrink();

    final leftEvent = ev.first;
    final rightEvent = ev.length >= 2 ? ev[1] : null;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '精彩瞬间',
            style: TextStyle(
              fontSize: 13,
              color: MemoryPage._muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 1,
                child: _buildHighlightPhoto(event: leftEvent),
              ),
              const SizedBox(width: 8),
              _buildArrowArea(),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildHighlightPhoto(event: rightEvent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _collectionCardShell({
    required Widget child,
    required bool isPinned,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: MemoryPage._cardShadow,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (isPinned)
              const Positioned(
                top: 12,
                right: 12,
                child: Icon(
                  Icons.star_rounded,
                  size: 20,
                  color: MemoryPage._star,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _narrowCard(
    BuildContext context,
    MemoryCollection c,
    List<MemoryEvent> ev,
  ) {
    return _collectionCardShell(
      isPinned: c.isPinned,
      onTap: () => _openCollection(context, c),
      child: _cardHeaderRow(c, ev),
    );
  }

  Widget _tallCard(
    BuildContext context,
    MemoryCollection c,
    List<MemoryEvent> ev,
  ) {
    return _collectionCardShell(
      isPinned: c.isPinned,
      onTap: () => _openCollection(context, c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeaderRow(c, ev),
          _highlightsSection(ev),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: MemoryPage._pageBg,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          '时光集',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: MemoryPage._titleColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewModeButton(
                  selected: _narrowCardsSelected,
                  icon: Icons.view_agenda,
                  onPressed: () => setState(() => _narrowCardsSelected = true),
                ),
                const SizedBox(width: 4),
                _viewModeButton(
                  selected: !_narrowCardsSelected,
                  icon: Icons.view_day,
                  onPressed: () =>
                      setState(() => _narrowCardsSelected = false),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _collections.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_album_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '暂无时光集',
                              style: TextStyle(
                                fontSize: 16,
                                color: MemoryPage._muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '点击右下角 + 创建你的第一个回忆集',
                              style: TextStyle(
                                fontSize: 14,
                                color: MemoryPage._muted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(0, 0, 0, 88 + bottomSafe),
                        itemCount: _collections.length,
                        itemBuilder: (ctx, i) {
                          final c = _collections[i];
                          final ev = _eventsByCol[c.id] ?? [];
                          return _narrowCardsSelected
                              ? _narrowCard(context, c, ev)
                              : _tallCard(context, c, ev);
                        },
                      ),
          ),
          Positioned(
            right: 16,
            bottom: 16 + bottomSafe,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MemoryPage._themeBlue,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    await showMemoryCreateSheet(context);
                    _refresh();
                  },
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
