import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 节日 / 事件分享图（1080×1920 逻辑像素，导出时 pixelRatio=1）。
///
/// [photoPaths] 首张照片存在时在背景叠加模糊图；无照片或文件缺失时保持纯色 [backgroundColor] 样式。
class ShareCardWidget extends StatelessWidget {
  const ShareCardWidget({
    super.key,
    required this.title,
    required this.primaryDateLine,
    required this.secondaryLines,
    required this.descriptionExcerpt,
    required this.backgroundColor,
    this.photoPaths = const [],
  });

  final String title;
  final String primaryDateLine;
  final List<String> secondaryLines;
  final String descriptionExcerpt;
  final Color backgroundColor;

  /// 本地照片路径；首张用于背景，多张时在底部展示缩略图条。
  final List<String> photoPaths;

  /// 仅当 [paths.first] 在磁盘存在时返回路径（否则视为无照片样式）。
  static String? _backgroundPathIfFirstFileExists(List<String> paths) {
    if (paths.isEmpty) return null;
    final p = paths.first;
    if (p.isEmpty) return null;
    try {
      final f = File(p);
      return f.existsSync() ? p : null;
    } catch (_) {
      return null;
    }
  }

  static List<String> _existingPathsInOrder(List<String> paths) {
    final out = <String>[];
    for (final p in paths) {
      if (p.isEmpty) continue;
      try {
        if (File(p).existsSync()) out.add(p);
      } catch (_) {}
    }
    return out;
  }

  static const double _padH = 40;
  static const double _padV = 60;
  static const double _brandH = 60;

  @override
  Widget build(BuildContext context) {
    final bgPath = _backgroundPathIfFirstFileExists(photoPaths);
    final usePhotoBg = bgPath != null;
    final existingForThumbs = _existingPathsInOrder(photoPaths);
    final showThumbStrip =
        usePhotoBg && existingForThumbs.length >= 2;

    final titleStyle = usePhotoBg
        ? const TextStyle(
            fontSize: 44,
            height: 1.15,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFFFFFF),
          )
        : const TextStyle(
            fontSize: 44,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          );

    final primaryLineStyle = usePhotoBg
        ? TextStyle(
            fontSize: 20,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.9),
          )
        : const TextStyle(
            fontSize: 20,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          );

    final secondaryLineStyle = usePhotoBg
        ? TextStyle(
            fontSize: 20,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.9),
          )
        : const TextStyle(
            fontSize: 20,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          );

    final descriptionStyle = usePhotoBg
        ? TextStyle(
            fontSize: 16,
            height: 1.55,
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.7),
          )
        : const TextStyle(
            fontSize: 16,
            height: 1.55,
            color: Color(0xFF334155),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 1080,
        height: 1920,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (usePhotoBg)
                    Positioned.fill(
                      child: Image.file(
                        File(bgPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: backgroundColor),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: ColoredBox(color: backgroundColor),
                    ),
                  if (usePhotoBg) ...[
                    Positioned.fill(
                      child: ColoredBox(
                        color: const Color(0xFF000000).withValues(alpha: 0.35),
                      ),
                    ),
                    Positioned.fill(
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: const ColoredBox(color: Colors.transparent),
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _padH,
                      _padV,
                      _padH,
                      24 + (showThumbStrip ? 48 + 16 : 0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          primaryDateLine,
                          style: primaryLineStyle,
                        ),
                        if (secondaryLines.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ...secondaryLines.map(
                            (line) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                line,
                                style: secondaryLineStyle,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 36),
                        Expanded(
                          child: Text(
                            descriptionExcerpt,
                            maxLines: 14,
                            overflow: TextOverflow.ellipsis,
                            style: descriptionStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showThumbStrip)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _ThumbnailStrip(
                        paths: existingForThumbs.take(3).toList(),
                        rawPhotoCount: photoPaths.length,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: _brandH,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A73E8),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 36,
                      errorBuilder: (_, _, _) => const SizedBox(width: 36),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '时光集',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
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
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.paths,
    required this.rawPhotoCount,
  });

  final List<String> paths;
  final int rawPhotoCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < paths.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _ThumbCell(
              path: paths[i],
              showOverflowBadge:
                  i == 2 && paths.length >= 3 && rawPhotoCount > 3,
              overflowCount: rawPhotoCount > 3 ? rawPhotoCount - 3 : 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _ThumbCell extends StatelessWidget {
  const _ThumbCell({
    required this.path,
    required this.showOverflowBadge,
    required this.overflowCount,
  });

  final String path;
  final bool showOverflowBadge;
  final int overflowCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black38),
            ),
            if (showOverflowBadge)
              ColoredBox(
                color: const Color(0xFF000000).withValues(alpha: 0.5),
                child: Center(
                  child: Text(
                    '+$overflowCount',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
