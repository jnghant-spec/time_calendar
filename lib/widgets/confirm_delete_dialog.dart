import 'package:flutter/material.dart';

const String kConfirmDeleteDefaultContent =
    '删除后将无法恢复，相关照片仍保留在相册中。';

/// 统一删除确认弹窗。返回 `true` 表示确认删除。
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String title,
  String? content,
  String? confirmText,
}) async {
  const titleColor = Color(0xFF1F2937);
  const muted = Color(0xFF94A3B8);

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content ?? kConfirmDeleteDefaultContent,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    '取消',
                    style: TextStyle(color: muted),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    confirmText ?? '删除',
                    style: const TextStyle(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
