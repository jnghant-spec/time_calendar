import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:time_calendar/services/tag_service.dart';

/// 标签图标 1:1 裁剪页（InteractiveViewer + 固定裁剪框）。
class TagPhotoCropPage extends StatefulWidget {
  const TagPhotoCropPage({super.key, required this.imagePath});

  final String imagePath;

  static const double cropSize = 300;
  static const int outputSize = 200;

  static Future<String?> show(BuildContext context, String imagePath) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => TagPhotoCropPage(imagePath: imagePath),
      ),
    );
  }

  @override
  State<TagPhotoCropPage> createState() => _TagPhotoCropPageState();
}

class _TagPhotoCropPageState extends State<TagPhotoCropPage> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _controller = TransformationController();
  double? _imageWidth;
  double? _imageHeight;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (!File(widget.imagePath).existsSync()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('照片文件不存在')),
        );
        Navigator.of(context).pop();
      });
      return;
    }
    _loadImageSize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _imageWidth = image.width.toDouble();
        _imageHeight = image.height.toDouble();
        _ready = true;
      });
      image.dispose();
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitImage());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片文件不存在')),
      );
      Navigator.of(context).pop();
    }
  }

  void _fitImage() {
    _controller.value = Matrix4.identity();
  }

  Future<void> _confirm() async {
    try {
      final boundary = _cropKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final pixelRatio = TagPhotoCropPage.outputSize / TagPhotoCropPage.cropSize;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return;
      final path = await TagService.persistTagPhoto(
        byteData.buffer.asUint8List(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(path);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _cropViewport() {
    if (!_ready || _imageWidth == null || _imageHeight == null) {
      return const SizedBox(
        width: TagPhotoCropPage.cropSize,
        height: TagPhotoCropPage.cropSize,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    const crop = TagPhotoCropPage.cropSize;
    return SizedBox(
      width: crop,
      height: crop,
      child: RepaintBoundary(
        key: _cropKey,
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 0.5,
          maxScale: 4.0,
          constrained: true,
          boundaryMargin: const EdgeInsets.all(100),
          clipBehavior: Clip.none,
          child: SizedBox(
            width: crop,
            height: crop,
            child: ClipRect(
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.cover,
                width: crop,
                height: crop,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: crop,
                  height: crop,
                  color: Colors.red.withValues(alpha: 0.2),
                  alignment: Alignment.center,
                  child: const Icon(Icons.error, color: Colors.red),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewSize = constraints.biggest;
            final holeCenter = Offset(viewSize.width / 2, viewSize.height / 2);
            final holeRadius = TagPhotoCropPage.cropSize / 2;
            final ringTop = holeCenter.dy - holeRadius;
            const hintHeight = 20.0;
            final hintTop = ringTop - 24 - hintHeight;

            return Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.grey[800]),
                Center(child: _cropViewport()),
                IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        size: viewSize,
                        painter: _CircleCropOverlayPainter(
                          holeRadius: holeRadius,
                          center: holeCenter,
                        ),
                      ),
                      Positioned(
                        top: hintTop.clamp(8.0, ringTop - 24),
                        left: 0,
                        right: 0,
                        child: const Center(
                          child: Text(
                            '拖动和缩放来调整照片位置',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 4,
                                  color: Color(0x8A000000),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 16 + bottom,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _ready ? _confirm : null,
                          child: const Text(
                            '确认裁剪',
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
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CircleCropOverlayPainter extends CustomPainter {
  _CircleCropOverlayPainter({
    required this.holeRadius,
    required this.center,
  });

  final double holeRadius;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addOval(Rect.fromCircle(center: center, radius: holeRadius));
    final overlay = Path.combine(PathOperation.difference, fullRect, hole);

    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    canvas.drawCircle(
      center,
      holeRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleCropOverlayPainter oldDelegate) {
    return oldDelegate.holeRadius != holeRadius ||
        oldDelegate.center != center;
  }
}
