import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/share_contact.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/utils/debug_account_switch.dart';
import 'package:time_calendar/widgets/numeric_keypad.dart';

/// 输入手机号与验证码，切换登录账号（UI 全屏，返回后底栏仍停留在「我的」Tab）。
class SwitchAccountPage extends StatefulWidget {
  const SwitchAccountPage({super.key});

  @override
  State<SwitchAccountPage> createState() => _SwitchAccountPageState();
}

class _SwitchAccountPageState extends State<SwitchAccountPage> {
  static const _kPrefsContacts = 'tc.share_management.contacts_v1';

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();
  _SwitchInputTarget? _activeInputTarget;
  Timer? _countdownTimer;
  int _countdown = 0;
  List<ShareContact> _shareContacts = const [];

  String get _phone => _phoneController.text;
  String get _code => _codeController.text;

  bool get _isPhoneValid => _phone.length == 11;
  bool get _isCodeEntered => _code.length == 6;
  bool get _canSwitch => _isPhoneValid && _isCodeEntered;
  bool get _canRequestSms => _isPhoneValid && _countdown == 0;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onFieldChanged);
    _codeController.addListener(_onFieldChanged);
    if (kDebugMode) {
      _loadShareContacts();
    }
  }

  Future<void> _loadShareContacts() async {
    final contacts = <ShareContact>[];
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kPrefsContacts);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            contacts.add(ShareContact.fromJson(e));
          } else if (e is Map) {
            contacts.add(
              ShareContact.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ),
            );
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _shareContacts = contacts);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController
      ..removeListener(_onFieldChanged)
      ..dispose();
    _codeController
      ..removeListener(_onFieldChanged)
      ..dispose();
    _phoneFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _onGetCode() {
    if (!_canRequestSms) return;
    // TODO(后端): 请求短信验证码
    setState(() => _countdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _onSwitch() async {
    if (!_canSwitch) return;

    if (kDebugMode) {
      final label = await DebugAccountSwitch.switchToPhone(
        phone: _phone,
        code: _code,
        contacts: _shareContacts,
      );
      if (!mounted) return;
      if (label != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DEBUG：已切换为 $label')),
        );
        Navigator.of(context).pop(true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'DEBUG：验证码请填 ${DebugAccountSwitch.debugVerificationCode}',
          ),
        ),
      );
      return;
    }

    // TODO(后端): 调用切换账号接口
    debugPrint('切换账号: phone=$_phone, code=$_code');
  }

  Future<void> _debugQuickSwitchToLaowang() async {
    final label = await DebugAccountSwitch.switchToLaowang(_shareContacts);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('DEBUG：已切换为 $label')),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _debugQuickSwitchToUserA() async {
    final label = await DebugAccountSwitch.switchToUserA();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('DEBUG：已切回 $label')),
    );
    Navigator.of(context).pop(true);
  }

  void _activateInput(_SwitchInputTarget target) {
    setState(() {
      _activeInputTarget = target;
    });
    if (target == _SwitchInputTarget.phone) {
      _phoneFocusNode.requestFocus();
      return;
    }
    _codeFocusNode.requestFocus();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
    if (_activeInputTarget != null) {
      setState(() {
        _activeInputTarget = null;
      });
    }
  }

  void _handleNumberTap(String number) {
    if (_activeInputTarget == null) {
      return;
    }

    if (_activeInputTarget == _SwitchInputTarget.phone) {
      if (_phoneController.text.length >= 11) {
        return;
      }
      final newText = '${_phoneController.text}$number';
      final shouldSwitchToCode = newText.length == 11;
      setState(() {
        _phoneController.text = newText;
        if (shouldSwitchToCode) {
          _activeInputTarget = _SwitchInputTarget.code;
        }
      });
      _phoneController.selection = TextSelection.collapsed(
        offset: _phoneController.text.length,
      );
      if (shouldSwitchToCode) {
        _codeFocusNode.requestFocus();
      }
      return;
    }

    if (_codeController.text.length >= 6) {
      return;
    }
    setState(() {
      _codeController.text = '${_codeController.text}$number';
    });
    _codeController.selection = TextSelection.collapsed(
      offset: _codeController.text.length,
    );
    if (_codeController.text.length == 6) {
      _dismissKeyboard();
    }
  }

  void _handleDelete() {
    if (_activeInputTarget == null) {
      return;
    }

    if (_activeInputTarget == _SwitchInputTarget.phone) {
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
      return;
    }

    if (_codeController.text.isEmpty) {
      return;
    }
    setState(() {
      _codeController.text = _codeController.text.substring(
        0,
        _codeController.text.length - 1,
      );
    });
    _codeController.selection = TextSelection.collapsed(
      offset: _codeController.text.length,
    );
  }

  String _currentAccountDisplay() {
    return UserSession.instance.phone;
  }

  Widget _buildDebugQuickSwitchSection(ColorScheme cs, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'DEBUG 快捷切换',
          style: textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _debugQuickSwitchToLaowang,
          child: const Text('模拟切换为：老王'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _debugQuickSwitchToUserA,
          child: Text('切回用户 A（${DebugAccountSwitch.userAPhone}）'),
        ),
        const SizedBox(height: 8),
        Text(
          '或输入手机号 + 验证码 ${DebugAccountSwitch.debugVerificationCode}',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    final hPad = w * 0.04;
    final vBlock = h * 0.02;
    final keyboardVisible = _activeInputTarget != null;
    final disabledFill = Color.lerp(cs.primary, cs.onPrimary, 0.75)!;
    final enabledFill = cs.primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: cs.surfaceContainerHigh,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: cs.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: cs.surface,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: cs.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '返回',
          ),
          title: Text(
            '切换账号',
            style: textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: cs.outline,
            ),
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _dismissKeyboard,
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                hPad,
                vBlock,
                hPad,
                (vBlock * 0.5).clamp(12.0, 16.0) +
                    (keyboardVisible
                        ? (vBlock * 0.2).clamp(4.0, 8.0)
                        : 0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CurrentAccountCard(
                    textTheme: textTheme,
                    colorScheme: cs,
                    accountLine: _currentAccountDisplay(),
                  ),
                  SizedBox(height: (vBlock * 1.2).clamp(20.0, 28.0)),
                  if (kDebugMode) ...[
                    _buildDebugQuickSwitchSection(cs, textTheme),
                    SizedBox(height: (vBlock * 1.0).clamp(16.0, 24.0)),
                  ],
                  Text(
                    '输入要切换的手机号',
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: TextField(
                      controller: _phoneController,
                      focusNode: _phoneFocusNode,
                      readOnly: true,
                      showCursor: true,
                      maxLength: 11,
                      decoration: _inputDecoration(
                        cs: cs,
                        textTheme: textTheme,
                        hint: '请输入手机号',
                      ).copyWith(counterText: ''),
                      style: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
                      onTap: () => _activateInput(_SwitchInputTarget.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 50,
                          child: TextField(
                            controller: _codeController,
                            focusNode: _codeFocusNode,
                            readOnly: true,
                            showCursor: true,
                            maxLength: 6,
                            style: textTheme.bodyLarge?.copyWith(
                              color: cs.onSurface,
                            ),
                            decoration: _inputDecoration(
                              cs: cs,
                              textTheme: textTheme,
                              hint: '请输入验证码',
                            ).copyWith(counterText: ''),
                            onTap: () =>
                                _activateInput(_SwitchInputTarget.code),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 50,
                          child: Material(
                            color: _canRequestSms
                                ? enabledFill
                                : disabledFill,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: _canRequestSms ? _onGetCode : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Center(
                                child: Text(
                                  _countdown > 0
                                      ? '${_countdown}s后重试'
                                      : '获取验证码',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelLarge?.copyWith(
                                    color: cs.onPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: (vBlock * 1.0).clamp(20.0, 28.0)),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _canSwitch ? _onSwitch : null,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _canSwitch ? enabledFill : disabledFill,
                        foregroundColor: cs.onPrimary,
                        disabledBackgroundColor: disabledFill,
                        disabledForegroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '切换账号',
                        style: textTheme.bodyLarge?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '切换后当前账号数据不会丢失，可随时切回',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: keyboardVisible
            ? NumericKeypad(
                onNumberTap: _handleNumberTap,
                onDelete: _handleDelete,
                onComplete: _dismissKeyboard,
              )
            : null,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required ColorScheme cs,
    required TextTheme textTheme,
    required String hint,
  }) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled: true,
      fillColor: cs.surfaceContainerHigh,
      hintText: hint,
      hintStyle: textTheme.bodyLarge?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.2),
      ),
    );
  }
}

enum _SwitchInputTarget { phone, code }

class _CurrentAccountCard extends StatelessWidget {
  const _CurrentAccountCard({
    required this.textTheme,
    required this.colorScheme,
    required this.accountLine,
  });

  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final String accountLine;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline, width: 0.7),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前账号',
            style: textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            accountLine,
            style: textTheme.bodyLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
