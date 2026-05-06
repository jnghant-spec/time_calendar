import 'package:flutter/material.dart';
import 'package:time_calendar/utils/size_config.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.monthLabel,
    this.onPreviousMonth,
    this.onNextMonth,
    this.onTitleTap,
    this.compact = false,
  });

  static const Color _iconColor = Color(0xFF9CA3AF);
  static const Color _iconChevron = Color(0xFF64748B);

  final String monthLabel;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback? onTitleTap;
  /// 为日历上半区限高时压缩纵向留白。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final g = SizeConfig.contentGutter(context);
    final vTop = compact ? 8.0 : SizeConfig.sp(context, 18);
    final vBot = compact ? 3.0 : SizeConfig.sp(context, 10);
    final titleSize = compact ? SizeConfig.sp(context, 20) : SizeConfig.sp(context, 24);
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.fromLTRB(g, vTop, g, vBot),
      child: Row(
        children: [
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTitleTap,
                borderRadius: BorderRadius.circular(8),
                splashColor: primary.withValues(alpha: 0.12),
                highlightColor: primary.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          monthLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            color: primary,
                            height: 1.4,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: _iconColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onPreviousMonth,
            icon: Icon(Icons.chevron_left_rounded, size: SizeConfig.sp(context, compact ? 24 : 28)),
            color: _iconChevron,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onNextMonth,
            icon: Icon(Icons.chevron_right_rounded, size: SizeConfig.sp(context, compact ? 24 : 28)),
            color: _iconChevron,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
