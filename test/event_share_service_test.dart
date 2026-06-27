import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/event_share_record.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/share_contact.dart';
import 'package:time_calendar/services/event_service.dart';
import 'package:time_calendar/services/event_share_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/services/user_session.dart';

ListEvent _sampleEvent({String id = 'evt_1'}) {
  return ListEvent(
    id: id,
    title: '好友生日',
    baseDate: DateTime(2027, 6, 5),
    tagId: 'birthday',
    repeatRule: EventRepeatRule.yearly,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserSession.instance.ensureInitialized();
    await UserSession.instance.setPhone('13800000001');
    await UserSession.instance.setNickname('用户A');
    await EventShareService.resetForTests();
    await EventService.clearAllEvents();
    TagService.reminderCountForTag = (_) => 0;
  });

  test('createOutgoingShare writes pending outgoing and incoming records', () async {
    final event = _sampleEvent();
    await EventShareService.createOutgoingShare(
      event: event,
      recipients: [
        ShareContact(name: '老王', phone: '13800000002'),
        ShareContact(name: '张三', phone: '13800000003'),
      ],
      registeredPhones: {'13800000002', '13800000003'},
    );

    final outgoing = await EventShareService.loadOutgoingRecords(event.id);
    expect(outgoing.length, 2);
    expect(outgoing.every((r) => r.status == ShareRecipientStatus.pending), isTrue);

    await UserSession.instance.setPhone('13800000002');
    await EventShareService.ensureLoaded();

    final pending = await EventShareService.getPendingForShareManagement();
    expect(pending.length, 1);
    expect(pending.first.eventSnapshot.title, '好友生日');
    expect(pending.first.senderName, '用户A');
  });

  test('acceptIncoming creates shared event and updates outgoing status', () async {
    final event = _sampleEvent();
    await EventShareService.createOutgoingShare(
      event: event,
      recipients: [ShareContact(name: '老王', phone: '13800000002')],
      registeredPhones: {'13800000002'},
    );

    await UserSession.instance.setPhone('13800000002');
    await EventShareService.ensureLoaded();

    final pending = await EventShareService.getPendingForShareManagement();
    expect(pending.length, 1);

    final accepted = await EventShareService.acceptIncoming(pending.first.id);
    expect(accepted, isNotNull);
    expect(accepted!.isShareIncoming, isTrue);
    expect(accepted.tagId, TagService.sharedIncomingTagId);
    expect(accepted.sharedFromUserName, '用户A');
    expect(accepted.sharedAt, isNotNull);
    expect(accepted.sharedSourceEventId, event.id);
    expect(accepted.ownerPhone, '13800000002');

    final events = await EventService.loadAllEvents();
    expect(events.length, 1);
    expect(events.first.id, accepted.id);

    await UserSession.instance.setPhone('13800000001');
    await EventShareService.ensureLoaded();

    final outgoing = await EventShareService.loadOutgoingRecords(event.id);
    expect(outgoing.single.status, ShareRecipientStatus.accepted);
    expect(outgoing.single.acceptedAt, isNotNull);
  });

  test('dismissIncoming marks outgoing as dismissed', () async {
    final event = _sampleEvent();
    await EventShareService.createOutgoingShare(
      event: event,
      recipients: [ShareContact(name: '老王', phone: '13800000002')],
      registeredPhones: {'13800000002'},
    );

    await UserSession.instance.setPhone('13800000002');
    await EventShareService.ensureLoaded();

    final pending = await EventShareService.getPendingForShareManagement();
    final ok = await EventShareService.dismissIncoming(pending.first.id);
    expect(ok, isTrue);

    final afterPending = await EventShareService.getPendingForShareManagement();
    expect(afterPending, isEmpty);

    await UserSession.instance.setPhone('13800000001');
    await EventShareService.ensureLoaded();

    final outgoing = await EventShareService.loadOutgoingRecords(event.id);
    expect(outgoing.single.status, ShareRecipientStatus.dismissed);
  });

  test('getPendingIncomingForBanner respects acceptOthers setting', () async {
    final event = _sampleEvent();
    await EventShareService.createOutgoingShare(
      event: event,
      recipients: [ShareContact(name: '老王', phone: '13800000002')],
      registeredPhones: {'13800000002'},
    );

    await UserSession.instance.setPhone('13800000002');
    await UserSession.instance.setAcceptOthersShareDefault(false);
    await EventShareService.ensureLoaded();

    final banner = await EventShareService.getPendingIncomingForBanner();
    expect(banner, isNull);

    final management = await EventShareService.getPendingForShareManagement();
    expect(management.length, 1);
  });

  test('createOutgoingShare does not duplicate pending for same recipient', () async {
    final event = _sampleEvent();
    final contact = ShareContact(name: '老王', phone: '13800000002');
    await EventShareService.createOutgoingShare(
      event: event,
      recipients: [contact],
      registeredPhones: {'13800000002'},
    );
    await EventShareService.createOutgoingShare(
      event: event,
      recipients: [contact],
      registeredPhones: {'13800000002'},
    );

    await UserSession.instance.setPhone('13800000002');
    await EventShareService.ensureLoaded();

    final pending = await EventShareService.getPendingForShareManagement();
    expect(pending.length, 1);

    final outgoing = await EventShareService.loadOutgoingRecords(event.id);
    expect(outgoing.length, 1);
  });

  test('acceptIncoming second call returns existing without duplicating events',
      () async {
    final event = _sampleEvent();
    await EventShareService.createOutgoingShare(
      event: event,
      recipients: [ShareContact(name: '老王', phone: '13800000002')],
      registeredPhones: {'13800000002'},
    );

    await UserSession.instance.setPhone('13800000002');
    await EventShareService.ensureLoaded();

    final pending = await EventShareService.getPendingForShareManagement();
    final first = await EventShareService.acceptIncoming(pending.first.id);
    final second = await EventShareService.acceptIncoming(pending.first.id);

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(second!.id, first!.id);

    final events = await EventService.loadAllEvents();
    expect(events.length, 1);
  });
}
