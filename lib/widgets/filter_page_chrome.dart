import 'package:flutter/material.dart';
import 'package:time_calendar/widgets/unified_tag_bar.dart';

/// 提醒页 / 时光集页共享的标题栏 + 标签筛选区。
class FilterPageChrome extends StatelessWidget {
  const FilterPageChrome({
    super.key,
    required this.title,
    this.onManagePressed,
    this.trailing,
  });

  final String title;
  final VoidCallback? onManagePressed;
  final Widget? trailing;

  static const double kToolbarHeight = 56.0;
  static const double kHorizontalPadding = 16.0;
  static const double kTagBarBottomGap = 8.0;
  static const Color kTitleColor = Color(0xFF0F172A);
  static const Color kPageBg = Color(0xFFFAFBFC);

  static TextStyle titleStyle(BuildContext context) => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: kTitleColor,
        height: 1.2,
      );

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: kPageBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: kToolbarHeight + safeTop,
            child: Padding(
              padding: EdgeInsets.only(
                left: kHorizontalPadding,
                right: kHorizontalPadding,
                top: safeTop,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle(context),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
          UnifiedTagBar(
            onManagePressed: onManagePressed,
            horizontalPadding: kHorizontalPadding,
          ),
          const SizedBox(height: kTagBarBottomGap),
        ],
      ),
    );
  }
}
