import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lunar/lunar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/pages/photo_crop_page.dart';
import 'package:time_calendar/services/event_share_service.dart';
import 'package:time_calendar/services/membership_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/widgets/common_date_picker.dart';
import 'package:time_calendar/widgets/membership_soft_paywall.dart';
import 'package:time_calendar/widgets/share_event_sheet.dart';
import 'package:time_calendar/widgets/tag_circle_widget.dart';
import 'package:time_calendar/widgets/tag_editor_sheet.dart';

// --- Design tokens（与任务规范一致） ---
const Color _kThemeBlue = Color(0xFF1A73E8);
const Color _kTitleColor = Color(0xFF0F172A);
const Color _kCloseGrey = Color(0xFF64748B);
const Color _kBorderInput = Color(0xFFECEFF5);
const Color _kHint = Color(0xFF94A3B8);
const double _kTitleInputHeight = 48.0;

/// 与周视图卡片 [WeekViewEventCard] 左侧照片区 `_photoW`:`_photoH` 一致（100:133）。
const double _kEventPhotoBoxWidth = 100;
const double _kEventPhotoBoxHeight = 133;
const List<BoxShadow> _kInputShadow = [
  BoxShadow(color: Color(0x0D111827), blurRadius: 20, offset: Offset(0, 8)),
];

/// 供添加事件流程在 `Navigator.pop` 之后调用（需传入仍挂载的页面 context，例如 Navigator 的 context）。
void showShareSheetAfterEventAdd(
  BuildContext parentContext,
  ListEvent event,
) {
  showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(parentContext).height * 0.90,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: ShareEventSheet(
          parentContext: parentContext,
          event: event,
          onShareComplete: () => EventShareService.revision.value++,
        ),
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
  final FocusNode _titleFocusNode = FocusNode();

  String _selectedTagId = '';
  List<ReminderTag> _availableTags = [];
  bool _pinned = false;
  bool _solarMode = true;

  DateTime _solarDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  late int _lunarYear;
  late int _lunarMonthSigned;
  late int _lunarDay;
  int? leapMonthPreference;

  EventRepeatRule _repeat = EventRepeatRule.yearly;
  EventType _eventType = EventType.generic;
  EventReminderType _reminder = EventReminderType.advanceAndSameDay;
  EventAdvanceDaysOption _advanceDays = EventAdvanceDaysOption.oneDay;

  TimeOfDay _advanceTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _sameDayTime = const TimeOfDay(hour: 9, minute: 0);

  bool _shareEnabled = false;

  MembershipTier _membershipTier = MembershipTier.free;

  String? _eventPhotoPath;
  bool _hasAutoFocused = false;

  bool get _isEditMode => widget.initialEvent != null;

  bool get _showLeapMonthPreference => !_solarMode && _lunarMonthSigned < 0;

  bool get _hasEventPhoto =>
      _eventPhotoPath != null && _eventPhotoPath!.isNotEmpty;

  Future<void> _pickAndCropPhoto() async {
    final tier = await MembershipService.currentTier();
    if (!mounted) return;
    final limit = MembershipService.benefits(tier).photosPerEvent;
    setState(() {
      _membershipTier = tier;
    });
    if (limit <= 0) {
      await showMembershipSoftPaywall(
        context,
        title: '上传照片',
        message: '照片上传是会员功能，升级基础版即可使用',
        primaryLabel: '升级会员',
        onTierChanged: _reloadMembershipTier,
      );
      return;
    }
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法访问相册，请在系统设置中开启权限')),
      );
      return;
    }
    if (!mounted) return;
    if (file == null) {
      FocusScope.of(context).unfocus();
      return;
    }

    final croppedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PhotoCropPage(sourcePath: file!.path),
      ),
    );
    if (!mounted) return;
    if (croppedPath == null) {
      FocusScope.of(context).unfocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _eventPhotoPath = croppedPath);
  }

  Future<void> _showPhotoReplaceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 48,
                  child: ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('重新选择', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndCropPhoto();
                    },
                  ),
                ),
                const Divider(height: 1),
                SizedBox(
                  height: 48,
                  child: ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      '删除照片',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (mounted) FocusScope.of(context).unfocus();
                      setState(() => _eventPhotoPath = null);
                    },
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListTile(
                    title: const Text(
                      '取消',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: _kCloseGrey),
                    ),
                    onTap: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<String?> _persistEventPhoto(String eventId, String? sourcePath) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final root = await getApplicationDocumentsDirectory();
    final photosDir = '${root.path}/photos';
    if (sourcePath.startsWith(photosDir)) return sourcePath;

    final dir = Directory(photosDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final batch = DateTime.now().microsecondsSinceEpoch;
    final destPath = '${dir.path}/${batch}_$eventId.jpg';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  Widget _eventPhotoBox({required Widget child}) {
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: _kEventPhotoBoxWidth,
        height: _kEventPhotoBoxHeight,
        child: child,
      ),
    );
  }

  Widget _buildPhotoAddEntry({required VoidCallback onTap}) {
    return _eventPhotoBox(
      child: CustomPaint(
        painter: _DashedRectPainter(color: const Color(0xFFE2E8F0)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, size: 24, color: _kHint),
              SizedBox(height: 8),
              Text('添加照片', style: TextStyle(fontSize: 14, color: _kHint)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return _eventPhotoBox(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.antiAlias,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _showPhotoReplaceSheet,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_eventPhotoPath!),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: GestureDetector(
              onTap: _showPhotoReplaceSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '更换',
                  style: TextStyle(color: _kThemeBlue, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '上传照片',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kTitleColor),
        ),
        const SizedBox(height: 10),
        if (_hasEventPhoto)
          _buildPhotoPreview()
        else
          _buildPhotoAddEntry(onTap: _pickAndCropPhoto),
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
      _noteCtrl.text = initial.note ?? '';
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
      _eventType = initial.eventType;
      _reminder = initial.reminderType;
      _advanceDays = initial.advanceDaysOption;
      _advanceTime = _parseTimeHm(initial.advanceTimeHm, fallbackTime);
      _sameDayTime = _parseTimeHm(initial.sameDayTimeHm, fallbackTime);
      _shareEnabled = initial.pendingShareAfterAdd;
      _eventPhotoPath = initial.photoPaths.isNotEmpty ? initial.photoPaths.first : null;
      leapMonthPreference = initial.leapMonthPreference;
    } else {
      _selectedTagId = widget.initialTagId ?? '';
      final lunar = Lunar.fromDate(_solarDate);
      _lunarYear = lunar.getYear();
      _lunarMonthSigned = lunar.getMonth();
      _lunarDay = lunar.getDay();
      if (_repeat == EventRepeatRule.yearly) {
        _eventType = EventType.birthday;
      }
    }
    _syncLeapMonthPreference();
    _titleCtrl.addListener(() => setState(() {}));
    MembershipService.currentTier().then((t) {
      if (mounted) {
        setState(() {
          _membershipTier = t;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasAutoFocused) return;
      _titleFocusNode.requestFocus();
      _hasAutoFocused = true;
    });
  }

  Future<void> _reloadMembershipTier() async {
    final t = await MembershipService.currentTier();
    if (mounted) {
      setState(() {
        _membershipTier = t;
      });
    }
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
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

  Widget _leapMonthPreferencePill(String label, int value) {
    final isSelected = leapMonthPreference == value;
    return GestureDetector(
      onTap: () => setState(() => leapMonthPreference = value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              color: isSelected ? const Color(0xFFFFFFFF) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeapMonthPreferenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '闰月生日提醒方式',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _leapMonthPreferencePill('平年正常月，闰年闰月', 0),
            _leapMonthPreferencePill('只在正常月过', 1),
            _leapMonthPreferencePill('闰年正、闰月都过', 2),
          ],
        ),
      ],
    );
  }

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
            if (mounted) FocusScope.of(context).unfocus();
            setState(() => _solarDate = picked);
            _syncLunarFromSolar(_solarDate);
            Navigator.pop(ctx);
          },
        );
      },
    );
    if (mounted) FocusScope.of(context).unfocus();
  }

  void _syncLunarFromSolar(DateTime d) {
    final lunar = Lunar.fromDate(d);
    _lunarYear = lunar.getYear();
    _lunarMonthSigned = lunar.getMonth();
    _lunarDay = lunar.getDay();
  }

  void _syncLeapMonthPreference() {
    if (_solarMode || _lunarMonthSigned >= 0) {
      leapMonthPreference = null;
    } else {
      leapMonthPreference ??= 0;
    }
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
            if (mounted) FocusScope.of(context).unfocus();
            setState(() {
              _lunarYear = year;
              _lunarMonthSigned = monthSigned;
              _lunarDay = dayLunar;
              final lunar = Lunar.fromYmd(year, monthSigned, dayLunar);
              final s = lunar.getSolar();
              _solarDate = DateTime(s.getYear(), s.getMonth(), s.getDay());
              _syncLeapMonthPreference();
            });
            Navigator.pop(ctx);
          },
        );
      },
    );
    if (mounted) FocusScope.of(context).unfocus();
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
            if (mounted) FocusScope.of(context).unfocus();
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
    if (mounted) FocusScope.of(context).unfocus();
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

    String? persistedPhotoPath;
    try {
      persistedPhotoPath = await _persistEventPhoto(eventId, _eventPhotoPath);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片保存失败，请重试')),
      );
      return;
    }

    final photoPaths =
        persistedPhotoPath != null ? [persistedPhotoPath] : <String>[];
    final noteRaw = _noteCtrl.text.trim();
    final note = noteRaw.isEmpty ? null : noteRaw;

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
      note: note,
      leapMonthPreference: _showLeapMonthPreference ? leapMonthPreference : null,
      eventType: _eventType,
      lastModifiedByName: initial?.lastModifiedByName,
      lastModifiedAt: initial?.lastModifiedAt,
      historicalPartnerName: initial?.historicalPartnerName,
      isShareIncoming: initial?.isShareIncoming ?? false,
      sharedFromUserId: initial?.sharedFromUserId,
      sharedFromUserName: initial?.sharedFromUserName,
      sharedFromUserPhone: initial?.sharedFromUserPhone,
      sharedAt: initial?.sharedAt,
      sharedSourceEventId: initial?.sharedSourceEventId,
      ownerPhone: initial?.ownerPhone ?? UserSession.instance.phone,
    );
    nav.pop(event);
    if (_shareEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navCtx.mounted) showShareSheetAfterEventAdd(navCtx, event);
      });
    }
  }

  bool get _showAdvance =>
      _reminder == EventReminderType.advanceAndSameDay || _reminder == EventReminderType.advanceOnly;

  bool get _showSameDay =>
      _reminder == EventReminderType.advanceAndSameDay || _reminder == EventReminderType.sameDayOnly;

  static const double _eventAddTagIconSize = 48;
  static const double _eventAddTagSlotSize = 56;

  Widget _eventAddTagIconSlot({required bool selected, required Widget icon}) {
    return Container(
      width: _eventAddTagSlotSize,
      height: _eventAddTagSlotSize,
      alignment: Alignment.center,
      decoration: selected
          ? BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFAFBFC),
              border: Border.all(color: const Color(0xFF1A73E8), width: 2),
            )
          : null,
      child: icon,
    );
  }

  Widget _eventAddTagPickerItem(ReminderTag tag) {
    final selected = _selectedTagId == tag.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            _selectedTagId = '';
          } else {
            _selectedTagId = tag.id;
            _applyTypeDefaults(tag.id);
          }
        });
      },
      onLongPress: () => _openEditTagSheet(tag),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _eventAddTagSlotSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _eventAddTagIconSlot(
              selected: selected,
              icon: TagCircleWidget(
                tag: tag,
                size: _eventAddTagIconSize,
                showLabel: false,
                isSelected: false,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tag.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? const Color(0xFF1A73E8)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _eventFieldDecoration(String hintText) {
    const radius = BorderRadius.all(Radius.circular(18));
    const enabledSide = BorderSide(color: Color(0xFFF1F5F9), width: 1.0);
    const focusedSide = BorderSide(color: Color(0xFF1A73E8), width: 1.5);
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintText: hintText,
      hintStyle: const TextStyle(color: _kHint, fontSize: 16),
      border: const OutlineInputBorder(borderRadius: radius, borderSide: enabledSide),
      enabledBorder: const OutlineInputBorder(borderRadius: radius, borderSide: enabledSide),
      focusedBorder: const OutlineInputBorder(borderRadius: radius, borderSide: focusedSide),
    );
  }

  Widget _labeledInputRow({
    required String label,
    required TextEditingController controller,
    required String hintText,
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
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              boxShadow: _kInputShadow,
            ),
            child: TextField(
              controller: controller,
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 16, height: 1.25, color: _kTitleColor),
              decoration: _eventFieldDecoration(hintText),
            ),
          ),
        ),
      ],
    );
  }

  Widget _titleInputRowWithPin() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 60,
          child: Text(
            '标题',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Container(
              height: _kTitleInputHeight,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(18)),
                boxShadow: _kInputShadow,
              ),
              child: TextField(
                controller: _titleCtrl,
                focusNode: _titleFocusNode,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                onTapOutside: (_) => _titleFocusNode.unfocus(),
                style: const TextStyle(fontSize: 16, height: 1.25, color: _kTitleColor),
                decoration: _eventFieldDecoration('输入事件标题…').copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _pinned = !_pinned),
          behavior: HitTestBehavior.opaque,
          child: SvgPicture.asset(
            'assets/images/ic_star.svg',
            width: _kTitleInputHeight,
            height: _kTitleInputHeight,
            fit: BoxFit.contain,
            colorFilter: _pinned
                ? null
                : const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const buttonHeight = 56.0;
    const scrollBottomPadding = 24.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      bottomNavigationBar: ColoredBox(
        color: const Color(0xFFFAFBFC),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Opacity(
              opacity: _canSave ? 1 : 0.5,
              child: SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kThemeBlue,
                    disabledBackgroundColor: _kHint,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _canSave ? () => _submit() : null,
                  child: Text(
                    _isEditMode
                        ? '保存修改'
                        : (_shareEnabled ? '保存并分享' : '添加提醒'),
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
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
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
                    '添加提醒',
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, scrollBottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 84,
                      child: SingleChildScrollView(
                        clipBehavior: Clip.none,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final tag in _availableTags) ...[
                              _eventAddTagPickerItem(tag),
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
                    Container(height: 1, color: const Color(0xFFF1F5F9)),
                    const SizedBox(height: 16),
                    _titleInputRowWithPin(),
                    const SizedBox(height: 8),
                    _labeledInputRow(
                      label: '备注',
                      controller: _noteCtrl,
                      hintText: '添加备注…',
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
                              _syncLeapMonthPreference();
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
                                _syncLeapMonthPreference();
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
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _showLeapMonthPreference
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                _buildLeapMonthPreferenceSection(),
                                const SizedBox(height: 16),
                              ],
                            )
                          : const SizedBox(height: 12),
                    ),
                    Wrap(
                      direction: Axis.horizontal,
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        _optionPill('不重复', _repeat == EventRepeatRule.none, () => setState(() {
                          _repeat = EventRepeatRule.none;
                          _eventType = EventType.generic;
                        })),
                        _optionPill('每天', _repeat == EventRepeatRule.daily, () => setState(() {
                          _repeat = EventRepeatRule.daily;
                          _eventType = EventType.generic;
                        })),
                        _optionPill('每周', _repeat == EventRepeatRule.weekly, () => setState(() {
                          _repeat = EventRepeatRule.weekly;
                          _eventType = EventType.generic;
                        })),
                        _optionPill('每月', _repeat == EventRepeatRule.monthly, () => setState(() {
                          _repeat = EventRepeatRule.monthly;
                          _eventType = EventType.generic;
                        })),
                        _optionPill('每年', _repeat == EventRepeatRule.yearly, () => setState(() {
                          _repeat = EventRepeatRule.yearly;
                          _eventType = EventType.birthday;
                          _syncLeapMonthPreference();
                        })),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_repeat == EventRepeatRule.yearly)
                      SizedBox(
                        height: 40,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _sectionIconTitle(icon: Icons.notifications_none_outlined, title: '提醒策略'),
                            const Spacer(),
                            const Text(
                              '标记为生日',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kTitleColor),
                            ),
                            const SizedBox(width: 8),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch.adaptive(
                                value: _eventType == EventType.birthday,
                                onChanged: (v) => setState(() => _eventType = v ? EventType.birthday : EventType.generic),
                                thumbColor: WidgetStateProperty.resolveWith(
                                  (s) => s.contains(WidgetState.selected) ? Colors.white : null,
                                ),
                                trackColor: WidgetStateProperty.resolveWith(
                                  (s) => s.contains(WidgetState.selected) ? _kThemeBlue : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
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
                  ],
                ),
              ),
            ),
          ],
        ),
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
  return SizedBox(
    height: 40,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
    ),
  );
}
