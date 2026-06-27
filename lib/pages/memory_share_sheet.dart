import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/share_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/widgets/memory_collection_detail_parts.dart';

enum _ShareViewMode { concise, longImage }

Future<void> showMemoryShareSheet(
  BuildContext context, {
  required MemoryCollection collection,
}) async {
  final height = MediaQuery.sizeOf(context).height;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    enableDrag: false,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(top: height * 0.08),
      child: SizedBox(
        height: height * 0.92,
        child: MemoryShareSheet(collection: collection),
      ),
    ),
  );
}

class MemoryShareSheet extends StatefulWidget {
  const MemoryShareSheet({super.key, required this.collection});

  final MemoryCollection collection;

  @override
  State<MemoryShareSheet> createState() => _MemoryShareSheetState();
}

class _MemoryShareSheetState extends State<MemoryShareSheet> {
  static const Color _bg = Color(0xFFFAFBFC);
  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _divider = Color(0xFFF1F5F9);
  static const int _longPageSize = 8;

  _ShareViewMode _mode = _ShareViewMode.concise;
  int _longPageIndex = 0;
  bool _loading = true;
  bool _busy = false;
  bool _isEditing = false;
  bool _hideLocation = false;

  late MemoryCollection _collection;
  List<MemoryEvent> _events = [];
  List<MemoryEvent> _sortedEvents = [];
  final Set<String> _selectedEventIds = {};
  List<MemoryEvent> _initialSortedEvents = [];
  Set<String> _initialSelectedEventIds = {};
  bool _initialHideLocation = false;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    _load();
  }

  Future<void> _load() async {
    final col =
        await MemoryService.getCollectionById(widget.collection.id) ??
        widget.collection;
    final events = await MemoryService.getEventsSorted(widget.collection.id);
    if (!mounted) return;
    setState(() {
      _collection = col;
      _events = events;
      _sortedEvents = List<MemoryEvent>.from(events);
      _selectedEventIds
        ..clear()
        ..addAll(events.map((e) => e.id));
      _loading = false;
      if (_events.isEmpty && _mode == _ShareViewMode.longImage) {
        _mode = _ShareViewMode.concise;
      }
      if (_longPageIndex >= _longPageCount && _longPageCount > 0) {
        _longPageIndex = _longPageCount - 1;
      }
    });
  }

  List<MemoryEvent> get _shareEvents => [
        for (final e in _sortedEvents)
          if (_selectedEventIds.contains(e.id)) e,
      ];

  void _enterEditMode() {
    setState(() {
      _initialSortedEvents = List<MemoryEvent>.from(_sortedEvents);
      _initialSelectedEventIds = Set<String>.from(_selectedEventIds);
      _initialHideLocation = _hideLocation;
      _isEditing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _sortedEvents = List<MemoryEvent>.from(_initialSortedEvents);
      _selectedEventIds
        ..clear()
        ..addAll(_initialSelectedEventIds);
      _hideLocation = _initialHideLocation;
      _isEditing = false;
      _longPageIndex = 0;
    });
  }

  void _finishEdit() {
    setState(() => _isEditing = false);
  }

  void _toggleEventSelection(String id) {
    setState(() {
      if (_selectedEventIds.contains(id)) {
        _selectedEventIds.remove(id);
      } else {
        _selectedEventIds.add(id);
      }
      if (_longPageIndex >= _longPageCount && _longPageCount > 0) {
        _longPageIndex = _longPageCount - 1;
      } else if (_longPageCount == 0) {
        _longPageIndex = 0;
      }
    });
  }

  void _reorderEvents(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _sortedEvents.removeAt(oldIndex);
      _sortedEvents.insert(newIndex, item);
    });
  }

  ReminderTag? get _tag => TagService.getTagById(_collection.tagId);

  Color get _tagColor => _tag?.accentColor ?? _themeBlue;

  int get _longPageCount {
    final count = _shareEvents.length;
    if (count == 0) return 0;
    return math.max(1, (count / _longPageSize).ceil());
  }

  String? _coverPath() {
    final custom = _collection.coverPhotoPath;
    if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
      return custom;
    }
    for (var i = _events.length - 1; i >= 0; i--) {
      final p = MemoryService.firstSlotPhotoPath(_events[i]);
      if (p != null) return p;
    }
    return null;
  }

  String _rangeLine() {
    if (_events.isEmpty) return '暂无瞬间';
    return '${formatYearMonthDot(_events.first.date)} - ${formatYearMonthDot(_events.last.date)}';
  }

  List<MemoryEvent> _eventsForLongPage(int pageIndex) {
    final list = _shareEvents;
    if (list.isEmpty) return const [];
    final start = pageIndex * _longPageSize;
    if (start >= list.length) return const [];
    final end = math.min(start + _longPageSize, list.length);
    return list.sublist(start, end);
  }

  void _switchMode(_ShareViewMode mode) {
    if (_isEditing) return;
    if (mode == _ShareViewMode.longImage && _events.isEmpty) return;
    setState(() {
      _mode = mode;
      _longPageIndex = 0;
    });
  }

  Future<List<String>> _captureForExport(double width) async {
    if (_mode == _ShareViewMode.concise) {
      final key = GlobalKey();
      final path = await _renderAndCapture(
        width: width,
        builder: () => _ShareConciseCard(
          collection: _collection,
          events: _shareEvents,
          sortedEvents: _sortedEvents,
          coverPath: _coverPath(),
          tag: _tag,
          tagColor: _tagColor,
          rangeLine: _rangeLine(),
          hideLocation: _hideLocation,
          isEditing: false,
          selectedEventIds: _selectedEventIds,
          forExport: true,
        ),
        key: key,
      );
      return path == null ? [] : [path];
    }

    final pageCount = _longPageCount;
    final keys = List.generate(pageCount, (_) => GlobalKey());
    final paths = await _renderMultipleAndCapture(
      width: width,
      builders: [
        for (var i = 0; i < pageCount; i++)
          () => _ShareLongPage(
            collection: _collection,
            events: _eventsForLongPage(i),
            sortedEvents: _sortedEvents,
            coverPath: _coverPath(),
            tag: _tag,
            tagColor: _tagColor,
            rangeLine: _rangeLine(),
            totalEventCount: _events.length,
            totalPhotoCount: MemoryService.countPhotosInCollection(_events),
            showHeader: i == 0,
            showBrand: i == pageCount - 1,
            hideLocation: _hideLocation,
            isEditing: false,
            selectedEventIds: _selectedEventIds,
            forExport: true,
          ),
      ],
      keys: keys,
    );
    return paths;
  }

  Future<String?> _renderAndCapture({
    required double width,
    required GlobalKey key,
    required Widget Function() builder,
  }) async {
    final paths = await _renderMultipleAndCapture(
      width: width,
      builders: [builder],
      keys: [key],
    );
    return paths.isEmpty ? null : paths.first;
  }

  Future<List<String>> _renderMultipleAndCapture({
    required double width,
    required List<Widget Function()> builders,
    required List<GlobalKey> keys,
  }) async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return [];

    final entries = <OverlayEntry>[];
    for (var i = 0; i < builders.length; i++) {
      final key = keys[i];
      entries.add(
        OverlayEntry(
          builder: (ctx) => Positioned(
            left: -20000,
            top: i * 12000.0,
            child: Material(
              color: Colors.white,
              child: RepaintBoundary(
                key: key,
                child: SizedBox(width: width, child: builders[i]()),
              ),
            ),
          ),
        ),
      );
    }

    for (final e in entries) {
      overlay.insert(e);
    }
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 120));

    try {
      return await ShareService.captureLongImagePages(
        keys,
        collectionName: _collection.name,
      );
    } finally {
      for (final e in entries) {
        e.remove();
      }
    }
  }

  Future<void> _saveToAlbum() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final width = MediaQuery.sizeOf(context).width - 32;
      final paths = await _captureForExport(width);
      if (paths.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('生成分享图失败')),
        );
        return;
      }
      await ShareService.saveImagesToAlbum(paths);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存 ${paths.length} 张图片到相册')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请检查相册权限')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareToFriends() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final width = MediaQuery.sizeOf(context).width - 32;
      final paths = await _captureForExport(width);
      if (paths.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('生成分享图失败')),
        );
        return;
      }
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            for (final p in paths) XFile(p, mimeType: 'image/png'),
          ],
          text: '${_collection.name} · 时光集',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _modePill({
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !enabled
              ? const Color(0xFFF1F5F9)
              : (selected ? _themeBlue : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
          border: selected || !enabled
              ? null
              : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: !enabled
                ? const Color(0xFFCBD5E1)
                : (selected ? Colors.white : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final photoCount = MemoryService.countPhotosInCollection(_events);
    final longDisabled = _events.isEmpty;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: _bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: _isEditing ? 0.5 : 1,
                  child: IgnorePointer(
                    ignoring: _isEditing,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _modePill(
                          label: '简洁卡片',
                          selected: _mode == _ShareViewMode.concise,
                          enabled: true,
                          onTap: () => _switchMode(_ShareViewMode.concise),
                        ),
                        const SizedBox(width: 8),
                        _modePill(
                          label: '纪念长图',
                          selected: _mode == _ShareViewMode.longImage,
                          enabled: !longDisabled,
                          onTap: () => _switchMode(_ShareViewMode.longImage),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: _muted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                if (!_isEditing && !_loading)
                  Positioned(
                    right: 8,
                    child: TextButton(
                      onPressed: _events.isEmpty ? null : _enterEditMode,
                      child: const Text(
                        '编辑',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _themeBlue,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _mode == _ShareViewMode.concise
                            ? _ShareConciseCard(
                                key: const ValueKey('concise'),
                                collection: _collection,
                                events: _shareEvents,
                                sortedEvents: _sortedEvents,
                                coverPath: _coverPath(),
                                tag: _tag,
                                tagColor: _tagColor,
                                rangeLine: _rangeLine(),
                                photoCount: photoCount,
                                hideLocation: _hideLocation,
                                isEditing: _isEditing,
                                selectedEventIds: _selectedEventIds,
                                onToggleSelect: _toggleEventSelection,
                                onReorder: _reorderEvents,
                                onHideLocationChanged: (v) =>
                                    setState(() => _hideLocation = v),
                                forExport: false,
                              )
                            : Column(
                                key: ValueKey('long_$_longPageIndex'),
                                children: [
                                  _ShareLongPage(
                                    collection: _collection,
                                    events: _isEditing
                                        ? _shareEvents
                                        : _eventsForLongPage(_longPageIndex),
                                    sortedEvents: _sortedEvents,
                                    coverPath: _coverPath(),
                                    tag: _tag,
                                    tagColor: _tagColor,
                                    rangeLine: _rangeLine(),
                                    totalEventCount: _events.length,
                                    totalPhotoCount: photoCount,
                                    showHeader:
                                        _isEditing || _longPageIndex == 0,
                                    showBrand: _isEditing ||
                                        _longPageIndex == _longPageCount - 1,
                                    hideLocation: _hideLocation,
                                    isEditing: _isEditing,
                                    selectedEventIds: _selectedEventIds,
                                    onToggleSelect: _toggleEventSelection,
                                    onReorder: _reorderEvents,
                                    onHideLocationChanged: (v) =>
                                        setState(() => _hideLocation = v),
                                    forExport: false,
                                  ),
                                  if (!_isEditing && _longPageCount > 1) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          onPressed: _longPageIndex > 0
                                              ? () => setState(
                                                    () => _longPageIndex--,
                                                  )
                                              : null,
                                          icon: const Icon(
                                            Icons.chevron_left,
                                            color: _muted,
                                          ),
                                        ),
                                        Text(
                                          '第 ${_longPageIndex + 1} / $_longPageCount 页',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: _muted,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed:
                                              _longPageIndex < _longPageCount - 1
                                              ? () => setState(
                                                    () => _longPageIndex++,
                                                  )
                                              : null,
                                          icon: const Icon(
                                            Icons.chevron_right,
                                            color: _muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
            ),
            Container(
              height: 64 + bottom,
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _divider)),
              ),
              child: _isEditing
                  ? Row(
                      children: [
                        TextButton(
                          onPressed: _cancelEdit,
                          child: const Text(
                            '取消',
                            style: TextStyle(
                              fontSize: 14,
                              color: _muted,
                            ),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 36,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _themeBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _finishEdit,
                            child: const Text(
                              '完成',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _themeBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _busy ? null : _saveToAlbum,
                              child: _busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '保存到相册',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _titleColor,
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _busy ? null : _shareToFriends,
                              child: const Text(
                                '分享给好友',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
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

class _ShareCover extends StatelessWidget {
  const _ShareCover({
    required this.height,
    required this.coverPath,
    required this.tagColor,
    required this.name,
  });

  final double height;
  final String? coverPath;
  final Color tagColor;
  final String name;

  String _initials(String n) {
    final t = n.trim();
    if (t.isEmpty) return '时';
    return t.length > 2 ? t.substring(0, 2) : t;
  }

  @override
  Widget build(BuildContext context) {
    final radius = const BorderRadius.vertical(top: Radius.circular(16));
    final Widget coverChild;
    if (coverPath != null) {
      coverChild = Image.file(
        File(coverPath!),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
      );
    } else {
      coverChild = Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tagColor, tagColor.withValues(alpha: 0.8)],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            coverChild,
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 1.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareInfoSection extends StatelessWidget {
  const _ShareInfoSection({
    required this.collection,
    required this.rangeLine,
    required this.tag,
    required this.tagColor,
    required this.photoCount,
    required this.eventCount,
    required this.titleSize,
  });

  final MemoryCollection collection;
  final String rangeLine;
  final ReminderTag? tag;
  final Color tagColor;
  final int photoCount;
  final int eventCount;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            collection.name.isNotEmpty ? collection.name : '未命名事件集',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rangeLine,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    tag!.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (tag != null) const SizedBox(width: 8),
              Text(
                '共 $eventCount 个瞬间 · $photoCount 张照片',
                style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareBrandFooter extends StatelessWidget {
  const _ShareBrandFooter({this.topPadding = 24});

  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '时光集',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A73E8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '记录美好时光',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          Container(
            width: 120,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFFFFB800)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareHideLocationRow extends StatelessWidget {
  const _ShareHideLocationRow({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const Text(
            '隐藏地点信息',
            style: TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
          ),
          const Spacer(),
          Switch.adaptive(
            value: value,
            activeTrackColor: const Color(0xFF1A73E8),
            activeThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE2E8F0),
            inactiveThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ShareEventCheckbox extends StatelessWidget {
  const _ShareEventCheckbox({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? const Color(0xFF1A73E8) : Colors.transparent,
          border: selected
              ? null
              : Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        alignment: Alignment.center,
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}

class _ShareConciseCard extends StatelessWidget {
  const _ShareConciseCard({
    super.key,
    required this.collection,
    required this.events,
    required this.sortedEvents,
    required this.coverPath,
    required this.tag,
    required this.tagColor,
    required this.rangeLine,
    required this.hideLocation,
    required this.isEditing,
    required this.selectedEventIds,
    this.photoCount,
    this.onToggleSelect,
    this.onReorder,
    this.onHideLocationChanged,
    this.forExport = false,
  });

  final MemoryCollection collection;
  final List<MemoryEvent> events;
  final List<MemoryEvent> sortedEvents;
  final String? coverPath;
  final ReminderTag? tag;
  final Color tagColor;
  final String rangeLine;
  final bool hideLocation;
  final bool isEditing;
  final Set<String> selectedEventIds;
  final int? photoCount;
  final ValueChanged<String>? onToggleSelect;
  final void Function(int, int)? onReorder;
  final ValueChanged<bool>? onHideLocationChanged;
  final bool forExport;

  static const int _previewMax = 5;

  @override
  Widget build(BuildContext context) {
    final count = photoCount ?? MemoryService.countPhotosInCollection(events);
    final displayEvents = forExport
        ? events
        : events.take(_previewMax).toList();
    final remaining = forExport ? 0 : events.length - displayEvents.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: forExport
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ShareCover(
            height: 200,
            coverPath: coverPath,
            tagColor: tagColor,
            name: collection.name,
          ),
          _ShareInfoSection(
            collection: collection,
            rangeLine: rangeLine,
            tag: tag,
            tagColor: tagColor,
            photoCount: count,
            eventCount: events.length,
            titleSize: 20,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '时间线',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ),
          if (events.isEmpty && !isEditing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                '暂无瞬间',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              ),
            )
          else if (isEditing && !forExport) ...[
            if (onHideLocationChanged != null)
              _ShareHideLocationRow(
                value: hideLocation,
                onChanged: onHideLocationChanged!,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: sortedEvents.length,
                onReorder: onReorder ?? (_, _) {},
                itemBuilder: (context, index) {
                  final e = sortedEvents[index];
                  return Padding(
                    key: ValueKey(e.id),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _ShareEventCheckbox(
                            selected: selectedEventIds.contains(e.id),
                            onTap: () => onToggleSelect?.call(e.id),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Opacity(
                            opacity: selectedEventIds.contains(e.id) ? 1 : 0.45,
                            child: _ConciseTimelineRow(
                              event: e,
                              hideLocation: hideLocation,
                            ),
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8, top: 2),
                            child: Icon(
                              Icons.drag_handle,
                              size: 20,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  for (final e in displayEvents)
                    _ConciseTimelineRow(
                      event: e,
                      hideLocation: hideLocation,
                    ),
                ],
              ),
            ),
          if (!forExport && remaining > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '还有 $remaining 个精彩瞬间...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              ),
            ),
          const _ShareBrandFooter(),
        ],
      ),
    );
  }
}

class _ConciseTimelineRow extends StatelessWidget {
  const _ConciseTimelineRow({
    required this.event,
    this.hideLocation = false,
  });

  final MemoryEvent event;
  final bool hideLocation;

  @override
  Widget build(BuildContext context) {
    final loc = event.location?.trim();
    final showLoc = !hideLocation && loc != null && loc.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MemoryTimelineRailMarker(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14, height: 1.4),
                      children: [
                        TextSpan(
                          text: formatMonthDayZh(event.date),
                          style: const TextStyle(
                            color: Color(0xFF1A73E8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: ' · ${event.title}',
                          style: const TextStyle(color: Color(0xFF1F2937)),
                        ),
                      ],
                    ),
                  ),
                  if (showLoc) ...[
                    const SizedBox(height: 6),
                    MemoryLocationCapsule(location: loc),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareLongPage extends StatelessWidget {
  const _ShareLongPage({
    required this.collection,
    required this.events,
    required this.sortedEvents,
    required this.coverPath,
    required this.tag,
    required this.tagColor,
    required this.rangeLine,
    required this.totalEventCount,
    required this.totalPhotoCount,
    required this.showHeader,
    required this.showBrand,
    required this.hideLocation,
    required this.isEditing,
    required this.selectedEventIds,
    this.onToggleSelect,
    this.onReorder,
    this.onHideLocationChanged,
    this.forExport = false,
  });

  final MemoryCollection collection;
  final List<MemoryEvent> events;
  final List<MemoryEvent> sortedEvents;
  final String? coverPath;
  final ReminderTag? tag;
  final Color tagColor;
  final String rangeLine;
  final int totalEventCount;
  final int totalPhotoCount;
  final bool showHeader;
  final bool showBrand;
  final bool hideLocation;
  final bool isEditing;
  final Set<String> selectedEventIds;
  final ValueChanged<String>? onToggleSelect;
  final void Function(int, int)? onReorder;
  final ValueChanged<bool>? onHideLocationChanged;
  final bool forExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            _ShareCover(
              height: 280,
              coverPath: coverPath,
              tagColor: tagColor,
              name: collection.name,
            ),
            _ShareInfoSection(
              collection: collection,
              rangeLine: rangeLine,
              tag: tag,
              tagColor: tagColor,
              photoCount: totalPhotoCount,
              eventCount: totalEventCount,
              titleSize: 24,
            ),
          ],
          if (isEditing && !forExport && onHideLocationChanged != null)
            _ShareHideLocationRow(
              value: hideLocation,
              onChanged: onHideLocationChanged!,
            ),
          if (isEditing && !forExport)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: sortedEvents.length,
                onReorder: onReorder ?? (_, _) {},
                itemBuilder: (context, index) {
                  final e = sortedEvents[index];
                  final selected = selectedEventIds.contains(e.id);
                  return Padding(
                    key: ValueKey(e.id),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                    child: Column(
                      children: [
                        if (index > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _ShareEventCheckbox(
                                  selected: selected,
                                  onTap: () => onToggleSelect?.call(e.id),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Opacity(
                                  opacity: selected ? 1 : 0.45,
                                  child: _LongEventBlock(
                                    event: e,
                                    hideLocation: hideLocation,
                                  ),
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 8, top: 8),
                                  child: Icon(
                                    Icons.drag_handle,
                                    size: 20,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            for (var i = 0; i < events.length; i++) ...[
              if (i > 0 || showHeader)
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              _LongEventBlock(
                event: events[i],
                hideLocation: hideLocation,
              ),
            ],
          if (showBrand) const _ShareBrandFooter(topPadding: 32),
        ],
      ),
    );
  }
}

class _LongEventBlock extends StatelessWidget {
  const _LongEventBlock({
    required this.event,
    this.hideLocation = false,
  });

  final MemoryEvent event;
  final bool hideLocation;

  @override
  Widget build(BuildContext context) {
    final loc = event.location?.trim();
    final showLoc = !hideLocation && loc != null && loc.isNotEmpty;
    final photo = MemoryService.firstSlotPhotoPath(event);
    final hasPhoto = photo != null && File(photo).existsSync();

    if (!hasPhoto) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MemoryTimelineRailMarker(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          formatMonthDayZh(event.date),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1A73E8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showLoc) ...[
                      const SizedBox(height: 6),
                      MemoryLocationCapsule(location: loc),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                formatMonthDayZh(event.date),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A73E8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          if (showLoc) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 12,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  loc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF1F5F9),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(photo),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 220,
                ),
                if (showLoc)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            loc,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
