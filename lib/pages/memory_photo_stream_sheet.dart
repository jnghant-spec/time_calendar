import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/pages/memory_create_sheet.dart';
import 'package:time_calendar/pages/memory_event_detail_sheet.dart';
import 'package:time_calendar/pages/memory_event_sheet.dart';
import 'package:time_calendar/pages/memory_share_sheet.dart';
import 'package:time_calendar/pages/join_sub_event_sheet.dart';
import 'package:time_calendar/pages/photo_viewer_page.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/widgets/confirm_delete_dialog.dart';
import 'package:time_calendar/widgets/memory_collection_detail_parts.dart';
import 'package:time_calendar/widgets/sub_event_action_sheet.dart';

Future<void> showMemoryPhotoStreamSheet(
  BuildContext context, {
  required MemoryCollection collection,
  int initialViewIndex = 0,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    enableDrag: false,
    isDismissible: false,
    builder: (ctx) => _MemoryPhotoStreamSheetHost(
      collection: collection,
      initialViewIndex: initialViewIndex,
    ),
  );
}

class _MemoryPhotoStreamSheetHost extends StatefulWidget {
  const _MemoryPhotoStreamSheetHost({
    required this.collection,
    this.initialViewIndex = 0,
  });

  final MemoryCollection collection;
  final int initialViewIndex;

  @override
  State<_MemoryPhotoStreamSheetHost> createState() =>
      _MemoryPhotoStreamSheetHostState();
}

class _MemoryPhotoStreamSheetHostState extends State<_MemoryPhotoStreamSheetHost> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(top: height * 0.08),
      child: SizedBox(
        height: height * 0.92,
        child: MemoryPhotoStreamSheet(
          collection: widget.collection,
          scrollController: _scrollController,
          initialViewIndex: widget.initialViewIndex,
        ),
      ),
    );
  }
}

class MemoryPhotoStreamSheet extends StatefulWidget {
  const MemoryPhotoStreamSheet({
    super.key,
    required this.collection,
    required this.scrollController,
    this.initialViewIndex = 0,
  });

  final MemoryCollection collection;
  final ScrollController scrollController;
  final int initialViewIndex;

  @override
  State<MemoryPhotoStreamSheet> createState() => _MemoryPhotoStreamSheetState();
}

class _MemoryPhotoStreamSheetState extends State<MemoryPhotoStreamSheet> {
  static const double _kViewportFraction =
      MemoryDetailDesignTokens.cardViewportFraction;

  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _sheetBg = Color(0xFFFAFBFC);
  static const Color _timelineLineColor = Color(0xFFE2E8F0);
  static const Color _timelineEndDotColor = Color(0xFFCBD5E1);
  static const Color _timelineDividerColor = Color(0xFFF1F5F9);

  static const double _timelineDateColumnWidth = 52;
  static const double _timelineDateToLineGap = 12;
  static const double _timelineRailWidth = 14;
  static const double _timelineLineWidth = 2;
  static const double _timelineContentGap = 16;
  static const double _timelineListBottomPadding = 72;
  static const double _timelineThumbSize = 48;
  static const double _timelineThumbRadius = 8;
  static const double _timelineThumbSpacing = 8;

  double get _timelineLineLeft =>
      _timelineDateColumnWidth +
      _timelineDateToLineGap +
      (_timelineRailWidth - _timelineLineWidth) / 2;

  double get _timelineEndDotLeft =>
      _timelineDateColumnWidth +
      _timelineDateToLineGap +
      (_timelineRailWidth - 6) / 2;

  /// 连续插值：|pageDelta| > 2 不渲染；邻页 scale≈0.82、opacity≈0.60。
  static ({
    double scale,
    double translateX,
    double opacity,
    bool showShadow,
  })? _cardTransformFor(double pageDelta, double photoWidth) {
    final absDist = pageDelta.abs();
    if (absDist > 2.0) return null;

    final clampedDist = absDist.clamp(0.0, 2.0);
    final opacity = 1.0 - (0.40 * clampedDist);
    if (opacity <= 0.01) return null;

    return (
      scale: 1.0 - (0.18 * clampedDist),
      translateX: pageDelta * (photoWidth * 0.38),
      opacity: opacity,
      showShadow: absDist < 0.3,
    );
  }

  List<MemoryEvent> _events = [];
  late MemoryCollection _collection;
  PageController? _pageController;
  late PageController _timelinePageController;
  int _logicalIndex = 0;
  late int _currentViewIndex;
  double _dragOffset = 0;
  bool _nestedSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    _currentViewIndex = widget.initialViewIndex.clamp(0, 1);
    _timelinePageController = PageController(initialPage: _currentViewIndex);
    _reload();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _timelinePageController.dispose();
    super.dispose();
  }

  Future<void> _reload({String? focusEventId}) async {
    final col =
        await MemoryService.getCollectionById(widget.collection.id) ??
            widget.collection;
    final rawList = await MemoryService.getEventsSorted(widget.collection.id);
    final list = <MemoryEvent>[];
    for (final event in rawList) {
      final cleaned = MemoryService.sanitizeMemoryEvent(event);
      if (!listEquals(cleaned.photoPaths, event.photoPaths)) {
        await MemoryService.upsertEvent(cleaned);
      }
      list.add(cleaned);
    }
    if (!mounted) return;
    _pageController?.dispose();
    final n = list.length;
    PageController? pc;
    var logic = _logicalIndex;
    if (focusEventId != null && n > 0) {
      final idx = list.indexWhere((e) => e.id == focusEventId);
      if (idx >= 0) logic = idx;
    }
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

  String _eventContentKey(MemoryEvent e) =>
      '${e.id}|${e.date.millisecondsSinceEpoch}|${e.photoPaths.join(',')}|${e.title}';

  VoidCallback _eventChangedHandler(String eventId) {
    return () {
      _reload(focusEventId: eventId);
    };
  }

  void _onPageChanged(int pageIndex) {
    if (_events.isEmpty) return;
    setState(() => _logicalIndex = pageIndex);
  }

  void _switchToView(int index) {
    if (_currentViewIndex == index) return;
    _timelinePageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _editCollection() async {
    final resolved =
        await MemoryService.getCollectionById(_collection.id) ?? _collection;
    if (!mounted) return;
    final changed = await showMemoryCollectionCreateSheet(
      context,
      collectionToEdit: resolved,
    );
    if (changed == true && mounted) {
      await _reload();
    }
  }

  void _onShareCollection() {
    showMemoryShareSheet(context, collection: _collection);
  }

  Future<bool?> _openMemoryEventSheet({MemoryEvent? initial}) async {
    if (!mounted) return null;
    setState(() => _nestedSheetOpen = true);
    try {
      return await showMemoryEventSheet(
        context,
        collectionId: _collection.id,
        initial: initial,
      );
    } finally {
      if (mounted) setState(() => _nestedSheetOpen = false);
    }
  }

  Future<void> _onCreateEvent() async {
    final changed = await _openMemoryEventSheet();
    if (changed == true) await _reload();
  }

  Future<void> _onEditCurrentEvent() async {
    if (_events.isEmpty) return;
    final e = _events[_logicalIndex];
    final changed = await _openMemoryEventSheet(initial: e);
    if (changed == true) await _reload(focusEventId: e.id);
  }

  void _onEventCardTap(int index) {
    if (index < 0 || index >= _events.length) return;
    final e = _events[index];
    final path = MemoryService.firstSlotPhotoPath(e);
    final hasPhoto = path != null && File(path).existsSync();
    if (hasPhoto) {
      _showEventDetail(e);
    } else {
      _editEvent(e);
    }
  }

  Future<void> _showEventDetail(MemoryEvent e) async {
    await showMemoryEventDetailSheet(
      context,
      event: e,
      collection: _collection,
      onChanged: _eventChangedHandler(e.id),
    );
    await _reload(focusEventId: e.id);
  }

  Future<void> _editEvent(MemoryEvent e) async {
    final changed = await _openMemoryEventSheet(initial: e);
    if (changed == true) await _reload(focusEventId: e.id);
  }

  Future<void> _openTimelineDetail(MemoryEvent e) async {
    await showMemoryEventDetailSheet(
      context,
      event: e,
      collection: _collection,
      onChanged: _eventChangedHandler(e.id),
    );
    await _reload(focusEventId: e.id);
  }

  void _onTimelineItemTap(MemoryEvent e) {
    final path = MemoryService.firstSlotPhotoPath(e);
    final hasPhoto = path != null && File(path).existsSync();
    if (hasPhoto) {
      _openTimelineDetail(e);
    } else {
      _editEvent(e);
    }
  }

  Future<void> _deleteSubEvent(MemoryEvent e) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: '删除「${e.title}」？',
    );
    if (!confirmed || !mounted) return;
    final deletedIndex = _events.indexWhere((item) => item.id == e.id);
    await MemoryService.deleteEvent(e.id, fromCollectionId: _collection.id);
    if (deletedIndex >= 0 &&
        deletedIndex <= _logicalIndex &&
        _logicalIndex > 0) {
      _logicalIndex--;
    }
    await _reload();
    if (_events.isEmpty && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _joinSubEvent(MemoryEvent e) async {
    await showJoinSubEventSheet(
      context,
      event: e,
      currentCollectionId: _collection.id,
    );
  }

  Future<void> _showSubEventActionSheet(MemoryEvent e) async {
    final controller = Slidable.of(context);
    controller?.close();
    await showSubEventActionSheet(
      context,
      event: e,
      onEdit: () => _editEvent(e),
      onJoin: () => _joinSubEvent(e),
      onDelete: () => _deleteSubEvent(e),
    );
  }

  Widget _slidableActionLabel({
    required IconData icon,
    required String label,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _timelineFittedDateLine(String text, TextStyle style) {
    return SizedBox(
      width: _timelineDateColumnWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          text,
          softWrap: false,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: style,
        ),
      ),
    );
  }

  Widget _timelineDateColumn(DateTime date) {
    final monthDaySlash = '${date.month}/${date.day}';
    final monthDayZh = '${date.month}月${date.day}';
    final monthDayLabel =
        monthDaySlash.length > 5 ? monthDayZh : monthDaySlash;

    return SizedBox(
      width: _timelineDateColumnWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _timelineFittedDateLine(
            '${date.year}',
            const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
          const SizedBox(height: 2),
          _timelineFittedDateLine(
            monthDayLabel,
            const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _titleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineNodeDot() {
    return SizedBox(
      width: _timelineRailWidth,
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _themeBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelinePhotoThumb(
    String path, {
    String? cacheKey,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _timelineThumbSize,
        height: _timelineThumbSize,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_timelineThumbRadius),
          child: Image.file(
            File(path),
            key: ValueKey(cacheKey ?? path),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineMoreThumb(
    String path,
    int remainingCount, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _timelineThumbSize,
        height: _timelineThumbSize,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_timelineThumbRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(path),
                key: ValueKey('more-$path'),
                fit: BoxFit.cover,
              ),
              const ColoredBox(color: Colors.black54),
              Center(
                child: Text(
                  '+$remainingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _timelinePhotoThumbnails(
    MemoryEvent e,
    List<String> photos,
  ) {
    if (photos.isEmpty) return const [];

    final items = <Widget>[];
    final visibleCount = photos.length > 3 ? 3 : photos.length;
    for (var i = 0; i < visibleCount; i++) {
      items.add(
        _buildTimelinePhotoThumb(
          photos[i],
          cacheKey: '${e.id}-${photos[i]}',
          onTap: () => PhotoViewerPage.showForMemoryEvent(
            context,
            event: e,
            initialIndex: i,
          ),
        ),
      );
    }
    if (photos.length > 3) {
      items.add(
        _buildTimelineMoreThumb(
          photos[3],
          photos.length - 3,
          onTap: () => _onTimelineItemTap(e),
        ),
      );
    }
    return items;
  }

  Widget _timelineItem(
    MemoryEvent e, {
    required bool isLast,
  }) {
    final loc = e.location?.trim();
    final allPhotos = MemoryService.existingPhotoPaths(e);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Slidable(
        key: ValueKey('timeline-${_eventContentKey(e)}'),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
            CustomSlidableAction(
              onPressed: (_) => _editEvent(e),
              backgroundColor: _themeBlue,
              foregroundColor: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: _slidableActionLabel(
                icon: Icons.edit,
                label: '编辑',
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) => _deleteSubEvent(e),
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              borderRadius: BorderRadius.zero,
              child: _slidableActionLabel(
                icon: Icons.delete_outline,
                label: '删除',
              ),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _timelineDateColumn(e.date),
                const SizedBox(width: _timelineDateToLineGap),
                _timelineNodeDot(),
              ],
            ),
            const SizedBox(width: _timelineContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _onTimelineItemTap(e),
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
                          const SizedBox(height: 6),
                          MemoryLocationCapsule(location: loc),
                        ],
                        if (allPhotos.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: _timelineThumbSpacing,
                            children: _timelinePhotoThumbnails(e, allPhotos),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _editEvent(e),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.photo_album_outlined,
                                    size: 32,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '点击添加照片',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(right: 8),
                      color: _timelineDividerColor,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20, color: _muted),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: () => _showSubEventActionSheet(e),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalCardView() {
    final toolbarPad = MemoryDetailBottomToolbar.totalHeight(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight - toolbarPad;
        final photoHeight = MemoryDetailDesignTokens.computeCardPhotoHeight(
          context,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: toolbarPad),
          child: SizedBox(
            height: availableHeight,
            child: Align(
              alignment: Alignment.center,
              child: _horizontalStream(photoHeight: photoHeight),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalListView() {
    if (_events.isEmpty) {
      return const Center(
        child: Text('暂无事件', style: TextStyle(color: _muted)),
      );
    }

    final bottomPad = MemoryDetailBottomToolbar.totalHeight(context) +
        _timelineListBottomPadding;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _timelineLineLeft,
                  top: -8,
                  bottom: 0,
                  child: Container(
                    width: _timelineLineWidth,
                    color: _timelineLineColor,
                  ),
                ),
                Positioned(
                  left: _timelineEndDotLeft,
                  bottom: -3,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _timelineEndDotColor,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _events.length; i++)
                      _timelineItem(
                        _events[i],
                        isLast: i == _events.length - 1,
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '— 已展示全部 ${_events.length} 个事件 —',
                  style: TextStyle(fontSize: 14, color: _muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDeleteCurrentEvent() async {
    if (_events.isEmpty) return;
    final event = _events[_logicalIndex];
    await _deleteSubEvent(event);
  }

  Widget _eventInfoOverlay(MemoryEvent e) {
    final loc = e.location?.trim();
    final showLoc = loc != null && loc.isNotEmpty;
    final dateLabel =
        '${e.date.year}年${e.date.month}月${e.date.day}日';

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
            Text(
              showLoc ? '$dateLabel · $loc' : dateLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventPhotoImage(
    MemoryEvent e,
    double width, {
    double? photoHeight,
  }) {
    final height = photoHeight ?? MemoryDetailDesignTokens.cardMinHeight;
    final path = MemoryService.firstSlotPhotoPath(e);
    final hasPhoto = path != null && File(path).existsSync();

    if (hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(path),
          key: ValueKey('${e.id}-$path'),
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFFF1F5F9),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_album_outlined,
              size: 48,
              color: Color(0xFFCBD5E1),
            ),
            SizedBox(height: 8),
            Text(
              '点击添加照片',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(
    MemoryEvent e,
    double photoWidth, {
    double? photoHeight,
    required double scale,
    required bool showShadow,
  }) {
    final cardHeight = photoHeight ?? MemoryDetailDesignTokens.cardMinHeight;
    return SizedBox(
      width: photoWidth,
      height: cardHeight,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: photoWidth,
              height: cardHeight,
              clipBehavior: Clip.none,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: showShadow
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : const [],
              ),
              child: _eventPhotoImage(
                e,
                photoWidth,
                photoHeight: cardHeight,
              ),
            ),
            _eventInfoOverlay(e),
          ],
        ),
      ),
    );
  }

  Widget _horizontalStream({double? photoHeight}) {
    final pc = _pageController;
    final n = _events.length;
    final cardPhotoHeight =
        photoHeight ?? MemoryDetailDesignTokens.cardMinHeight;

    if (n == 0 || pc == null) {
      return SizedBox(
        height: cardPhotoHeight + 24,
        child: const Center(
          child: Text('暂无事件', style: TextStyle(color: _muted)),
        ),
      );
    }

    final scrollPhysics = n <= 1
        ? const NeverScrollableScrollPhysics()
        : const ClampingScrollPhysics();

    return SizedBox(
      height: cardPhotoHeight + 32,
      child: LayoutBuilder(
        builder: (context, _) {
          final screenWidth = MediaQuery.sizeOf(context).width;
          final itemWidth = screenWidth * _kViewportFraction;
          final photoWidth = screenWidth * _kViewportFraction;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: cardPhotoHeight,
                width: screenWidth,
                child: PageView.builder(
                  controller: pc,
                  physics: scrollPhysics,
                  clipBehavior: Clip.none,
                  itemCount: n,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) => GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _onEventCardTap(index),
                    child: Container(
                      color: Colors.transparent,
                      width: itemWidth,
                      height: cardPhotoHeight,
                    ),
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

                  final sortedCards = <({double absDist, Widget card})>[];

                  for (final entry in _events.asMap().entries) {
                    final index = entry.key;
                    final event = entry.value;
                    final pageDelta = page - index;
                    final transform =
                        _cardTransformFor(pageDelta, photoWidth);
                    if (transform == null) continue;

                    final baseOffset = (index - page) * itemWidth;
                    final left = screenWidth / 2 +
                        baseOffset +
                        transform.translateX -
                        photoWidth / 2;

                    final absDist = pageDelta.abs();

                    sortedCards.add((
                      absDist: absDist,
                      card: Positioned(
                        left: left,
                        top: 0,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Opacity(
                            opacity: transform.opacity,
                            child: _buildEventCard(
                              event,
                              photoWidth,
                              photoHeight: cardPhotoHeight,
                              scale: transform.scale,
                              showShadow: transform.showShadow,
                            ),
                          ),
                        ),
                      ),
                    ));
                  }

                  sortedCards.sort(
                    (a, b) => b.absDist.compareTo(a.absDist),
                  );

                  return SizedBox(
                    width: screenWidth,
                    height: cardPhotoHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ...sortedCards.map((e) => e.card),
                        if (n > 0)
                          Positioned(
                            left: screenWidth / 2 + photoWidth / 2 - 36,
                            top: cardPhotoHeight - 36,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _showSubEventActionSheet(
                                  _events[_logicalIndex.clamp(0, n - 1)],
                                ),
                                child: const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Icon(
                                    Icons.more_vert,
                                    size: 24,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  VoidCallback? _toolbarEditAction() {
    if (_currentViewIndex == 1) return _editCollection;
    if (_events.isEmpty) return null;
    return _onEditCurrentEvent;
  }

  VoidCallback? _toolbarDeleteAction() {
    if (_events.isEmpty) return null;
    return _currentViewIndex == 0 ? _onDeleteCurrentEvent : null;
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Transform.translate(
      offset: Offset(0, _dragOffset),
      child: Stack(
        children: [
          ClipRRect(
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
                    child: Column(
                      children: [
                        MemoryCollectionDetailHeader(
                          collection: _collection,
                          events: _events,
                          isListViewActive: _currentViewIndex == 1,
                          onShare: _onShareCollection,
                          onEditCollection: _editCollection,
                          onSwitchToList: () => _switchToView(1),
                          onSwitchToGrid: () => _switchToView(0),
                        ),
                        Expanded(
                          child: PageView(
                            controller: _timelinePageController,
                            physics: const NeverScrollableScrollPhysics(),
                            onPageChanged: (index) =>
                                setState(() => _currentViewIndex = index),
                            children: [
                              _buildHorizontalCardView(),
                              _buildVerticalListView(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MemoryDetailBottomToolbar(
              onAdd: _onCreateEvent,
              onEdit: _toolbarEditAction(),
              onDelete: _toolbarDeleteAction(),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: sheetHeight * 0.35,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (details) {
                      if (_nestedSheetOpen) return;
                      if (details.delta.dy > 0) {
                        setState(() => _dragOffset += details.delta.dy);
                      }
                    },
                    onVerticalDragEnd: (details) {
                      if (_nestedSheetOpen) {
                        setState(() => _dragOffset = 0);
                        return;
                      }
                      final threshold = sheetHeight / 3;
                      if (_dragOffset > threshold ||
                          details.velocity.pixelsPerSecond.dy > 800) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => _dragOffset = 0);
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                const IgnorePointer(
                  child: SizedBox(width: 120, height: 96),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
