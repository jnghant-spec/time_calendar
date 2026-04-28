import 'package:flutter/material.dart';

/// 用户订阅 / 会员等级（PRD：免费版、基础版、高级版）。
enum UserSubscriptionTier {
  free,
  basic,
  premium,
}

/// 全局应用上下文：会员等级与商业化配额预留。
///
/// 后续接入真实用户态时，可改为 Provider / Riverpod 等，此处先按 PRD 预留 InheritedWidget。
class UserAppContext extends InheritedWidget {
  const UserAppContext({
    super.key,
    required this.tier,
    required super.child,
  });

  /// PRD：免费版活跃日程上限（占位，后续在创建日程时统一校验）。
  static const int freeTierActiveTaskLimit = 8;

  final UserSubscriptionTier tier;

  static UserAppContext? maybeOf(BuildContext context) {
    return context.findAncestorWidgetOfExactType<UserAppContext>();
  }

  static UserAppContext of(BuildContext context) {
    final result = maybeOf(context);
    assert(result != null, 'UserAppContext not found in widget tree');
    return result!;
  }

  bool get isFree => tier == UserSubscriptionTier.free;

  @override
  bool updateShouldNotify(UserAppContext oldWidget) => oldWidget.tier != tier;
}
