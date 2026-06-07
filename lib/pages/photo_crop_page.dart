import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// 与 [WeekViewEventCard] 左侧照片区 `_photoW`:`_photoH` 一致（100:133）。
const double kEventPhotoCropAspectRatio = 100 / 133;

/// 裁剪事件照片；确认后返回持久化前的临时文件路径。
class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({
    super.key,
    required this.sourcePath,
    this.aspectRatio = kEventPhotoCropAspectRatio,
  });

  final String sourcePath;
  final double aspectRatio;

  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

class _PhotoCropPageState extends State<PhotoCropPage>
    with TickerProviderStateMixin {
  static const Color _kThemeBlue = Color(0xFF1A73E8);
  static const double _snapThreshold = 10;
  static const Duration _snapDuration = Duration(milliseconds: 250);

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _imageLayerKey = GlobalKey();
  final GlobalKey _imageKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();
  bool _exporting = false;
  bool _initialFitApplied = false;
  ui.Size? _imagePixelSize;
  Rect? _cropRect;
  Size? _viewportSize;
  double? _logicalW;
  double? _logicalH;

  AnimationController? _snapAnimationController;

  @override
  void initState() {
    super.initState();
    _loadImagePixelSize();
  }

  @override
  void dispose() {
    _snapAnimationController?.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadImagePixelSize() async {
    final bytes = await File(widget.sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() {
      _imagePixelSize = ui.Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    });
    frame.image.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryApplyInitialFit());
  }

  void _tryApplyInitialFit() {
    if (_initialFitApplied || !mounted) return;

    final cropRect = _cropRect;
    final viewportSize = _viewportSize;
    final imagePixelSize = _imagePixelSize;
    final logicalW = _logicalW;
    final logicalH = _logicalH;
    if (cropRect == null ||
        viewportSize == null ||
        imagePixelSize == null ||
        logicalW == null ||
        logicalH == null ||
        logicalW <= 0 ||
        logicalH <= 0) {
      return;
    }

    final photoAspect = logicalW / logicalH;
    final cropAspect = widget.aspectRatio;
    final double minScale;
    if (photoAspect > cropAspect) {
      minScale = cropRect.height / logicalH;
    } else {
      minScale = cropRect.width / logicalW;
    }

    final imageLeft = (viewportSize.width - logicalW) / 2;
    final imageTop = (viewportSize.height - logicalH) / 2;
    final imageCenterX = imageLeft + logicalW / 2;
    final imageCenterY = imageTop + logicalH / 2;

    _transformController.value = Matrix4.identity()
      ..translateByDouble(imageCenterX, imageCenterY, 0, 1)
      ..scaleByDouble(minScale, minScale, 1, 1)
      ..translateByDouble(-imageCenterX, -imageCenterY, 0, 1);

    _initialFitApplied = true;
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    if (event.scrollDelta.dy == 0) return;

    final currentScale = _transformController.value.getMaxScaleOnAxis();
    if (currentScale <= 0) return;

    final newScale = (currentScale *
            (event.scrollDelta.dy > 0 ? 0.9 : 1.1))
        .clamp(0.5, 4.0);
    final scaleChange = newScale / currentScale;
    if (scaleChange == 1.0) return;

    final layerBox =
        _imageLayerKey.currentContext?.findRenderObject() as RenderBox?;
    final focalLocal = layerBox != null
        ? layerBox.globalToLocal(event.position)
        : event.localPosition;
    final focalPointScene = _transformController.toScene(focalLocal);

    _transformController.value = Matrix4.identity()
      ..translateByDouble(focalPointScene.dx, focalPointScene.dy, 0, 1)
      ..scaleByDouble(scaleChange, scaleChange, 1, 1)
      ..translateByDouble(-focalPointScene.dx, -focalPointScene.dy, 0, 1)
      ..multiply(_transformController.value);
  }

  Rect? _transformedImageRect() =>
      _transformedImageRectFor(_transformController.value);

  Rect? _transformedImageRectFor(Matrix4 matrix) {
    final viewportSize = _viewportSize;
    final logicalW = _logicalW;
    final logicalH = _logicalH;
    if (viewportSize == null || logicalW == null || logicalH == null) {
      return null;
    }

    final imageLeft = (viewportSize.width - logicalW) / 2;
    final imageTop = (viewportSize.height - logicalH) / 2;
    final corners = [
      Offset(imageLeft, imageTop),
      Offset(imageLeft + logicalW, imageTop),
      Offset(imageLeft + logicalW, imageTop + logicalH),
      Offset(imageLeft, imageTop + logicalH),
    ];

    final transformed = corners
        .map((point) => MatrixUtils.transformPoint(matrix, point))
        .toList(growable: false);

    final xs = transformed.map((point) => point.dx);
    final ys = transformed.map((point) => point.dy);
    return Rect.fromLTRB(
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    );
  }

  Matrix4 _lerpMatrix4(Matrix4 begin, Matrix4 end, double t) {
    return Matrix4.fromList(
      List.generate(
        16,
        (i) => begin.storage[i] + (end.storage[i] - begin.storage[i]) * t,
      ),
    );
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    final cropRect = _cropRect;
    final imageRect = _transformedImageRect();
    if (cropRect == null || imageRect == null) return;

    final scale = _transformController.value.getMaxScaleOnAxis();
    if (scale <= 0) return;

    final leftDist = (cropRect.left - imageRect.left).abs();
    final rightDist = (cropRect.right - imageRect.right).abs();
    final topDist = (cropRect.top - imageRect.top).abs();
    final bottomDist = (cropRect.bottom - imageRect.bottom).abs();

    var dx = 0.0;
    var dy = 0.0;

    if (leftDist < _snapThreshold && imageRect.left > cropRect.left) {
      dx += (cropRect.left - imageRect.left) / scale;
    }
    if (rightDist < _snapThreshold && imageRect.right < cropRect.right) {
      dx += (cropRect.right - imageRect.right) / scale;
    }
    if (topDist < _snapThreshold && imageRect.top > cropRect.top) {
      dy += (cropRect.top - imageRect.top) / scale;
    }
    if (bottomDist < _snapThreshold && imageRect.bottom < cropRect.bottom) {
      dy += (cropRect.bottom - imageRect.bottom) / scale;
    }

    if (dx == 0 && dy == 0) return;

    final startMatrix = Matrix4.copy(_transformController.value);
    final endMatrix = Matrix4.copy(_transformController.value)
      ..translateByDouble(dx, dy, 0, 1);

    _snapAnimationController?.dispose();
    _snapAnimationController = AnimationController(
      vsync: this,
      duration: _snapDuration,
    );
    final animation = CurvedAnimation(
      parent: _snapAnimationController!,
      curve: Curves.easeOut,
    );

    void listener() {
      _transformController.value =
          _lerpMatrix4(startMatrix, endMatrix, animation.value);
    }

    animation.addListener(listener);
    _snapAnimationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animation.removeListener(listener);
        final snappedRect = _transformedImageRect();
        if (snappedRect != null) {
          final stillOff =
              (cropRect.left - snappedRect.left).abs() > _snapThreshold ||
              (cropRect.right - snappedRect.right).abs() > _snapThreshold ||
              (cropRect.top - snappedRect.top).abs() > _snapThreshold ||
              (cropRect.bottom - snappedRect.bottom).abs() > _snapThreshold;
          if (stillOff) {
            _transformController.value = endMatrix;
          }
        }
      } else if (status == AnimationStatus.dismissed) {
        animation.removeListener(listener);
      }
    });
    _snapAnimationController!.forward();
  }

  Future<String?> _exportCroppedImage() async {
    final cropRect = _cropRect;
    final viewportSize = _viewportSize;
    final imagePixelSize = _imagePixelSize;
    if (cropRect == null || viewportSize == null || imagePixelSize == null) {
      return null;
    }

    final imageBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (imageBox == null || !imageBox.hasSize) return null;

    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return null;

    final cropCorners = [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ];

    final imagePoints = cropCorners.map((point) {
      final global = stackBox.localToGlobal(point);
      return imageBox.globalToLocal(global);
    }).toList();

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalW = imagePixelSize.width / dpr;
    final logicalH = imagePixelSize.height / dpr;
    if (logicalW <= 0 || logicalH <= 0) return null;

    final scaleX = imagePixelSize.width / logicalW;
    final scaleY = imagePixelSize.height / logicalH;

    final pixelXs = imagePoints.map((p) => p.dx * scaleX).toList();
    final pixelYs = imagePoints.map((p) => p.dy * scaleY).toList();

    final srcLeft = pixelXs.reduce(math.min).clamp(0.0, imagePixelSize.width);
    final srcTop = pixelYs.reduce(math.min).clamp(0.0, imagePixelSize.height);
    final srcRight = pixelXs.reduce(math.max).clamp(0.0, imagePixelSize.width);
    final srcBottom =
        pixelYs.reduce(math.max).clamp(0.0, imagePixelSize.height);

    const expandPx = 2.0;
    final expandedLeft =
        (srcLeft - expandPx).clamp(0.0, imagePixelSize.width);
    final expandedTop =
        (srcTop - expandPx).clamp(0.0, imagePixelSize.height);
    final expandedRight =
        (srcRight + expandPx).clamp(0.0, imagePixelSize.width);
    final expandedBottom =
        (srcBottom + expandPx).clamp(0.0, imagePixelSize.height);

    final srcW = expandedRight - expandedLeft;
    final srcH = expandedBottom - expandedTop;
    if (srcW <= 1 || srcH <= 1) return null;

    final bytes = await File(widget.sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final outW = srcW.round();
    final outH = srcH.round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      srcImage,
      Rect.fromLTWH(expandedLeft, expandedTop, srcW, srcH),
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final outImage = await picture.toImage(outW, outH);
    srcImage.dispose();

    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    outImage.dispose();
    if (byteData == null) return null;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/event_crop_${DateTime.now().microsecondsSinceEpoch}.png';
    await File(outPath).writeAsBytes(byteData.buffer.asUint8List());
    return outPath;
  }

  Future<void> _onConfirm() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await _exportCroppedImage();
      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('裁剪失败，请重试')),
        );
        return;
      }
      Navigator.pop(context, path);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _buildImageLayer(double logicalW, double logicalH) {
    return Listener(
      key: _imageLayerKey,
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          _handlePointerScroll(event);
        }
      },
      child: InteractiveViewer(
        transformationController: _transformController,
        panEnabled: true,
        scaleEnabled: true,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.5,
        maxScale: 4.0,
        onInteractionEnd: _onInteractionEnd,
        child: Center(
          child: Image.file(
            key: _imageKey,
            File(widget.sourcePath),
            width: logicalW,
            height: logicalH,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _exporting ? null : () => Navigator.pop(context),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '裁剪照片',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _exporting ? null : _onConfirm,
                    child: Text(
                      _exporting ? '处理中' : '确认',
                      style: const TextStyle(
                        color: _kThemeBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewportSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final cropWidth = viewportSize.width * 0.8;
                  final cropHeight = cropWidth / widget.aspectRatio;
                  final cropRect = Rect.fromCenter(
                    center: Offset(
                      viewportSize.width / 2,
                      viewportSize.height / 2,
                    ),
                    width: cropWidth,
                    height: cropHeight,
                  );

                  _cropRect = cropRect;
                  _viewportSize = viewportSize;

                  final pixelSize = _imagePixelSize;
                  final logicalW =
                      pixelSize == null ? null : pixelSize.width / dpr;
                  final logicalH =
                      pixelSize == null ? null : pixelSize.height / dpr;
                  _logicalW = logicalW;
                  _logicalH = logicalH;

                  if (!_initialFitApplied &&
                      logicalW != null &&
                      logicalH != null) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _tryApplyInitialFit(),
                    );
                  }

                  return Stack(
                    key: _stackKey,
                    fit: StackFit.expand,
                    children: [
                      if (logicalW != null && logicalH != null)
                        _buildImageLayer(logicalW, logicalH)
                      else
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white54),
                        ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _CropOverlayPainter(cropRect: cropRect),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.cropRect});

  final Rect cropRect;

  static const double _radius = 16;
  static const double _borderWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()..addRect(Offset.zero & size);
    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cropRect, const Radius.circular(_radius)),
      );
    final maskPath = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cropRect, const Radius.circular(_radius)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}
