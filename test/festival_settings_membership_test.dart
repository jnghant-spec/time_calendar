import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/services/festival_data_loader.dart';
import 'package:time_calendar/services/festival_service.dart';
import 'package:time_calendar/services/membership_service.dart';

/// 节日订阅与会员档位相关的持久化行为（避免整页 Widget 测试中的动画/资产异步带来的不稳定）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  test('recommended ethnic + religious id lists total six entries', () {
    expect(MembershipRecommendedFestivals.ethnicIds.length, 3);
    expect(MembershipRecommendedFestivals.religiousIds.length, 3);
  });

  test('basic tier persists arbitrary ethnic picks without recommended-only filtering',
      () async {
    SharedPreferences.setMockInitialValues({});
    await FestivalDataLoader.ensureLoaded();
    await MembershipService.setTier(MembershipTier.basic);

    final maps = FestivalDataLoader.ethnicFestivalsOrEmpty();
    final all = <String>{};
    for (final m in maps) {
      final id = m['id'];
      if (id is String && id.isNotEmpty) all.add(id);
    }
    final nonRec = all.difference(MembershipRecommendedFestivals.ethnicIds);
    final pick = nonRec.take(5).toSet();
    expect(pick.length, 5);

    await MembershipService.persistFestivalsFromFullUserIntent(pick);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(FestivalSubscriptionPrefs.storageKey)!;
    final active = (jsonDecode(raw) as List).cast<String>().toSet();
    expect(active.containsAll(pick), isTrue);
  });
}
