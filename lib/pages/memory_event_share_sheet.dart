import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/share_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/widgets/memory_event_photo_grid.dart';

enum _EventShareMode { concise, longImage }

Future<void> showMemoryEventShareSheet(
  BuildContext context, {
  required MemoryEvent event,
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
        child: MemoryEventShareSheet(
          event: event,
          collection: collection,
        ),
      ),
    ),
  );
}

class MemoryEventShareSheet extends StatefulWidget {
  const MemoryEventShareSheet({
    super.key,
    required this.event,
    required this.collection,
  });

  final MemoryEvent event;
  final MemoryCollection collection;

  @override
  State<MemoryEventShareSheet> createState() => _MemoryEventShareSheetState();
}

class _MemoryEventShareSheetState extends State<MemoryEventShareSheet> {
  static const Color _bg = Color(0xFFFAFBFC);
  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _divider = Color(0xFFF1F5F9);
  static const double _maxExportPageHeight = 4000;

  _EventShareMode _mode = _EventShareMode.concise;
  bool _busy = false;

  MemoryEvent get _event => widget.event;

  List<String> get _photoPaths => MemoryService.existingPhotoPaths(_event);

  String? get _coverPath => MemoryService.firstSlotPhotoPath(_event);

  bool get _hasPhotos => _photoPaths.isNotEmpty;

  Color get _tagColor {
    final tag = TagService.getTagById(widget.collection.tagId);
    return tag?.accentColor ?? _themeBlue;
  }

  String get _shareFileName =>
      _event.title.isNotEmpty ? _event.title : 'memory_event';

  void _switchMode(_EventShareMode mode) {
    if (mode == _EventShareMode.longImage && !_hasPhotos) return;
    setState(() => _mode = mode);
  }

  Future<List<String>> _renderAndCapture({
    required double width,
    required List<Widget Function()> builders,
    required List<GlobalKey> keys,
  }) async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return [];

    final entries = <OverlayEntry>[];
    for (var i = 0; i < builders.length; i++) {
      entries.add(
        OverlayEntry(
          builder: (ctx) => Positioned(
            left: -20000,
            top: i * 15000.0,
            child: Material(
              color: Colors.white,
              child: RepaintBoundary(
                key: keys[i],
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
        collectionName: _shareFileName,
      );
    } finally {
      for (final e in entries) {
        e.remove();
      }
    }
  }

  Future<List<String>> _captureForExport(double width) async {
    if (_mode == _EventShareMode.concise) {
      final key = GlobalKey();
      final paths = await _renderAndCapture(
        width: width,
        builders: [
          () => _EventShareConciseCard(
            event: _event,
            tagColor: _tagColor,
            contentWidth: width,
            forExport: true,
          ),
        ],
        keys: [key],
      );
      return paths;
    }

    final pages = _buildLongExportPages(width);
    if (pages.isEmpty) return [];
    final keys = List.generate(pages.length, (_) => GlobalKey());
    return _renderAndCapture(
      width: width,
      builders: [
        for (final page in pages)
          () => _EventShareLongExportPage(
            event: _event,
            coverPath: _coverPath,
            tagColor: _tagColor,
            photoPaths: page.photoPaths,
            photoTileHeight: MemoryEventPhotoGrid.shareTileHeight(width),
            showHeader: page.showHeader,
            showPhotoTitle: page.showPhotoTitle,
            showBrand: page.showBrand,
          ),
      ],
      keys: keys,
    );
  }

  List<_LongExportSlice> _buildLongExportPages(double contentWidth) {
    final photos = _photoPaths;
    if (photos.isEmpty) {
      return [
        _LongExportSlice(
          showHeader: true,
          showPhotoTitle: false,
          photoPaths: const [],
          showBrand: true,
        ),
      ];
    }

    final photoTileHeight = MemoryEventPhotoGrid.shareTileHeight(contentWidth);
    final photoBlockH =
        photoTileHeight + MemoryEventPhotoGridTokens.sharePhotoSpacing;
    final headerH = photoTileHeight + 130.0;
    const titleH = 48.0;
    const brandH = 132.0;

    final pages = <_LongExportSlice>[];
    var photoIndex = 0;
    var isFirst = true;

    while (isFirst || photoIndex < photos.length) {
      var used = isFirst ? headerH + titleH : 0.0;
      final slice = <String>[];

      while (photoIndex < photos.length) {
        final remainingAfter = photos.length - photoIndex - 1;
        final brandReserve = remainingAfter == 0 && slice.isNotEmpty ? brandH : 0.0;
        final nextCost = photoBlockH + brandReserve;
        if (used + nextCost > _maxExportPageHeight && slice.isNotEmpty) {
          break;
        }
        if (used + photoBlockH > _maxExportPageHeight && slice.isNotEmpty) {
          break;
        }
        slice.add(photos[photoIndex]);
        used += photoBlockH;
        photoIndex++;
      }

      final isLast = photoIndex >= photos.length;
      pages.add(
        _LongExportSlice(
          showHeader: isFirst,
          showPhotoTitle: isFirst,
          photoPaths: slice,
          showBrand: isLast,
        ),
      );
      isFirst = false;

      if (slice.isEmpty && !isLast) {
        break;
      }
    }

    return pages;
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
          text: '${_event.title} · 时光集',
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
    final longDisabled = !_hasPhotos;
    final contentWidth = MediaQuery.sizeOf(context).width - 32;

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
            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    '生成分享卡片',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _titleColor,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 24, color: _titleColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _modePill(
                  label: '简洁卡片',
                  selected: _mode == _EventShareMode.concise,
                  enabled: true,
                  onTap: () => _switchMode(_EventShareMode.concise),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: longDisabled ? 0.5 : 1,
                  child: _modePill(
                    label: '纪念长图',
                    selected: _mode == _EventShareMode.longImage,
                    enabled: !longDisabled,
                    onTap: () => _switchMode(_EventShareMode.longImage),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _mode == _EventShareMode.concise
                      ? _EventShareConciseCard(
                          key: const ValueKey('concise'),
                          event: _event,
                          tagColor: _tagColor,
                          contentWidth: contentWidth,
                          forExport: false,
                        )
                      : _EventShareLongPreviewCard(
                          key: const ValueKey('long'),
                          event: _event,
                          coverPath: _coverPath,
                          tagColor: _tagColor,
                          photoPaths: _photoPaths,
                          contentWidth: contentWidth,
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
              child: Row(
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

class _LongExportSlice {
  const _LongExportSlice({
    required this.showHeader,
    required this.showPhotoTitle,
    required this.photoPaths,
    required this.showBrand,
  });

  final bool showHeader;
  final bool showPhotoTitle;
  final List<String> photoPaths;
  final bool showBrand;
}

class _EventShareCover extends StatelessWidget {
  const _EventShareCover({
    required this.height,
    required this.coverPath,
    required this.tagColor,
    required this.title,
  });

  final double height;
  final String? coverPath;
  final Color tagColor;
  final String title;

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
          _initials(title),
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

class _EventShareInfoSection extends StatelessWidget {
  const _EventShareInfoSection({
    required this.event,
    required this.titleSize,
  });

  final MemoryEvent event;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final loc = event.location?.trim();
    final showLoc = loc != null && loc.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            event.title.isNotEmpty ? event.title : '未命名事件',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatFullDate(event.date),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
          if (showLoc) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EventShareBrandFooter extends StatelessWidget {
  const _EventShareBrandFooter({this.topPadding = 24});

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

class _EventShareConciseCard extends StatelessWidget {
  const _EventShareConciseCard({
    super.key,
    required this.event,
    required this.tagColor,
    required this.contentWidth,
    this.forExport = false,
  });

  final MemoryEvent event;
  final Color tagColor;
  final double contentWidth;
  final bool forExport;

  Widget _buildPhotoHeader() {
    final gridSlots = MemoryEventPhotoGrid.gridSlotPaths(event);
    final photoCount = MemoryEventPhotoGrid.filledSlotCount(event);

    if (photoCount == 0) {
      return _EventShareCover(
        height: 200,
        coverPath: null,
        tagColor: tagColor,
        title: event.title,
      );
    }
    if (photoCount == 1) {
      return _EventShareCover(
        height: 200,
        coverPath: MemoryEventPhotoGrid.firstFilledSlotPath(event),
        tagColor: tagColor,
        title: event.title,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: MemoryEventShareConciseGrid(
        gridSlotPaths: gridSlots,
        contentWidth: contentWidth - 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: forExport ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
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
          _buildPhotoHeader(),
          _EventShareInfoSection(event: event, titleSize: 20),
          const _EventShareBrandFooter(),
        ],
      ),
    );
  }
}

class _EventShareLongPreviewCard extends StatelessWidget {
  const _EventShareLongPreviewCard({
    super.key,
    required this.event,
    required this.coverPath,
    required this.tagColor,
    required this.photoPaths,
    required this.contentWidth,
  });

  final MemoryEvent event;
  final String? coverPath;
  final Color tagColor;
  final List<String> photoPaths;
  final double contentWidth;

  @override
  Widget build(BuildContext context) {
    final photoTileHeight = MemoryEventPhotoGrid.shareTileHeight(contentWidth);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EventShareCover(
            height: photoTileHeight,
            coverPath: coverPath,
            tagColor: tagColor,
            title: event.title,
          ),
          _EventShareInfoSection(event: event, titleSize: 24),
          if (photoPaths.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '纪念照片',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < photoPaths.length; i++) ...[
                    if (i > 0)
                      SizedBox(
                        height: MemoryEventPhotoGridTokens.sharePhotoSpacing,
                      ),
                    MemoryEventSharePhotoTile(
                      path: photoPaths[i],
                      height: photoTileHeight,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const _EventShareBrandFooter(topPadding: 32),
        ],
      ),
    );
  }
}

class _EventShareLongExportPage extends StatelessWidget {
  const _EventShareLongExportPage({
    required this.event,
    required this.coverPath,
    required this.tagColor,
    required this.photoPaths,
    required this.photoTileHeight,
    required this.showHeader,
    required this.showPhotoTitle,
    required this.showBrand,
  });

  final MemoryEvent event;
  final String? coverPath;
  final Color tagColor;
  final List<String> photoPaths;
  final double photoTileHeight;
  final bool showHeader;
  final bool showPhotoTitle;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            _EventShareCover(
              height: photoTileHeight,
              coverPath: coverPath,
              tagColor: tagColor,
              title: event.title,
            ),
            _EventShareInfoSection(event: event, titleSize: 24),
          ],
          if (showPhotoTitle && photoPaths.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '纪念照片',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ),
          if (photoPaths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < photoPaths.length; i++) ...[
                    if (i > 0)
                      SizedBox(
                        height: MemoryEventPhotoGridTokens.sharePhotoSpacing,
                      ),
                    MemoryEventSharePhotoTile(
                      path: photoPaths[i],
                      height: photoTileHeight,
                    ),
                  ],
                ],
              ),
            ),
          if (showBrand) const _EventShareBrandFooter(topPadding: 32),
        ],
      ),
    );
  }
}
