import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lunar/lunar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/services/membership_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/widgets/event_photo_paths_preview.dart';
import 'package:time_calendar/widgets/common_date_picker.dart';
import 'package:time_calendar/widgets/membership_soft_paywall.dart';
import 'package:time_calendar/widgets/tag_circle_widget.dart';
import 'package:time_calendar/widgets/tag_editor_sheet.dart';

// --- Design tokens（与任务规范一致） ---
const Color _kThemeBlue = Color(0xFF1A73E8);
const Color _kPinStar = Color(0xFFFFB800);
const Color _kTitleColor = Color(0xFF0F172A);
const Color _kCloseGrey = Color(0xFF64748B);
const Color _kBorderInput = Color(0xFFECEFF5);
const Color _kError = Color(0xFFF04444);
const Color _kHint = Color(0xFF94A3B8);
const List<BoxShadow> _kInputShadow = [
  BoxShadow(color: Color(0x0D111827), blurRadius: 20, offset: Offset(0, 8)),
];

/// 与清单页 `_ShareDailyQuota` 完全一致的存储 key，保证限额共用。
class _ShareDailyQuota {
  static String _keyFor(DateTime d) =>
      'share_daily_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<int> getTodayCount() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyFor(DateTime.now())) ?? 0;
  }

  static Future<void> addToToday(int n) async {
    if (n <= 0) return;
    final p = await SharedPreferences.getInstance();
    final k = _keyFor(DateTime.now());
    await p.setInt(k, (p.getInt(k) ?? 0) + n);
  }
}

class _ShareResultEntry {
  const _ShareResultEntry({required this.phone, required this.registered});
  final String phone;
  final bool registered;
}

class _ShareEventSheet extends StatefulWidget {
  const _ShareEventSheet({required this.parentContext});

  final BuildContext parentContext;

  @override
  State<_ShareEventSheet> createState() => _ShareEventSheetState();
}

class _ShareEventSheetState extends State<_ShareEventSheet> {
  final List<TextEditingController> _controllers = [];

  bool _resultsPhase = false;
  List<_ShareResultEntry> _results = [];
  int _registeredCount = 0;
  int _smsCount = 0;

  static const BoxDecoration _phoneDecorationNeutral = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(18)),
    boxShadow: [
      BoxShadow(
        color: Color(0x0D111827),
        blurRadius: 20,
        offset: Offset(0, 8),
      ),
    ],
    border: Border.fromBorderSide(BorderSide(color: Color(0xFFECEFF5))),
  );

  static final BoxDecoration _phoneDecorationError = _phoneDecorationNeutral.copyWith(
    border: Border.all(color: Color(0xFFF04444)),
  );

  @override
  void initState() {
    super.initState();
    final c = TextEditingController();
    c.addListener(() => setState(() {}));
    _controllers.add(c);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool _hasFieldError(String text) {
    if (text.isEmpty) return false;
    return !RegExp(r'^\d{11}$').hasMatch(text);
  }

  bool _allEnteredPhonesValid() {
    final phones = _controllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (phones.isEmpty) return false;
    return phones.every((p) => RegExp(r'^\d{11}$').hasMatch(p));
  }

  void _tryAddField() {
    if (_controllers.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该事件单次最多可分享给 5 人')),
      );
      return;
    }
    final c = TextEditingController();
    c.addListener(() => setState(() {}));
    setState(() => _controllers.add(c));
  }

  void _removeField(int index) {
    if (_controllers.length <= 1) return;
    _controllers[index].dispose();
    setState(() => _controllers.removeAt(index));
  }

  Future<void> _submitShare() async {
    if (!_allEnteredPhonesValid()) return;
    final phones = _controllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

    final daily = await _ShareDailyQuota.getTodayCount();
    if (!mounted) return;
    if (daily + phones.length > 20) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const Text('今日分享名额已满（每日最多 20 人），请明天再试'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
          ],
        ),
      );
      return;
    }

    final results = <_ShareResultEntry>[];
    var reg = 0;
    var sms = 0;
    for (final p in phones) {
      final last = int.tryParse(p.substring(p.length - 1)) ?? 0;
      final registered = last.isOdd;
      results.add(_ShareResultEntry(phone: p, registered: registered));
      if (registered) {
        reg++;
      } else {
        sms++;
      }
    }

    await _ShareDailyQuota.addToToday(phones.length);

    setState(() {
      _results = results;
      _registeredCount = reg;
      _smsCount = sms;
      _resultsPhase = true;
    });
  }

  void _finishSheet() {
    final n = _results.length;
    final m = _registeredCount;
    final k = _smsCount;
    Navigator.of(context).pop();
    if (!widget.parentContext.mounted) return;
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(content: Text('已分享给 $n 位，$m 位等待确认，$k 位将收到短信（免费）')),
    );
  }

  Widget _phoneField(int index) {
    final c = _controllers[index];
    final err = _hasFieldError(c.text);
    return Container(
      decoration: err ? _phoneDecorationError : _phoneDecorationNeutral,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.phone, color: Color(0xFF9CA3AF), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '请输入手机号',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final atMaxFields = _controllers.length >= 5;
    final showMaxHint = atMaxFields;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '分享给…',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              if (!_resultsPhase) ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _controllers.length,
                  itemBuilder: (context, index) {
                    final c = _controllers[index];
                    final err = _hasFieldError(c.text);
                    final isLast = index == _controllers.length - 1;
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == _controllers.length - 1 ? 0 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: _phoneField(index)),
                              if (_controllers.length >= 2)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.grey.shade600,
                                  onPressed: () => _removeField(index),
                                ),
                              if (isLast)
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  color: atMaxFields ? Colors.grey : Theme.of(context).colorScheme.primary,
                                  onPressed: atMaxFields ? null : _tryAddField,
                                ),
                            ],
                          ),
                          if (err)
                            const Padding(
                              padding: EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                '请输入正确的 11 位手机号',
                                style: TextStyle(fontSize: 12, color: Color(0xFFF04444)),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                if (showMaxHint) ...[
                  const SizedBox(height: 8),
                  Text(
                    '该事件单次最多可分享给 5 人',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _allEnteredPhonesValid() ? _submitShare : null,
                    child: const Text('确认分享'),
                  ),
                ),
              ] else ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    primary: false,
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final r = _results[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              r.registered ? Icons.check_circle : Icons.sms_outlined,
                              color: r.registered ? const Color(0xFF10B981) : const Color(0xFFF97316),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.phone,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    r.registered ? '已发送至对方账号，等待确认' : '已发送邀请短信（免费）',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _finishSheet,
                    child: const Text('完成'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 供添加事件流程在 `Navigator.pop` 之后调用（需传入仍挂载的页面 context，例如 Navigator 的 context）。
void showShareSheetAfterEventAdd(BuildContext parentContext) {
  showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: _ShareEventSheet(parentContext: parentContext),
      );
    },
  );
}

class _TimePickerModal extends StatefulWidget {
  const _TimePickerModal({
    required this.initial,
    required this.onCancel,
    required this.onConfirm,
  });

  final TimeOfDay initial;
  final VoidCallback onCancel;
  final ValueChanged<TimeOfDay> onConfirm;

  @override
  State<_TimePickerModal> createState() => _TimePickerModalState();
}

class _TimePickerModalState extends State<_TimePickerModal> {
  late int _hour;
  late int _minuteIndex;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour.clamp(0, 23);
    final mm = widget.initial.minute;
    _minuteIndex = mm >= 30 ? 1 : 0;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minuteIndex);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDatePickerSheetShell(
      title: '选择时间',
      cancelLabel: '取消',
      confirmLabel: '确定',
      onCancel: widget.onCancel,
      onConfirm: () {
        final minute = _minuteIndex == 1 ? 30 : 0;
        widget.onConfirm(TimeOfDay(hour: _hour.clamp(0, 23), minute: minute));
      },
      child: SizedBox(
        height: 240,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: CupertinoPicker(
                selectionOverlay: const AppTransparentPickerOverlay(),
                scrollController: _hourCtrl,
                itemExtent: 44,
                diameterRatio: 1.2,
                magnification: 1.0,
                squeeze: 0.9,
                looping: false,
                onSelectedItemChanged: (i) {
                  HapticFeedback.lightImpact();
                  setState(() => _hour = i);
                },
                children: List.generate(
                  24,
                  (i) => appDateWheelLabelCell(
                    i.toString().padLeft(2, '0'),
                    i == _hour,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: CupertinoPicker(
                selectionOverlay: const AppTransparentPickerOverlay(),
                scrollController: _minuteCtrl,
                itemExtent: 44,
                diameterRatio: 1.2,
                magnification: 1.0,
                squeeze: 0.9,
                looping: false,
                onSelectedItemChanged: (i) {
                  HapticFeedback.lightImpact();
                  setState(() => _minuteIndex = i.clamp(0, 1));
                },
                children: [
                  appDateWheelLabelCell('00分', _minuteIndex == 0),
                  appDateWheelLabelCell('30分', _minuteIndex == 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 页面主体 ---

TimeOfDay _parseTimeHm(String hm, TimeOfDay fallback) {
  final parts = hm.split(':');
  if (parts.length != 2) return fallback;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return fallback;
  if (h < 0 || h > 23 || m < 0 || m > 59) return fallback;
  return TimeOfDay(hour: h, minute: m);
}

class EventAddPage extends StatefulWidget {
  const EventAddPage({
    super.key,
    this.initialEvent,
    this.initialTagId,
    this.customReminderCountForNewEvent,
    this.onGalleryTap,
    this.onCameraTap,
  });

  final ListEvent? initialEvent;
  /// 新建事件时预选标签（需在本地标签列表中存在）；编辑模式忽略。
  final String? initialTagId;
  /// 创建新事件时已有的自定义提醒条数（与清单中非节日事件总数对齐）。
  final int? customReminderCountForNewEvent;
  final VoidCallback? onGalleryTap;
  final VoidCallback? onCameraTap;

  @override
  State<EventAddPage> createState() => _EventAddPageState();
}

class _EventAddPageState extends State<EventAddPage> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  String _selectedTagId = '';
  List<ReminderTag> _availableTags = [];
  bool _pinned = false;
  bool _solarMode = true;

  DateTime _solarDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  late int _lunarYear;
  late int _lunarMonthSigned;
  late int _lunarDay;

  EventRepeatRule _repeat = EventRepeatRule.yearly;
  EventReminderType _reminder = EventReminderType.advanceAndSameDay;
  EventAdvanceDaysOption _advanceDays = EventAdvanceDaysOption.oneDay;

  TimeOfDay _advanceTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _sameDayTime = const TimeOfDay(hour: 9, minute: 0);

  bool _shareEnabled = false;

  MembershipTier _membershipTier = MembershipTier.free;

  /// 与当前档位 [MembershipService.benefits] 对齐，异步初始化。
  int _photoLimit = 0;

  final List<XFile> _selectedPhotos = [];
  List<String> _existingPhotoPaths = [];

  bool get _isEditMode => widget.initialEvent != null;

  int get _totalPhotoCount => _existingPhotoPaths.length + _selectedPhotos.length;

  List<String> get _displayPhotoPaths =>
      [..._existingPhotoPaths, ..._selectedPhotos.map((x) => x.path)];

  Future<void> _onPhotoLimitReached() async {
    if (!mounted) return;
    final limit = _photoLimit;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('当前档位最多可上传 $limit 张照片')),
    );
    if (_membershipTier == MembershipTier.free) {
      await showMembershipSoftPaywall(
        context,
        title: '上传照片',
        message: '升级会员即可上传更多纪念照片',
        primaryLabel: '升级会员',
        onTierChanged: _reloadMembershipTier,
      );
    }
  }

  void _openPhotoPreview(int displayIndex) {
    final paths = _displayPhotoPaths;
    if (displayIndex < 0 || displayIndex >= paths.length) return;
    showEventPhotoPathsPreview(context, photoPaths: paths, initialIndex: displayIndex);
  }

  Future<void> _showPermissionSettingsHint(String resourceLabel) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('请在系统设置中允许时光集访问$resourceLabel'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensurePhotosPermission() async {
    var status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return true;
    status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) {
      await _showPermissionSettingsHint('相册');
      return false;
    }
    return false;
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await _showPermissionSettingsHint('相机');
      return false;
    }
    return false;
  }

  Future<void> _pickGallery() async {
    final tier = await MembershipService.currentTier();
    if (!mounted) return;
    final limit = MembershipService.benefits(tier).photosPerEvent;
    setState(() {
      _membershipTier = tier;
      _photoLimit = limit;
    });
    if (limit <= 0) return;
    if (_totalPhotoCount >= limit) {
      await _onPhotoLimitReached();
      return;
    }
    if (!await _ensurePhotosPermission()) return;
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (files.isEmpty || !mounted) return;

    final tierAfter = await MembershipService.currentTier();
    if (!mounted) return;
    final limitAfter = MembershipService.benefits(tierAfter).photosPerEvent;
    setState(() {
      _membershipTier = tierAfter;
      _photoLimit = limitAfter;
    });
    final remaining = limitAfter - _totalPhotoCount;
    if (remaining <= 0) {
      await _onPhotoLimitReached();
      return;
    }
    var toAdd = files;
    if (files.length > remaining) {
      toAdd = files.sublist(0, remaining);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('当前档位最多可上传 $limitAfter 张照片')),
      );
    }
    setState(() => _selectedPhotos.addAll(toAdd));
  }

  Future<void> _pickCamera() async {
    final tier = await MembershipService.currentTier();
    if (!mounted) return;
    final limit = MembershipService.benefits(tier).photosPerEvent;
    setState(() {
      _membershipTier = tier;
      _photoLimit = limit;
    });
    if (limit <= 0) return;
    if (_totalPhotoCount >= limit) {
      await _onPhotoLimitReached();
      return;
    }
    if (!await _ensureCameraPermission()) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (file == null || !mounted) return;

    final tierAfter = await MembershipService.currentTier();
    if (!mounted) return;
    final limitAfter = MembershipService.benefits(tierAfter).photosPerEvent;
    setState(() {
      _membershipTier = tierAfter;
      _photoLimit = limitAfter;
    });
    if (_totalPhotoCount >= limitAfter) {
      await _onPhotoLimitReached();
      return;
    }
    setState(() => _selectedPhotos.add(file));
  }

  void _removePhotoAtDisplayIndex(int index) {
    setState(() {
      if (index < _existingPhotoPaths.length) {
        _existingPhotoPaths.removeAt(index);
      } else {
        _selectedPhotos.removeAt(index - _existingPhotoPaths.length);
      }
    });
  }

  Future<List<String>> _persistNewPhotos(String eventId, List<XFile> files) async {
    if (files.isEmpty) return [];
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final batch = DateTime.now().microsecondsSinceEpoch;
    final out = <String>[];
    for (var i = 0; i < files.length; i++) {
      final destPath = '${dir.path}/${batch}_${eventId}_$i.jpg';
      await File(files[i].path).copy(destPath);
      out.add(destPath);
    }
    return out;
  }

  Widget _compactPhotoIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool atLimit,
  }) {
    return Opacity(
      opacity: atLimit ? 0.3 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: atLimit ? () => _onPhotoLimitReached() : onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 28, color: _kThemeBlue),
          ),
        ),
      ),
    );
  }

  Widget _photoThumbnailGrid() {
    return LayoutBuilder(
      builder: (ctx, c) {
        final itemW = (c.maxWidth - 16) / 3;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_totalPhotoCount, (i) {
            final imageWidget = i < _existingPhotoPaths.length
                ? Image.file(File(_existingPhotoPaths[i]), fit: BoxFit.cover)
                : Image.file(File(_selectedPhotos[i - _existingPhotoPaths.length].path), fit: BoxFit.cover);
            return SizedBox(
              width: itemW,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () => _openPhotoPreview(i),
                        behavior: HitTestBehavior.opaque,
                        child: imageWidget,
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removePhotoAtDisplayIndex(i),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    final cap = _photoLimit;
    final expanded = cap <= 0 || _totalPhotoCount == 0;
    final atLimit = cap > 0 && _totalPhotoCount >= cap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '上传照片',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kTitleColor),
        ),
        const SizedBox(height: 10),
        if (cap == 0)
          Row(
            children: [
              Expanded(
                child: _PhotoSlot(
                  icon: Icons.photo_library_outlined,
                  label: '手机相册',
                  onTap: () => showMembershipSoftPaywall(
                    context,
                    title: '上传照片',
                    message: '照片上传是会员功能，升级基础版即可使用',
                    primaryLabel: '升级会员',
                    onTierChanged: _reloadMembershipTier,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoSlot(
                  icon: Icons.photo_camera_outlined,
                  label: '拍照',
                  onTap: () => showMembershipSoftPaywall(
                    context,
                    title: '上传照片',
                    message: '照片上传是会员功能，升级基础版即可使用',
                    primaryLabel: '升级会员',
                    onTierChanged: _reloadMembershipTier,
                  ),
                ),
              ),
            ],
          )
        else if (expanded)
          Row(
            children: [
              Expanded(
                child: _PhotoSlot(
                  icon: Icons.photo_library_outlined,
                  label: '手机相册',
                  onTap: _pickGallery,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoSlot(
                  icon: Icons.photo_camera_outlined,
                  label: '拍照',
                  onTap: _pickCamera,
                ),
              ),
            ],
          )
        else ...[
          SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _compactPhotoIconButton(
                  icon: Icons.photo_library_outlined,
                  onTap: _pickGallery,
                  atLimit: atLimit,
                ),
                const SizedBox(width: 24),
                const SizedBox(
                  height: 28,
                  child: VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                ),
                const SizedBox(width: 24),
                _compactPhotoIconButton(
                  icon: Icons.photo_camera_outlined,
                  onTap: _pickCamera,
                  atLimit: atLimit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _photoThumbnailGrid(),
        ],
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEvent;
    const fallbackTime = TimeOfDay(hour: 9, minute: 0);
    if (initial != null) {
      _titleCtrl.text = initial.title;
      _selectedTagId = initial.tagId;
      _pinned = initial.isPinned;
      _solarMode = !(initial.isLunarDate || initial.isLunarRecurring);
      final bd = initial.baseDate;
      _solarDate = DateTime(bd.year, bd.month, bd.day);
      if (_solarMode) {
        final lunar = Lunar.fromDate(_solarDate);
        _lunarYear = lunar.getYear();
        _lunarMonthSigned = lunar.getMonth();
        _lunarDay = lunar.getDay();
      } else {
        final lunar = Lunar.fromDate(DateTime(bd.year, bd.month, bd.day));
        _lunarYear = lunar.getYear();
        _lunarMonthSigned = lunar.getMonth();
        _lunarDay = lunar.getDay();
      }
      _repeat = initial.repeatRule;
      _reminder = initial.reminderType;
      _advanceDays = initial.advanceDaysOption;
      _advanceTime = _parseTimeHm(initial.advanceTimeHm, fallbackTime);
      _sameDayTime = _parseTimeHm(initial.sameDayTimeHm, fallbackTime);
      _shareEnabled = initial.pendingShareAfterAdd;
      _existingPhotoPaths = List<String>.from(initial.photoPaths);
    } else {
      _selectedTagId = widget.initialTagId ?? '';
      final lunar = Lunar.fromDate(_solarDate);
      _lunarYear = lunar.getYear();
      _lunarMonthSigned = lunar.getMonth();
      _lunarDay = lunar.getDay();
    }
    _titleCtrl.addListener(() => setState(() {}));
    MembershipService.currentTier().then((t) {
      if (mounted) {
        setState(() {
          _membershipTier = t;
          _photoLimit = MembershipService.benefits(t).photosPerEvent;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tags = await TagService.loadTags();
      if (!mounted) return;
      setState(() {
        _availableTags = tags;
        if (widget.initialEvent != null) {
          final tid = widget.initialEvent!.tagId;
          _selectedTagId =
              tags.any((t) => t.id == tid) ? tid : (tags.isNotEmpty ? tags.first.id : '');
        } else {
          final sheetTagId = widget.initialTagId;
          if (sheetTagId != null && tags.any((t) => t.id == sheetTagId)) {
            _selectedTagId = sheetTagId;
          } else if (tags.isNotEmpty) {
            _selectedTagId = tags.first.id;
          } else {
            _selectedTagId = '';
          }
          if (_selectedTagId.isNotEmpty) {
            _applyTypeDefaults(_selectedTagId);
          }
        }
      });
    });
  }

  Future<void> _reloadMembershipTier() async {
    final t = await MembershipService.currentTier();
    if (mounted) {
      setState(() {
        _membershipTier = t;
        _photoLimit = MembershipService.benefits(t).photosPerEvent;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _titleOk => _titleCtrl.text.trim().isNotEmpty;

  bool get _tagOk =>
      _selectedTagId.trim().isNotEmpty &&
      _availableTags.any((t) => t.id == _selectedTagId);

  bool get _canSave => _titleOk && _tagOk;

  Future<void> _reloadTags() async {
    final tags = await TagService.loadTags();
    if (!mounted) return;
    setState(() {
      _availableTags = tags;
      if (!tags.any((t) => t.id == _selectedTagId)) {
        _selectedTagId = tags.isNotEmpty ? tags.first.id : '';
      }
    });
  }

  Future<void> _openAddTagSheet() async {
    if (_availableTags.length >= TagService.maxTagCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多可创建 10 个标签')),
      );
      return;
    }
    final created = await showTagEditorSheet(
      context,
      nextSortOrder: _availableTags.length,
    );
    if (created == null || !mounted) return;
    await _reloadTags();
    setState(() {
      _selectedTagId = created.id;
      _applyTypeDefaults(created.id);
    });
  }

  Future<void> _openEditTagSheet(ReminderTag tag) async {
    final updated = await showTagEditorSheet(context, initial: tag);
    if (!mounted) return;
    await _reloadTags();
    if (updated != null) {
      setState(() {
        _selectedTagId = updated.id;
        _applyTypeDefaults(updated.id);
      });
    }
  }

  void _applyTypeDefaults(String tagId) {
    if (tagId == 'birthday' || tagId == 'partner') {
      _repeat = EventRepeatRule.yearly;
      _reminder = EventReminderType.advanceAndSameDay;
      _advanceDays = EventAdvanceDaysOption.oneDay;
    } else {
      _repeat = EventRepeatRule.none;
      _reminder = EventReminderType.sameDayOnly;
    }
  }

  DateTime _effectiveGregorian() {
    if (_solarMode) {
      return DateTime(_solarDate.year, _solarDate.month, _solarDate.day);
    }
    final lunar = Lunar.fromYmd(_lunarYear, _lunarMonthSigned, _lunarDay);
    final s = lunar.getSolar();
    return DateTime(s.getYear(), s.getMonth(), s.getDay());
  }

  String _solarDisplay(DateTime d) {
    return '${d.year}年${d.month}月${d.day}日';
  }

  String _lunarDisplayFull() {
    final lunar = Lunar.fromYmd(_lunarYear, _lunarMonthSigned, _lunarDay);
    return '${lunar.getYearInChinese()}年${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _optionPill(String label, bool isSelected, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1A73E8) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // ← 关键：强制宽度由文字决定
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _pickSolarDate() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return AppSolarDatePickerModal(
          initialDate: DateTime(_solarDate.year, _solarDate.month, _solarDate.day),
          onCancel: () => Navigator.pop(ctx),
          onConfirm: (picked) {
            setState(() => _solarDate = picked);
            _syncLunarFromSolar(_solarDate);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  void _syncLunarFromSolar(DateTime d) {
    final lunar = Lunar.fromDate(d);
    _lunarYear = lunar.getYear();
    _lunarMonthSigned = lunar.getMonth();
    _lunarDay = lunar.getDay();
  }

  Future<void> _pickLunarDate() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return AppLunarDatePickerModal(
          initialYear: _lunarYear,
          initialMonthSigned: _lunarMonthSigned,
          initialDay: _lunarDay,
          onCancel: () => Navigator.pop(ctx),
          onConfirm: (year, monthSigned, dayLunar) {
            setState(() {
              _lunarYear = year;
              _lunarMonthSigned = monthSigned;
              _lunarDay = dayLunar;
              final lunar = Lunar.fromYmd(year, monthSigned, dayLunar);
              final s = lunar.getSolar();
              _solarDate = DateTime(s.getYear(), s.getMonth(), s.getDay());
            });
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  Future<void> _pickTime({required bool advance}) async {
    final initial = advance ? _advanceTime : _sameDayTime;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return _TimePickerModal(
          initial: initial,
          onCancel: () => Navigator.pop(ctx),
          onConfirm: (t) {
            setState(() {
              if (advance) {
                _advanceTime = t;
              } else {
                _sameDayTime = t;
              }
            });
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_titleOk) return;
    if (!_tagOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请为事件选择一个标签')),
      );
      return;
    }
    final tier = await MembershipService.currentTier();
    if (!mounted) return;

    if (!MembershipService.canUseLunarBirthday(tier) && !_solarMode) {
      if (!mounted) return;
      await showMembershipSoftPaywall(
        context,
        title: '农历提醒',
        message: '农历生日提醒是基础版功能，升级即可使用',
        primaryLabel: '升级会员',
        onTierChanged: _reloadMembershipTier,
      );
      return;
    }

    if (!_isEditMode) {
      final count = widget.customReminderCountForNewEvent ?? 0;
      if (!MembershipService.canCreateReminder(tier, count)) {
        if (!mounted) return;
        await showReminderQuotaPaywall(
          context,
          onTierChanged: _reloadMembershipTier,
        );
        return;
      }
    }

    final nav = Navigator.of(context);
    final navCtx = nav.context;
    final base = _effectiveGregorian();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final baseDay = DateTime(base.year, base.month, base.day);
    final isExpired = (_repeat == EventRepeatRule.none) && baseDay.isBefore(today);
    final initial = widget.initialEvent;
    final eventId = initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    List<String> newPersisted;
    try {
      newPersisted = await _persistNewPhotos(eventId, _selectedPhotos);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片保存失败，请重试')),
      );
      return;
    }

    final photoPaths = [..._existingPhotoPaths, ...newPersisted];

    final event = ListEvent(
      id: eventId,
      title: _titleCtrl.text.trim(),
      baseDate: DateTime(base.year, base.month, base.day),
      tagId: _selectedTagId,
      isPinned: _pinned,
      isLunarRecurring: !_solarMode,
      isExpired: isExpired,
      repeatRule: _repeat,
      reminderType: _reminder,
      advanceDaysOption: _advanceDays,
      advanceTimeHm: _fmtTime(_advanceTime),
      sameDayTimeHm: _fmtTime(_sameDayTime),
      isLunarDate: !_solarMode,
      photoUrl: initial?.photoUrl,
      photoPaths: photoPaths,
      pendingShareAfterAdd: _shareEnabled,
    );
    nav.pop(event);
    if (_shareEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navCtx.mounted) showShareSheetAfterEventAdd(navCtx);
      });
    }
  }

  bool get _showAdvance =>
      _reminder == EventReminderType.advanceAndSameDay || _reminder == EventReminderType.advanceOnly;

  bool get _showSameDay =>
      _reminder == EventReminderType.advanceAndSameDay || _reminder == EventReminderType.sameDayOnly;

  Widget _labeledInputRow({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required Color borderColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: _kInputShadow,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            alignment: Alignment.center,
            child: TextField(
              controller: controller,
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 16, height: 1.25, color: _kTitleColor),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: const TextStyle(color: _kHint, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleBorderColor = _titleOk ? _kBorderInput : _kError;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: _kCloseGrey, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    '添加事件',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _kTitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: TagCircleWidget.barHeight,
                      child: SingleChildScrollView(
                        clipBehavior: Clip.none,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final tag in _availableTags) ...[
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTagId = tag.id;
                                    _applyTypeDefaults(tag.id);
                                  });
                                },
                                onLongPress: () => _openEditTagSheet(tag),
                                behavior: HitTestBehavior.opaque,
                                child: TagCircleWidget(
                                  tag: tag,
                                  isSelected: _selectedTagId == tag.id,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            TagCircleWidget.scrollActionPill(
                              label: '新建',
                              onTap: _availableTags.length <
                                      TagService.maxTagCount
                                  ? _openAddTagSheet
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _labeledInputRow(
                      label: '标题',
                      controller: _titleCtrl,
                      hintText: '输入事件标题…',
                      borderColor: titleBorderColor,
                    ),
                    const SizedBox(height: 16),
                    _labeledInputRow(
                      label: '备注',
                      controller: _noteCtrl,
                      hintText: '添加备注…',
                      borderColor: _kBorderInput,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: _kPinStar, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            '置顶',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _kTitleColor),
                          ),
                          const Spacer(),
                          Switch.adaptive(
                            value: _pinned,
                            onChanged: (v) => setState(() => _pinned = v),
                            thumbColor: WidgetStateProperty.resolveWith(
                              (s) => s.contains(WidgetState.selected) ? Colors.white : null,
                            ),
                            trackColor: WidgetStateProperty.resolveWith(
                              (s) => s.contains(WidgetState.selected) ? _kThemeBlue : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionIconTitle(icon: Icons.calendar_today_outlined, title: '时间设置'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _CalendarModePill(
                            label: '公历',
                            selected: _solarMode,
                            onTap: () => setState(() {
                              _solarMode = true;
                              _syncLunarFromSolar(_solarDate);
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CalendarModePill(
                            label: '农历',
                            selected: !_solarMode,
                            onTap: () async {
                              if (!MembershipService.canUseLunarBirthday(
                                _membershipTier,
                              )) {
                                await showMembershipSoftPaywall(
                                  context,
                                  title: '农历提醒',
                                  message:
                                      '农历生日提醒是基础版功能，升级即可使用',
                                  primaryLabel: '升级会员',
                                  onTierChanged: _reloadMembershipTier,
                                );
                                return;
                              }
                              setState(() {
                                _solarMode = false;
                                _syncLunarFromSolar(_solarDate);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        if (_solarMode) {
                          _pickSolarDate();
                        } else {
                          _pickLunarDate();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _kBorderInput),
                          boxShadow: _kInputShadow,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _solarMode ? _solarDisplay(_solarDate) : _lunarDisplayFull(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: _kTitleColor,
                                ),
                              ),
                            ),
                            const Icon(Icons.calendar_month_outlined, color: _kCloseGrey, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      direction: Axis.horizontal,
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        _optionPill('不重复', _repeat == EventRepeatRule.none, () => setState(() => _repeat = EventRepeatRule.none)),
                        _optionPill('每天', _repeat == EventRepeatRule.daily, () => setState(() => _repeat = EventRepeatRule.daily)),
                        _optionPill('每周', _repeat == EventRepeatRule.weekly, () => setState(() => _repeat = EventRepeatRule.weekly)),
                        _optionPill('每月', _repeat == EventRepeatRule.monthly, () => setState(() => _repeat = EventRepeatRule.monthly)),
                        _optionPill('每年', _repeat == EventRepeatRule.yearly, () => setState(() => _repeat = EventRepeatRule.yearly)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionIconTitle(icon: Icons.notifications_none_outlined, title: '提醒策略'),
                    const SizedBox(height: 10),
                    Wrap(
                      direction: Axis.horizontal,
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        _optionPill('前置+当天', _reminder == EventReminderType.advanceAndSameDay, () => setState(() => _reminder = EventReminderType.advanceAndSameDay)),
                        _optionPill('仅前置', _reminder == EventReminderType.advanceOnly, () => setState(() => _reminder = EventReminderType.advanceOnly)),
                        _optionPill('仅当天', _reminder == EventReminderType.sameDayOnly, () => setState(() => _reminder = EventReminderType.sameDayOnly)),
                      ],
                    ),
                    if (_showAdvance) ...[
                      const SizedBox(height: 10),
                      const Text(
                        '前置提醒选项',
                        style: TextStyle(fontSize: 12, color: _kCloseGrey, fontWeight: FontWeight.w400),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        direction: Axis.horizontal,
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.start,
                        children: [
                          _optionPill('前1天', _advanceDays == EventAdvanceDaysOption.oneDay, () => setState(() => _advanceDays = EventAdvanceDaysOption.oneDay)),
                          _optionPill('前3天', _advanceDays == EventAdvanceDaysOption.threeDays, () => setState(() => _advanceDays = EventAdvanceDaysOption.threeDays)),
                          _optionPill('前1周', _advanceDays == EventAdvanceDaysOption.oneWeek, () => setState(() => _advanceDays = EventAdvanceDaysOption.oneWeek)),
                          _optionPill('前1月', _advanceDays == EventAdvanceDaysOption.oneMonth, () => setState(() => _advanceDays = EventAdvanceDaysOption.oneMonth)),
                        ],
                      ),
                    ],
                    if (_showSameDay) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check, size: 16, color: _kThemeBlue),
                            SizedBox(width: 6),
                            Text(
                              '当天提醒',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _kThemeBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_showAdvance) ...[
                      const SizedBox(height: 10),
                      _TimeRow(
                        label: '前置时间',
                        timeText: _fmtTime(_advanceTime),
                        onTap: () => _pickTime(advance: true),
                      ),
                    ],
                    if (_showSameDay) ...[
                      const SizedBox(height: 8),
                      _TimeRow(
                        label: '当天时间',
                        timeText: _fmtTime(_sameDayTime),
                        onTap: () => _pickTime(advance: false),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildPhotoSection(context),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.share_outlined, color: _kHint, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            '分享',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _kTitleColor),
                          ),
                          const Spacer(),
                          Switch.adaptive(
                            value: _shareEnabled,
                            onChanged: (v) => setState(() => _shareEnabled = v),
                            thumbColor: WidgetStateProperty.resolveWith(
                              (s) => s.contains(WidgetState.selected) ? Colors.white : null,
                            ),
                            trackColor: WidgetStateProperty.resolveWith(
                              (s) => s.contains(WidgetState.selected) ? _kThemeBlue : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 80 + MediaQuery.paddingOf(context).bottom),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
              child: Opacity(
                opacity: _canSave ? 1 : 0.5,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kThemeBlue,
                      disabledBackgroundColor: _kHint,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _canSave ? () => _submit() : null,
                    child: Text(
                      _isEditMode
                          ? '保存修改'
                          : (_shareEnabled ? '保存并分享' : '添加事件'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

class _CalendarModePill extends StatelessWidget {
  const _CalendarModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kThemeBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _kCloseGrey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.timeText,
    required this.onTap,
  });

  final String label;
  final String timeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: _kHint, size: 16),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: _kCloseGrey),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(timeText, style: const TextStyle(fontSize: 14, color: Colors.black)),
                  const Icon(Icons.keyboard_arrow_down, color: _kCloseGrey, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: const Color(0xFFE2E8F0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 88,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: _kHint),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 14, color: _kCloseGrey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final path = Path()..addRRect(r);
    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        dashedPath.addPath(
          metric.extractPath(d, (d + 6).clamp(0.0, metric.length)),
          Offset.zero,
        );
        d += 10;
      }
    }
    canvas.drawPath(
      dashedPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _sectionIconTitle({required IconData icon, required String title}) {
  return Row(
    children: [
      Icon(icon, size: 16, color: _kCloseGrey),
      const SizedBox(width: 6),
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _kTitleColor,
        ),
      ),
    ],
  );
}
