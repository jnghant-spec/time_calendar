import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/pages/photo_viewer_page.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/widgets/common_date_picker.dart';

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
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height;
      return Padding(
        padding: EdgeInsets.only(top: height * 0.08),
        child: SizedBox(
          height: height * 0.92,
          child: MemoryEventSheet(
            collectionId: collectionId,
            initial: initial,
            readOnlyPreview: readOnlyPreview,
          ),
        ),
      );
    },
  );
}

class MemoryEventSheet extends StatefulWidget {
  const MemoryEventSheet({
    super.key,
    required this.collectionId,
    this.initial,
    this.readOnlyPreview = false,
  });

  final String collectionId;
  final MemoryEvent? initial;
  final bool readOnlyPreview;

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
  late List<String?> _slotPhotos;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _locCtrl = TextEditingController(text: e?.location ?? '');
    _date = e?.date ?? DateTime.now();
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

  Future<void> _pickForSlot(int slotIndex) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (file == null) return;
      final path = await _persistPhoto(file);
      if (!mounted || path == null) return;
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
    } catch (_) {}
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

  Future<void> _takePhoto() async {
    try {
      final emptyIdx = _slotPhotos.indexWhere((s) => s == null);
      if (emptyIdx < 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('九宫格已满')));
        return;
      }
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (file == null) return;
      final path = await _persistPhoto(file);
      if (!mounted || path == null) return;
      setState(() => _slotPhotos[emptyIdx] = path);
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showMemoryEventDatePicker(
      context,
      initialDate: _date,
    );
    if (picked != null) {
      setState(
        () => _date = DateTime(picked.year, picked.month, picked.day),
      );
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
    );
    if (widget.initial == null) {
      await MemoryService.addEventToCollection(event, widget.collectionId);
    } else {
      await MemoryService.upsertEvent(event);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  List<String> _viewerPhotoPaths() {
    return _slotPhotos
        .where(
          (p) => p != null && p.trim().isNotEmpty && File(p).existsSync(),
        )
        .cast<String>()
        .toList();
  }

  void _openPhotoViewer(int gridIndex) {
    final paths = _viewerPhotoPaths();
    if (paths.isEmpty) return;
    final path = _slotPhotos[gridIndex];
    if (path == null) return;
    final initialIndex = paths.indexOf(path);
    PhotoViewerPage.show(
      context,
      photos: paths.map((p) => MemoryPhoto(path: p)).toList(),
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
      eventName: _titleCtrl.text.trim().isEmpty ? '纪念事件' : _titleCtrl.text.trim(),
      eventDate: _date,
    );
  }

  void _showPhotoActionSheet(int index) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('替换照片'),
              onTap: () {
                Navigator.pop(ctx);
                _pickForSlot(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除照片'),
              onTap: () {
                Navigator.pop(ctx);
                final oldPath = _slotPhotos[index];
                setState(() => _slotPhotos[index] = null);
                MemoryService.deletePhotoFileIfExists(oldPath);
              },
            ),
          ],
        ),
      ),
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
            onLongPress: () => _showPhotoActionSheet(index),
            child: slotChrome(highlight: highlight, showImage: true),
          ),
        );
      },
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
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        decoration: InputDecoration(
                          hintText: '输入事件名称',
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: _locCtrl,
                        decoration: InputDecoration(
                          hintText: '添加地点',
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
                      const SizedBox(height: 16),
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
                                Text(
                                  formatMemoryStreamDayZh(_date),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: MemoryEventSheet._themeBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '纪念照片',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: MemoryEventSheet._titleColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 3,
                        childAspectRatio: 1.0,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MemoryEventSheet._themeBlue,
                                side: const BorderSide(
                                  color: MemoryEventSheet._themeBlue,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _pickMultiGallery,
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                size: 18,
                                color: MemoryEventSheet._themeBlue,
                              ),
                              label: const Text(
                                '从相册上传',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: MemoryEventSheet._themeBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MemoryEventSheet._themeBlue,
                                side: const BorderSide(
                                  color: MemoryEventSheet._themeBlue,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _takePhoto,
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                                color: MemoryEventSheet._themeBlue,
                              ),
                              label: const Text(
                                '拍照上传',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: MemoryEventSheet._themeBlue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  height: 48,
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
