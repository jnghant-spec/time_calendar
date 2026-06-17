import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/pages/tag_photo_crop_page.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/widgets/tag_circle_widget.dart';

const Color _titleColor = Color(0xFF1F2937);
const Color _muted = Color(0xFF94A3B8);
const Color _themeBlue = Color(0xFF1A73E8);
const Color _switchInactiveTrack = Color(0xFFE5E7EB);
const Color _partnerStatusMuted = Color(0xFF9CA3AF);
const Color _partnerSharedRed = Color(0xFFE01D1D);
const Color _deleteRed = Color(0xFFEF4444);
const Color _dangerRed = Color(0xFFFF4D4D);
const Color _nameHintAmber = Color(0xFFF59E0B);

/// 删除标签二次确认（管理列表滑块 / 编辑页底部按钮共用）。
Future<bool> showConfirmDeleteTagDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除该标签吗？这可能影响相关事件'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('取消', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '删除',
              style: TextStyle(color: _dangerRed),
            ),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

/// 新建/编辑单个标签；保存后 `Navigator.pop(context, tag)`。
Future<ReminderTag?> showTagEditorSheet(
  BuildContext context, {
  ReminderTag? initial,
  int? nextSortOrder,
  Future<bool> Function(ReminderTag tag)? onDelete,
}) {
  return showModalBottomSheet<ReminderTag>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: TagEditorSheet(
          initial: initial,
          nextSortOrder: nextSortOrder,
          onDelete: onDelete,
        ),
      );
    },
  );
}

/// 标签管理入口：列表中选择编辑/新建（内部均调用 [showTagEditorSheet]）。
Future<void> showTagManageSheet(
  BuildContext context, {
  required Future<void> Function() onTagsChanged,
  Future<bool> Function(ReminderTag tag)? onDeleteTag,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _TagManageSheet(
      onTagsChanged: onTagsChanged,
      onDeleteTag: onDeleteTag,
    ),
  );
}

/// 二次确认后解除关联并删除标签；返回是否已删除。
Future<bool> confirmUnlinkDeleteTag(
  BuildContext context,
  ReminderTag tag,
) async {
  if (tag.isSystemTag) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('系统标签不可删除'),
        duration: Duration(seconds: 2),
      ),
    );
    return false;
  }

  final counts = await TagService.countTagAssociations(tag.id);
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('删除"${tag.name}"标签？'),
        content: Text(
          '该标签下还有 ${counts.reminders} 个提醒事项和 ${counts.collections} 个事件集。'
          '删除后，这些内容将不再带有此标签，但数据不会丢失。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('取消', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '仍要删除',
              style: TextStyle(color: _deleteRed),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return false;
  await TagService.unlinkAndDeleteTag(tag.id);
  return true;
}

/// 主题蓝圆形「+」新建按钮（48px）。
class TagAddCircleButton extends StatelessWidget {
  const TagAddCircleButton({
    super.key,
    required this.onTap,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final bool enabled;

  static const double _itemHeight = TagCircleWidget.itemHeight;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: _itemHeight,
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: _themeBlue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.add, size: 24, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '新建',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 14 / 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TagEditorSheet extends StatefulWidget {
  const TagEditorSheet({
    super.key,
    this.initial,
    this.nextSortOrder,
    this.onDelete,
  });

  final ReminderTag? initial;
  final int? nextSortOrder;
  final Future<bool> Function(ReminderTag tag)? onDelete;

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  late final TextEditingController _nameCtrl;
  late int _colorIndex;
  String? _photoPath;
  String? _iconName;
  bool _saving = false;
  late bool _isPartnerTag;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameCtrl = TextEditingController(text: initial?.name ?? '');
    if (initial != null) {
      if (initial.accentColor == null) {
        _colorIndex = TagCircleWidget.kTagNoThemeIndex;
      } else {
        final idx = TagCircleWidget.kTagPresetColors.indexWhere(
          (c) => c.toARGB32() == initial.accentColor!.toARGB32(),
        );
        _colorIndex = idx >= 0 ? idx : 0;
      }
      _photoPath = initial.photoPath;
      _iconName = _hasPhotoPath(initial.photoPath)
          ? null
          : _resolveIconKey(initial.iconName);
    } else {
      _colorIndex = 0;
      _iconName = TagCircleWidget.defaultIconKey;
    }
    _isPartnerTag = initial?.isPartnerTag ?? false;
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Color? get _selectedThemeColor => _colorIndex == TagCircleWidget.kTagNoThemeIndex
      ? null
      : TagCircleWidget.kTagPresetColors[_colorIndex];

  Color get _pickerAccent =>
      TagCircleWidget.themeColorOrDefault(_selectedThemeColor);

  bool get _nameOk => _nameCtrl.text.trim().isNotEmpty;

  bool _themeColorEquals(Color? a, Color? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.toARGB32() == b.toARGB32();
  }

  static String? _iconKeyForCompare({required bool hasPhoto, String? iconName}) =>
      hasPhoto ? null : _resolveIconKey(iconName);

  bool get _hasChanges {
    if (!_isEdit) return _nameOk;
    final initial = widget.initial!;
    final initialHasPhoto = _hasPhotoPath(initial.photoPath);
    return _nameCtrl.text.trim() != initial.name ||
        !_themeColorEquals(_selectedThemeColor, initial.accentColor) ||
        _photoPath != initial.photoPath ||
        _iconKeyForCompare(hasPhoto: _hasActivePhoto, iconName: _iconName) !=
            _iconKeyForCompare(
              hasPhoto: initialHasPhoto,
              iconName: initial.iconName,
            ) ||
        _isPartnerTag != initial.isPartnerTag;
  }

  bool get _canSave => _nameOk && _hasChanges && !_saving;

  bool get _isSystemTag => _isEdit && widget.initial!.isSystemTag;

  bool get _showLongNameHint => _nameCtrl.text.characters.length > 4;

  bool get _hasActivePhoto => _hasPhotoPath(_photoPath);

  /// 有照片时不展示图标选中态；无照片时用于预览与图标网格。
  String? get _activeIconName => _hasActivePhoto ? null : _iconName;

  static bool _hasPhotoPath(String? path) =>
      path != null && path.isNotEmpty && File(path).existsSync();

  static String _resolveIconKey(String? iconName) {
    if (iconName != null &&
        iconName.isNotEmpty &&
        TagPresetIcons.dataFor(iconName) != null) {
      return iconName;
    }
    return TagCircleWidget.defaultIconKey;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final name = _nameCtrl.text.trim();
    setState(() => _saving = true);
    try {
      ReminderTag tag;
      final themeColor = _selectedThemeColor;
      final iconBg = themeColor != null
          ? themeColor.withValues(alpha: 0.15)
          : const Color(0xFFF1F5F9);
      if (_isEdit) {
        final initial = widget.initial!;
        tag = initial.copyWith(
          name: name,
          accentColor: themeColor,
          clearAccentColor: themeColor == null,
          iconBgColor: iconBg,
          photoPath: _photoPath,
          iconName: _hasActivePhoto ? null : _resolveIconKey(_iconName),
          clearPhotoPath: _photoPath == null && initial.photoPath != null,
          clearIconName: _hasActivePhoto ||
              (_iconName == null && initial.iconName != null),
          isPartnerTag: _isPartnerTag,
        );
        await TagService.updateTag(tag);
      } else {
        tag = ReminderTag(
          id: TagService.newTagId(),
          name: name,
          accentColor: themeColor,
          iconBgColor: iconBg,
          sortOrder: widget.nextSortOrder ?? 0,
          isDefault: false,
          createdAt: DateTime.now(),
          photoPath: _photoPath,
          iconName: _hasActivePhoto ? null : _resolveIconKey(_iconName),
          isSystemTag: false,
          isPartnerTag: _isPartnerTag,
        );
        await TagService.addTag(tag);
      }
      await TagService.loadTags();
      if (!mounted) return;
      Navigator.pop(context, tag);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final initial = widget.initial;
    if (initial == null) return;
    if (initial.isSystemTag) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('系统标签不可删除'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!await showConfirmDeleteTagDialog(context)) return;
    if (!mounted) return;
    await TagService.unlinkAndDeleteTag(initial.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _onDeleteTagPressed() {
    if (_isSystemTag) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('系统标签不可删除'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _delete();
  }

  Widget _iconPickerCell(MapEntry<String, IconData> entry) {
    final selected =
        !_hasActivePhoto && _iconName != null && _iconName == entry.key;
    return GestureDetector(
      onTap: () => setState(() {
        _photoPath = null;
        _iconName = entry.key;
      }),
      child: Transform.scale(
        scale: selected ? 1.1 : 1.0,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected
                ? _pickerAccent.withValues(alpha: 0.18)
                : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? _pickerAccent : const Color(0xFFE2E8F0),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            entry.value,
            size: 18,
            color: selected ? _pickerAccent : _muted,
          ),
        ),
      ),
    );
  }

  Widget _iconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择图标',
          style: TextStyle(fontSize: 14, color: _muted),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (var i = 0; i < TagPresetIcons.entries.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  _iconPickerCell(TagPresetIcons.entries[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const double _colorSwatchSize = 32;
  static const double _colorRingGap = 2.75;
  static const double _colorRingBorderWidth = 1.5;

  /// 选中态：主题蓝外环 + 白间隙，未选中仅 32px 色块。
  Widget _colorSwatchShell({required bool selected, required Widget child}) {
    final inner = SizedBox(
      width: _colorSwatchSize,
      height: _colorSwatchSize,
      child: child,
    );
    if (!selected) return inner;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: _themeBlue,
          width: _colorRingBorderWidth,
        ),
      ),
      padding: const EdgeInsets.all(_colorRingGap),
      child: inner,
    );
  }

  Widget _noThemeSwatch() {
    final selected = _colorIndex == TagCircleWidget.kTagNoThemeIndex;
    return GestureDetector(
      onTap: () => setState(() => _colorIndex = TagCircleWidget.kTagNoThemeIndex),
      child: _colorSwatchShell(
        selected: selected,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF1F5F9),
            border: selected
                ? null
                : Border.all(
                    color: TagCircleWidget.kDefaultTagColor,
                    width: 1,
                  ),
          ),
          alignment: Alignment.center,
          child: Transform.rotate(
            angle: -0.78539816339,
            child: Container(
              width: 16,
              height: 2,
              color: _dangerRed,
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorSwatch(int index) {
    final selected = _colorIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _colorIndex = index),
      child: _colorSwatchShell(
        selected: selected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TagCircleWidget.kTagPresetColors[index],
          ),
        ),
      ),
    );
  }

  Widget _colorPalette() {
    final swatchCount = TagCircleWidget.kTagPresetColors.length;
    final selectedOuter = _colorSwatchSize +
        2 * _colorRingGap +
        2 * _colorRingBorderWidth;
    return SizedBox(
      height: selectedOuter,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < swatchCount; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _colorSwatch(i),
            ],
            const SizedBox(width: 12),
            _noThemeSwatch(),
          ],
        ),
      ),
    );
  }

  Widget _partnerShareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '设为伴侣共享标签',
                style: TextStyle(fontSize: 16, color: _titleColor),
              ),
            ),
            Switch(
              value: _isPartnerTag,
              onChanged: (value) => setState(() => _isPartnerTag = value),
              activeTrackColor: _themeBlue,
              activeThumbColor: Colors.white,
              inactiveTrackColor: _switchInactiveTrack,
              inactiveThumbColor: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '开启后，该标签下的提醒与时光集将自动同步给伴侣',
          style: TextStyle(fontSize: 12, color: _partnerStatusMuted),
        ),
      ],
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 95,
      );
      if (file == null || !mounted) return;
      final cropped = await TagPhotoCropPage.show(context, file.path);
      if (cropped != null) {
        setState(() {
          _photoPath = cropped;
          _iconName = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _showPhotoSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetBottom = MediaQuery.paddingOf(ctx).bottom;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Material(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + sheetBottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.photo_library_outlined),
                      title: const Text('从相册选取'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickPhoto(ImageSource.gallery);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_camera_outlined),
                      title: const Text('拍照'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickPhoto(ImageSource.camera);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 4,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: _themeBlue,
                          minimumSize: const Size(64, 48),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      _isEdit ? '编辑标签' : '新建标签',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _titleColor,
                      ),
                    ),
                    Positioned(
                      right: 4,
                      child: TextButton(
                        onPressed: _canSave ? _save : null,
                        style: TextButton.styleFrom(
                          foregroundColor: _canSave ? _themeBlue : _muted,
                          disabledForegroundColor: _muted,
                          minimumSize: const Size(64, 48),
                        ),
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
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _showPhotoSourceSheet,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TagCircleWidget.buildEditorPreview(
                              size: 80,
                              themeColor: _selectedThemeColor,
                              photoPath: _photoPath,
                              iconName: _activeIconName,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '点击更换照片',
                              style: TextStyle(
                                fontSize: 14,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '标签名称',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: '输入标签名称',
                        hintStyle: const TextStyle(color: _muted, fontSize: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              const BorderSide(color: Color(0xFFECEFF5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: _themeBlue),
                        ),
                      ),
                      style: const TextStyle(fontSize: 16, color: _titleColor),
                    ),
                    if (_showLongNameHint) ...[
                      const SizedBox(height: 6),
                      const Text(
                        '标签名称较长，在标签栏可能显示不全',
                        style: TextStyle(
                          fontSize: 12,
                          color: _nameHintAmber,
                          height: 20 / 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _iconPicker(),
                    const SizedBox(height: 16),
                    const Text(
                      '选择主题色',
                      style: TextStyle(
                        fontSize: 14,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _colorPalette(),
                    const SizedBox(height: 16),
                    _partnerShareSection(),
                    if (_isEdit) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _onDeleteTagPressed,
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                _isSystemTag ? _muted : _dangerRed,
                            backgroundColor: Colors.transparent,
                            side: BorderSide(
                              color: _isSystemTag ? _muted : _dangerRed,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            '删除标签',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _isSystemTag ? _muted : _dangerRed,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagManageSheet extends StatefulWidget {
  const _TagManageSheet({
    required this.onTagsChanged,
    this.onDeleteTag,
  });

  final Future<void> Function() onTagsChanged;
  final Future<bool> Function(ReminderTag tag)? onDeleteTag;

  @override
  State<_TagManageSheet> createState() => _TagManageSheetState();
}

class _TagManageSheetState extends State<_TagManageSheet> {
  List<ReminderTag> _tags = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await TagService.loadTags();
    if (!mounted) return;
    setState(() => _tags = list);
  }

  Future<void> _create() async {
    if (_tags.length >= TagService.maxTagCount) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多可创建 10 个标签')),
      );
      return;
    }
    final created = await showTagEditorSheet(
      context,
      nextSortOrder: _tags.length,
    );
    if (created == null) return;
    await widget.onTagsChanged();
    await _load();
  }

  Future<void> _edit(ReminderTag tag) async {
    await showTagEditorSheet(
      context,
      initial: tag,
      onDelete: widget.onDeleteTag,
    );
    if (!mounted) return;
    await widget.onTagsChanged();
    await _load();
  }

  Future<void> _deleteTag(ReminderTag tag) async {
    if (tag.isSystemTag) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('系统标签不可删除'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!await showConfirmDeleteTagDialog(context)) return;
    if (!mounted) return;
    await TagService.unlinkAndDeleteTag(tag.id);
    if (!mounted) return;
    await widget.onTagsChanged();
    setState(() => _tags.removeWhere((t) => t.id == tag.id));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom + 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        '管理标签',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _titleColor,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: _muted),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ManageCreateRow(
                          enabled: _tags.length < TagService.maxTagCount,
                          onTap: _create,
                        ),
                      ),
                      for (var i = 0; i < _tags.length; i++) ...[
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF1F5F9),
                          indent: 16,
                          endIndent: 16,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Slidable(
                            key: ValueKey(_tags[i].id),
                            closeOnScroll: true,
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              extentRatio: 0.2,
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _deleteTag(_tags[i]),
                                  backgroundColor: _dangerRed,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_outline,
                                  borderRadius: BorderRadius.zero,
                                ),
                              ],
                            ),
                            child: _ManageTagListTile(
                              tag: _tags[i],
                              onTap: () => _edit(_tags[i]),
                            ),
                          ),
                        ),
                      ],
                    ],
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

class _ManageCreateRow extends StatelessWidget {
  const _ManageCreateRow({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _themeBlue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                '新建标签',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _themeBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageTagListTile extends StatelessWidget {
  const _ManageTagListTile({
    required this.tag,
    required this.onTap,
  });

  final ReminderTag tag;
  final VoidCallback onTap;

  Widget _buildPartnerStatus() {
    if (!tag.isPartnerTag) return const SizedBox.shrink();

    if (TagService.isPartnerRelationAccepted()) {
      final partnerName = TagService.getPartnerRelation().partnerName ?? '伴侣';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/ic_couple_hearts.svg',
            width: 16,
            height: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '已与$partnerName共享',
            style: const TextStyle(
              fontSize: 12,
              color: _partnerSharedRed,
            ),
          ),
        ],
      );
    }

    return const Text(
      '待绑定伴侣',
      style: TextStyle(
        fontSize: 12,
        color: _partnerStatusMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        highlightColor: Colors.grey.withValues(alpha: 0.05),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                TagCircleWidget(tag: tag, size: 36, showLabel: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tag.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _titleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildPartnerStatus(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
