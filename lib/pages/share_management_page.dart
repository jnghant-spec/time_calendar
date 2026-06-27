import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/event_share_record.dart';
import 'package:time_calendar/models/partner_relation.dart';
import 'package:time_calendar/models/share_contact.dart';
import 'package:time_calendar/services/event_service.dart';
import 'package:time_calendar/services/event_share_service.dart';
import 'package:time_calendar/services/tag_bar_state.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/utils/debug_account_switch.dart';
import 'package:time_calendar/widgets/incoming_share_banner.dart';
import 'package:time_calendar/widgets/numeric_keypad.dart';

/// 共享管理：常用联系人、伴侣类事件共享、接受他人共享。
class ShareManagementPage extends StatefulWidget {
  const ShareManagementPage({super.key});

  @override
  State<ShareManagementPage> createState() => _ShareManagementPageState();
}

class _ShareManagementPageState extends State<ShareManagementPage> {
  static const _kPrefsContacts = 'tc.share_management.contacts_v1';
  static const _kPrefsPartnerPhone = 'tc.share_management.partner_phone';

  static const _pageBg = Color(0xFFFAFBFC);
  static const _coupleCardBg = Color(0xFFFDF2F8);
  static const _tipBg = Color(0xFFFCE7F3);
  static const _tipText = Color(0xFFEC4899);
  static const _themeBlue = Color(0xFF1A73E8);
  static const _errorRed = Color(0xFFEF4444);
  static const _switchInactiveTrack = Color(0xFFE5E7EB);
  static const _mutedGrey = Color(0xFF9CA3AF);
  static const _titleGrey = Color(0xFF1F2937);
  static final _phoneMobile = RegExp(r'^1[3-9]\d{9}$');
  static const _kAvatarColors = <int>[
    0xFF8B5CF6,
    0xFFF59E0B,
    0xFFEF4444,
    0xFF10B981,
    0xFF06B6D4,
    0xFFEC4899,
    0xFF6366F1,
    0xFF14B8A6,
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  /// 为 `true` 时底部显示 [NumericKeypad]（与切换账号页一致），系统 IME 不用于手机号。
  bool _phoneKeypadOpen = false;

  final List<ShareContact> _contacts = [];
  PartnerRelation _partnerRelation =
      const PartnerRelation(status: PartnerStatus.none);
  String? _partnerPhone;
  bool _partnerAutoShare = true;
  bool _acceptOthers = true;
  bool _loaded = false;
  bool _debugToolsExpanded = false;
  List<IncomingSharePayload> _pendingIncoming = const [];
  bool _pendingExpanded = false;

  bool get _canAdd {
    return _nameController.text.trim().isNotEmpty &&
        _phoneMobile.hasMatch(_digitsOnly(_phoneController.text));
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFormChanged);
    _phoneController.addListener(_onFormChanged);
    _nameFocusNode.addListener(_onNameFocusChange);
    _bootstrap();
  }

  void _onNameFocusChange() {
    if (_nameFocusNode.hasFocus && _phoneKeypadOpen) {
      setState(() => _phoneKeypadOpen = false);
    }
  }

  void _onFormChanged() => setState(() {});

  void _activatePhoneInput() {
    _nameFocusNode.unfocus();
    setState(() => _phoneKeypadOpen = true);
    _phoneFocusNode.requestFocus();
  }

  void _dismissAllKeyboards() {
    FocusScope.of(context).unfocus();
    if (_phoneKeypadOpen) {
      setState(() => _phoneKeypadOpen = false);
    }
  }

  void _handleKeypadNumber(String digit) {
    if (!_phoneKeypadOpen) {
      return;
    }
    if (_phoneController.text.length >= 11) {
      return;
    }
    setState(() {
      _phoneController.text = '${_phoneController.text}$digit';
    });
    _phoneController.selection = TextSelection.collapsed(
      offset: _phoneController.text.length,
    );
  }

  void _handleKeypadDelete() {
    if (!_phoneKeypadOpen) {
      return;
    }
    if (_phoneController.text.isEmpty) {
      return;
    }
    setState(() {
      _phoneController.text = _phoneController.text.substring(
        0,
        _phoneController.text.length - 1,
      );
    });
    _phoneController.selection = TextSelection.collapsed(
      offset: _phoneController.text.length,
    );
  }

  Future<void> _bootstrap() async {
    await UserSession.instance.ensureInitialized();
    await TagService.loadTags();
    _partnerAutoShare = UserSession.instance.autoShareEnabled;
    _acceptOthers = UserSession.instance.acceptOthersShareDefault;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPrefsContacts);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            _contacts.add(ShareContact.fromJson(e));
          } else if (e is Map) {
            _contacts.add(
              ShareContact.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ),
            );
          }
        }
      } catch (_) {}
    }
    _partnerPhone = p.getString(_kPrefsPartnerPhone);
    _partnerRelation = TagService.getPartnerRelation();
    _syncPartnerPhoneFromRelation();
    _reconcilePartner();
    await _reloadPendingIncoming();
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  Future<void> _reloadPendingIncoming() async {
    final pending = await EventShareService.getPendingForShareManagement();
    if (!mounted) return;
    setState(() {
      _pendingIncoming = List<IncomingSharePayload>.from(pending)
        ..sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
      if (_pendingIncoming.length <= 1) {
        _pendingExpanded = false;
      }
    });
  }

  Future<void> _acceptPendingIncoming(IncomingSharePayload payload) async {
    final event = await EventShareService.acceptIncoming(payload.id);
    if (!mounted) return;
    if (event != null) {
      await TagBarState().loadTags();
      EventShareService.revision.value++;
    }
    await _reloadPendingIncoming();
    if (!mounted) return;
    _toast(event != null ? '已接受「${payload.eventSnapshot.title}」' : '接受失败');
  }

  Future<void> _dismissPendingIncoming(IncomingSharePayload payload) async {
    final ok = await EventShareService.dismissIncoming(payload.id);
    if (!mounted) return;
    if (ok) EventShareService.revision.value++;
    await _reloadPendingIncoming();
    if (!mounted) return;
    _toast(ok ? '已忽略' : '操作失败');
  }

  void _syncPartnerPhoneFromRelation() {
    final id = _partnerRelation.partnerContactId;
    if (_partnerRelation.status == PartnerStatus.none || id == null) {
      return;
    }
    _partnerPhone = id;
  }

  void _reconcilePartner() {
    if (_partnerPhone == null) return;
    final exists = _contacts.any((c) => c.phone == _partnerPhone);
    if (!exists) {
      _partnerPhone = null;
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _phoneController.removeListener(_onFormChanged);
    _nameFocusNode.removeListener(_onNameFocusChange);
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<void> _persistLocal() async {
    final p = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_contacts.map((e) => e.toJson()).toList());
    await p.setString(_kPrefsContacts, encoded);
    if (_partnerPhone == null) {
      await p.remove(_kPrefsPartnerPhone);
    } else {
      await p.setString(_kPrefsPartnerPhone, _partnerPhone!);
    }
  }

  /// TODO(后端): 常用共享联系人 — 按手机号查询 App 注册用户
  /// - 接口：GET /users/lookup?phone=xxx（或等价）
  /// - 返回：{ registered: bool, avatarUrl?: string, nickname?: string }
  /// - 添加联系人后静默查询；已注册展示服务端头像，未注册展示「未注册」小标签（非短信）
  /// - 不在「添加联系人」时发送短信；短信/邀请仅在「首次分享提醒」或「亲密关系邀请」时触发
  /// - 需扩展 ShareContact：registered、avatarUrl（本地缓存 + JSON 持久化）
  /// - 关联：share_event_sheet.dart 分享结果页 App内/短信；_attemptPartnerInviteOrSync 伴侣邀请短信
  Future<void> _onAdd() async {
    if (!_canAdd) return;
    final name = _nameController.text.trim();
    final phone = _digitsOnly(_phoneController.text);
    if (!_phoneMobile.hasMatch(phone)) {
      _toast('请输入正确的 11 位手机号');
      return;
    }
    if (_contacts.any((c) => c.phone == phone)) {
      _toast('该联系人已存在');
      return;
    }
    if (_contacts.any((c) => c.name.trim() == name.trim())) {
      _toast('该称呼已存在');
      return;
    }
    setState(() {
      _contacts.insert(0, ShareContact(name: name, phone: phone));
      _partnerPhone ??= phone;
      _reconcilePartner();
      _nameController.clear();
      _phoneController.clear();
    });
    _dismissAllKeyboards();
    await _persistLocal();
  }

  Future<void> _removeContact(ShareContact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('删除联系人'),
          content: Text('确定删除联系人【${c.name}】？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    final shouldResetPartner =
        _partnerRelation.partnerContactId == c.phone &&
        _partnerRelation.status != PartnerStatus.none;
    if (shouldResetPartner) {
      await _archivePartnerNameToEvents();
    }
    var turnOffAuto = false;
    setState(() {
      _contacts.removeWhere((e) => e.phone == c.phone);
      if (_partnerPhone == c.phone) {
        _partnerPhone = null;
        if (_partnerAutoShare) {
          _partnerAutoShare = false;
          turnOffAuto = true;
        }
      }
      if (_partnerRelation.partnerContactId == c.phone &&
          _partnerRelation.status != PartnerStatus.none) {
        _partnerRelation = const PartnerRelation(status: PartnerStatus.none);
      }
    });
    if (turnOffAuto) {
      await UserSession.instance.setAutoShareEnabled(false);
    }
    if (_partnerRelation.status == PartnerStatus.none &&
        TagService.getPartnerRelation().status != PartnerStatus.none) {
      await TagService.setPartnerRelation(
        const PartnerRelation(status: PartnerStatus.none),
      );
    }
    await _persistLocal();
  }

  Future<void> _onPickFromContacts() async {
    if (!_canUseNativeContacts) {
      _toast('当前环境不支持通讯录选择');
      return;
    }
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      _toast('需要通讯录权限才能选择联系人');
      return;
    }
    try {
      final id = await FlutterContacts.native.showPicker();
      if (id == null || !mounted) return;
      final contact = await FlutterContacts.get(
        id,
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      if (contact == null) return;
      final name = (contact.displayName?.trim().isNotEmpty ?? false)
          ? contact.displayName!.trim()
          : '联系人';
      if (contact.phones.isEmpty) {
        _toast('该联系人没有电话号码');
        return;
      }
      var digits = _digitsOnly(contact.phones.first.number);
      if (digits.length == 11 && _phoneMobile.hasMatch(digits)) {
        // ok
      } else if (digits.length > 11) {
        digits = digits.substring(digits.length - 11);
        if (!_phoneMobile.hasMatch(digits)) {
          _toast('未识别到有效手机号');
          return;
        }
      } else {
        _toast('未识别到有效手机号');
        return;
      }
      setState(() {
        _nameController.text = name;
        _phoneController.text = digits;
      });
      _dismissAllKeyboards();
    } catch (e) {
      if (mounted) {
        _toast('打开通讯录失败');
      }
    }
  }

  bool get _canUseNativeContacts {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _debugSetPartnerStatus(PartnerStatus status) async {
    final current = _partnerRelation;
    await TagService.setPartnerRelation(
      PartnerRelation(
        status: status,
        partnerContactId: current.partnerContactId,
        partnerName: current.partnerName,
      ),
    );
    if (!mounted) return;
    setState(() {
      _partnerRelation = TagService.getPartnerRelation();
      _syncPartnerPhoneFromRelation();
      _reconcilePartner();
    });
  }

  Future<void> _debugClearAllContacts() async {
    await ShareContact.clearAllContacts();
    if (!mounted) return;
    setState(() {
      _contacts.clear();
      _reconcilePartner();
    });
    await _persistLocal();
  }

  Future<void> _debugSwitchToLaowang() async {
    if (!kDebugMode) return;
    final label = await DebugAccountSwitch.switchToLaowang(_contacts);
    if (!mounted) return;
    await _reloadPendingIncoming();
    if (!mounted) return;
    _toast('已模拟切换为 $label');
  }

  Future<void> _debugSwitchToUserA() async {
    if (!kDebugMode) return;
    final label = await DebugAccountSwitch.switchToUserA();
    if (!mounted) return;
    await _reloadPendingIncoming();
    if (!mounted) return;
    _toast('已切回 $label');
  }

  Widget _debugToolButton(String label, Future<void> Function() onTap) {
    return SizedBox(
      height: 36,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => onTap(),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _titleGrey,
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildDebugTestTools() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        InkWell(
          onTap: () => setState(() => _debugToolsExpanded = !_debugToolsExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Text(
                  '测试工具',
                  style: TextStyle(
                    fontSize: 14,
                    color: _mutedGrey,
                  ),
                ),
                const Spacer(),
                Icon(
                  _debugToolsExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: _mutedGrey,
                ),
              ],
            ),
          ),
        ),
        if (_debugToolsExpanded) ...[
          const SizedBox(height: 8),
          _debugToolButton(
            '设为 none（无关系）',
            () => _debugSetPartnerStatus(PartnerStatus.none),
          ),
          const SizedBox(height: 8),
          _debugToolButton(
            '设为 pending（等待中）',
            () => _debugSetPartnerStatus(PartnerStatus.pending),
          ),
          const SizedBox(height: 8),
          _debugToolButton(
            '设为 accepted（已接受）',
            () => _debugSetPartnerStatus(PartnerStatus.accepted),
          ),
          const SizedBox(height: 8),
          _debugToolButton(
            '设为 rejected（已拒绝）',
            () => _debugSetPartnerStatus(PartnerStatus.rejected),
          ),
          const SizedBox(height: 8),
          _debugToolButton('清空所有联系人', _debugClearAllContacts),
          const SizedBox(height: 8),
          _debugToolButton('模拟切换为：老王', _debugSwitchToLaowang),
          const SizedBox(height: 8),
          _debugToolButton(
            '切回用户 A（${DebugAccountSwitch.userAPhone}）',
            _debugSwitchToUserA,
          ),
        ],
      ],
    );
  }

  /// TODO(后端): 发送伴侣邀请短信或同步推送。
  Future<bool> _attemptPartnerInviteOrSync() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return true;
  }

  Future<void> _retryPartnerSync() async {
    final cleared = _partnerRelation.copyWith(syncFailed: false);
    await TagService.setPartnerRelation(cleared);
    if (!mounted) return;
    setState(() => _partnerRelation = TagService.getPartnerRelation());

    final ok = await _attemptPartnerInviteOrSync();
    if (!mounted) return;
    if (ok) {
      return;
    }
    final failed = TagService.getPartnerRelation().copyWith(syncFailed: true);
    await TagService.setPartnerRelation(failed);
    if (!mounted) return;
    setState(() => _partnerRelation = TagService.getPartnerRelation());
    _toast('同步失败，请稍后重试');
  }

  Future<void> _sendPartnerInviteAfterPick(ShareContact selected) async {
    await TagService.setPartnerRelation(
      PartnerRelation(
        status: PartnerStatus.pending,
        partnerContactId: selected.phone,
        partnerName: selected.name,
        syncFailed: false,
      ),
    );
    if (!mounted) return;
    setState(() {
      _partnerRelation = TagService.getPartnerRelation();
      _partnerPhone = selected.phone;
    });
    await _persistLocal();

    final ok = await _attemptPartnerInviteOrSync();
    if (!mounted) return;
    if (!ok) {
      final failed = TagService.getPartnerRelation().copyWith(syncFailed: true);
      await TagService.setPartnerRelation(failed);
      if (!mounted) return;
      setState(() => _partnerRelation = TagService.getPartnerRelation());
    }
  }

  String? _resolvedPartnerNameForArchive() {
    final fromRelation = _partnerRelation.partnerName?.trim();
    if (fromRelation != null && fromRelation.isNotEmpty) return fromRelation;

    final fromBound = _boundPartnerContact()?.name.trim();
    if (fromBound != null && fromBound.isNotEmpty) return fromBound;

    final phone = _partnerPhone ?? _partnerRelation.partnerContactId;
    if (phone != null && phone.isNotEmpty) {
      for (final c in _contacts) {
        if (c.phone == phone) {
          final fromContact = c.name.trim();
          if (fromContact.isNotEmpty) return fromContact;
        }
      }
    }
    return null;
  }

  Future<void> _archivePartnerNameToEvents() async {
    final currentPartnerName = _resolvedPartnerNameForArchive();
    if (currentPartnerName == null) return;

    final partnerTagIds =
        TagService.getPartnerTags().map((t) => t.id).toSet();
    if (partnerTagIds.isEmpty) return;

    final events = await EventService.loadAllEvents();
    var changed = false;
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      if (!partnerTagIds.contains(e.tagId)) continue;
      events[i] = e.copyWith(historicalPartnerName: currentPartnerName);
      changed = true;
    }
    if (changed) {
      await EventService.saveAllEvents(events);
    }
    await TagService.setLastUnboundPartnerName(currentPartnerName);
  }

  Future<void> _resetPartnerRelation() async {
    await _archivePartnerNameToEvents();
    await TagService.setPartnerRelation(
      const PartnerRelation(status: PartnerStatus.none),
    );
    var turnOffAuto = false;
    setState(() {
      _partnerRelation = TagService.getPartnerRelation();
      _partnerPhone = null;
      if (_partnerAutoShare) {
        _partnerAutoShare = false;
        turnOffAuto = true;
      }
    });
    if (turnOffAuto) {
      await UserSession.instance.setAutoShareEnabled(false);
    }
    await _persistLocal();
  }

  String _resolvedPartnerDisplayName() {
    return _resolvedPartnerNameForArchive() ?? '伴侣';
  }

  Future<void> _unbindPartnerWithFeedback() async {
    final partnerName = _resolvedPartnerDisplayName();
    await _resetPartnerRelation();
    if (!mounted) return;
    _toast('已解除与 $partnerName 的亲密关系');
  }

  Future<void> _confirmUnbindPartner() async {
    final partnerName = _resolvedPartnerDisplayName();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('解除亲密关系'),
          content: Text(
            '确定解除与「$partnerName」的亲密关系？\n\n'
            '• 将不再自动同步亲密关系类事件\n'
            '• 已有内容会保留为「曾与 $partnerName 共享」\n'
            '• $partnerName 仍会保留在常用共享联系人中',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定解除'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    await _unbindPartnerWithFeedback();
  }

  Future<void> _cancelPartnerInvite() async {
    await _resetPartnerRelation();
  }

  Future<void> _showPartnerPickerSheet() async {
    final selected = await showModalBottomSheet<ShareContact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      builder: (sheetContext) {
        return _PartnerPickerSheet(
          contacts: List<ShareContact>.unmodifiable(_contacts),
          selectedPhone: _partnerPhone,
          avatarBuilder: _buildContactAvatar,
        );
      },
    );

    if (selected == null || !mounted) return;
    if (_partnerRelation.status != PartnerStatus.none) {
      await _archivePartnerNameToEvents();
    }
    await _sendPartnerInviteAfterPick(selected);
  }

  Color _avatarColor(int index) =>
      Color(_kAvatarColors[index % _kAvatarColors.length]);

  int _colorIndexForContact(ShareContact contact) {
    final idx = _contacts.indexWhere((c) => c.phone == contact.phone);
    if (idx >= 0) return idx;
    final phone = contact.phone;
    if (phone.isEmpty) return 0;
    var hash = 0;
    for (var i = 0; i < phone.length; i++) {
      hash = (hash + phone.codeUnitAt(i)) % _kAvatarColors.length;
    }
    return hash;
  }

  Widget _buildContactAvatar(
    ShareContact contact, {
    required double size,
  }) {
    final idx = _colorIndexForContact(contact);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: size * 0.12),
      decoration: BoxDecoration(
        color: _avatarColor(idx),
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          contact.avatarText,
          style: TextStyle(
            fontSize: size * 0.33,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  ShareContact? _boundPartnerContact() {
    final phone = _partnerPhone ?? _partnerRelation.partnerContactId;
    if (phone == null || phone.isEmpty) return null;
    for (final c in _contacts) {
      if (c.phone == phone) return c;
    }
    return ShareContact(
      name: _partnerRelation.partnerName ?? '',
      phone: phone,
    );
  }

  Future<void> _onPartnerAutoChanged(bool v) async {
    if (v) {
      if (_partnerRelation.status != PartnerStatus.accepted ||
          _partnerPhone == null) {
        _toast('请先建立伴侣关系');
        return;
      }
      setState(() => _partnerAutoShare = true);
    } else {
      setState(() => _partnerAutoShare = false);
    }
    await UserSession.instance.setAutoShareEnabled(_partnerAutoShare);
    if (!mounted) return;
    final name = _partnerRelation.partnerName?.trim().isNotEmpty == true
        ? _partnerRelation.partnerName!.trim()
        : '另一半';
    if (_partnerAutoShare) {
      _toast('已开启实时同步，后续修改将自动推送');
    } else {
      _toast('已关闭实时同步，$name 不会自动收到你的修改');
    }
  }

  Future<void> _onAcceptOthersChanged(bool v) async {
    setState(() => _acceptOthers = v);
    await UserSession.instance.setAcceptOthersShareDefault(v);
    // TODO(后端): 同步「接受他人共享」
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.04;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final h = MediaQuery.sizeOf(context).height;
    final vBlock = h * 0.02;
    final keypadExtra =
        _phoneKeypadOpen ? (vBlock * 0.2).clamp(4.0, 8.0) : 0.0;

    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: cs.surfaceContainerHigh,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: cs.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _pageBg,
        resizeToAvoidBottomInset: !_phoneKeypadOpen,
        appBar: AppBar(
          backgroundColor: cs.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '返回',
          ),
          title: Text(
            '共享管理',
            style: textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 0.7, color: cs.outline),
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _dismissAllKeyboards,
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                hPad,
                20,
                hPad,
                24 + viewInsets.bottom + keypadExtra,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                _buildPartnerRelationSection(context, cs, textTheme),
                if (kDebugMode) _buildDebugTestTools(),
                const SizedBox(height: 20),
                _sectionTitle(context, '常用共享联系人'),
                const SizedBox(height: 16),
                _buildAddArea(cs, textTheme),
                if (_contacts.isNotEmpty) const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _contacts.length,
                  separatorBuilder: (context, _) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = _contacts[i];
                    return _ContactRow(
                      contact: c,
                      colorScheme: cs,
                      textTheme: textTheme,
                      avatarBuilder: _buildContactAvatar,
                      onDelete: () => _removeContact(c),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _sectionTitle(context, '共享通用设置'),
                const SizedBox(height: 16),
                _buildAcceptOthersCard(cs, textTheme),
                _buildPendingIncomingSection(cs),
              ],
            ),
            ),
          ),
        ),
        bottomNavigationBar: _phoneKeypadOpen
            ? NumericKeypad(
                onNumberTap: _handleKeypadNumber,
                onDelete: _handleKeypadDelete,
                onComplete: _dismissAllKeyboards,
              )
            : null,
      ),
    );
  }

  /// 与「伴侣类事件共享」行内标题同一套字号，避免与设计稿层级不一致。
  TextStyle _sectionTitleTextStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.titleMedium;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: cs.onSurface,
      height: 1.35,
    );
  }

  Widget _sectionTitle(BuildContext context, String t) {
    return Text(t, style: _sectionTitleTextStyle(context));
  }

  Widget _buildAddArea(ColorScheme cs, TextTheme textTheme) {
    final disabled = Color.lerp(cs.primary, cs.onPrimary, 0.75)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _outlineField(
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(
              cs,
              textTheme,
              hint: '输入称呼 (如:亲爱的...)',
            ),
            style: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _outlineField(
                child: TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  readOnly: true,
                  showCursor: true,
                  maxLength: 11,
                  buildCounter:
                      (
                        BuildContext context, {
                        required int currentLength,
                        required bool isFocused,
                        required int? maxLength,
                      }) {
                    return const SizedBox.shrink();
                  },
                  decoration: _fieldDecoration(
                    cs,
                    textTheme,
                    hint: '输入手机号添加联系人',
                  ).copyWith(counterText: ''),
                  style: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
                  onTap: _activatePhoneInput,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: cs.surface,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _onPickFromContacts,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outline, width: 0.7),
                  ),
                  child: SvgPicture.asset(
                    'assets/images/ic_contacts.svg',
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(cs.primary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              height: 40,
              child: FilledButton(
                onPressed: _canAdd ? _onAdd : null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: _canAdd ? cs.primary : disabled,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '添加',
                  style: textTheme.labelLarge?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static InputDecoration _fieldDecoration(
    ColorScheme cs,
    TextTheme textTheme, {
    required String hint,
  }) {
    return InputDecoration(
      isDense: true,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintText: hint,
      hintStyle: textTheme.bodyLarge?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.4),
      ),
    );
  }

  static Widget _outlineField({required Widget child}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.7),
        ),
        child: child,
      ),
    );
  }

  Widget _buildPartnerRelationSection(
    BuildContext context,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    final relation = _partnerRelation;
    final partnerName = _resolvedPartnerDisplayName();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/images/ic_couple_hearts.svg',
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 6),
            Text(
              '亲密关系共享',
              style: _sectionTitleTextStyle(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: _coupleCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0x19EF4444),
              width: 0.7,
            ),
          ),
          child: switch (relation.status) {
            PartnerStatus.none => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _showPartnerPickerSheet,
                      style: FilledButton.styleFrom(
                        backgroundColor: _themeBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '从联系人中选择',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '设置后，亲密关系类提醒与时光集将自动同步给 TA，让 TA 实时感受到你的牵挂与陪伴。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: _mutedGrey,
                    ),
                  ),
                ],
              ),
            PartnerStatus.pending => Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '等待 $partnerName 接受邀请',
                      style: textTheme.bodyLarge?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelPartnerInvite,
                    child: Text(
                      '取消邀请',
                      style: textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            PartnerStatus.accepted => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildContactAvatar(
                        _boundPartnerContact() ??
                            ShareContact(
                              name: partnerName,
                              phone: _partnerPhone ?? '',
                            ),
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              partnerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _titleGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (_boundPartnerContact()?.maskedPhone ??
                                  ShareContact(
                                    name: '',
                                    phone: _partnerPhone ?? '',
                                  ).maskedPhone),
                              style: const TextStyle(
                                fontSize: 13,
                                color: _mutedGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _confirmUnbindPartner,
                        child: const Text(
                          '解除',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _mutedGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '自动共享',
                              style: textTheme.bodyLarge?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '亲密关系类事件变动时自动同步给另一半',
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _partnerAutoShare,
                        onChanged: _onPartnerAutoChanged,
                        activeTrackColor: cs.primary,
                        activeThumbColor: cs.onPrimary,
                        inactiveTrackColor: _switchInactiveTrack,
                        inactiveThumbColor: Colors.white,
                      ),
                    ],
                  ),
                  if (_partnerAutoShare) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _tipBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '开启后，TA 将能实时感受到你的每一份陪伴与牵挂。',
                        style: textTheme.bodySmall?.copyWith(
                          color: _tipText,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            PartnerStatus.rejected => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$partnerName 已拒绝邀请',
                    style: const TextStyle(
                      fontSize: 14,
                      color: _errorRed,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _showPartnerPickerSheet,
                      style: FilledButton.styleFrom(
                        backgroundColor: _themeBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '从联系人中选择',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          },
        ),
        if (relation.syncFailed) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _retryPartnerSync,
            behavior: HitTestBehavior.opaque,
            child: const Text(
              '同步失败，点击重试',
              style: TextStyle(
                fontSize: 12,
                color: _errorRed,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingIncomingSection(ColorScheme cs) {
    if (_pendingIncoming.isEmpty) {
      return const SizedBox.shrink();
    }

    final latest = _pendingIncoming.first;
    final rest = _pendingIncoming.length > 1
        ? _pendingIncoming.sublist(1)
        : const <IncomingSharePayload>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        _sectionTitle(context, '待处理的分享'),
        const SizedBox(height: 12),
        _buildPendingIncomingCard(latest),
        if (rest.isNotEmpty && !_pendingExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              onTap: () => setState(() => _pendingExpanded = true),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '还有 ${rest.length} 条待处理 ▼',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        if (rest.isNotEmpty && _pendingExpanded) ...[
          ...rest.map(_buildPendingIncomingCard),
          InkWell(
            onTap: () => setState(() => _pendingExpanded = false),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '收起 ▲',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingIncomingCard(IncomingSharePayload payload) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline, width: 0.7),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: IncomingShareActionPanel(
          payload: payload,
          onAccept: () => _acceptPendingIncoming(payload),
          onDismiss: () => _dismissPendingIncoming(payload),
        ),
      ),
    );
  }

  Widget _buildAcceptOthersCard(ColorScheme cs, TextTheme textTheme) {
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline, width: 0.7),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '接受他人共享',
                    style: textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '允许其他用户向你共享事件',
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _acceptOthers,
              onChanged: _onAcceptOthersChanged,
              activeTrackColor: cs.primary,
              activeThumbColor: cs.onPrimary,
              inactiveTrackColor: _switchInactiveTrack,
              inactiveThumbColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerPickerSheet extends StatefulWidget {
  const _PartnerPickerSheet({
    required this.contacts,
    required this.selectedPhone,
    required this.avatarBuilder,
  });

  final List<ShareContact> contacts;
  final String? selectedPhone;
  final Widget Function(ShareContact contact, {required double size})
      avatarBuilder;

  @override
  State<_PartnerPickerSheet> createState() => _PartnerPickerSheetState();
}

class _PartnerPickerSheetState extends State<_PartnerPickerSheet> {
  static const _themeBlue = Color(0xFF1A73E8);
  static const _mutedGrey = Color(0xFF9CA3AF);
  static const _titleGrey = Color(0xFF1F2937);

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboardAndPop([ShareContact? selected]) {
    FocusManager.instance.primaryFocus?.unfocus();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      Navigator.pop(context, selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.contacts.where((c) {
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          c.phone.contains(query);
    }).toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '选择亲密关系联系人',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _titleGrey,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _dismissKeyboardAndPop(),
                      icon: const Icon(Icons.close, color: _mutedGrey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索联系人',
                    hintStyle: TextStyle(
                      color: _mutedGrey.withValues(alpha: 0.8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 0.7,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 0.7,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: _themeBlue,
                        width: 0.7,
                      ),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: widget.contacts.isEmpty
                    ? _buildEmptyState()
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              '未找到匹配的联系人',
                              style: TextStyle(
                                fontSize: 14,
                                color: _mutedGrey,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final c = filtered[index];
                              final isSelected = widget.selectedPhone != null &&
                                  widget.selectedPhone == c.phone;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _dismissKeyboardAndPop(c),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        widget.avatarBuilder(c, size: 40),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: _titleGrey,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                c.maskedPhone,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: _mutedGrey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            size: 20,
                                            color: _themeBlue,
                                          )
                                        else
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFFE5E7EB),
                                                width: 1.5,
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
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _dismissKeyboardAndPop(),
                child: Text(
                  '取消',
                  style: TextStyle(
                    fontSize: 15,
                    color: _mutedGrey,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '暂无常用联系人，请先添加',
            style: TextStyle(fontSize: 14, color: _mutedGrey),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _dismissKeyboardAndPop(),
            child: const Text(
              '去添加联系人',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _themeBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.colorScheme,
    required this.textTheme,
    required this.avatarBuilder,
    required this.onDelete,
  });

  final ShareContact contact;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final Widget Function(ShareContact contact, {required double size})
      avatarBuilder;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.7),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // TODO(后端): 已注册时用 NetworkImage(avatarUrl)，未注册显示「未注册」标签
            avatarBuilder(contact, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.phone,
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(Icons.close, size: 20, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
