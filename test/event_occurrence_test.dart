import 'package:flutter_test/flutter_test.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/utils/event_date_utils.dart';

void main() {
  test('yearly solar maps base date into arbitrary view year/month (anchor 2000)', () {
    final e = ListEvent(
      id: '1',
      title: '测试生日',
      baseDate: DateTime(2000, 1, 1),
      tagId: 'birthday',
      repeatRule: EventRepeatRule.yearly,
    );
    expect(occurrenceDatesInGregorianMonth(e, 2026, 1), [DateTime(2026, 1, 1)]);
    expect(occurrenceDatesInGregorianMonth(e, 2026, 5), isEmpty);
    expect(eventOccursOnGregorianDay(e, DateTime(2025, 1, 1)), true);
    expect(e.anchorDate, DateTime(2000, 1, 1));
  });

  test('yearly does not occur before anchor date', () {
    final e = ListEvent(
      id: '1b',
      title: '测试每年循环',
      baseDate: DateTime(2026, 4, 5),
      tagId: 'birthday',
      repeatRule: EventRepeatRule.yearly,
    );
    expect(occurrenceDatesInGregorianMonth(e, 2025, 4), isEmpty);
    expect(occurrenceDatesInGregorianMonth(e, 2026, 4), [DateTime(2026, 4, 5)]);
    expect(occurrenceDatesInGregorianMonth(e, 2027, 4), [DateTime(2027, 4, 5)]);
  });

  test('daily recurring does not appear before anchor', () {
    final e = ListEvent(
      id: 'd',
      title: '测试每天循环',
      baseDate: DateTime(2026, 4, 5),
      tagId: 'goal',
      repeatRule: EventRepeatRule.daily,
    );
    final april = occurrenceDatesInGregorianMonth(e, 2026, 4);
    expect(april.first, DateTime(2026, 4, 5));
    expect(april.last, DateTime(2026, 4, 30));
    expect(april.length, 26);
    expect(occurrenceDatesInGregorianMonth(e, 2026, 3), isEmpty);
    expect(eventOccursOnGregorianDay(e, DateTime(2026, 4, 4)), false);
    expect(eventOccursOnGregorianDay(e, DateTime(2026, 4, 5)), true);
  });

  test('non-recurring only occurs on stored month', () {
    final e = ListEvent(
      id: '2',
      title: '截止',
      baseDate: DateTime(2026, 5, 10),
      tagId: 'goal',
      repeatRule: EventRepeatRule.none,
    );
    expect(occurrenceDatesInGregorianMonth(e, 2026, 5), [DateTime(2026, 5, 10)]);
    expect(occurrenceDatesInGregorianMonth(e, 2027, 5), isEmpty);
  });

  test('calendar dot uses occurrence only not advance reminder day', () {
    final e = ListEvent(
      id: 'adv',
      title: '还信用卡',
      baseDate: DateTime(2026, 6, 5),
      tagId: 'partner',
      repeatRule: EventRepeatRule.none,
      reminderType: EventReminderType.advanceOnly,
      advanceDaysOption: EventAdvanceDaysOption.oneDay,
    );
    expect(eventOccursOnGregorianDay(e, DateTime(2026, 6, 5)), true);
    expect(eventOccursOnGregorianDay(e, DateTime(2026, 6, 4)), false);
    expect(eventOccursOnGregorianDay(e, DateTime(2026, 6, 3)), false);
  });

  test('effectiveDate yearly still rolls forward from today', () {
    final e = ListEvent(
      id: '3',
      title: 'y',
      baseDate: DateTime(2000, 1, 1),
      tagId: 'birthday',
      repeatRule: EventRepeatRule.yearly,
    );
    final next = effectiveDate(e);
    expect(next.month == 1 && next.day == 1, true);
    expect(next.isBefore(DateTime(1899, 1, 1)), false);
  });
}
