import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/services/festival_data_loader.dart';
import 'package:time_calendar/services/festival_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';

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

  /// SharedPreferences：`monthly` / `yearly`，与 [MembershipSheet] 年付开关一致。
  static const String billingPeriodPrefsKey = 'membership_billing_period';
  static const String _keyArchivedEventIds = 'membership_archived_event_ids';
  static const String _keyTrialPushScheduled = 'premium_trial_push_scheduled';
  static const String _keyTrialEndedBannerShown = 'premium_trial_ended_banner_shown';

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
    await reconcileFestivalSubscriptions();
  }

  static Future<void> startPremiumTrial({int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    final end =
        DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
    await prefs.setInt(_keyTrialEnd, end);
    await prefs.setBool(_keyTrialEndedBannerShown, false);
    await prefs.setBool(_keyTrialPushScheduled, false);
  }

  /// 新用户：本地尚无档位记录且无体验结束时间时，自动开启 7 日高级体验。
  static Future<void> maybeOfferNewUserPremiumTrial() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyTier)) return;
    if (prefs.containsKey(_keyTrialEnd)) return;
    await startPremiumTrial(days: 7);
  }

  static Future<int?> trialEndMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTrialEnd);
  }

  static Future<bool> isPremiumTrialActive() async {
    final end = await trialEndMillis();
    if (end == null) return false;
    return DateTime.now().millisecondsSinceEpoch < end;
  }

  /// 体验剩余整天数（至少为 1 直到当天结束前）。
  static Future<int?> trialRemainingWholeDays() async {
    final end = await trialEndMillis();
    if (end == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= end) return null;
    final diff = end - now;
    final days = (diff / Duration.millisecondsPerDay).ceil();
    return days.clamp(1, 999);
  }

  static Future<String> billingPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(billingPeriodPrefsKey) ?? 'monthly';
  }

  static Future<void> setBillingPeriod(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(billingPeriodPrefsKey, value);
  }

  static Future<void> setTrialPushScheduled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTrialPushScheduled, v);
  }

  static Future<bool> wasTrialPushScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTrialPushScheduled) ?? false;
  }

  static Future<bool> consumeTrialEndedBannerFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final trialEnd = prefs.getInt(_keyTrialEnd);
    if (trialEnd == null) return false;
    if (DateTime.now().millisecondsSinceEpoch < trialEnd) return false;
    if (prefs.getBool(_keyTrialEndedBannerShown) == true) return false;
    await prefs.setBool(_keyTrialEndedBannerShown, true);
    return true;
  }

  static TierBenefits benefits(MembershipTier? tier) {
    final t = tier ?? MembershipTier.free;
    return MembershipConfig.benefits[t]!;
  }

  static bool canCreateReminder(MembershipTier tier, int currentReminderCount) {
    final quota = benefits(tier).reminderQuota;
    return currentReminderCount < quota;
  }

  static int remainingEthnicQuota(
    MembershipTier tier,
    int currentSubscribedCount,
  ) {
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

  // --- 节日：静默超额（降级保留） ---

  static Future<Set<String>> loadHiddenFestivalIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(FestivalSubscriptionPrefs.hiddenSilentKey);
    return _decodeIdSet(raw);
  }

  /// 日历推算订阅全集：活跃 ∪ 静默。
  static Future<Set<String>> calendarMergedFestivalIds(
    Set<String> activeIds,
  ) async {
    final hidden = await loadHiddenFestivalIds();
    return {...activeIds, ...hidden};
  }

  static Future<void> reconcileFestivalSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final active = _decodeIdSet(prefs.getString(FestivalSubscriptionPrefs.storageKey));
    final hiddenPrev =
        _decodeIdSet(prefs.getString(FestivalSubscriptionPrefs.hiddenSilentKey));
    await FestivalDataLoader.ensureLoaded();
    await _writeFestivalSplit({...active, ...hiddenPrev}, await currentTier());
  }

  /// 节日设置页保存：根据用户当前勾选全集写入 active/hidden 拆分。
  static Future<void> persistFestivalsFromFullUserIntent(Set<String> intent) async {
    await FestivalDataLoader.ensureLoaded();
    await _writeFestivalSplit(intent, await currentTier());
  }

  static Future<void> _writeFestivalSplit(Set<String> U, MembershipTier tier) async {
    final ethnicSet = _ethnicIdsFromCache();
    final religiousSet = _religiousIdsFromCache();

    final ethnicSorted = U.where(ethnicSet.contains).toList()..sort();
    final religiousSorted = U.where(religiousSet.contains).toList()..sort();
    final neutral =
        U.difference(ethnicSorted.toSet()).difference(religiousSorted.toSet());

    final eQuota = benefits(tier).ethnicFestivalQuota;
    final rQuota = benefits(tier).religiousFestivalQuota;

    final ethnicKeepList = _takeQuota(ethnicSorted, eQuota);
    final ethnicHidden =
        eQuota == -1 ? <String>{} : ethnicSorted.skip(eQuota).toSet();

    final religiousKeepList = _takeQuota(religiousSorted, rQuota);
    final religiousHidden =
        rQuota == -1 ? <String>{} : religiousSorted.skip(rQuota).toSet();

    final newActive = {
      ...neutral,
      ...ethnicKeepList,
      ...religiousKeepList,
    };
    final newHidden = {...ethnicHidden, ...religiousHidden};

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      FestivalSubscriptionPrefs.storageKey,
      jsonEncode(newActive.toList()..sort()),
    );
    await prefs.setString(
      FestivalSubscriptionPrefs.hiddenSilentKey,
      jsonEncode(newHidden.toList()..sort()),
    );
  }

  static List<String> _takeQuota(List<String> sorted, int quota) {
    if (quota == -1) return sorted;
    if (sorted.length <= quota) return sorted;
    return sorted.take(quota).toList();
  }

  static Set<String> _decodeIdSet(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  static Set<String> _ethnicIdsFromCache() {
    final out = <String>{};
    for (final m in FestivalDataLoader.ethnicFestivalsOrEmpty()) {
      final id = m['id'];
      if (id is String && id.isNotEmpty) out.add(id);
    }
    return out;
  }

  static Set<String> _religiousIdsFromCache() {
    final out = <String>{};
    for (final m in FestivalDataLoader.religiousFestivalsOrEmpty()) {
      final id = m['id'];
      if (id is String && id.isNotEmpty) out.add(id);
    }
    return out;
  }

  // --- 自定义提醒：降级归档（仅 UI / 提醒层面的隐藏） ---

  static Future<Set<String>> loadArchivedEventIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyArchivedEventIds);
    return _decodeIdSet(raw);
  }

  static Future<void> syncArchivedEventsForTier(List<ListEvent> events) async {
    final tier = await currentTier();
    final quota = benefits(tier).reminderQuota;
    final sorted = List<ListEvent>.from(events);
    _sortEventsForArchive(sorted);

    final archived = sorted.skip(quota).map((e) => e.id).toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyArchivedEventIds,
      jsonEncode(archived.toList()..sort()),
    );
  }

  static void _sortEventsForArchive(List<ListEvent> list) {
    list.sort((a, b) {
      final ta = _archiveTier(a);
      final tb = _archiveTier(b);
      if (ta != tb) return ta.compareTo(tb);
      final da = effectiveDate(a);
      final db = effectiveDate(b);
      if (ta >= 2) {
        return db.compareTo(da);
      }
      return da.compareTo(db);
    });
  }

  static int _archiveTier(ListEvent e) {
    final expired = isEventExpired(e);
    if (!expired) {
      return e.isPinned ? 0 : 1;
    }
    return e.isPinned ? 2 : 3;
  }

  static bool isEventArchivedForTier(ListEvent e, Set<String> archivedIds) =>
      archivedIds.contains(e.id);

  /// 对外公开的归档判定入口（清单排序等与清单页一致）。
  static void sortEventsSameAsListPage(List<ListEvent> events) {
    _sortEventsForArchive(events);
  }
}
