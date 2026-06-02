import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/services/memory_service.dart';

MemoryCollection _collection(String id, String name) {
  return MemoryCollection(
    id: id,
    name: name,
    tagId: 'tag_$id',
    createdAt: DateTime.utc(2024, 1, 1),
  );
}

MemoryEvent _event(String id, String title, {DateTime? date}) {
  return MemoryEvent(
    id: id,
    title: title,
    date: date ?? DateTime.utc(2024, 6, 15),
    photoPaths: const ['a.jpg', '', '', '', '', '', '', '', ''],
  );
}

Future<void> _seedCollections(List<MemoryCollection> collections) async {
  for (final c in collections) {
    await MemoryService.addCollection(c);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  test('addEventToCollection creates event and link', () async {
    await _seedCollections([_collection('col_a', '事件集 A')]);
    final event = _event('ev1', '妈妈生日');
    await MemoryService.addEventToCollection(event, 'col_a');

    expect(await MemoryService.getSubEventCountByCollectionId('col_a'), 1);
    final loaded = await MemoryService.getEventsByCollection('col_a');
    expect(loaded, hasLength(1));
    expect(loaded.first.id, 'ev1');
    expect(loaded.first.title, '妈妈生日');
    expect(await MemoryService.getEventById('ev1'), isNotNull);
  });

  test('joinSubEvent links same entity to two collections', () async {
    await _seedCollections([
      _collection('col_a', '事件集 A'),
      _collection('col_b', '事件集 B'),
    ]);
    final event = _event('ev1', '妈妈生日');
    await MemoryService.addEventToCollection(event, 'col_a');
    await MemoryService.joinSubEvent('ev1', 'col_b');

    final inA = await MemoryService.getEventsByCollection('col_a');
    final inB = await MemoryService.getEventsByCollection('col_b');
    expect(inA, hasLength(1));
    expect(inB, hasLength(1));
    expect(inA.first.id, inB.first.id);
    expect(await MemoryService.getCollectionIdsBySubEventId('ev1'),
        containsAll(['col_a', 'col_b']));
  });

  test('upsertEvent syncs across linked collections', () async {
    await _seedCollections([
      _collection('col_a', 'A'),
      _collection('col_b', 'B'),
    ]);
    final event = _event('ev1', '妈妈生日');
    await MemoryService.addEventToCollection(event, 'col_a');
    await MemoryService.joinSubEvent('ev1', 'col_b');

    final updated = event.copyWith(
      title: '妈妈生日（更新）',
      date: DateTime.utc(2025, 3, 8),
    );
    await MemoryService.upsertEvent(updated);

    final inA = await MemoryService.getEventsByCollection('col_a');
    final inB = await MemoryService.getEventsByCollection('col_b');
    expect(inA.first.title, '妈妈生日（更新）');
    expect(inB.first.title, '妈妈生日（更新）');
    expect(inA.first.date, DateTime.utc(2025, 3, 8));
    expect(inB.first.date, DateTime.utc(2025, 3, 8));
  });

  test('delete from one collection keeps event in others', () async {
    await _seedCollections([
      _collection('col_a', 'A'),
      _collection('col_b', 'B'),
    ]);
    await MemoryService.addEventToCollection(_event('ev1', '妈妈生日'), 'col_a');
    await MemoryService.joinSubEvent('ev1', 'col_b');

    await MemoryService.deleteEvent('ev1', fromCollectionId: 'col_a');

    expect(await MemoryService.getEventsByCollection('col_a'), isEmpty);
    expect(await MemoryService.getEventsByCollection('col_b'), hasLength(1));
    expect(await MemoryService.getEventById('ev1'), isNotNull);
  });

  test('delete from sole collection removes entity', () async {
    await _seedCollections([_collection('col_a', 'A')]);
    await MemoryService.addEventToCollection(_event('ev1', '妈妈生日'), 'col_a');

    await MemoryService.deleteEvent('ev1', fromCollectionId: 'col_a');

    expect(await MemoryService.getEventsByCollection('col_a'), isEmpty);
    expect(await MemoryService.getEventById('ev1'), isNull);
  });

  test('deleteCollection removes unique events, keeps shared', () async {
    await _seedCollections([
      _collection('col_a', 'A'),
      _collection('col_b', 'B'),
    ]);
    await MemoryService.addEventToCollection(_event('ev1', '共享'), 'col_a');
    await MemoryService.addEventToCollection(_event('ev2', '独有'), 'col_a');
    await MemoryService.joinSubEvent('ev1', 'col_b');

    await MemoryService.deleteCollection('col_a');

    expect(await MemoryService.getCollectionById('col_a'), isNull);
    expect(await MemoryService.getEventById('ev2'), isNull);
    expect(await MemoryService.getEventById('ev1'), isNotNull);
    expect(await MemoryService.getEventsByCollection('col_b'), hasLength(1));
  });

  test('joinSubEvent throws when already linked', () async {
    await _seedCollections([
      _collection('col_a', 'A'),
      _collection('col_b', 'B'),
    ]);
    await MemoryService.addEventToCollection(_event('ev1', '妈妈生日'), 'col_a');
    await MemoryService.joinSubEvent('ev1', 'col_b');

    expect(
      () => MemoryService.joinSubEvent('ev1', 'col_b'),
      throwsA(isA<SubEventAlreadyInCollectionException>()),
    );
  });

  test('v2 collectionId migrates to association links', () async {
    SharedPreferences.setMockInitialValues({
      'memory_collections_v2': '''
[{"id":"col_a","name":"A","tagId":"t1","isPinned":false,"createdAt":"2024-01-01T00:00:00.000Z"}]
''',
      'memory_events_v2': '''
[{"id":"ev1","title":"旧数据","collectionId":"col_a","date":"2024-06-15T00:00:00.000Z","photoPaths":[]}]
''',
    });

    final events = await MemoryService.loadEvents();
    expect(events, hasLength(1));
    expect(events.first.id, 'ev1');

    final inCollection = await MemoryService.getEventsByCollection('col_a');
    expect(inCollection, hasLength(1));
    expect(inCollection.first.title, '旧数据');

    final rawEvent = events.first.toJson();
    expect(rawEvent.containsKey('collectionId'), isFalse);
  });
}
