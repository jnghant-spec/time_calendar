import 'package:flutter/material.dart';
import 'package:time_calendar/models/memory_event.dart';

const Color _titleColor = Color(0xFF1F2937);
const Color _muted = Color(0xFF94A3B8);
const Color _themeBlue = Color(0xFF1A73E8);
const Color _deleteRed = Color(0xFFEF4444);
const Color _dividerColor = Color(0xFFF1F5F9);

Future<void> showSubEventActionSheet(
  BuildContext context, {
  required MemoryEvent event,
  required VoidCallback onEdit,
  required VoidCallback onJoin,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                '选择操作',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1, color: _dividerColor),
              _SubEventActionTile(
                icon: Icons.edit_outlined,
                label: '编辑事件',
                iconColor: _themeBlue,
                textColor: _titleColor,
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit();
                },
              ),
              _SubEventActionTile(
                icon: Icons.library_add_outlined,
                label: '加入其他事件集',
                iconColor: _themeBlue,
                textColor: _titleColor,
                onTap: () {
                  Navigator.pop(ctx);
                  onJoin();
                },
              ),
              _SubEventActionTile(
                icon: Icons.delete_outline,
                label: '删除',
                iconColor: _deleteRed,
                textColor: _deleteRed,
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx),
                  child: const SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 16,
                          color: _muted,
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
    },
  );
}

class _SubEventActionTile extends StatelessWidget {
  const _SubEventActionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: iconColor),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
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
