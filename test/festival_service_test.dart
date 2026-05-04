import 'package:flutter_test/flutter_test.dart';
import 'package:time_calendar/services/festival_service.dart';

void main() {
  test('May 2026 includes Labour Day and Mothers Day', () {
    final list = FestivalService.getFestivalsForMonth(2026, 5);
    final names = list.map((e) => e.name).toSet();
    expect(names.contains('劳动节'), true);
    expect(names.contains('母亲节'), true);
    final labour = list.firstWhere((e) => e.id == 'labour_day');
    expect(labour.gregorianDate, DateTime(2026, 5, 1));
    final md = list.firstWhere((e) => e.id == 'mothers_day');
    expect(md.gregorianDate.weekday, DateTime.sunday);
    expect(md.gregorianDate.day >= 8 && md.gregorianDate.day <= 14, true);
  });

  test('Dragon Boat 2026 falls in June (lunar conversion)', () {
    final june = FestivalService.getFestivalsForMonth(2026, 6);
    expect(june.any((e) => e.id == 'dragon_boat'), true);
    final boat = june.firstWhere((e) => e.id == 'dragon_boat');
    expect(boat.gregorianDate, DateTime(2026, 6, 19));
  });

  test('Qingming uses solar term in April', () {
    final april = FestivalService.getFestivalsForMonth(2026, 4);
    expect(april.any((e) => e.id == 'qingming'), true);
    final q = april.firstWhere((e) => e.id == 'qingming');
    expect(q.gregorianDate, DateTime(2026, 4, 5));
  });

  test('subscribedIds filters to requested holidays only', () {
    final may = FestivalService.getFestivalsForMonth(
      2026,
      5,
      subscribedIds: {'labour_day', 'mothers_day'},
    );
    expect(may.length, 2);
    expect(may.map((e) => e.id).toSet(), {'labour_day', 'mothers_day'});
  });
}
