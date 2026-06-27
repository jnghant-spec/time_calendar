import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/pages/memory_photo_stream_sheet.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/widgets/tag_circle_widget.dart';
import 'package:time_calendar/widgets/tag_editor_sheet.dart';

Future<bool?> showMemoryCollectionCreateSheet(
  BuildContext context, {
  MemoryCollection? collectionToEdit,
  ListEvent? prefillEvent,
}) async {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height;
      return Padding(
        padding: EdgeInsets.only(top: height * 0.08),
        child: SizedBox(
          height: height * 0.92,
          child: MemoryCreateSheet(
            outerContext: context,
            prefillEvent: prefillEvent,
            collectionToEdit: collectionToEdit,
          ),
        ),
      );
    },
  );
}

/// 兼容旧调用。
Future<bool?> showMemoryCreateSheet(
  BuildContext context, {
  ListEvent? prefillEvent,
}) =>
    showMemoryCollectionCreateSheet(context, prefillEvent: prefillEvent);

class MemoryCreateSheet extends StatefulWidget {
  const MemoryCreateSheet({
    super.key,
    required this.outerContext,
    this.prefillEvent,
    this.collectionToEdit,
  });

  final BuildContext outerContext;
  final ListEvent? prefillEvent;
  final MemoryCollection? collectionToEdit;

  static const Color _titleColor = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFECEFF5);
  static const Color _pillBorder = Color(0xFFE2E8F0);
  static const Color _themeBlue = Color(0xFF1A73E8);
  static const Color _disabledBtn = Color(0xFFD1D5DB);
  static const Color _pageBg = Color(0xFFFAFBFC);
  static const Color _inactiveTagLabel = Color(0xFF666666);
  static const double _coverThumbSize = 120;
  static const double _coverThumbRadius = 16;

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

  late String _initialName;
  String? _initialTagId;
  String? _initialCoverPath;
  late bool _initialPinned;
  bool _initialCaptured = false;

  bool get _isEditMode => widget.collectionToEdit != null;

  bool get _nameOk => _nameCtrl.text.trim().isNotEmpty;

  static String? _normalizedCover(String? path) =>
      path == null || path.isEmpty ? null : path;

  bool get _isDirty {
    if (_nameCtrl.text.trim() != _initialName) return true;
    if (_selectedTagId != _initialTagId) return true;
    if (_normalizedCover(_coverPhotoPath) !=
        _normalizedCover(_initialCoverPath)) {
      return true;
    }
    if (_pinned != _initialPinned) return true;
    return false;
  }

  bool get _canSubmit => _nameOk && _isDirty && !_loadingTags;

  @override
  void initState() {
    super.initState();
    final edit = widget.collectionToEdit;
    if (edit != null) {
      _nameCtrl.text = edit.name;
      _coverPhotoPath = edit.coverPhotoPath;
      _pinned = edit.isPinned;
      _selectedTagId = edit.tagId;
    }
    _initialName = _nameCtrl.text.trim();
    _initialCoverPath = _coverPhotoPath;
    _initialPinned = _pinned;
    _initialTagId = _selectedTagId;
    _nameCtrl.addListener(_onFormChanged);
    _loadTags();
  }

  void _onFormChanged() => setState(() {});

  void _captureInitialSnapshot() {
    if (_initialCaptured) return;
    _initialCaptured = true;
    _initialName = _nameCtrl.text.trim();
    _initialTagId = _selectedTagId;
    _initialCoverPath = _coverPhotoPath;
    _initialPinned = _pinned;
  }

  Future<void> _openAddTagSheet() async {
    if (_tags.length >= TagService.maxTagCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多可创建 10 个标签')),
      );
      return;
    }
    final created = await showTagEditorSheet(
      context,
      nextSortOrder: _tags.length,
    );
    if (created == null || !mounted) return;
    final list = await TagService.loadTags();
    setState(() {
      _tags = list;
      _selectedTagId = created.id;
    });
  }

  Future<void> _openEditTagSheet(ReminderTag tag) async {
    final updated = await showTagEditorSheet(context, initial: tag);
    if (!mounted) return;
    final list = await TagService.loadTags();
    setState(() {
      _tags = list;
      if (updated != null) {
        _selectedTagId = updated.id;
      } else if (_selectedTagId == tag.id &&
          !list.any((t) => t.id == tag.id)) {
        _selectedTagId = list.isNotEmpty ? list.first.id : null;
      }
    });
  }

  static const double _tagCircleSize = 48;
  static const double _tagRingBorder = 2;
  static const double _tagRingGap = 2;
  static const double _tagIconSlot = _tagCircleSize +
      2 * (_tagRingGap + _tagRingBorder);
  static const double _tagItemWidth = 56;
  static const double _tagBarHeight = 90;

  /// Style A：外蓝环 → #FAFBFC 间隙 → 48px 图标（固定 56px 槽位防跳动）。
  Widget _tagIconSandwich({required bool selected, required Widget circle}) {
    if (!selected) {
      return SizedBox(
        width: _tagIconSlot,
        height: _tagIconSlot,
        child: Center(child: circle),
      );
    }
    return Container(
      width: _tagIconSlot,
      height: _tagIconSlot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MemoryCreateSheet._pageBg,
        border: Border.all(
          color: MemoryCreateSheet._themeBlue,
          width: _tagRingBorder,
        ),
      ),
      padding: const EdgeInsets.all(_tagRingGap),
      child: ClipOval(
        child: SizedBox(
          width: _tagCircleSize,
          height: _tagCircleSize,
          child: circle,
        ),
      ),
    );
  }

  Widget _tagPickerItem(ReminderTag t) {
    final sel = _selectedTagId == t.id;
    return GestureDetector(
      onTap: () {
        if (!sel) setState(() => _selectedTagId = t.id);
      },
      onLongPress: () => _openEditTagSheet(t),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _tagItemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _tagIconSandwich(
              selected: sel,
              circle: TagCircleWidget(
                tag: t,
                size: _tagCircleSize,
                showLabel: false,
                isSelected: false,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: sel
                    ? MemoryCreateSheet._themeBlue
                    : MemoryCreateSheet._inactiveTagLabel,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagAddPickerItem() {
    final enabled = _tags.length < TagService.maxTagCount;
    return GestureDetector(
      onTap: enabled ? _openAddTagSheet : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: SizedBox(
          width: _tagItemWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _tagIconSandwich(
                selected: false,
                circle: Container(
                  width: _tagCircleSize,
                  height: _tagCircleSize,
                  decoration: const BoxDecoration(
                    color: MemoryCreateSheet._themeBlue,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.add,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '新建',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MemoryCreateSheet._inactiveTagLabel,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tagPickerRow() {
    return SizedBox(
      height: _tagBarHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        itemCount: _tags.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == _tags.length) {
            return Align(
              alignment: Alignment.topCenter,
              child: _tagAddPickerItem(),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: _tagPickerItem(_tags[index]),
          );
        },
      ),
    );
  }

  Future<bool> _confirmDiscardChanges() async {
    final discard = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('放弃本次修改吗？'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续编辑'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _requestClose() async {
    if (!_isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (await _confirmDiscardChanges() && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadTags() async {
    final list = await TagService.loadTags();
    if (!mounted) return;
    setState(() {
      _tags = list;
      final edit = widget.collectionToEdit;
      if (edit != null) {
        _selectedTagId =
            list.any((t) => t.id == edit.tagId) ? edit.tagId : null;
      } else {
        _selectedTagId ??= list.isNotEmpty ? list.first.id : null;
      }
      _loadingTags = false;
      _captureInitialSnapshot();
    });
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onFormChanged);
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

  Widget _coverPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.add_photo_alternate,
          size: 28,
          color: MemoryCreateSheet._muted,
        ),
        const SizedBox(height: 6),
        Text(
          '上传封面',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
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
      ).showSnackBar(const SnackBar(content: Text('请选择标签类型')));
      return;
    }

    final edit = widget.collectionToEdit;
    if (edit != null) {
      final ok = await MemoryService.updateCollection(
        edit.copyWith(
          name: name,
          tagId: tagId,
          coverPhotoPath: _coverPhotoPath,
          isPinned: _pinned,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(ok ? true : false);
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
      await MemoryService.addEventToCollection(
        MemoryService.cloneFromListEvent(pre),
        collection.id,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.outerContext.mounted) return;
      showMemoryPhotoStreamSheet(widget.outerContext, collection: collection);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom;

    final canSubmit = _canSubmit;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscardChanges() && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
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
                      _isEditMode ? '修改时光集' : '新建时光集',
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
                        onPressed: _requestClose,
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
                        _tagPickerRow(),
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: _pickCover,
                            child: Container(
                              width: MemoryCreateSheet._coverThumbSize,
                              height: MemoryCreateSheet._coverThumbSize,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  MemoryCreateSheet._coverThumbRadius,
                                ),
                                border: Border.all(
                                  color: MemoryCreateSheet._pillBorder,
                                  width: 2,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _coverPhotoPath != null &&
                                      _coverPhotoPath!.isNotEmpty
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          File(_coverPhotoPath!),
                                          fit: BoxFit.cover,
                                          width: MemoryCreateSheet._coverThumbSize,
                                          height: MemoryCreateSheet._coverThumbSize,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  _coverPlaceholder(),
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
                                  : _coverPlaceholder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              const Text(
                                '设为置顶',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: MemoryCreateSheet._titleColor,
                                ),
                              ),
                              const Spacer(),
                              Switch.adaptive(
                                value: _pinned,
                                activeThumbColor: Colors.white,
                                activeTrackColor: MemoryCreateSheet._themeBlue,
                                inactiveTrackColor:
                                    MemoryCreateSheet._pillBorder,
                                inactiveThumbColor: Colors.white,
                                onChanged: (v) => setState(() => _pinned = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canSubmit
                                  ? MemoryCreateSheet._themeBlue
                                  : MemoryCreateSheet._disabledBtn,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  MemoryCreateSheet._disabledBtn,
                              disabledForegroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: canSubmit ? _save : null,
                            child: Text(
                              _isEditMode ? '更新' : '保存',
                              style: const TextStyle(
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
