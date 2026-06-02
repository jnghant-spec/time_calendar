import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/pages/memory_photo_stream_sheet.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/tag_service.dart';

Future<void> showMemoryCreateSheet(
  BuildContext context, {
  ListEvent? prefillEvent,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) =>
        MemoryCreateSheet(outerContext: context, prefillEvent: prefillEvent),
  );
}

Future<void> showMemoryCollectionEditSheet(
  BuildContext context, {
  required MemoryCollection collection,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => MemoryCreateSheet(
      outerContext: context,
      editingCollection: collection,
    ),
  );
}

class MemoryCreateSheet extends StatefulWidget {
  const MemoryCreateSheet({
    super.key,
    required this.outerContext,
    this.prefillEvent,
    this.editingCollection,
  });

  final BuildContext outerContext;
  final ListEvent? prefillEvent;
  final MemoryCollection? editingCollection;

  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFECEFF5);
  static const Color _pillBorder = Color(0xFFE2E8F0);
  static const Color _themeBlue = Color(0xFF1A73E8);

  @override
  State<MemoryCreateSheet> createState() => _MemoryCreateSheetState();
}

class _MemoryCreateSheetState extends State<MemoryCreateSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  List<ReminderTag> _tags = [];
  String? _selectedTagId;
  String? _coverPhotoPath;
  bool _pinned = false;
  bool _loadingTags = true;

  @override
  void initState() {
    super.initState();
    final edit = widget.editingCollection;
    if (edit != null) {
      _nameCtrl.text = edit.name;
      _coverPhotoPath = edit.coverPhotoPath;
      _pinned = edit.isPinned;
      _selectedTagId = edit.tagId;
    }
    _loadTags();
  }

  Future<void> _loadTags() async {
    final list = await TagService.loadTags();
    if (!mounted) return;
    setState(() {
      _tags = list;
      final edit = widget.editingCollection;
      if (edit != null && list.any((t) => t.id == edit.tagId)) {
        _selectedTagId = edit.tagId;
      } else {
        _selectedTagId ??= list.isNotEmpty ? list.first.id : null;
      }
      _loadingTags = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<String?> _persistCover(XFile file) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final covers = Directory('${dir.path}/covers');
      if (!covers.existsSync()) {
        covers.createSync(recursive: true);
      }
      final name = '${MemoryService.generateId('cov')}.jpg';
      final dest = File('${covers.path}/$name');
      await File(file.path).copy(dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickCover() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null) return;
      final path = await _persistCover(file);
      if (!mounted) return;
      setState(() => _coverPhotoPath = path);
    } catch (_) {}
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写事件集名称')));
      return;
    }
    final tagId = _selectedTagId;
    if (tagId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可用标签')));
      return;
    }

    final edit = widget.editingCollection;
    if (edit != null) {
      await MemoryService.updateCollection(
        edit.copyWith(
          name: name,
          tagId: tagId,
          coverPhotoPath: _coverPhotoPath,
          isPinned: _pinned,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    final collection = MemoryCollection(
      id: MemoryService.generateId('mcol'),
      // 必须使用名称输入框文案，禁止改为事件数量或索引。
      name: name,
      tagId: tagId,
      coverPhotoPath: _coverPhotoPath,
      isPinned: _pinned,
      createdAt: DateTime.now(),
    );
    await MemoryService.addCollection(collection);

    final pre = widget.prefillEvent;
    if (pre != null) {
      await MemoryService.addEvent(
        MemoryService.cloneFromListEvent(pre, collection.id),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.outerContext.mounted) return;
      showMemoryPhotoStreamSheet(widget.outerContext, collection: collection);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.85,
        child: ClipRRect(
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
                      Text(
                        widget.editingCollection != null ? '修改信息' : '新建事件集',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: MemoryCreateSheet._titleColor,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: MemoryCreateSheet._muted,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_loadingTags)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '标签类型',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _tags.map((t) {
                              final sel = _selectedTagId == t.id;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _selectedTagId = t.id),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: sel ? t.accentColor : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: sel
                                            ? t.accentColor
                                            : MemoryCreateSheet._pillBorder,
                                      ),
                                    ),
                                    child: Text(
                                      t.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: sel
                                            ? Colors.white
                                            : MemoryCreateSheet._titleColor,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '事件集名称',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 48,
                            child: TextField(
                              controller: _nameCtrl,
                              decoration: InputDecoration(
                                hintText: '输入事件集名称，如：2023 北京之旅',
                                hintStyle: const TextStyle(
                                  fontSize: 15,
                                  color: MemoryCreateSheet._muted,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: MemoryCreateSheet._border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: MemoryCreateSheet._themeBlue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '封面照片',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _coverPhotoPath == null ? _pickCover : null,
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: MemoryCreateSheet._pillBorder,
                                  width: 2,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child:
                                  _coverPhotoPath != null &&
                                      File(_coverPhotoPath!).existsSync()
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          File(_coverPhotoPath!),
                                          fit: BoxFit.cover,
                                        ),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: GestureDetector(
                                            onTap: () => setState(
                                              () => _coverPhotoPath = null,
                                            ),
                                            child: Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.45,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.add_photo_alternate,
                                          size: 32,
                                          color: MemoryCreateSheet._muted,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '点击上传封面照片',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '设为置顶',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: MemoryCreateSheet._titleColor,
                                ),
                              ),
                              Switch(
                                value: _pinned,
                                activeThumbColor: Colors.white,
                                activeTrackColor: MemoryCreateSheet._themeBlue,
                                onChanged: (v) => setState(() => _pinned = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MemoryCreateSheet._themeBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _loadingTags ? null : _save,
                              child: const Text(
                                '保存',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
