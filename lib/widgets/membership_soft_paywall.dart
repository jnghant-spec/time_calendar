import 'package:flutter/material.dart';

import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/pages/membership_sheet.dart';
import 'package:time_calendar/services/membership_service.dart';

/// 场景化付费墙：底部圆角白底 + 双按钮（与设计稿 Phase 2 一致）。
Future<void> showMembershipSoftPaywall(
  BuildContext context, {
  required String title,
  required String message,
  String primaryLabel = '查看会员',
  String secondaryLabel = '暂不需要',
  VoidCallback? onTierChanged,
}) async {
  final openMembership = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon:
                            const Icon(Icons.close, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(ctx, true),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1A73E8),
                                Color(0xFF60A5FA),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              primaryLabel,
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
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        secondaryLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  if (!context.mounted) return;
  if (openMembership == true) {
    await showMembershipSheet(context, onTierChanged: onTierChanged);
  }
}

/// 自定义提醒数量超限：底部付费墙，文案按当前档位区分。
Future<void> showReminderQuotaPaywall(
  BuildContext context, {
  VoidCallback? onTierChanged,
}) async {
  final tier = await MembershipService.currentTier();
  if (!context.mounted) return;
  const free = MembershipTier.free;
  const basic = MembershipTier.basic;
  const prem = MembershipTier.premium;

  final String message;
  switch (tier) {
    case MembershipTier.free:
      message =
          '免费版最多可创建 ${MembershipConfig.benefits[free]!.reminderQuota} 个提醒事项，升级基础版可创建 ${MembershipConfig.benefits[basic]!.reminderQuota} 个';
      break;
    case MembershipTier.basic:
      message =
          '基础版最多可创建 ${MembershipConfig.benefits[basic]!.reminderQuota} 个提醒事项，升级高级版可创建 ${MembershipConfig.benefits[prem]!.reminderQuota} 个';
      break;
    case MembershipTier.premium:
      message =
          '高级版最多可创建 ${MembershipConfig.benefits[prem]!.reminderQuota} 个提醒事项';
      break;
  }

  await showMembershipSoftPaywall(
    context,
    title: '提醒数量已达上限',
    message: message,
    primaryLabel: '升级会员',
    onTierChanged: onTierChanged,
  );
}
