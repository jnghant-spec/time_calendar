import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/membership_tier.dart';
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

  test('currentTier defaults to free', () async {
    final tier = await MembershipService.currentTier();
    expect(tier, MembershipTier.free);
  });

  test('setTier persists', () async {
    await MembershipService.setTier(MembershipTier.basic);
    expect(await MembershipService.currentTier(), MembershipTier.basic);
    await MembershipService.setTier(MembershipTier.free);
  });

  test('premium trial overrides stored tier', () async {
    await MembershipService.setTier(MembershipTier.free);
    await MembershipService.startPremiumTrial(days: 7);
    expect(await MembershipService.currentTier(), MembershipTier.premium);
  });

  test('canCreateReminder respects quotas', () {
    expect(
      MembershipService.canCreateReminder(MembershipTier.free, 7),
      isTrue,
    );
    expect(
      MembershipService.canCreateReminder(MembershipTier.free, 8),
      isFalse,
    );
    expect(
      MembershipService.canCreateReminder(MembershipTier.basic, 19),
      isTrue,
    );
    expect(
      MembershipService.canCreateReminder(MembershipTier.basic, 20),
      isFalse,
    );
  });

  test('remaining ethnic quota free subtracts subscribed', () {
    expect(
      MembershipService.remainingEthnicQuota(MembershipTier.free, 2),
      1,
    );
  });

  test('remaining religious quota premium is unlimited sentinel', () {
    expect(
      MembershipService.remainingReligiousQuota(MembershipTier.premium, 999),
      9999,
    );
  });

  test('remaining ethnic quota premium subtracts subscribed count', () {
    expect(
      MembershipService.remainingEthnicQuota(MembershipTier.premium, 10),
      10,
    );
  });

  test('canUseLunarBirthday differs between free and paid tiers', () {
    expect(MembershipService.canUseLunarBirthday(MembershipTier.free), isFalse);
    expect(MembershipService.canUseLunarBirthday(MembershipTier.basic), isTrue);
    expect(MembershipService.canUseLunarBirthday(MembershipTier.premium), isTrue);
  });

  test('canCreateReminder boundary: premium count 199 vs 200', () {
    expect(
      MembershipService.canCreateReminder(MembershipTier.premium, 199),
      isTrue,
    );
    expect(
      MembershipService.canCreateReminder(MembershipTier.premium, 200),
      isFalse,
    );
  });

  test('premium trial active within window then expires', () async {
    SharedPreferences.setMockInitialValues({});
    await MembershipService.startPremiumTrial(days: 7);
    expect(await MembershipService.currentTier(), MembershipTier.premium);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'premium_trial_end',
      DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    );

    expect(await MembershipService.currentTier(), MembershipTier.free);
  });
}
