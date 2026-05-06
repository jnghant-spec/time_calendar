import 'package:flutter/material.dart';

import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/services/membership_service.dart';
import 'package:time_calendar/widgets/membership/comparison_table.dart';
import 'package:time_calendar/widgets/membership/tier_card.dart';

Future<void> showMembershipSheet(
  BuildContext context, {
  VoidCallback? onTierChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return MembershipSheet(onTierChanged: onTierChanged);
    },
  );
}

class MembershipSheet extends StatefulWidget {
  const MembershipSheet({super.key, this.onTierChanged});

  final VoidCallback? onTierChanged;

  @override
  State<MembershipSheet> createState() => _MembershipSheetState();
}

class _MembershipSheetState extends State<MembershipSheet> {
  MembershipTier _actualTier = MembershipTier.free;
  MembershipTier _selectedTier = MembershipTier.free;
  bool _yearly = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    MembershipService.currentTier().then((t) {
      if (!mounted) return;
      setState(() {
        _actualTier = t;
        _selectedTier = t;
        _loaded = true;
      });
    });
  }

  static int _tierOrder(MembershipTier t) => MembershipTier.values.indexOf(t);

  String _priceMain(MembershipTier t) {
    final b = MembershipConfig.benefits[t]!;
    if (t == MembershipTier.free) return '¥0';
    final p = _yearly ? b.priceYearly : b.priceMonthly;
    return _yearly ? '¥$p/年' : '¥$p/月';
  }

  String _priceSub(MembershipTier t) {
    final b = MembershipConfig.benefits[t]!;
    if (t == MembershipTier.free) return '永久免费';
    if (!_yearly) {
      final y = b.priceYearly;
      final m12 = b.priceMonthly * 12;
      final save = (m12 - y).toStringAsFixed(1);
      return '年付 ¥$y · 省 ¥$save';
    }
    final perMonth = (b.priceYearly / 12).toStringAsFixed(2);
    return '约合 ¥$perMonth/月';
  }

  Future<void> _confirmTierChange() async {
    await MembershipService.setTier(_selectedTier);
    if (!mounted) return;
    widget.onTierChanged?.call();
    Navigator.of(context).pop();
  }

  Widget _gradientButton({
    required VoidCallback? onPressed,
    required List<Color> gradientColors,
    required String label,
    bool enabled = true,
  }) {
    final opacity = enabled ? 1.0 : 0.45;
    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onPressed : null,
          child: Ink(
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required VoidCallback? onPressed,
    required String label,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: enabled ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _disabledPlaceholder(String label) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height * 0.88;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: h,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ColoredBox(
            color: Colors.white,
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFF1A73E8),
                              Color(0xFF3B82F6),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Row(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '👑',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '当前等级：${MembershipConfig.benefits[_actualTier]!.label}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.18),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.close, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                '解锁完整时光体验',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '选择适合你的版本，随时可切换',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: MembershipTierCard(
                                      tier: MembershipTier.free,
                                      selected:
                                          _selectedTier == MembershipTier.free,
                                      isCurrentTier:
                                          _actualTier == MembershipTier.free,
                                      priceLabel:
                                          _priceMain(MembershipTier.free),
                                      subPriceLabel:
                                          _priceSub(MembershipTier.free),
                                      onTap: () => setState(() =>
                                          _selectedTier = MembershipTier.free),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: MembershipTierCard(
                                      tier: MembershipTier.basic,
                                      selected:
                                          _selectedTier == MembershipTier.basic,
                                      isCurrentTier:
                                          _actualTier == MembershipTier.basic,
                                      priceLabel:
                                          _priceMain(MembershipTier.basic),
                                      subPriceLabel:
                                          _priceSub(MembershipTier.basic),
                                      badgeLabel: '推荐',
                                      badgeStyle: const MembershipTierBadgeStyle(
                                        backgroundColor: Color(0xFF1A73E8),
                                        textColor: Colors.white,
                                      ),
                                      onTap: () => setState(() =>
                                          _selectedTier = MembershipTier.basic),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: MembershipTierCard(
                                      tier: MembershipTier.premium,
                                      selected: _selectedTier ==
                                          MembershipTier.premium,
                                      isCurrentTier: _actualTier ==
                                          MembershipTier.premium,
                                      priceLabel:
                                          _priceMain(MembershipTier.premium),
                                      subPriceLabel:
                                          _priceSub(MembershipTier.premium),
                                      badgeLabel: 'VIP',
                                      badgeStyle: const MembershipTierBadgeStyle(
                                        backgroundColor: Color(0xFFFCD34D),
                                        textColor: Color(0xFF78350F),
                                      ),
                                      onTap: () => setState(() =>
                                          _selectedTier =
                                              MembershipTier.premium),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      '按年付费更省',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: _yearly,
                                    activeTrackColor: const Color(0xFF1A73E8),
                                    thumbColor: WidgetStateProperty.all(Colors.white),
                                    onChanged: (v) =>
                                        setState(() => _yearly = v),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              MembershipComparisonTable(
                                currentTier: _actualTier,
                              ),
                              SizedBox(height: 88 + bottom),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
                        child: Builder(
                          builder: (ctx) {
                            final sel = _selectedTier;
                            final same = sel == _actualTier;
                            final selOrder = _tierOrder(sel);
                            final actOrder = _tierOrder(_actualTier);

                            if (same) {
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  _disabledPlaceholder('已是当前等级'),
                                ],
                              );
                            }

                            if (selOrder > actOrder) {
                              final toPremium =
                                  sel == MembershipTier.premium;
                              final label =
                                  '立即升级至 ${MembershipConfig.benefits[sel]!.label}';
                              return _gradientButton(
                                onPressed: _confirmTierChange,
                                gradientColors: toPremium
                                    ? const [
                                        Color(0xFFF59E0B),
                                        Color(0xFFFCD34D),
                                      ]
                                    : const [
                                        Color(0xFF1A73E8),
                                        Color(0xFF60A5FA),
                                      ],
                                label: label,
                              );
                            }

                            final downgradeLabel =
                                '立即调整至 ${MembershipConfig.benefits[sel]!.label}';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _outlineButton(
                                  onPressed: _confirmTierChange,
                                  label: downgradeLabel,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  '当前权益持续至下个订阅周期，已添加内容保留但超额提醒将暂停通知',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            );
                          },
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
