import 'package:flutter_test/flutter_test.dart';
import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/services/membership_service.dart';

/// 与 [EventAddPage._submit] 中农历门槛、提醒配额判定一致（无 Widget，避免滚轮动画导致 flutter test 挂起）。
void main() {
  test('lunar birthday path requires non-free tier', () {
    expect(MembershipService.canUseLunarBirthday(MembershipTier.free), isFalse);
    expect(MembershipService.canUseLunarBirthday(MembershipTier.basic), isTrue);
    expect(MembershipService.canUseLunarBirthday(MembershipTier.premium), isTrue);
  });

  test('new event blocked when existing custom reminders reach tier quota', () {
    expect(MembershipService.canCreateReminder(MembershipTier.free, 8), isFalse);
    expect(MembershipService.canCreateReminder(MembershipTier.basic, 20), isFalse);
    expect(MembershipService.canCreateReminder(MembershipTier.premium, 200), isFalse);
  });
}
