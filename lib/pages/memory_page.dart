import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/pages/memory_create_sheet.dart';
import 'package:time_calendar/pages/memory_photo_stream_sheet.dart';
import 'package:time_calendar/pages/photo_viewer_page.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/tag_bar_state.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/widgets/confirm_delete_dialog.dart';
import 'package:time_calendar/widgets/tag_circle_widget.dart';
import 'package:time_calendar/widgets/tag_editor_sheet.dart';
import 'package:time_calendar/widgets/unified_tag_bar.dart';

/// FAB bottom(16) + FAB height(56) + breathing space(8)
const _kListScrollBottomPadding = 16.0 + 56.0 + 8.0;

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _pageBg = Color(0xFFFAFBFC);
  static const Color _star = Color(0xFFFFB800);
  static const Color _deleteRed = Color(0xFFEF4444);
  static const Color _disabled = Color(0xFFCBD5E1);
  static const Color _dividerColor = Color(0xFFF1F5F9);
  static const List<BoxShadow> _cardShadow = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const Color _pinnedStarBg = Color(0xFFFFFBEB);

  static List<BoxShadow> _pinnedCollectionShadows() => [
        BoxShadow(
          color: _star.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static Widget _pinnedStarBadge() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _pinnedStarBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/images/ic_star.svg',
          width: 20,
          height: 20,
        ),
      ),
    );
  }

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

enum _CoverThumbStyle { standard, narrow, tall }

class _MemoryPageState extends State<MemoryPage> {
  bool _narrowCardsSelected = true;
  List<MemoryCollection> _collections = [];
  Map<String, List<MemoryEvent>> _eventsByCol = {};
  bool _loading = true;

  List<MemoryCollection> _visibleCollections() {
    final filterTagId = TagBarState().selectedTagId;
    if (filterTagId == null) return _collections;
    return _collections.where((c) => c.tagId == filterTagId).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await MemoryService.repairOrphanTagAssociations();
      if (mounted) await _refresh();
    });
  }

  Future<void> _refresh() async {
    await TagBarState().loadTags();
    final tags = TagBarState().tags;
    final selected = TagBarState().selectedTagId;
    if (selected != null && !tags.any((t) => t.id == selected)) {
      TagBarState().selectTag(null);
    }
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

  Future<bool> _deleteTagFromEditor(ReminderTag tag) async {
    if (!mounted) return false;
    final ok = await confirmUnlinkDeleteTag(context, tag);
    if (!ok || !mounted) return false;
    if (TagBarState().selectedTagId == tag.id) {
      TagBarState().selectTag(null);
    }
    return true;
  }

  Future<void> _openTagManage() async {
    await showTagManageSheet(
      context,
      onTagsChanged: () async {
        await TagBarState().loadTags();
        await _refresh();
      },
      onDeleteTag: _deleteTagFromEditor,
    );
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

  Future<void> _togglePinCollection(MemoryCollection c) async {
    await MemoryService.updateCollection(
      c.copyWith(isPinned: !c.isPinned),
    );
    await _refresh();
  }

  Future<void> _editCollection(MemoryCollection c) async {
    final resolved = await MemoryService.getCollectionById(c.id) ?? c;
    if (!mounted) return;
    final changed = await showMemoryCollectionCreateSheet(
      context,
      collectionToEdit: resolved,
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _deleteCollection(MemoryCollection c) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: '删除「${c.name}」？',
      content: '删除后该事件集内的子事件将保留在您的清单中。',
    );
    if (!confirmed || !mounted) return;
    await MemoryService.deleteCollection(c.id);
    await _refresh();
  }

  Future<void> _showCollectionActionSheet(MemoryCollection c) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text(
                  '选择操作',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MemoryPage._titleColor,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1, color: MemoryPage._dividerColor),
                _CollectionActionTile(
                  icon: c.isPinned ? Icons.star_border : Icons.star,
                  label: c.isPinned ? '取消置顶' : '置顶',
                  iconColor: MemoryPage._star,
                  textColor: MemoryPage._titleColor,
                  onTap: () {
                    Navigator.pop(ctx);
                    _togglePinCollection(c);
                  },
                ),
                _CollectionActionTile(
                  icon: Icons.edit_outlined,
                  label: '编辑',
                  iconColor: MemoryPage._themeBlue,
                  textColor: MemoryPage._titleColor,
                  onTap: () {
                    Navigator.pop(ctx);
                    _editCollection(c);
                  },
                ),
                _CollectionActionTile(
                  icon: Icons.delete_outline,
                  label: '删除',
                  iconColor: MemoryPage._deleteRed,
                  textColor: MemoryPage._deleteRed,
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteCollection(c);
                  },
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: const SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            color: MemoryPage._muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _slidableAction({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onTap,
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
    return CustomSlidableAction(
      autoClose: true,
      padding: EdgeInsets.zero,
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      borderRadius: borderRadius,
      onPressed: (_) => onTap(),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverThumb(
    MemoryCollection c,
    List<MemoryEvent> ev, {
    _CoverThumbStyle style = _CoverThumbStyle.standard,
  }) {
    final size = switch (style) {
      _CoverThumbStyle.narrow => 80.0,
      _CoverThumbStyle.tall => 120.0,
      _CoverThumbStyle.standard => 72.0,
    };
    final radius = style == _CoverThumbStyle.standard ? 8.0 : 16.0;
    final iconSize = switch (style) {
      _CoverThumbStyle.tall => 40.0,
      _CoverThumbStyle.narrow => 32.0,
      _CoverThumbStyle.standard => 28.0,
    };
    final path = _coverPath(c, ev);
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.photo_album_outlined,
        color: MemoryPage._muted,
        size: iconSize,
      ),
    );
  }

  Widget _collectionTagLabel(MemoryCollection c) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TagCircleWidget.cardTagPill(tagId: c.tagId),
    );
  }

  Widget _cardInfoColumn(
    MemoryCollection c,
    List<MemoryEvent> ev, {
    bool compactSpacing = false,
    bool tallLayout = false,
    Widget? statsTrailing,
  }) {
    final tagLabel = _collectionTagLabel(c);
    final photoCount = MemoryService.countPhotosInCollection(ev);
    final statsText = '共 ${ev.length} 个事件 · $photoCount 张照片';

    if (tallLayout) {
      return Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: MemoryPage._titleColor,
                ),
              ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: tagLabel,
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                _rangeLine(ev),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: MemoryPage._muted,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      statsText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: MemoryPage._muted,
                      ),
                    ),
                  ),
                  ?statsTrailing,
                ],
              ),
            ],
          ),
        ),
      );
    }

    final lineGap = compactSpacing ? 4.0 : 6.0;
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
          SizedBox(height: lineGap),
          LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: tagLabel,
              );
            },
          ),
          SizedBox(height: lineGap),
          Text(
            _rangeLine(ev),
            style: const TextStyle(
              fontSize: 13,
              color: MemoryPage._muted,
            ),
          ),
          SizedBox(height: lineGap),
          Row(
            children: [
              Expanded(
                child: Text(
                  statsText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MemoryPage._muted,
                  ),
                ),
              ),
              ?statsTrailing,
            ],
          ),
        ],
      ),
    );
  }

  Widget _moreMenuButton(MemoryCollection c, {bool compact = false}) {
    if (compact) {
      return GestureDetector(
        onTap: () => _showCollectionActionSheet(c),
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(
            Icons.more_vert,
            size: 20,
            color: MemoryPage._muted,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _showCollectionActionSheet(c),
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          Icons.more_vert,
          size: 20,
          color: MemoryPage._muted,
        ),
      ),
    );
  }

  Widget _cardHeaderRow(
    MemoryCollection c,
    List<MemoryEvent> ev, {
    _CoverThumbStyle thumbStyle = _CoverThumbStyle.standard,
    bool tallLayout = false,
    Widget? statsTrailing,
  }) {
    final horizontalGap = tallLayout ? 16.0 : 12.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _coverThumb(c, ev, style: thumbStyle),
        SizedBox(width: horizontalGap),
        _cardInfoColumn(
          c,
          ev,
          compactSpacing: thumbStyle == _CoverThumbStyle.narrow,
          tallLayout: tallLayout,
          statsTrailing: statsTrailing,
        ),
      ],
    );
  }

  Widget _collectionListBody() {
    return ListenableBuilder(
      listenable: TagBarState(),
      builder: (context, _) {
        final visible = _visibleCollections();
        if (_collections.isEmpty) {
          return Center(
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
          );
        }
        if (visible.isEmpty) {
          return const Center(
            child: Text(
              '该标签下暂无事件集',
              style: TextStyle(
                fontSize: 16,
                color: MemoryPage._muted,
              ),
            ),
          );
        }
        return ListView.builder(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: _kListScrollBottomPadding),
          itemCount: visible.length,
          itemBuilder: (ctx, i) {
            final c = visible[i];
            final ev = _eventsByCol[c.id] ?? [];
            return _narrowCardsSelected
                ? _narrowCard(context, c, ev)
                : _tallCard(context, c, ev);
          },
        );
      },
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: photoHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.photo,
            color: MemoryPage._disabled,
            size: 24,
          ),
        ),
      );
    }

    final path = MemoryService.firstSlotPhotoPath(event);
    final hasPhoto = path != null && File(path).existsSync();

    if (!hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: photoHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.photo,
            color: MemoryPage._disabled,
            size: 24,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => PhotoViewerPage.showForMemoryEvent(context, event: event),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                      bottom: Radius.circular(16),
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
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        formatYearMonthDot(event.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArrowArea() {
    return const SizedBox(
      width: 44,
      height: 120,
      child: Center(
        child: Icon(
          Icons.arrow_forward,
          size: 20,
          color: MemoryPage._disabled,
        ),
      ),
    );
  }

  Widget _highlightsSection(List<MemoryEvent> ev) {
    if (ev.isEmpty) return const SizedBox.shrink();

    final displayEvents = <MemoryEvent>[ev.first];
    if (ev.length >= 2) {
      displayEvents.add(ev.last);
    }

    final leftEvent = displayEvents.first;
    final rightEvent = displayEvents.length >= 2 ? displayEvents.last : null;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
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
              if (rightEvent != null) ...[
                const SizedBox(width: 8),
                _buildArrowArea(),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildHighlightPhoto(event: rightEvent),
                ),
              ],
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
    const margin = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    const padding = EdgeInsets.all(16);
    final inner = Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (isPinned)
          Positioned(
            top: 8,
            right: 8,
            child: MemoryPage._pinnedStarBadge(),
          ),
      ],
    );

    if (!isPinned) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: MemoryPage._cardShadow,
          ),
          child: inner,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: padding,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: MemoryPage._pinnedCollectionShadows(),
              ),
              child: inner,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: const BoxDecoration(
                  color: MemoryPage._star,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _narrowCardContent(
    MemoryCollection c,
    List<MemoryEvent> ev,
  ) {
    return _collectionCardShell(
      isPinned: c.isPinned,
      onTap: () => _openCollection(context, c),
      child: _cardHeaderRow(
        c,
        ev,
        thumbStyle: _CoverThumbStyle.narrow,
      ),
    );
  }

  Widget _narrowCard(
    BuildContext context,
    MemoryCollection c,
    List<MemoryEvent> ev,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.hardEdge,
      child: Slidable(
        key: ValueKey(c.id),
        closeOnScroll: true,
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.48,
          children: [
            _slidableAction(
              icon: c.isPinned ? Icons.star_border : Icons.star,
              label: c.isPinned ? '取消置顶' : '置顶',
              backgroundColor: MemoryPage._star,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              onTap: () => _togglePinCollection(c),
            ),
            _slidableAction(
              icon: Icons.edit,
              label: '编辑',
              backgroundColor: MemoryPage._themeBlue,
              onTap: () => _editCollection(c),
            ),
            _slidableAction(
              icon: Icons.delete_outline,
              label: '删除',
              backgroundColor: MemoryPage._deleteRed,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              onTap: () => _deleteCollection(c),
            ),
          ],
        ),
        child: _narrowCardContent(c, ev),
      ),
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
          _cardHeaderRow(
            c,
            ev,
            thumbStyle: _CoverThumbStyle.tall,
            tallLayout: true,
            statsTrailing: _moreMenuButton(c, compact: true),
          ),
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
            child: _MemoryViewModeCapsule(
              narrowSelected: _narrowCardsSelected,
              onNarrow: () => setState(() => _narrowCardsSelected = true),
              onTall: () => setState(() => _narrowCardsSelected = false),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_loading) ...[
                  UnifiedTagBar(onManagePressed: _openTagManage),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _collectionListBody(),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 32 + bottomSafe,
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

class _CollectionActionTile extends StatelessWidget {
  const _CollectionActionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: iconColor),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS 风格胶囊视图切换（窄列表 / 高卡片）。
class _MemoryViewModeCapsule extends StatelessWidget {
  const _MemoryViewModeCapsule({
    required this.narrowSelected,
    required this.onNarrow,
    required this.onTall,
  });

  final bool narrowSelected;
  final VoidCallback onNarrow;
  final VoidCallback onTall;

  static const Color _track = Color(0xFFF0F0F2);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _iconIdle = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _track,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final thumbW = constraints.maxWidth / 2;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: narrowSelected ? 0 : thumbW,
                    top: 0,
                    bottom: 0,
                    width: thumbW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _segment(
                          icon: Icons.view_agenda_outlined,
                          selected: narrowSelected,
                          onTap: onNarrow,
                        ),
                      ),
                      Expanded(
                        child: _segment(
                          icon: Icons.view_day_outlined,
                          selected: !narrowSelected,
                          onTap: onTall,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _segment({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: selected ? _themeBlue : _iconIdle,
          ),
        ),
      ),
    );
  }
}
