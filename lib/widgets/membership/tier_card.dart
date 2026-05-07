import 'package:flutter/material.dart';

import 'package:time_calendar/models/membership_tier.dart';

/// 会员档位卡片（三档横向 [Row] 中的一列）。
class MembershipTierCard extends StatelessWidget {
  const MembershipTierCard({
    super.key,
    required this.tier,
    required this.selected,
    required this.isCurrentTier,
    required this.priceLabel,
    required this.subPriceLabel,
    required this.onTap,
    this.badgeLabel,
    this.badgeStyle,
    this.savingsLine,
  });

  final MembershipTier tier;
  final bool selected;
  final bool isCurrentTier;
  final String priceLabel;
  final String subPriceLabel;
  final VoidCallback onTap;
  final String? badgeLabel;
  final MembershipTierBadgeStyle? badgeStyle;
  /// 年付时在主价格下展示的节省文案（绿色强调）。
  final String? savingsLine;

  bool get _premiumSelectedFill =>
      tier == MembershipTier.premium && selected;

  @override
  Widget build(BuildContext context) {
    const borderIdle = Color(0xFFE2E8F0);
    const blue = Color(0xFF1A73E8);
    const amberBorder = Color(0xFFF59E0B);

    final borderColor = selected
        ? (tier == MembershipTier.premium ? amberBorder : blue)
        : borderIdle;
    final borderWidth = selected ? 2.0 : 1.0;
    final bg = _premiumSelectedFill
        ? const Color(0xFFFFFBEB)
        : (selected ? const Color(0xFFEFF6FF) : Colors.white);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (badgeLabel != null && badgeStyle != null)
              Positioned(
                right: -4,
                top: -8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeStyle!.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeLabel!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: badgeStyle!.textColor,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  MembershipConfig.benefits[tier]!.label.replaceAll('版', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  priceLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: tier == MembershipTier.free ? 18 : 15,
                    fontWeight: FontWeight.w700,
                    color: tier == MembershipTier.premium
                        ? const Color(0xFFB45309)
                        : const Color(0xFF0F172A),
                  ),
                ),
                if ((savingsLine ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    savingsLine!.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D),
                      height: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  subPriceLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                if (isCurrentTier)
                  Container(
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0).withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '当前',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 23),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MembershipTierBadgeStyle {
  const MembershipTierBadgeStyle({
    required this.backgroundColor,
    required this.textColor,
  });

  final Color backgroundColor;
  final Color textColor;
}
