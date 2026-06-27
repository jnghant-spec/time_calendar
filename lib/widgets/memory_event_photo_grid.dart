import 'dart:io';

import 'package:flutter/material.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/services/memory_service.dart';

/// 瞬间九宫格与分享拼图共用 token。
abstract final class MemoryEventPhotoGridTokens {
  static const double sharePhotoSpacing = 16;
  static const double shareGridSpacing = 3;
  static const double shareGridRadius = 8;
  static const double sharePhotoTileRadius = 12;
  static const Color sharePlaceholderBg = Color(0xFFF1F5F9);
  static const Color shareEmptySlotBorder = Color(0xFFE2E8F0);
}

class MemoryEventPhotoGridEntry {
  const MemoryEventPhotoGridEntry({required this.slot, required this.path});

  final int slot;
  final String path;
}

/// 瞬间九宫格视觉顺序与分享拼图逻辑（中心格 slot 1）。
abstract final class MemoryEventPhotoGrid {
  MemoryEventPhotoGrid._();

  static const int gridCellCount = 9;

  /// 九宫格 UI index 0~8 → slot 编号（中心为 1）。
  static const List<int> gridSlotOrder = [2, 3, 4, 5, 1, 6, 7, 8, 9];

  /// 与编辑页 grid index 对齐的 9 格路径（空位为 null）。
  static List<String?> gridSlotPaths(MemoryEvent event) {
    return MemoryService.sanitizePhotoGridSlots(
      MemoryService.decodePhotoGridSlots(event.photoPaths),
    );
  }

  static int filledSlotCount(MemoryEvent event) {
    return gridSlotPaths(event).where((p) => p != null).length;
  }

  static String? firstFilledSlotPath(MemoryEvent event) {
    for (final path in gridSlotPaths(event)) {
      if (path != null) return path;
    }
    return null;
  }

  static List<MemoryEventPhotoGridEntry> visualEntries(MemoryEvent event) {
    final slots = gridSlotPaths(event);
    final entries = <MemoryEventPhotoGridEntry>[];
    for (var i = 0; i < gridSlotOrder.length && i < slots.length; i++) {
      final path = slots[i];
      if (path == null) continue;
      entries.add(MemoryEventPhotoGridEntry(slot: gridSlotOrder[i], path: path));
    }
    return entries;
  }

  /// 纪念长图 1:1 照片块高度（与内容区同宽）。
  static double shareTileHeight(double contentWidth) => contentWidth;
}

/// 简洁分享卡固定 3×3 九宫格（与编辑页位置一致，空位浅灰占位）。
class MemoryEventShareConciseGrid extends StatelessWidget {
  const MemoryEventShareConciseGrid({
    super.key,
    required this.gridSlotPaths,
    required this.contentWidth,
  });

  final List<String?> gridSlotPaths;
  final double contentWidth;

  @override
  Widget build(BuildContext context) {
    final spacing = MemoryEventPhotoGridTokens.shareGridSpacing;
    final cellSize = (contentWidth - spacing * 2) / 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 1,
      ),
      itemCount: MemoryEventPhotoGrid.gridCellCount,
      itemBuilder: (context, index) {
        final path = index < gridSlotPaths.length ? gridSlotPaths[index] : null;
        if (path == null) {
          return _ConciseGridEmptyCell(size: cellSize);
        }
        return _ConciseGridPhotoCell(path: path, size: cellSize);
      },
    );
  }
}

class _ConciseGridPhotoCell extends StatelessWidget {
  const _ConciseGridPhotoCell({
    required this.path,
    required this.size,
  });

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(MemoryEventPhotoGridTokens.shareGridRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, _, _) => ColoredBox(
            color: MemoryEventPhotoGridTokens.sharePlaceholderBg,
            child: const Icon(Icons.broken_image_outlined, color: Color(0xFFCBD5E1)),
          ),
        ),
      ),
    );
  }
}

class _ConciseGridEmptyCell extends StatelessWidget {
  const _ConciseGridEmptyCell({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MemoryEventPhotoGridTokens.sharePlaceholderBg,
        borderRadius: BorderRadius.circular(MemoryEventPhotoGridTokens.shareGridRadius),
        border: Border.all(color: MemoryEventPhotoGridTokens.shareEmptySlotBorder),
      ),
    );
  }
}

/// 纪念长图固定 1:1 照片块。
class MemoryEventSharePhotoTile extends StatelessWidget {
  const MemoryEventSharePhotoTile({
    super.key,
    required this.path,
    required this.height,
  });

  final String path;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          MemoryEventPhotoGridTokens.sharePhotoTileRadius,
        ),
        color: MemoryEventPhotoGridTokens.sharePlaceholderBg,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Color(0xFFCBD5E1)),
        ),
      ),
    );
  }
}
