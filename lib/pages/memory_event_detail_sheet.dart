import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/pages/join_sub_event_sheet.dart';
import 'package:time_calendar/pages/memory_event_share_sheet.dart';
import 'package:time_calendar/pages/memory_event_sheet.dart';
import 'package:time_calendar/pages/photo_viewer_page.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/widgets/confirm_delete_dialog.dart';

Future<void> showMemoryEventDetailSheet(
  BuildContext context, {
  required MemoryEvent event,
  required MemoryCollection collection,
  VoidCallback? onChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    enableDrag: false,
    builder: (ctx) => _MemoryEventDetailSheetHost(
      event: event,
      collection: collection,
      onChanged: onChanged,
    ),
  );
}

class _MemoryEventDetailSheetHost extends StatefulWidget {
  const _MemoryEventDetailSheetHost({
    required this.event,
    required this.collection,
    this.onChanged,
  });

  final MemoryEvent event;
  final MemoryCollection collection;
  final VoidCallback? onChanged;

  @override
  State<_MemoryEventDetailSheetHost> createState() =>
      _MemoryEventDetailSheetHostState();
}

class _MemoryEventDetailSheetHostState extends State<_MemoryEventDetailSheetHost> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(top: height * 0.08),
      child: SizedBox(
        height: height * 0.92,
        child: MemoryEventDetailSheet(
          event: widget.event,
          collection: widget.collection,
          scrollController: _scrollController,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

class MemoryEventDetailSheet extends StatefulWidget {
  const MemoryEventDetailSheet({
    super.key,
    required this.event,
    required this.collection,
    required this.scrollController,
    this.onChanged,
  });

  final MemoryEvent event;
  final MemoryCollection collection;
  final ScrollController scrollController;
  final VoidCallback? onChanged;

  @override
  State<MemoryEventDetailSheet> createState() => _MemoryEventDetailSheetState();
}

enum _PhotoDragMode { none, horizontal, vertical }

class _MemoryEventDetailSheetState extends State<MemoryEventDetailSheet>
    with SingleTickerProviderStateMixin {
  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _sheetBg = Color(0xFFFAFBFC);

  late MemoryEvent _event;
  double _sheetDragOffset = 0;
  int _currentPhotoIndex = 0;
  double _dragOffset = 0;
  double _photoWidth = 0;
  double _overscrollDelta = 0;
  bool _isPopping = false;
  double _sheetHeight = 0;
  double _initialDragX = 0;
  double _initialDragY = 0;
  _PhotoDragMode _photoDragMode = _PhotoDragMode.none;
  late final AnimationController _photoAnimController;
  late Animation<double> _photoAnim;
  int _targetPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _photoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _photoAnimController.addListener(() {
      if (mounted) setState(() => _dragOffset = _photoAnim.value);
    });
    _photoAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _currentPhotoIndex = _targetPhotoIndex;
          _dragOffset = 0;
        });
      }
    });
    _event = widget.event;
  }

  @override
  void dispose() {
    _photoAnimController.dispose();
    super.dispose();
  }

  List<String> get _photos => MemoryService.existingPhotoPaths(_event);

  bool get _hasCoverPhoto => MemoryService.eventHasCoverPhoto(_event);

  Widget _coverBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _themeBlue,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '封面',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      ),
    );
  }

  int _coverTargetIndex(int displayCount) {
    if (displayCount <= 1) return 0;
    if (displayCount <= 3) return 1;
    if (displayCount == 4) return 1;
    return 4;
  }

  Widget _buildPhotoGridItem(String path) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path),
        key: ValueKey(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _buildCoverGridItem(String path) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(path),
            key: ValueKey('cover-$path'),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          if (_hasCoverPhoto)
            Positioned(
              top: 4,
              left: 4,
              child: _coverBadge(),
            ),
        ],
      ),
    );
  }

  Widget _buildOverflowGridItem(String path, int remainingCount) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(path),
            key: ValueKey('overflow-$path'),
            fit: BoxFit.cover,
          ),
          const ColoredBox(color: Colors.black54),
          Center(
            child: Text(
              '+$remainingCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridItemTap(List<String> photos, String path, Widget child) {
    return GestureDetector(
      onTap: () {
        final index = photos.indexOf(path);
        _openPhotoViewer(initialIndex: index >= 0 ? index : 0);
      },
      child: child,
    );
  }

  List<Widget> _buildGridItems(List<String> photos) {
    if (photos.isEmpty) return const [];

    final coverPath = photos.first;
    final otherPaths = photos.skip(1).toList();
    final total = photos.length;
    final displayCount = math.min(total, 9);
    final targetIndex = _coverTargetIndex(displayCount);
    final items = <Widget>[];
    var otherIndex = 0;

    for (var i = 0; i < displayCount; i++) {
      if (i == targetIndex) {
        items.add(
          _gridItemTap(
            photos,
            coverPath,
            _buildCoverGridItem(coverPath),
          ),
        );
      } else if (total > 9 && i == displayCount - 1) {
        final path = otherPaths[otherIndex];
        items.add(
          _gridItemTap(
            photos,
            path,
            _buildOverflowGridItem(path, total - 8),
          ),
        );
      } else {
        final path = otherPaths[otherIndex];
        otherIndex++;
        items.add(
          _gridItemTap(
            photos,
            path,
            _buildPhotoGridItem(path),
          ),
        );
      }
    }
    return items;
  }

  void _openPhotoViewer({required int initialIndex}) {
    PhotoViewerPage.showForMemoryEvent(
      context,
      event: _event,
      initialIndex: initialIndex,
    );
  }

  Future<void> _openEdit() async {
    final changed = await showMemoryEventSheet(
      context,
      collectionId: widget.collection.id,
      initial: _event,
    );
    if (!mounted || changed != true) return;
    final updated = await MemoryService.getEventById(_event.id);
    if (updated != null) {
      final photos = MemoryService.existingPhotoPaths(updated);
      setState(() {
        _event = updated;
        if (photos.isEmpty) {
          _currentPhotoIndex = 0;
        } else {
          _currentPhotoIndex =
              _currentPhotoIndex.clamp(0, photos.length - 1);
        }
      });
    }
    widget.onChanged?.call();
  }

  Future<void> _confirmDelete() async {
    final ok = await showConfirmDeleteDialog(
      context,
      title: '删除「${_event.title}」？',
    );
    if (!ok || !mounted) return;
    await MemoryService.deleteEvent(_event.id, fromCollectionId: widget.collection.id);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onChanged?.call();
  }

  void _shareCard() {
    showMemoryEventShareSheet(
      context,
      event: _event,
      collection: widget.collection,
    );
  }

  Future<void> _openJoin() async {
    await showJoinSubEventSheet(
      context,
      event: _event,
      currentCollectionId: widget.collection.id,
      onJoined: widget.onChanged,
    );
  }

  Widget _buildSolidActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _themeBlue,
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildOutlinedActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: _themeBlue),
      label: Text(label, style: const TextStyle(color: _themeBlue)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _themeBlue),
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildDeleteTextButton({required VoidCallback onTap}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: const Text(
        '删除',
        style: TextStyle(
          color: Color(0xFFEF4444),
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildBottomActions(double bottomSafe) {
    return Container(
      decoration: const BoxDecoration(
        color: _sheetBg,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomSafe),
      child: Row(
        children: [
          Expanded(
            child: _buildSolidActionButton(
              icon: Icons.edit,
              label: '编辑',
              onTap: _openEdit,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildOutlinedActionButton(
              icon: Icons.add_to_photos_outlined,
              label: '加入',
              onTap: _openJoin,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildOutlinedActionButton(
              icon: Icons.share_outlined,
              label: '分享',
              onTap: _shareCard,
            ),
          ),
          const SizedBox(width: 8),
          _buildDeleteTextButton(onTap: _confirmDelete),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final loc = _event.location?.trim();
    final photos = _photos;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.92;
    _sheetHeight = sheetHeight;

    return Transform.translate(
      offset: Offset(0, _sheetDragOffset),
      child: Stack(
        children: [
          ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: _sheetBg,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: PrimaryScrollController(
                controller: widget.scrollController,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (!mounted || _isPopping) return false;
                    if (notification is ScrollUpdateNotification) {
                      final metrics = notification.metrics;
                      final delta = notification.scrollDelta;
                      if (metrics.pixels <= 0 &&
                          delta != null &&
                          delta < 0) {
                        _overscrollDelta += delta.abs();
                        if (_overscrollDelta > 60) {
                          _isPopping = true;
                          Navigator.of(context).maybePop();
                          return true;
                        }
                      } else if (metrics.pixels > 0 ||
                          (delta != null && delta > 0)) {
                        _overscrollDelta = 0;
                      }
                    } else if (notification is OverscrollNotification) {
                      if (notification.metrics.pixels <= 0 &&
                          notification.overscroll < 0) {
                        _overscrollDelta += notification.overscroll.abs();
                        if (_overscrollDelta > 60) {
                          _isPopping = true;
                          Navigator.of(context).maybePop();
                          return true;
                        }
                      }
                    } else if (notification is ScrollEndNotification) {
                      _overscrollDelta = 0;
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  if (photos.isEmpty)
                    Container(
                      height: 280,
                      margin: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(
                            Icons.photo,
                            size: 48,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 280,
                      margin: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _photoWidth = constraints.maxWidth;
                          final totalOffset =
                              -_currentPhotoIndex * (_photoWidth + 16) +
                              _dragOffset;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (_) {
                              _photoDragMode = _PhotoDragMode.none;
                              _initialDragX = 0;
                              _initialDragY = 0;
                            },
                            onPanUpdate: (details) {
                              if (_photoDragMode == _PhotoDragMode.none) {
                                _initialDragX += details.delta.dx;
                                _initialDragY += details.delta.dy;
                                if (_initialDragX.abs() > 12 &&
                                    _initialDragX.abs() >
                                        _initialDragY.abs() * 1.5) {
                                  _photoDragMode = _PhotoDragMode.horizontal;
                                } else if (_initialDragY.abs() > 12 &&
                                    _initialDragY.abs() >
                                        _initialDragX.abs() * 1.5) {
                                  _photoDragMode = _PhotoDragMode.vertical;
                                }
                              }

                              if (_photoDragMode ==
                                  _PhotoDragMode.horizontal) {
                                if (photos.length <= 1) return;
                                setState(() {
                                  var next = _dragOffset + details.delta.dx;
                                  if (_currentPhotoIndex == 0 && next > 0) {
                                    next = 0;
                                  }
                                  if (_currentPhotoIndex >= photos.length - 1 &&
                                      next < 0) {
                                    next = 0;
                                  }
                                  _dragOffset = next;
                                });
                              } else if (_photoDragMode ==
                                  _PhotoDragMode.vertical) {
                                if (details.delta.dy > 0) {
                                  setState(
                                    () => _sheetDragOffset += details.delta.dy,
                                  );
                                }
                              }
                            },
                            onPanEnd: (details) {
                              if (_photoDragMode ==
                                  _PhotoDragMode.horizontal) {
                                if (photos.length <= 1) return;
                                final velocity =
                                    details.velocity.pixelsPerSecond.dx;
                                final threshold = _photoWidth * 0.25;
                                int target = _currentPhotoIndex;
                                if (_dragOffset > threshold || velocity > 300) {
                                  target = _currentPhotoIndex - 1;
                                } else if (_dragOffset < -threshold ||
                                    velocity < -300) {
                                  target = _currentPhotoIndex + 1;
                                }
                                target = target.clamp(0, photos.length - 1);
                                _targetPhotoIndex = target;

                                final double endOffset;
                                if (target != _currentPhotoIndex) {
                                  endOffset = target > _currentPhotoIndex
                                      ? -(_photoWidth + 16)
                                      : (_photoWidth + 16);
                                } else {
                                  endOffset = 0;
                                }

                                _photoAnim = Tween<double>(
                                  begin: _dragOffset,
                                  end: endOffset,
                                ).animate(
                                  CurvedAnimation(
                                    parent: _photoAnimController,
                                    curve: Curves.easeOutCubic,
                                  ),
                                );
                                _photoAnimController.forward(from: 0);
                              } else if (_photoDragMode ==
                                  _PhotoDragMode.vertical) {
                                final threshold = _sheetHeight / 3;
                                if (_sheetDragOffset > threshold ||
                                    details.velocity.pixelsPerSecond.dy > 800) {
                                  Navigator.of(context).pop();
                                } else {
                                  setState(() => _sheetDragOffset = 0);
                                }
                              }
                              _photoDragMode = _PhotoDragMode.none;
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                height: 280,
                                child: Stack(
                                  clipBehavior: Clip.hardEdge,
                                  children: [
                                    for (int i = 0; i < photos.length; i++)
                                      Positioned(
                                        left: i * (_photoWidth + 16) +
                                            totalOffset,
                                        top: 0,
                                        width: _photoWidth,
                                        height: 280,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onTap: () => _openPhotoViewer(
                                            initialIndex: i,
                                          ),
                                          child: Image.file(
                                            File(photos[i]),
                                            key: ValueKey(photos[i]),
                                            fit: BoxFit.cover,
                                            width: _photoWidth,
                                            height: 280,
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.45),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_currentPhotoIndex + 1}/${photos.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (photos.length > 1)
                                      Positioned(
                                        bottom: 12,
                                        left: 0,
                                        right: 0,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(
                                            photos.length,
                                            (index) {
                                              return Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: index ==
                                                          _currentPhotoIndex
                                                      ? Colors.white
                                                          .withValues(
                                                              alpha: 0.9)
                                                      : Colors.white
                                                          .withValues(
                                                              alpha: 0.4),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _event.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _titleColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              size: 14,
                              color: _muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${formatFullDate(_event.date)} ${formatWeekdayZh(_event.date)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        if (loc != null && loc.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 14,
                                color: _muted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  loc,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '纪念照片（${photos.length}张）',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _titleColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                        padding: EdgeInsets.zero,
                        children: _buildGridItems(photos),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 16),
                ],
                ),
                ),
              ),
            ),
            ),
            _buildBottomActions(bottom),
          ],
        ),
      ),
    ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 40,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 0) {
                  setState(() => _sheetDragOffset += details.delta.dy);
                }
              },
              onVerticalDragEnd: (details) {
                final threshold = _sheetHeight / 3;
                if (_sheetDragOffset > threshold ||
                    details.velocity.pixelsPerSecond.dy > 800) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _sheetDragOffset = 0);
                }
              },
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}
