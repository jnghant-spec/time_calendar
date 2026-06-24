import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/pages/photo_viewer_page.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/widgets/common_date_picker.dart';
import 'package:time_calendar/widgets/memory_event_date_label.dart';

/// 子事件编辑页布局 token。
abstract final class MemoryEventSheetLayoutTokens {
  static const double dragHandleHeight = 40;
  static const double scrollPaddingTop = 16;
  static const double scrollPaddingBottom = 12;
  static const double sectionGap = 12;
  static const double bottomBarHeight = 48;
  static const double bottomBarSafeMin = 12;
  static const EdgeInsets textFieldContentPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const double gridCrossSpacing = 8;
  static const double gridMainSpacing = 8;
  static const double horizontalPadding = 16;
  static const double maxSheetFraction = 0.96;
  static const double minSheetFraction = 0.5;
  static const double sheetHeightSlack = 8;
}

double computeMemoryEventSheetContentHeight(BuildContext context) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final safeBottom = MediaQuery.paddingOf(context).bottom;

  final gridInnerWidth = screenWidth -
      MemoryEventSheetLayoutTokens.horizontalPadding * 2 -
      MemoryEventSheetLayoutTokens.gridCrossSpacing * 2;
  final cellSize = gridInnerWidth / 3;
  final gridHeight =
      cellSize * 3 + MemoryEventSheetLayoutTokens.gridMainSpacing * 2;

  const titleFieldHeight = 48.0;
  const locationFieldHeight = 48.0;
  const dateCapsuleHeight = 40.0;
  const photoHeaderHeight = 48.0;
  const gap = MemoryEventSheetLayoutTokens.sectionGap;

  return MemoryEventSheetLayoutTokens.dragHandleHeight +
      MemoryEventSheetLayoutTokens.scrollPaddingTop +
      titleFieldHeight +
      gap +
      locationFieldHeight +
      gap +
      dateCapsuleHeight +
      gap +
      photoHeaderHeight +
      gap +
      gridHeight +
      MemoryEventSheetLayoutTokens.scrollPaddingBottom +
      MemoryEventSheetLayoutTokens.bottomBarHeight +
      MemoryEventSheetLayoutTokens.bottomBarSafeMin +
      safeBottom +
      MemoryEventSheetLayoutTokens.sheetHeightSlack;
}

double computeMemoryEventSheetInitialSize(BuildContext context) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  if (screenHeight <= 0) return 0.95;
  final fraction =
      computeMemoryEventSheetContentHeight(context) / screenHeight;
  return fraction.clamp(
    MemoryEventSheetLayoutTokens.minSheetFraction,
    MemoryEventSheetLayoutTokens.maxSheetFraction,
  );
}

Future<bool?> showMemoryEventSheet(
  BuildContext context, {
  required String collectionId,
  MemoryEvent? initial,
  bool readOnlyPreview = false,
}) async {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: false,
    builder: (ctx) {
      return _MemoryEventSheetDraggableHost(
        collectionId: collectionId,
        initial: initial,
        readOnlyPreview: readOnlyPreview,
      );
    },
  );
}

/// 拖拽结束时按方向与 extent 判断是否关闭，避免连续 pop 连带关闭上一层。
class _MemoryEventSheetDraggableHost extends StatefulWidget {
  const _MemoryEventSheetDraggableHost({
    required this.collectionId,
    this.initial,
    this.readOnlyPreview = false,
  });

  final String collectionId;
  final MemoryEvent? initial;
  final bool readOnlyPreview;

  @override
  State<_MemoryEventSheetDraggableHost> createState() =>
      _MemoryEventSheetDraggableHostState();
}

class _MemoryEventSheetDraggableHostState
    extends State<_MemoryEventSheetDraggableHost> {
  Offset? _pointerDown;
  bool _dismissed = false;
  bool _initialExtentSet = false;
  double _lastExtent = 0.95;
  double _minExtent = MemoryEventSheetLayoutTokens.minSheetFraction;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialExtentSet) {
      _lastExtent = computeMemoryEventSheetInitialSize(context);
      _initialExtentSet = true;
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDown = event.position;
    _dismissed = false;
  }

  void _onPointerUp(PointerUpEvent event) {
    _tryDismiss(pointerUp: event.position);
  }

  void _tryDismiss({required Offset pointerUp}) {
    if (_dismissed || _pointerDown == null || !mounted) return;

    final down = _pointerDown!;
    final dy = pointerUp.dy - down.dy;
    final dx = pointerUp.dx - down.dx;
    final atMinExtent = _lastExtent <= _minExtent + 0.001;
    final verticalDominant = dy > 0 && dy.abs() > dx.abs();

    if (!atMinExtent || !verticalDominant) return;

    _dismissed = true;
    _pointerDown = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialSize = computeMemoryEventSheetInitialSize(context);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) {
        _pointerDown = null;
      },
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          _lastExtent = notification.extent;
          _minExtent = notification.minExtent;
          return false;
        },
        child: DraggableScrollableSheet(
          initialChildSize: initialSize,
          minChildSize: MemoryEventSheetLayoutTokens.minSheetFraction,
          maxChildSize: MemoryEventSheetLayoutTokens.maxSheetFraction,
          expand: false,
          snap: true,
          snapSizes: [initialSize],
          builder: (context, scrollController) {
            return MemoryEventSheet(
              collectionId: widget.collectionId,
              initial: widget.initial,
              readOnlyPreview: widget.readOnlyPreview,
              scrollController: scrollController,
            );
          },
        ),
      ),
    );
  }
}

class MemoryEventSheet extends StatefulWidget {
  const MemoryEventSheet({
    super.key,
    required this.collectionId,
    this.initial,
    this.readOnlyPreview = false,
    this.scrollController,
  });

  final String collectionId;
  final MemoryEvent? initial;
  final bool readOnlyPreview;
  final ScrollController? scrollController;

  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _themeBlue = Color(0xFF1A73E8);

  @override
  State<MemoryEventSheet> createState() => _MemoryEventSheetState();
}

class _MemoryEventSheetState extends State<MemoryEventSheet> {
  /// 九宫格 index 0~8 对应的 slot 编号（中心格为 1 号）。
  static const List<int> _gridSlotOrder = [2, 3, 4, 5, 1, 6, 7, 8, 9];

  late final TextEditingController _titleCtrl;
  late final TextEditingController _locCtrl;
  late DateTime _date;
  late bool _isLunarDate;
  late List<String?> _slotPhotos;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _locCtrl = TextEditingController(text: e?.location ?? '');
    _date = e?.date ?? DateTime.now();
    _isLunarDate = e?.isLunarDate ?? false;
    _slotPhotos = MemoryService.sanitizePhotoGridSlots(
      MemoryService.decodePhotoGridSlots(e?.photoPaths ?? const []),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  Future<String?> _persistPhoto(XFile file) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/memory_event_photos');
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }
      final dest = File(
        '${folder.path}/${MemoryService.generateId('mimg')}.jpg',
      );
      await File(file.path).copy(dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _pickForSlot(int slotIndex) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (file == null) return false;
      final path = await _persistPhoto(file);
      if (!mounted || path == null) return false;
      final oldPath = _slotPhotos[slotIndex];
      setState(() {
        _slotPhotos[slotIndex] = path;
        _slotPhotos = MemoryService.sanitizePhotoGridSlots(_slotPhotos);
      });
      if (oldPath != null &&
          oldPath != path &&
          oldPath.trim().isNotEmpty) {
        MemoryService.deletePhotoFileIfExists(oldPath);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickMultiGallery() async {
    try {
      final files = await ImagePicker().pickMultiImage(
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (files.isEmpty) return;
      var overflow = false;
      for (final f in files) {
        final emptyIdx = _slotPhotos.indexWhere((s) => s == null);
        if (emptyIdx < 0) {
          overflow = true;
          break;
        }
        final path = await _persistPhoto(f);
        if (path != null) _slotPhotos[emptyIdx] = path;
      }
      if (!mounted) return;
      setState(() {});
      if (overflow && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('最多保存 9 张照片，已忽略超出部分')));
      }
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final result = await showMemoryEventDatePicker(
      context,
      initialDate: _date,
      initialIsLunarDate: _isLunarDate,
    );
    if (result != null) {
      setState(() {
        _date = DateTime(
          result.date.year,
          result.date.month,
          result.date.day,
        );
        _isLunarDate = result.isLunarDate;
      });
    }
  }

  Future<void> _saveEvent() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写事件名称')));
      return;
    }
    final locText = _locCtrl.text.trim();
    final slots = MemoryService.sanitizePhotoGridSlots(_slotPhotos);
    final event = MemoryEvent(
      id: widget.initial?.id ?? MemoryService.generateId('mev'),
      title: title,
      location: locText.isEmpty ? null : locText,
      date: _date,
      photoPaths: MemoryService.encodePhotoGridSlots(slots),
      isLunarDate: _isLunarDate,
    );
    if (widget.initial == null) {
      await MemoryService.addEventToCollection(event, widget.collectionId);
    } else {
      await MemoryService.upsertEvent(event);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  List<({String path, int gridIndex})> _viewerPhotoEntries() {
    final entries = <({String path, int gridIndex})>[];
    for (var i = 0; i < _slotPhotos.length; i++) {
      final path = _slotPhotos[i];
      if (path != null &&
          path.trim().isNotEmpty &&
          File(path).existsSync()) {
        entries.add((path: path, gridIndex: i));
      }
    }
    return entries;
  }

  void _deletePhotoAtGridIndex(int gridIndex) {
    final oldPath = _slotPhotos[gridIndex];
    setState(() => _slotPhotos[gridIndex] = null);
    MemoryService.deletePhotoFileIfExists(oldPath);
  }

  void _openPhotoViewer(int gridIndex) {
    final entries = _viewerPhotoEntries();
    if (entries.isEmpty) return;
    final path = _slotPhotos[gridIndex];
    if (path == null) return;
    final initialIndex = entries.indexWhere((e) => e.gridIndex == gridIndex);
    final gridIndices = entries.map((e) => e.gridIndex).toList(growable: false);
    PhotoViewerPage.show(
      context,
      photos: entries.map((e) => MemoryPhoto(path: e.path)).toList(),
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
      eventName: _titleCtrl.text.trim().isEmpty ? '纪念事件' : _titleCtrl.text.trim(),
      eventDate: _date,
      onReplaceCurrentPhoto: (viewerIndex) async {
        final slotIndex = gridIndices[viewerIndex];
        final replaced = await _pickForSlot(slotIndex);
        if (!mounted || !replaced) return;
        Navigator.of(context).pop();
      },
      onDeleteCurrentPhoto: (viewerIndex) async {
        final slotIndex = gridIndices[viewerIndex];
        _deletePhotoAtGridIndex(slotIndex);
        if (!mounted) return;
        Navigator.of(context).pop();
      },
    );
  }

  void _onEmptySlotTap(int index) {
    _pickForSlot(index);
  }

  void _onPhotoSlotTap(int index) {
    _openPhotoViewer(index);
  }

  Widget _photoSlot(int index, double side) {
    final path = _slotPhotos[index];
    final hasPhoto = path != null && File(path).existsSync();

    final slot = _gridSlotOrder[index];

    Widget slotBadge() {
      return Positioned(
        top: 4,
        right: 4,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: MemoryEventSheet._themeBlue,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$slot',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    Widget slotChrome({required bool highlight, required bool showImage}) {
      return Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight
                ? MemoryEventSheet._themeBlue
                : const Color(0xFFE2E8F0),
            width: highlight ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showImage && path != null && File(path).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(path), fit: BoxFit.cover),
              )
            else
              const Center(
                child: Icon(
                  Icons.add,
                  color: Color(0xFFCBD5E1),
                  size: 24,
                ),
              ),
            slotBadge(),
            if (slot == 1)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MemoryEventSheet._themeBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '封面',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final fromIndex = details.data;
        setState(() {
          final temp = _slotPhotos[fromIndex];
          _slotPhotos[fromIndex] = _slotPhotos[index];
          _slotPhotos[index] = temp;
        });
      },
      builder: (context, candidateData, rejected) {
        final highlight = candidateData.isNotEmpty;

        if (!hasPhoto) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onEmptySlotTap(index),
            child: slotChrome(highlight: highlight, showImage: false),
          );
        }

        final photoPath = path;

        return LongPressDraggable<int>(
          data: index,
          delay: const Duration(milliseconds: 150),
          feedback: Material(
            color: Colors.transparent,
            elevation: 0,
            child: Opacity(
              opacity: 0.9,
              child: Transform.scale(
                scale: 1.05,
                child: Container(
                  width: side,
                  height: side,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(photoPath), fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging:
              slotChrome(highlight: false, showImage: false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onPhotoSlotTap(index),
            // 长按由 LongPressDraggable 占用，用于拖拽排序；更换/删除见预览页底栏。
            child: slotChrome(highlight: highlight, showImage: true),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return SizedBox(
      height: MemoryEventSheetLayoutTokens.dragHandleHeight,
      width: double.infinity,
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: const Color(0xFFFAFBFC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDragHandle(),
              Expanded(
                child: SingleChildScrollView(
                  controller: widget.scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    MemoryEventSheetLayoutTokens.horizontalPadding,
                    MemoryEventSheetLayoutTokens.scrollPaddingTop,
                    MemoryEventSheetLayoutTokens.horizontalPadding,
                    MemoryEventSheetLayoutTokens.scrollPaddingBottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        decoration: InputDecoration(
                          hintText: '输入事件名称',
                          contentPadding:
                              MemoryEventSheetLayoutTokens.textFieldContentPadding,
                          hintStyle: const TextStyle(
                            color: Color(0xFFCBD5E1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: MemoryEventSheet._themeBlue,
                            ),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: MemoryEventSheetLayoutTokens.sectionGap),
                      TextField(
                        controller: _locCtrl,
                        decoration: InputDecoration(
                          hintText: '添加地点',
                          contentPadding:
                              MemoryEventSheetLayoutTokens.textFieldContentPadding,
                          hintStyle: const TextStyle(
                            color: Color(0xFFCBD5E1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: MemoryEventSheet._themeBlue,
                            ),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: MemoryEventSheetLayoutTokens.sectionGap),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: _pickDate,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: MemoryEventSheet._themeBlue,
                                ),
                                const SizedBox(width: 6),
                                MemoryEventDateLabel(
                                  date: _date,
                                  isLunarDate: _isLunarDate,
                                  variant: MemoryEventDateLabelVariant.editChip,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: MemoryEventSheetLayoutTokens.sectionGap),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '纪念照片',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: MemoryEventSheet._titleColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '最多 9 张 · 1 号为封面',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pickMultiGallery,
                            style: TextButton.styleFrom(
                              foregroundColor: MemoryEventSheet._themeBlue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              '从相册添加',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: MemoryEventSheetLayoutTokens.sectionGap),
                      GridView.count(
                        crossAxisCount: 3,
                        childAspectRatio: 1.0,
                        mainAxisSpacing: MemoryEventSheetLayoutTokens.gridMainSpacing,
                        crossAxisSpacing:
                            MemoryEventSheetLayoutTokens.gridCrossSpacing,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: List.generate(
                          9,
                          (i) => LayoutBuilder(
                            builder: (context, constraints) {
                              final cell = constraints.maxWidth;
                              return _photoSlot(i, cell);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: MemoryEventSheetLayoutTokens.sectionGap),
                    ],
                  ),
                ),
              ),
              SafeArea(
                minimum: EdgeInsets.fromLTRB(
                  MemoryEventSheetLayoutTokens.horizontalPadding,
                  0,
                  MemoryEventSheetLayoutTokens.horizontalPadding,
                  MemoryEventSheetLayoutTokens.bottomBarSafeMin,
                ),
                child: SizedBox(
                  height: MemoryEventSheetLayoutTokens.bottomBarHeight,
                  child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text(
                          '关闭',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _saveEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MemoryEventSheet._themeBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '保存',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
}
