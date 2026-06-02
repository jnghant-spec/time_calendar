import 'dart:io';

import 'package:flutter/material.dart';

/// 全屏照片预览（PageView + InteractiveViewer），背景纯黑。
class EventPhotoPathsPreviewOverlay extends StatefulWidget {
  const EventPhotoPathsPreviewOverlay({
    super.key,
    required this.paths,
    required this.initialIndex,
  });

  final List<String> paths;
  final int initialIndex;

  @override
  State<EventPhotoPathsPreviewOverlay> createState() =>
      _EventPhotoPathsPreviewOverlayState();
}

class _EventPhotoPathsPreviewOverlayState extends State<EventPhotoPathsPreviewOverlay> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    final n = widget.paths.length;
    final safe = n == 0 ? 0 : widget.initialIndex.clamp(0, n - 1);
    _currentPage = safe;
    _pageController = PageController(initialPage: safe);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final paths = widget.paths;
    if (paths.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close());
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: paths.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (ctx, i) {
              return SizedBox.expand(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  clipBehavior: Clip.none,
                  child: Image.file(
                    File(paths[i]),
                    fit: BoxFit.contain,
                    errorBuilder: (context, _, _) => const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: _close,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentPage + 1} / ${paths.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
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

/// [photoPaths] 中仅展示磁盘仍存在的文件；全部缺失时不弹出。
Future<void> showEventPhotoPathsPreview(
  BuildContext context, {
  required List<String> photoPaths,
  int initialIndex = 0,
}) async {
  final existing = photoPaths.where((p) => File(p).existsSync()).toList();
  if (existing.isEmpty) return;
  final idx = initialIndex.clamp(0, existing.length - 1);
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EventPhotoPathsPreviewOverlay(paths: existing, initialIndex: idx),
    ),
  );
}
