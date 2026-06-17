import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/pages/memory_create_sheet.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/tag_service.dart';

Future<void> showMemoryStoreSheet(
  BuildContext context, {
  required ListEvent listEvent,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height;
      return Padding(
        padding: EdgeInsets.only(top: height * 0.08),
        child: SizedBox(
          height: height * 0.92,
          child: MemoryStoreSheet(outerContext: context, listEvent: listEvent),
        ),
      );
    },
  );
}

class MemoryStoreSheet extends StatefulWidget {
  const MemoryStoreSheet({
    super.key,
    required this.outerContext,
    required this.listEvent,
  });

  final BuildContext outerContext;
  final ListEvent listEvent;

  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _saveDisabled = Color(0xFFCBD5E1);

  @override
  State<MemoryStoreSheet> createState() => _MemoryStoreSheetState();
}

class _MemoryStoreSheetState extends State<MemoryStoreSheet> {
  List<MemoryCollection> _collections = [];
  String? _selectedId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await TagService.loadTags();
    final list = await MemoryService.getSortedCollections();
    if (!mounted) return;
    setState(() {
      _collections = list;
      _selectedId = list.isNotEmpty ? list.first.id : null;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final id = _selectedId;
    if (id == null || id.isEmpty) return;
    final ev = MemoryService.cloneFromListEvent(widget.listEvent);
    await MemoryService.addEventToCollection(ev, id);
    if (!mounted) return;
    Navigator.of(context).pop();
    final outer = widget.outerContext;
    if (!outer.mounted) return;
    ScaffoldMessenger.of(outer).showSnackBar(
      const SnackBar(content: Text('已存入时光集')),
    );
  }

  void _openCreateNewAndStore() {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.outerContext.mounted) return;
      showMemoryCreateSheet(
        widget.outerContext,
        prefillEvent: widget.listEvent,
      );
    });
  }

  Widget _radioIndicator({required bool selected}) {
    if (selected) {
      return Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: MemoryStoreSheet._themeBlue,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.check, size: 12, color: Colors.white),
      );
    }
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
    );
  }

  Widget _collectionCover(MemoryCollection c) {
    final path = c.coverPhotoPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(path),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ),
      );
    }
    return const CircleAvatar(
      radius: 20,
      backgroundColor: Color(0xFFF1F5F9),
      child: Icon(
        Icons.photo,
        size: 16,
        color: MemoryStoreSheet._muted,
      ),
    );
  }

  Widget _partnerShareTitleMarker(String tagId) {
    if (!TagService.shouldShowPartnerShareMarker(tagId)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: SvgPicture.asset(
        'assets/images/ic_couple_hearts.svg',
        width: 16,
        height: 16,
      ),
    );
  }

  Widget _collectionRow(MemoryCollection c) {
    final selected = _selectedId == c.id;
    return InkWell(
      onTap: () => setState(() => _selectedId = c.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _collectionCover(c),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 15,
                        color: MemoryStoreSheet._titleColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _partnerShareTitleMarker(c.tagId),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _radioIndicator(selected: selected),
          ],
        ),
      ),
    );
  }

  Widget _createNewRow() {
    return InkWell(
      onTap: _openCreateNewAndStore,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MemoryStoreSheet._themeBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add,
                color: MemoryStoreSheet._themeBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '新建事件集并存入',
                style: TextStyle(
                  fontSize: 15,
                  color: MemoryStoreSheet._themeBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: MemoryStoreSheet._muted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final canSave = _selectedId != null && _selectedId!.isNotEmpty;

    return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      '存入时光集',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: MemoryStoreSheet._titleColor,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: MemoryStoreSheet._muted,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              if (_loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _collections.length + 1,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (ctx, i) {
                      if (i == _collections.length) {
                        return _createNewRow();
                      }
                      return _collectionRow(_collections[i]);
                    },
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
                child: GestureDetector(
                  onTap: canSave ? _save : null,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: canSave
                          ? MemoryStoreSheet._themeBlue
                          : MemoryStoreSheet._saveDisabled,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '保存',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
