import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 修改昵称，确认后 [Navigator.pop] 返回新昵称；取消与返回不携带结果。
class EditNicknamePage extends StatefulWidget {
  const EditNicknamePage({
    super.key,
    required this.currentNickname,
  });

  /// 当前已保存的昵称，可为空（与「用户昵称」展示一致）
  final String currentNickname;

  @override
  State<EditNicknamePage> createState() => _EditNicknamePageState();
}

class _EditNicknamePageState extends State<EditNicknamePage> {
  static const int _maxLen = 20;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentNickname)
      ..addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _popCancel() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _onConfirm() {
    final n = _controller.text.trim();
    if (n.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入昵称')),
      );
      return;
    }
    // TODO(后端): 提交昵称到服务端
    if (!mounted) return;
    Navigator.of(context).pop<String>(n);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    final hPad = w * 0.04;
    final vBlock = h * 0.025;
    final len = _controller.text.length;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: cs.surfaceContainerHigh,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: cs.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: cs.surface,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: cs.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
            onPressed: _popCancel,
            tooltip: '返回',
          ),
          title: Text(
            '修改昵称',
            style: textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 0.7,
              color: cs.outline,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              hPad,
              (vBlock * 0.8).clamp(12.0, 20.0),
              hPad,
              (vBlock * 1.2) + viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '昵称',
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: (vBlock * 0.3).clamp(6.0, 10.0)),
                TextField(
                  controller: _controller,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxLen),
                  ],
                  style: textTheme.bodyLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                    hintText: '用户昵称',
                    hintStyle: textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
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
                  ),
                ),
                SizedBox(height: (vBlock * 0.2).clamp(4.0, 8.0)),
                Text(
                  '$len/$_maxLen',
                  textAlign: TextAlign.right,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.06,
                  ),
                ),
                SizedBox(height: (vBlock * 1.0).clamp(20.0, 32.0)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _popCancel,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: cs.outline),
                          backgroundColor: cs.surfaceContainerHigh,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '取消',
                          style: textTheme.bodyLarge?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _onConfirm,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '确认',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
