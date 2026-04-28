import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/services/user_session.dart';
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
  static final _phoneMobile = RegExp(r'^1[3-9]\d{9}$');

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  /// 为 `true` 时底部显示 [NumericKeypad]（与切换账号页一致），系统 IME 不用于手机号。
  bool _phoneKeypadOpen = false;

  final List<ShareContact> _contacts = [];
  String? _partnerPhone;
  bool _partnerAutoShare = true;
  bool _acceptOthers = true;
  bool _loaded = false;

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
    _reconcilePartner();
    if (mounted) {
      setState(() => _loaded = true);
    }
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

  Future<void> _onAdd() async {
    if (!_canAdd) return;
    final name = _nameController.text.trim();
    final phone = _digitsOnly(_phoneController.text);
    if (!_phoneMobile.hasMatch(phone)) {
      _toast('请输入正确的 11 位手机号');
      return;
    }
    if (_contacts.any((c) => c.phone == phone)) {
      _toast('该手机号已在列表中');
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
    });
    if (turnOffAuto) {
      await UserSession.instance.setAutoShareEnabled(false);
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

  Future<void> _onPartnerAutoChanged(bool v) async {
    if (v) {
      if (_partnerPhone == null || _contacts.isEmpty) {
        _toast('请先选择伴侣共享联系人');
        return;
      }
      setState(() => _partnerAutoShare = true);
    } else {
      setState(() => _partnerAutoShare = false);
    }
    await UserSession.instance.setAutoShareEnabled(_partnerAutoShare);
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
                      onDelete: () => _removeContact(c),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildCoupleSection(context, cs, textTheme),
                const SizedBox(height: 20),
                _sectionTitle(context, '共享通用设置'),
                const SizedBox(height: 16),
                _buildAcceptOthersCard(cs, textTheme),
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
              hint: '输入称呼（如：小李）',
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

  String? get _validPartnerValue {
    if (_partnerPhone == null) return null;
    if (!_contacts.any((c) => c.phone == _partnerPhone)) return null;
    return _partnerPhone;
  }

  Widget _buildCoupleSection(
    BuildContext context,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
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
              '伴侣类事件共享',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '伴侣共享联系人',
                style: textTheme.bodyLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _validPartnerValue, // ignore: deprecated_member_use
                isExpanded: true,
                items: _contacts
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.phone,
                        child: Text(
                          '${c.name}(${c.phone})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _contacts.isEmpty
                    ? null
                    : (v) {
                        setState(() => _partnerPhone = v);
                        _persistLocal();
                      },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outline, width: 0.7),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: const Color(0xFF89888D).withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 1),
                  ),
                ),
                hint: Text(
                  _contacts.isEmpty ? '请先添加常用共享联系人' : '请选择',
                  style: textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
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
                          '伴侣类事件变动时自动同步给对方',
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
        ),
      ],
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
            ),
          ],
        ),
      ),
    );
  }
}

class ShareContact {
  ShareContact({required this.name, required this.phone});

  final String name;
  final String phone;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory ShareContact.fromJson(Map<String, dynamic> m) {
    final phoneRaw = m['phone'];
    final phoneStr = phoneRaw is int
        ? '$phoneRaw'
        : (phoneRaw as String? ?? '');
    return ShareContact(
      name: m['name']?.toString() ?? '',
      phone: phoneStr,
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.colorScheme,
    required this.textTheme,
    required this.onDelete,
  });

  final ShareContact contact;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
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
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/images/ic_avatar.svg',
                width: 16,
                height: 16,
                fit: BoxFit.contain,
              ),
            ),
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
