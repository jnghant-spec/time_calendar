import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:time_calendar/pages/main_navigation_page.dart';
import 'package:time_calendar/utils/size_config.dart';
import 'package:time_calendar/pages/webview_page.dart';
import 'package:time_calendar/widgets/numeric_keypad.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();

  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  DateTime? _codeExpireAt;
  bool _agreedToTerms = false;
  _InputTarget? _activeInputTarget;

  static const Color _themeBlue = Color(0xFF1A73E8);
  static const String _testPhone = '17701601082';
  static const String _testCode = '123456';
  static const Color _loginDisabledBg = Color(0xFFE6EBF5);
  static const Color _loginDisabledFg = Color(0xFF90A0B7);
  static const Color _codeDisabledBg = Color(0xFFBFD4F8);
  static const Color _codeDisabledFg = Color(0xFFFFFFFF);
  late final TapGestureRecognizer _serviceAgreementRecognizer;
  late final TapGestureRecognizer _privacyPolicyRecognizer;

  bool get _isPhoneValid {
    final phone = _phoneController.text.trim();
    return RegExp(r'^\d{11}$').hasMatch(phone);
  }

  bool get _canRequestCode => _isPhoneValid && _countdownSeconds == 0;

  bool get _isCodeValid => _codeController.text.trim().length == 6;

  bool get _canLogin => _agreedToTerms && _isPhoneValid && _isCodeValid;

  @override
  void initState() {
    super.initState();
    _serviceAgreementRecognizer = TapGestureRecognizer()
      ..onTap = () => _openDocumentPage(
        title: '用户服务协议',
        assetPath: 'assets/docs/user_service_agreement.md',
      );
    _privacyPolicyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openDocumentPage(
        title: '隐私政策',
        assetPath: 'assets/docs/privacy_policy.md',
      );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocusNode.dispose();
    _codeFocusNode.dispose();
    _serviceAgreementRecognizer.dispose();
    _privacyPolicyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openDocumentPage({
    required String title,
    required String assetPath,
  }) async {
    _dismissKeyboard();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebviewPage(title: title, assetPath: assetPath),
      ),
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdownSeconds = 60;
      _codeExpireAt = DateTime.now().add(const Duration(minutes: 5));
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _countdownSeconds = 0;
        });
        return;
      }

      setState(() {
        _countdownSeconds--;
      });
    });
  }

  void _onRequestCode() {
    if (!_isPhoneValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的 11 位手机号')));
      return;
    }

    _startCountdown();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('验证码已发送，有效期5分钟，请勿重复点击')));
  }

  void _onLogin() {
    if (!_canLogin) return;
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final isCodeExpired =
        _codeExpireAt != null && DateTime.now().isAfter(_codeExpireAt!);

    // 1) 验证码不是测试值：给出明确反馈
    if (code != _testCode) {
      _activateInput(_InputTarget.code);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码错误，请重新输入')));
      return;
    }

    // 2) 验证码是测试值，但若发生了倒计时请求，且已经过期：提示过期
    if (isCodeExpired) {
      _activateInput(_InputTarget.code);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码已过期，请重新获取')));
      return;
    }

    // 3) 验证码正确，校验手机号
    if (phone != _testPhone) {
      _activateInput(_InputTarget.phone);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('手机号错误，请重新输入')));
      return;
    }

    // 4) 通过：进入主导航（必须使用本 State 的 context，避免 MyApp 层无 Navigator）
    _dismissKeyboard();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainNavigationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formWidth = SizeConfig.formWidth(context);
    final hMargin = SizeConfig.horizontalMargin(context);
    final keyboardVisible = _activeInputTarget != null;
    final logo = SizeConfig.logoSize(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              hMargin,
              SizeConfig.sp(context, 20),
              hMargin,
              keyboardVisible
                  ? SizeConfig.sp(context, 24)
                  : SizeConfig.sp(context, 20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: SizeConfig.sp(context, 28)),
                Center(
                  child: Container(
                    width: logo,
                    height: logo,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A1A73E8),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
                SizedBox(height: SizeConfig.sp(context, 20)),
                Text(
                  '欢迎使用时光日历',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                    fontSize: SizeConfig.sp(context, 24),
                  ),
                ),
                SizedBox(height: SizeConfig.sp(context, 10)),
                Text(
                  '您的专属时光管家',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                    fontSize: SizeConfig.sp(context, 15),
                  ),
                ),
                SizedBox(height: SizeConfig.sp(context, 32)),
                Center(
                  child: SizedBox(
                    width: formWidth,
                    child: _buildPhoneInput(context),
                  ),
                ),
                SizedBox(height: SizeConfig.sp(context, 16)),
                Center(
                  child: SizedBox(
                    width: formWidth,
                    child: _buildCodeInput(context),
                  ),
                ),
                SizedBox(height: SizeConfig.sp(context, 22)),
                Center(
                  child: SizedBox(
                    width: formWidth,
                    height: SizeConfig.sp(
                      context,
                      52,
                    ).clamp(48.0, 56.0).toDouble(),
                    child: _buildLoginButton(context),
                  ),
                ),
                SizedBox(height: SizeConfig.sp(context, 14)),
                Text(
                  '首次登录将自动创建账号',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF9CA3AF),
                    fontSize: SizeConfig.sp(context, 14),
                  ),
                ),
                SizedBox(height: SizeConfig.sp(context, 20)),
                Center(
                  child: SizedBox(
                    width: formWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreedToTerms = value ?? false;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: SizeConfig.sp(context, 14),
                                color: const Color(0xFF4B5563),
                              ),
                              children: [
                                const TextSpan(text: '已阅读并同意 '),
                                TextSpan(
                                  text: '《用户服务协议》',
                                  recognizer: _serviceAgreementRecognizer,
                                  style: const TextStyle(
                                    color: _themeBlue,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(text: ' 及 '),
                                TextSpan(
                                  text: '《隐私政策》',
                                  recognizer: _privacyPolicyRecognizer,
                                  style: const TextStyle(
                                    color: _themeBlue,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: keyboardVisible
          ? NumericKeypad(
              onNumberTap: _handleNumberTap,
              onDelete: _handleDelete,
            )
          : null,
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    final enabled = _canLogin;
    final bg = enabled ? _themeBlue : _loginDisabledBg;
    final fg = enabled ? Colors.white : _loginDisabledFg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? _onLogin : null,
          child: Center(
            child: Text(
              '登录 / 注册',
              style: TextStyle(
                fontSize: SizeConfig.sp(context, 20),
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput(BuildContext context) {
    final fs = SizeConfig.sp(context, 20).clamp(18.0, 24.0).toDouble();
    return Container(
      decoration: _inputContainerDecoration(),
      child: Row(
        children: [
          SizedBox(width: SizeConfig.sp(context, 16)),
          Text(
            '+86',
            style: TextStyle(
              fontSize: fs,
              color: const Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: SizeConfig.sp(context, 12),
            ),
            width: 1,
            height: SizeConfig.sp(context, 28),
            color: const Color(0xFFE5E7EB),
          ),
          Expanded(
            child: TextField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              readOnly: true,
              showCursor: true,
              maxLength: 11,
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: '请输入手机号',
                hintStyle: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: fs,
                ),
              ),
              style: TextStyle(fontSize: fs, color: const Color(0xFF111827)),
              onTap: () => _activateInput(_InputTarget.phone),
            ),
          ),
          SizedBox(width: SizeConfig.sp(context, 16)),
        ],
      ),
    );
  }

  Widget _buildCodeInput(BuildContext context) {
    final fs = SizeConfig.sp(context, 20).clamp(18.0, 24.0).toDouble();
    final btnH = SizeConfig.sp(context, 52).clamp(48.0, 56.0).toDouble();
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: _inputContainerDecoration(),
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.sp(context, 14),
            ),
            child: TextField(
              controller: _codeController,
              focusNode: _codeFocusNode,
              readOnly: true,
              showCursor: true,
              maxLength: 6,
              decoration: InputDecoration(
                border: InputBorder.none,
                counterText: '',
                hintText: '请输入验证码',
                hintStyle: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: fs,
                ),
              ),
              style: TextStyle(fontSize: fs, color: const Color(0xFF111827)),
              onTap: () => _activateInput(_InputTarget.code),
            ),
          ),
        ),
        SizedBox(width: SizeConfig.screenWidth(context) * 0.03),
        Flexible(
          flex: 2,
          child: SizedBox(
            height: btnH,
            child: _buildRequestCodeButton(context),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCodeButton(BuildContext context) {
    final enabled = _canRequestCode;
    final bg = enabled ? _themeBlue : _codeDisabledBg;
    final fg = enabled ? Colors.white : _codeDisabledFg;
    final text = _countdownSeconds > 0 ? '${_countdownSeconds}s' : '获取验证码';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? _onRequestCode : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SizeConfig.sp(
                    context,
                    16,
                  ).clamp(14.0, 18.0).toDouble(),
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _activateInput(_InputTarget target) {
    setState(() {
      _activeInputTarget = target;
    });

    if (target == _InputTarget.phone) {
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

    if (_activeInputTarget == _InputTarget.phone) {
      if (_phoneController.text.length >= 11) {
        return;
      }
      final newText = '${_phoneController.text}$number';
      final shouldSwitchToCode = newText.length == 11;
      setState(() {
        _phoneController.text = newText;
        if (shouldSwitchToCode) {
          _activeInputTarget = _InputTarget.code;
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
  }

  void _handleDelete() {
    if (_activeInputTarget == null) {
      return;
    }

    if (_activeInputTarget == _InputTarget.phone) {
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

  BoxDecoration _inputContainerDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D111827),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
      border: Border.all(color: const Color(0xFFECEFF5)),
    );
  }
}

enum _InputTarget { phone, code }
