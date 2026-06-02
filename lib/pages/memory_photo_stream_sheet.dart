import 'dart:io';

import 'package:flutter/material.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/pages/memory_collection_timeline_sheet.dart';
import 'package:time_calendar/pages/memory_create_sheet.dart';
import 'package:time_calendar/pages/memory_event_sheet.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/widgets/memory_collection_detail_parts.dart';

Future<void> showMemoryPhotoStreamSheet(
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
      builder: (_, scrollController) => MemoryPhotoStreamSheet(
        collection: collection,
        scrollController: scrollController,
      ),
    ),
  );
}

class MemoryPhotoStreamSheet extends StatefulWidget {
  const MemoryPhotoStreamSheet({
    super.key,
    required this.collection,
    required this.scrollController,
  });

  final MemoryCollection collection;
  final ScrollController scrollController;

  @override
  State<MemoryPhotoStreamSheet> createState() => _MemoryPhotoStreamSheetState();
}

class _CardTransform {
  const _CardTransform({
    required this.scale,
    required this.translateX,
    required this.opacity,
    required this.showShadow,
  });

  final double scale;
  final double translateX;
  final double opacity;
  final bool showShadow;
}

class _MemoryPhotoStreamSheetState extends State<MemoryPhotoStreamSheet> {
  static const double _kViewportFraction = 0.72;
  static const double _cardPhotoHeight = 280;

  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _sheetBg = Color(0xFFFAFBFC);

  static _CardTransform? _cardTransformFor(double pageDelta) {
    final ad = pageDelta.abs();
    if (ad > 2.0) return null;

    if (ad <= 0.5) {
      return const _CardTransform(
        scale: 1.0,
        translateX: 0,
        opacity: 1.0,
        showShadow: true,
      );
    }
    if (pageDelta > 0.5 && pageDelta < 1.5) {
      return const _CardTransform(
        scale: 0.82,
        translateX: -55,
        opacity: 0.85,
        showShadow: false,
      );
    }
    if (pageDelta < -0.5 && pageDelta > -1.5) {
      return const _CardTransform(
        scale: 0.82,
        translateX: 55,
        opacity: 0.85,
        showShadow: false,
      );
    }
    if (ad >= 1.5 && ad <= 2.0) {
      return _CardTransform(
        scale: 0.70,
        translateX: pageDelta > 0 ? -90 : 90,
        opacity: 0.0,
        showShadow: false,
      );
    }
    return null;
  }

  List<MemoryEvent> _events = [];
  late MemoryCollection _collection;
  PageController? _pageController;
  int _logicalIndex = 0;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    _reload();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final col =
        await MemoryService.getCollectionById(widget.collection.id) ??
            widget.collection;
    final list = await MemoryService.getEventsSorted(widget.collection.id);
    if (!mounted) return;
    _pageController?.dispose();
    final n = list.length;
    PageController? pc;
    var logic = _logicalIndex;
    if (n > 0) {
      logic = logic.clamp(0, n - 1);
      pc = PageController(
        initialPage: logic,
        viewportFraction: _kViewportFraction,
      );
    }
    setState(() {
      _collection = col;
      _events = list;
      _logicalIndex = n > 0 ? logic : 0;
      _pageController = pc;
    });
  }

  void _onPageChanged(int pageIndex) {
    if (_events.isEmpty) return;
    setState(() => _logicalIndex = pageIndex);
  }

  void _switchToTimeline() {
    final col = _collection;
    final nav = Navigator.of(context);
    nav.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!nav.context.mounted) return;
      showMemoryCollectionTimelineSheet(nav.context, collection: col);
    });
  }

  Future<void> _editCollection() async {
    final resolved =
        await MemoryService.getCollectionById(_collection.id) ?? _collection;
    if (!mounted) return;
    await showMemoryCollectionEditSheet(context, collection: resolved);
    await _reload();
  }

  void _onShareCollection() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能开发中')),
    );
  }

  Future<void> _openAdd() async {
    await showMemoryEventSheet(context, collectionId: _collection.id);
    await _reload();
  }

  Future<void> _openEdit() async {
    if (_events.isEmpty) return;
    final e = _events[_logicalIndex];
    await showMemoryEventSheet(
      context,
      collectionId: _collection.id,
      initial: e,
    );
    await _reload();
  }

  Future<void> _confirmDelete() async {
    if (_events.isEmpty) return;
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
                    child: const Text('取消', style: TextStyle(color: _muted)),
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
    if (ok != true) return;
    final id = _events[_logicalIndex].id;
    await MemoryService.deleteEvent(id);
    if (_logicalIndex >= _events.length - 1 && _logicalIndex > 0) {
      _logicalIndex--;
    }
    await _reload();
    if (_events.isEmpty && mounted) {
      Navigator.pop(context);
    }
  }

  Widget _eventInfoOverlay(MemoryEvent e) {
    final loc = e.location?.trim();
    final showLoc = loc != null && loc.isNotEmpty;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 4),
                Text(
                  formatMonthDayZh(e.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                if (showLoc) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.place_outlined,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      loc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventPhoto(MemoryEvent e, double width) {
    final path = MemoryService.firstSlotPhotoPath(e);
    final hasPhoto = path != null && File(path).existsSync();

    Widget image = hasPhoto
        ? Image.file(File(path), fit: BoxFit.cover)
        : Container(
            color: const Color(0xFFF1F5F9),
            alignment: Alignment.center,
            child: const Icon(
              Icons.photo_album_outlined,
              size: 48,
              color: Color(0xFFCBD5E1),
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: _cardPhotoHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            _eventInfoOverlay(e),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(
    MemoryEvent e,
    double photoWidth, {
    required bool showShadow,
  }) {
    return Container(
      width: photoWidth,
      height: _cardPhotoHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  spreadRadius: 3,
                  offset: const Offset(0, 12),
                ),
              ]
            : const [],
      ),
      child: _eventPhoto(e, photoWidth),
    );
  }

  Widget _horizontalStream() {
    final pc = _pageController;
    final n = _events.length;

    if (n == 0 || pc == null) {
      return SizedBox(
        height: _cardPhotoHeight + 24,
        child: const Center(
          child: Text('暂无事件', style: TextStyle(color: _muted)),
        ),
      );
    }

    final scrollPhysics = n <= 1
        ? const NeverScrollableScrollPhysics()
        : const ClampingScrollPhysics();

    return SizedBox(
      height: _cardPhotoHeight,
      child: LayoutBuilder(
        builder: (context, _) {
          final screenWidth = MediaQuery.sizeOf(context).width;
          final itemWidth = screenWidth * _kViewportFraction;
          final photoWidth = screenWidth * 0.85;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: _cardPhotoHeight,
                width: screenWidth,
                child: PageView.builder(
                  controller: pc,
                  physics: scrollPhysics,
                  itemCount: n,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) => Container(
                    color: Colors.transparent,
                    width: itemWidth,
                    height: _cardPhotoHeight,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: pc,
                builder: (context, _) {
                  double page;
                  if (pc.hasClients && pc.position.hasContentDimensions) {
                    page = pc.page ?? _logicalIndex.toDouble();
                  } else {
                    page = _logicalIndex.toDouble();
                  }

                  final behind = <Widget>[];
                  final front = <Widget>[];

                  for (final entry in _events.asMap().entries) {
                    final index = entry.key;
                    final event = entry.value;
                    final pageDelta = page - index;
                    final transform = _cardTransformFor(pageDelta);
                    if (transform == null) continue;

                    final baseOffset = (index - page) * itemWidth;
                    final left = screenWidth / 2 +
                        baseOffset +
                        transform.translateX -
                        photoWidth / 2;
                    final isCurrent = pageDelta.abs() <= 0.5;

                    final card = Positioned(
                      left: left,
                      top: 0,
                      child: IgnorePointer(
                        ignoring: true,
                        child: Opacity(
                          opacity: transform.opacity,
                          child: Transform.scale(
                            scale: transform.scale,
                            alignment: Alignment.center,
                            child: _buildEventCard(
                              event,
                              photoWidth,
                              showShadow: transform.showShadow,
                            ),
                          ),
                        ),
                      ),
                    );

                    if (isCurrent) {
                      front.add(card);
                    } else {
                      behind.add(card);
                    }
                  }

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [...behind, ...front],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bottomActionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _bottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _bottomActionBtn(
            Icons.add,
            '新建',
            _titleColor,
            _openAdd,
          ),
          _bottomActionBtn(
            Icons.edit,
            '编辑',
            _titleColor,
            _events.isEmpty ? null : _openEdit,
          ),
          _bottomActionBtn(
            Icons.delete_outline,
            '删除',
            const Color(0xFFEF4444),
            _events.isEmpty ? null : _confirmDelete,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
                padding: EdgeInsets.only(bottom: bottomInset),
                children: [
                  MemoryCollectionDetailHeader(
                    collection: _collection,
                    events: _events,
                    isListViewActive: false,
                    onShare: _onShareCollection,
                    onEditCollection: _editCollection,
                    onSwitchToList: _switchToTimeline,
                    onSwitchToGrid: () {},
                  ),
                  _horizontalStream(),
                  _bottomActions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
