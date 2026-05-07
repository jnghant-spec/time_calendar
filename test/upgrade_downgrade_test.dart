import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/services/festival_data_loader.dart';
import 'package:time_calendar/services/festival_service.dart';
import 'package:time_calendar/services/membership_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  test(
      'premium ethnic subscriptions split into active (8) and hidden (7) on downgrade to basic',
      () async {
    await FestivalDataLoader.ensureLoaded();
    final maps = FestivalDataLoader.ethnicFestivalsOrEmpty();
    final ids = <String>[];
    for (final m in maps) {
      final id = m['id'];
      if (id is String && id.isNotEmpty) ids.add(id);
    }
    ids.sort();
    expect(ids.length, greaterThanOrEqualTo(15));

    final fifteen = ids.take(15).toSet();

    await MembershipService.setTier(MembershipTier.premium);
    await MembershipService.persistFestivalsFromFullUserIntent(fifteen);

    await MembershipService.setTier(MembershipTier.basic);

    expect(await MembershipService.currentTier(), MembershipTier.basic);

    final prefs = await SharedPreferences.getInstance();
    final rawActive = prefs.getString(FestivalSubscriptionPrefs.storageKey);
    final rawHidden = prefs.getString(FestivalSubscriptionPrefs.hiddenSilentKey);
    expect(rawActive, isNotNull);
    expect(rawHidden, isNotNull);

    final active = (jsonDecode(rawActive!) as List).cast<String>().toSet();
    final hidden = (jsonDecode(rawHidden!) as List).cast<String>().toSet();

    final sortedFifteen = fifteen.toList()..sort();
    final keep = sortedFifteen.take(8).toSet();
    final overflow = sortedFifteen.skip(8).toSet();

    for (final id in keep) {
      expect(active.contains(id), isTrue, reason: '$id should stay active');
    }
    for (final id in overflow) {
      expect(hidden.contains(id), isTrue, reason: '$id should move to hidden');
    }
  });
}
