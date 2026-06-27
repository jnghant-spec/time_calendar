import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/utils/event_owner_filter.dart';

ListEvent _event({
  required String id,
  bool incoming = false,
  String? ownerPhone,
  String? sharedSourceEventId,
}) {
  return ListEvent(
    id: id,
    title: '测试',
    baseDate: DateTime(2027, 6, 5),
    tagId: 'birthday',
    isShareIncoming: incoming,
    ownerPhone: ownerPhone,
    sharedSourceEventId: sharedSourceEventId,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserSession.instance.ensureInitialized();
  });

  test('legacy owned events visible only to default phone user', () async {
    await UserSession.instance.setPhone(UserPreferenceDefaults.defaultPhone);
    expect(isEventVisibleToCurrentUser(_event(id: 'a')), isTrue);

    await UserSession.instance.setPhone('13800000002');
    expect(isEventVisibleToCurrentUser(_event(id: 'a')), isFalse);
  });

  test('incoming without owner visible to current user', () async {
    await UserSession.instance.setPhone('13800000002');
    expect(
      isEventVisibleToCurrentUser(_event(id: 'in', incoming: true)),
      isTrue,
    );
  });

  test('ownerPhone isolates events per account', () async {
    final aEvent = _event(id: 'a', ownerPhone: '17701601082');
    final bEvent = _event(
      id: 'b',
      incoming: true,
      ownerPhone: '13800000002',
      sharedSourceEventId: 'src1',
    );
    final all = [aEvent, bEvent];

    await UserSession.instance.setPhone('17701601082');
    final forA = filterEventsForCurrentUser(all);
    expect(forA.map((e) => e.id), ['a']);

    await UserSession.instance.setPhone('13800000002');
    final forB = filterEventsForCurrentUser(all);
    expect(forB.map((e) => e.id), ['b']);
  });

  test('mergeEventsForCurrentUser preserves other account data', () {
    final aEvent = _event(id: 'a', ownerPhone: '17701601082');
    final bEvent = _event(id: 'b', ownerPhone: '13800000002');
    final updatedB = bEvent.copyWith(title: '已改');
    final merged = mergeEventsForCurrentUser(
      [aEvent, bEvent],
      [updatedB],
    );
    expect(merged.length, 2);
    expect(merged.firstWhere((e) => e.id == 'a').title, '测试');
    expect(merged.firstWhere((e) => e.id == 'b').title, '已改');
  });
}
