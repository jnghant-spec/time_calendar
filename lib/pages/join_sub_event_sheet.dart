import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/services/memory_service.dart';

const Color _titleColor = Color(0xFF1F2937);
const Color _muted = Color(0xFF94A3B8);
const Color _disabled = Color(0xFFCBD5E1);
const Color _dividerColor = Color(0xFFF1F5F9);
const Color _successGreen = Color(0xFF10B981);
const Color _warningAmber = Color(0xFFF59E0B);
const Color _errorRed = Color(0xFFEF4444);

enum _JoinTileState { current, alreadyJoined, joinable }

/// 选择目标事件集并复制子事件为独立副本后加入。
Future<void> showJoinSubEventSheet(
  BuildContext context, {
  required MemoryEvent event,
  required String currentCollectionId,
  VoidCallback? onJoined,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _JoinSubEventSheet(
      event: event,
      currentCollectionId: currentCollectionId,
      onJoined: onJoined,
    ),
  );
}

class _JoinSubEventSheet extends StatefulWidget {
  const _JoinSubEventSheet({
    required this.event,
    required this.currentCollectionId,
    this.onJoined,
  });

  final MemoryEvent event;
  final String currentCollectionId;
  final VoidCallback? onJoined;

  @override
  State<_JoinSubEventSheet> createState() => _JoinSubEventSheetState();
}

class _JoinSubEventSheetState extends State<_JoinSubEventSheet> {
  List<MemoryCollection> _collections = [];
  Map<String, List<MemoryEvent>> _eventsByCollection = {};
  Set<String> _joinedCollectionIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final collections = await MemoryService.getSortedCollections();
    final joinedIds =
        await MemoryService.getCollectionIdsBySubEventId(widget.event.id);
    final grouped = <String, List<MemoryEvent>>{};
    for (final c in collections) {
      grouped[c.id] = await MemoryService.getEventsSorted(c.id);
    }
    final joinedWithCopies = joinedIds.toSet();
    for (final c in collections) {
      if (c.id == widget.currentCollectionId) continue;
      final events = grouped[c.id] ?? [];
      if (events.any((e) => _isIndependentCopy(e))) {
        joinedWithCopies.add(c.id);
      }
    }
    if (!mounted) return;
    setState(() {
      _collections = collections;
      _eventsByCollection = grouped;
      _joinedCollectionIds = joinedWithCopies;
      _loading = false;
    });
  }

  bool _isIndependentCopy(MemoryEvent candidate) {
    if (candidate.id == widget.event.id) return false;
    final source = widget.event;
    return candidate.title == source.title &&
        candidate.date == source.date &&
        candidate.location == source.location &&
        listEquals(candidate.photoPaths, source.photoPaths);
  }

  MemoryEvent _duplicateSubEvent(MemoryEvent source) {
    return source.copyWith(
      id: MemoryService.generateId('mev'),
      photoPaths: List<String>.from(source.photoPaths),
    );
  }

  List<MemoryCollection> get _targetCollections =>
      _collections.where((c) => c.id != widget.currentCollectionId).toList();

  _JoinTileState _tileState(String collectionId) {
    if (collectionId == widget.currentCollectionId) {
      return _JoinTileState.current;
    }
    if (_joinedCollectionIds.contains(collectionId)) {
      return _JoinTileState.alreadyJoined;
    }
    return _JoinTileState.joinable;
  }

  Future<void> _joinToTarget(MemoryCollection target) async {
    if (_tileState(target.id) == _JoinTileState.current) return;
    try {
      final copy = _duplicateSubEvent(widget.event);
      await MemoryService.addEventToCollection(copy, target.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('已加入，此事件现在可独立编辑'),
          backgroundColor: _successGreen,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      widget.onJoined?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('加入失败，请重试'),
          backgroundColor: _errorRed,
        ),
      );
    }
  }

  String? _coverPath(MemoryCollection c) {
    final custom = c.coverPhotoPath;
    if (custom != null &&
        custom.isNotEmpty &&
        File(custom).existsSync()) {
      return custom;
    }
    final ev = _eventsByCollection[c.id] ?? [];
    for (var i = ev.length - 1; i >= 0; i--) {
      final p = MemoryService.firstSlotPhotoPath(ev[i]);
      if (p != null) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: _muted, fontSize: 16),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '加入其他事件集',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 64),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '选择要加入的事件集',
              style: TextStyle(fontSize: 14, color: _muted),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '加入后，此事件将在新事件集中独立存在，修改不会影响原事件集',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _warningAmber,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 1, color: _dividerColor),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_targetCollections.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 32, 16, 32 + bottom),
                child: Column(
                  children: const [
                    Icon(
                      Icons.folder_open_outlined,
                      size: 48,
                      color: _disabled,
                    ),
                    SizedBox(height: 12),
                    Text(
                      '暂无其他事件集',
                      style: TextStyle(fontSize: 14, color: _muted),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _collections.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: _dividerColor,
                        ),
                        itemBuilder: (context, index) {
                          final c = _collections[index];
                          final state = _tileState(c.id);
                          final ev = _eventsByCollection[c.id] ?? [];
                          final photoCount =
                              MemoryService.countPhotosInCollection(ev);
                          return _CollectionJoinTile(
                            name: c.name,
                            stats:
                                '共 ${ev.length} 个事件 · $photoCount 张照片',
                            coverPath: _coverPath(c),
                            state: state,
                            onTap: state == _JoinTileState.current
                                ? null
                                : () => _joinToTarget(c),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: bottom),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CollectionJoinTile extends StatelessWidget {
  const _CollectionJoinTile({
    required this.name,
    required this.stats,
    required this.coverPath,
    required this.state,
    this.onTap,
  });

  final String name;
  final String stats;
  final String? coverPath;
  final _JoinTileState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == _JoinTileState.current;
    final isJoined = state == _JoinTileState.alreadyJoined;
    final isJoinable = state == _JoinTileState.joinable;

    final nameColor = isCurrent ? _disabled : _titleColor;
    final statsColor = isCurrent ? _disabled : _muted;

    Widget cover = coverPath != null
        ? Image.file(
            File(coverPath!),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          )
        : Container(
            width: 48,
            height: 48,
            color: const Color(0xFFF1F5F9),
            alignment: Alignment.center,
            child: Icon(
              Icons.photo_album_outlined,
              size: 22,
              color: statsColor,
            ),
          );
    if (isCurrent) {
      cover = Opacity(opacity: 0.4, child: cover);
    }

    Widget trailing;
    if (isCurrent) {
      trailing = const Text(
        '当前所在',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _disabled,
        ),
      );
    } else if (isJoined) {
      trailing = const Text(
        '已加入',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _successGreen,
        ),
      );
    } else {
      trailing = const Icon(
        Icons.chevron_right,
        size: 20,
        color: _muted,
      );
    }

    final content = SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: cover,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: nameColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stats,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: statsColor,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );

    if (isJoinable || isJoined) {
      return Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: content,
        ),
      );
    }

    return IgnorePointer(
      child: Material(
        color: Colors.white,
        child: content,
      ),
    );
  }
}
