import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

class _PhotoCropPageState extends State<PhotoCropPage> {
  static const Color _kThemeBlue = Color(0xFF1A73E8);

  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  bool _exporting = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<String?> _exportCroppedImage() async {
    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
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

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = 24.0;
    final cropWidth = MediaQuery.sizeOf(context).width - horizontalPadding * 2;
    final cropHeight = cropWidth / widget.aspectRatio;

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
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      key: _boundaryKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: cropWidth,
                          height: cropHeight,
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.file(
                              File(widget.sourcePath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Container(
                        width: cropWidth,
                        height: cropHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 2),
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
    );
  }
}
