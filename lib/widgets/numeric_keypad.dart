import 'package:flutter/material.dart';
import 'package:time_calendar/utils/size_config.dart';

/// 与 [LoginPage] 一致的 3×4 数字键盘，底部第四行 `[, 0, 删除]`；左侧可显示「完成」以收起键盘。
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onNumberTap,
    required this.onDelete,
    this.onComplete,
  });

  final void Function(String digit) onNumberTap;
  final VoidCallback onDelete;
  final VoidCallback? onComplete;

  static const List<List<String>> _keyRows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'delete'],
  ];

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = SizeConfig.numericKeyboardHeight(context);
    return SafeArea(
      top: false,
      child: Container(
        height: keyboardHeight,
        color: const Color(0xFFF1F4FA),
        padding: EdgeInsets.fromLTRB(
          SizeConfig.horizontalMargin(context),
          SizeConfig.sp(context, 12),
          SizeConfig.horizontalMargin(context),
          SizeConfig.sp(context, 14),
        ),
        child: Column(
          children: [
            for (final row in _keyRows)
              Expanded(
                child: Row(
                  children: [
                    for (final key in row)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(SizeConfig.sp(context, 5)),
                          child: _KeyButton(
                            keyToken: key,
                            onNumberTap: onNumberTap,
                            onDelete: onDelete,
                            onComplete: onComplete,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.keyToken,
    required this.onNumberTap,
    required this.onDelete,
    this.onComplete,
  });

  final String keyToken;
  final void Function(String digit) onNumberTap;
  final VoidCallback onDelete;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    if (keyToken.isEmpty) {
      if (onComplete == null) {
        return const SizedBox.shrink();
      }
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onComplete,
          child: Center(
            child: Text(
              '完成',
              style: TextStyle(
                fontSize: SizeConfig.sp(context, 16).clamp(14.0, 18.0),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A73E8),
              ),
            ),
          ),
        ),
      );
    }

    final isDelete = keyToken == 'delete';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (isDelete) {
            onDelete();
            return;
          }
          onNumberTap(keyToken);
        },
        child: Center(
          child: isDelete
              ? const Icon(Icons.backspace_outlined, color: Color(0xFF4B5563))
              : Text(
                  keyToken,
                  style: TextStyle(
                    fontSize: SizeConfig.sp(context, 26).clamp(22.0, 30.0),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
        ),
      ),
    );
  }
}
