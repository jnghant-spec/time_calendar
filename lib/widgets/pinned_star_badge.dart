import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 置顶卡片顶部金线色（清单/日历一致）。
const Color kPinnedStarGold = Color(0xFFFFB800);

/// 置顶星标淡金底。
const Color kPinnedStarBadgeBg = Color(0xFFFFFBEB);

/// 置顶星标在卡片内容区 Stack 内的 [Positioned] 坐标（与清单页一致）。
const double kPinnedStarBadgeTop = -8;
const double kPinnedStarBadgeRight = 6;

/// 清单/日历置顶卡片右上角星标。
class PinnedStarBadge extends StatelessWidget {
  const PinnedStarBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: kPinnedStarBadgeBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/images/ic_star.svg',
          width: 22,
          height: 22,
        ),
      ),
    );
  }
}
