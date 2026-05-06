import 'package:shared_preferences/shared_preferences.dart';

import 'package:time_calendar/models/membership_tier.dart';

/// 免费版强制订阅的节日 ID（与 assets JSON 内 `id` 一致）。
class MembershipRecommendedFestivals {
  MembershipRecommendedFestivals._();

  static const Set<String> ethnicIds = {
    'zang_losar',
    'dai_water_splashing',
    'yi_huoba',
  };

  static const Set<String> religiousIds = {
    'buddhism_buddha_birth',
    'islam_eid_fitr',
    'christianity_christmas',
  };

  static bool isRecommendedEthnic(String id) => ethnicIds.contains(id);

  static bool isRecommendedReligious(String id) => religiousIds.contains(id);
}

class MembershipService {
  MembershipService._();

  static const String _keyTier = 'membership_tier';
  static const String _keyTrialEnd = 'premium_trial_end';

  static Future<MembershipTier> currentTier() async {
    final prefs = await SharedPreferences.getInstance();
    final trialEnd = prefs.getInt(_keyTrialEnd);
    if (trialEnd != null) {
      if (DateTime.now().millisecondsSinceEpoch < trialEnd) {
        return MembershipTier.premium;
      }
    }
    final raw = prefs.getString(_keyTier) ?? 'free';
    return MembershipTier.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => MembershipTier.free,
    );
  }

  static Future<void> setTier(MembershipTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTier, tier.name);
  }

  static Future<void> startPremiumTrial({int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    final end =
        DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
    await prefs.setInt(_keyTrialEnd, end);
  }

  static TierBenefits benefits(MembershipTier? tier) {
    final t = tier ?? MembershipTier.free;
    return MembershipConfig.benefits[t]!;
  }

  static bool canCreateReminder(MembershipTier tier, int currentReminderCount) {
    final quota = benefits(tier).reminderQuota;
    return currentReminderCount < quota;
  }

  static int remainingEthnicQuota(MembershipTier tier, int currentSubscribedCount) {
    final quota = benefits(tier).ethnicFestivalQuota;
    if (quota == -1) return 9999;
    return quota - currentSubscribedCount;
  }

  static int remainingReligiousQuota(
    MembershipTier tier,
    int currentSubscribedCount,
  ) {
    final quota = benefits(tier).religiousFestivalQuota;
    if (quota == -1) return 9999;
    return quota - currentSubscribedCount;
  }

  static bool canUploadPhoto(MembershipTier tier, int currentPhotosInEvent) {
    final limit = benefits(tier).photosPerEvent;
    if (limit == 0) return false;
    return currentPhotosInEvent < limit;
  }

  static bool canUseLunarBirthday(MembershipTier tier) {
    return benefits(tier).lunarBirthday;
  }
}
