import 'package:flutter_test/flutter_test.dart';
import 'package:time_calendar/models/membership_tier.dart';

void main() {
  group('MembershipConfig.benefits', () {
    test('reminder quotas per tier', () {
      expect(MembershipConfig.benefits[MembershipTier.free]!.reminderQuota, 8);
      expect(MembershipConfig.benefits[MembershipTier.basic]!.reminderQuota, 20);
      expect(MembershipConfig.benefits[MembershipTier.premium]!.reminderQuota, 200);
    });

    test('ethnic festival quotas per tier', () {
      expect(MembershipConfig.benefits[MembershipTier.free]!.ethnicFestivalQuota, 3);
      expect(MembershipConfig.benefits[MembershipTier.basic]!.ethnicFestivalQuota, 8);
      expect(MembershipConfig.benefits[MembershipTier.premium]!.ethnicFestivalQuota, 20);
    });

    test('religious festival quotas per tier', () {
      expect(
        MembershipConfig.benefits[MembershipTier.free]!.religiousFestivalQuota,
        3,
      );
      expect(
        MembershipConfig.benefits[MembershipTier.basic]!.religiousFestivalQuota,
        8,
      );
      expect(
        MembershipConfig.benefits[MembershipTier.premium]!.religiousFestivalQuota,
        -1,
      );
    });

    test('lunar birthday flags per tier', () {
      expect(MembershipConfig.benefits[MembershipTier.free]!.lunarBirthday, isFalse);
      expect(MembershipConfig.benefits[MembershipTier.basic]!.lunarBirthday, isTrue);
      expect(MembershipConfig.benefits[MembershipTier.premium]!.lunarBirthday, isTrue);
    });

    test('photos per event per tier', () {
      expect(MembershipConfig.benefits[MembershipTier.free]!.photosPerEvent, 1);
      expect(MembershipConfig.benefits[MembershipTier.basic]!.photosPerEvent, 9);
      expect(MembershipConfig.benefits[MembershipTier.premium]!.photosPerEvent, 9);
    });
  });
}
