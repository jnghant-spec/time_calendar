import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';

/// 预览页照片项（仅含本地路径，非持久化模型）。
class MemoryPhoto {
  const MemoryPhoto({required this.path});

  final String path;
}

class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.eventName,
    this.eventDate,
  });

  final List<MemoryPhoto> photos;
  final int initialIndex;
  final String eventName;
  final DateTime? eventDate;

  static Future<void> showForMemoryEvent(
    BuildContext context, {
    required MemoryEvent event,
    int initialIndex = 0,
  }) {
    final paths = MemoryService.existingPhotoPaths(event);
    if (paths.isEmpty) return Future.value();
    return show(
      context,
      photos: paths.map((p) => MemoryPhoto(path: p)).toList(),
      initialIndex: initialIndex,
      eventName: event.title,
      eventDate: event.date,
    );
  }

  static Future<void> show(
    BuildContext context, {
    required List<MemoryPhoto> photos,
    required int initialIndex,
    required String eventName,
    DateTime? eventDate,
  }) async {
    final existing =
        photos.where((p) => File(p.path).existsSync()).toList(growable: false);
    if (existing.isEmpty) return;
    final idx = initialIndex.clamp(0, existing.length - 1);
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerPage(
          photos: existing,
          initialIndex: idx,
          eventName: eventName,
          eventDate: eventDate,
        ),
      ),
    );
  }

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _uiVisible = true;
  final Map<int, TransformationController> _transformControllers = {};

  static const SystemUiOverlayStyle _lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle _restoreOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setSystemUIOverlayStyle(_lightOverlay);
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(_restoreOverlay);
    _pageController.dispose();
    for (final c in _transformControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TransformationController _controllerFor(int index) {
    return _transformControllers.putIfAbsent(
      index,
      TransformationController.new,
    );
  }

  void _toggleZoom(int index) {
    final controller = _controllerFor(index);
    final scale = controller.value.getMaxScaleOnAxis();
    if (scale > 1.05) {
      controller.value = Matrix4.identity();
    } else {
      controller.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
    }
  }

  void _close() => Navigator.of(context).pop();

  String _bottomSubtitle() {
    final datePart = widget.eventDate != null
        ? '${formatFullDate(widget.eventDate!)} · '
        : '';
    return '$datePart${_currentIndex + 1} / ${widget.photos.length}';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _uiVisible = !_uiVisible),
                  onDoubleTap: () => _toggleZoom(_currentIndex),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.photos.length,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: (context, index) {
                      return Center(
                        child: InteractiveViewer(
                          transformationController: _controllerFor(index),
                          minScale: 0.5,
                          maxScale: 4.0,
                          clipBehavior: Clip.none,
                          child: Image.file(
                            File(widget.photos[index].path),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: top + 8,
            right: 16,
            child: AnimatedOpacity(
              opacity: _uiVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_uiVisible,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    onPressed: _close,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _uiVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_uiVisible,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.eventName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _bottomSubtitle(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
