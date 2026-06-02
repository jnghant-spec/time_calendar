import 'dart:io';

import 'package:flutter/material.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';

/// 时光集详情弹窗（横向/纵向）共用顶部区块。
class MemoryCollectionDetailHeader extends StatelessWidget {
  const MemoryCollectionDetailHeader({
    super.key,
    required this.collection,
    required this.events,
    required this.isListViewActive,
    required this.onShare,
    required this.onEditCollection,
    required this.onSwitchToList,
    required this.onSwitchToGrid,
  });

  final MemoryCollection collection;
  final List<MemoryEvent> events;
  final bool isListViewActive;
  final VoidCallback onShare;
  final VoidCallback onEditCollection;
  final VoidCallback onSwitchToList;
  final VoidCallback onSwitchToGrid;

  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _themeBlue = Color(0xFF1A73E8);

  String? _coverPath() {
    final custom = collection.coverPhotoPath;
    if (custom != null &&
        custom.isNotEmpty &&
        File(custom).existsSync()) {
      return custom;
    }
    for (var i = events.length - 1; i >= 0; i--) {
      final p = MemoryService.firstSlotPhotoPath(events[i]);
      if (p != null) return p;
    }
    return null;
  }

  String _rangeLine() {
    if (events.isEmpty) return '暂无事件';
    return '${formatYearMonthDot(events.first.date)} - ${formatYearMonthDot(events.last.date)}';
  }

  Widget _tagPill() {
    final tag = TagService.getTagById(collection.tagId);
    if (tag == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tag.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 11,
          color: tag.accentColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cover = _coverPath();
    final photoCount = MemoryService.countPhotosInCollection(events);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                cover != null
                    ? Image.file(File(cover), fit: BoxFit.cover)
                    : Container(
                        color: const Color(0xFFF1F5F9),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.photo_album_outlined,
                          size: 48,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                Positioned(
                  top: 24,
                  right: 24,
                  child: Row(
                    children: [
                      _circleIconBtn(
                        Icons.share_outlined,
                        const Color(0xFF1A73E8),
                        Colors.white,
                        onShare,
                      ),
                      const SizedBox(width: 8),
                      _circleIconBtn(
                        Icons.edit_outlined,
                        Colors.white,
                        const Color(0xFF1F2937),
                        onEditCollection,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Text(
          collection.name.isNotEmpty ? collection.name : '未命名时光集',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _rangeLine(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _tagPill(),
            const SizedBox(width: 8),
            Text(
              '· 共 ${events.length} 个事件 · $photoCount 张照片',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '事件时间线',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _titleColor,
                ),
              ),
              Row(
                children: [
                  _viewToggleBtn(
                    Icons.view_list_outlined,
                    isListViewActive,
                    onSwitchToList,
                  ),
                  const SizedBox(width: 8),
                  _viewToggleBtn(
                    Icons.grid_view_outlined,
                    !isListViewActive,
                    onSwitchToGrid,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _circleIconBtn(
    IconData icon,
    Color bgColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }

  static Widget _viewToggleBtn(
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? _themeBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: isActive ? Colors.white : _muted,
        ),
      ),
    );
  }
}
