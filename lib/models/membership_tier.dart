// 会员与配额（与 PRD：免费 / 基础 / 高级 对齐，供 User、AppConfig 共用）

enum MembershipTier {
  /// 免费版
  free,

  /// 基础版
  basic,

  /// 高级版
  premium,
}

/// 各等级「已创建事件」上限（PRD 占位，可与接口下发值对齐）。
int eventQuotaForTier(MembershipTier tier) {
  switch (tier) {
    case MembershipTier.free:
      return 8;
    case MembershipTier.basic:
      return 20;
    case MembershipTier.premium:
      return 50;
  }
}
