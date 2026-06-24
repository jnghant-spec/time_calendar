import 'package:flutter_test/flutter_test.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/utils/event_date_utils.dart';

void main() {
  test('MemoryEvent.fromJson defaults isLunarDate to false', () {
    final event = MemoryEvent.fromJson({
      'id': 'ev1',
      'title': '测试',
      'date': '2025-05-16T00:00:00.000',
      'photoPaths': <String>[],
    });
    expect(event.isLunarDate, isFalse);
  });

  test('MemoryEvent round-trips isLunarDate', () {
    final event = MemoryEvent(
      id: 'ev1',
      title: '测试',
      date: DateTime(2025, 5, 16),
      isLunarDate: true,
    );
    final restored = MemoryEvent.fromJson(event.toJson());
    expect(restored.isLunarDate, isTrue);
  });

  test('formatMemoryEventLunarPill uses lunar month and day', () {
    final date = DateTime(2025, 5, 16);
    expect(formatMemoryEventLunarPill(date), '农历 四月十九');
  });
}
