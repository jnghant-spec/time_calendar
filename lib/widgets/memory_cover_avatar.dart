import 'dart:io';

import 'package:flutter/material.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/services/tag_service.dart';

/// 时光集封面圆：有路径则照片，否则标签色底 + [TagIconHelper]。
class MemoryCoverAvatar extends StatelessWidget {
  const MemoryCoverAvatar({
    super.key,
    required this.collection,
    required this.diameter,
    required this.tagAccent,
    required this.tagIconBg,
    this.imagePathOverride,
  });

  final MemoryCollection collection;
  final double diameter;
  final Color tagAccent;
  final Color tagIconBg;
  /// 若为 non-null 且文件存在，优先于 [MemoryCollection.coverPhotoPath] 展示。
  final String? imagePathOverride;

  @override
  Widget build(BuildContext context) {
    final override = imagePathOverride;
    if (override != null &&
        override.isNotEmpty &&
        File(override).existsSync()) {
      return ClipOval(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Image.file(File(override), fit: BoxFit.cover),
        ),
      );
    }
    final path = collection.coverPhotoPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipOval(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Image.file(File(path), fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(color: tagIconBg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: TagIconHelper.build(
        tagId: collection.tagId,
        color: tagAccent,
        size: diameter * 0.5,
      ),
    );
  }
}
