import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/share_contact.dart';
import 'package:time_calendar/services/event_share_service.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/utils/debug_account_switch.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserSession.instance.ensureInitialized();
    await EventShareService.resetForTests();
  });

  test('resolveLaowangContact prefers name containing 老王', () {
    final contact = DebugAccountSwitch.resolveLaowangContact([
      ShareContact(name: '张三', phone: '13800000003'),
      ShareContact(name: '老王', phone: '13800000002'),
    ]);
    expect(contact.name, '老王');
    expect(contact.phone, '13800000002');
  });

  test('switchToLaowang updates UserSession and bumps revision', () async {
    EventShareService.revision.value = 0;
    final label = await DebugAccountSwitch.switchToLaowang([
      ShareContact(name: '老王', phone: '13800000002'),
    ]);
    expect(label, contains('老王'));
    expect(UserSession.instance.phone, '13800000002');
    expect(UserSession.instance.nickname, '老王');
    expect(EventShareService.revision.value, 1);
  });

  test('switchToUserA restores default account', () async {
    await DebugAccountSwitch.switchToLaowang(const []);
    await DebugAccountSwitch.switchToUserA();
    expect(UserSession.instance.phone, DebugAccountSwitch.userAPhone);
    expect(UserSession.instance.nickname, DebugAccountSwitch.userANickname);
  });

  test('switchToPhone requires debug code 123456', () async {
    final ok = await DebugAccountSwitch.switchToPhone(
      phone: '13800000002',
      code: '123456',
      contacts: [ShareContact(name: '老王', phone: '13800000002')],
    );
    expect(ok, isNotNull);
    expect(UserSession.instance.phone, '13800000002');

    final bad = await DebugAccountSwitch.switchToPhone(
      phone: '13800000002',
      code: '000000',
    );
    expect(bad, isNull);
  });
}
