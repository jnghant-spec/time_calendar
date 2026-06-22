import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_calendar/models/memory_event.dart';
import 'package:time_calendar/services/memory_service.dart';

void main() {
  late Directory tempDir;
  late String existingPath;
  late String missingPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('memory_photo_paths_test');
    existingPath = '${tempDir.path}/exists.jpg';
    await File(existingPath).writeAsString('photo');
    missingPath = '${tempDir.path}/missing.jpg';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('sanitizePhotoGridSlots keeps existing files and clears invalid slots', () {
    final slots = <String?>[
      existingPath,
      '',
      missingPath,
      null,
      existingPath,
      null,
      null,
      null,
      null,
    ];

    final sanitized = MemoryService.sanitizePhotoGridSlots(slots);

    expect(sanitized[0], existingPath);
    expect(sanitized[1], isNull);
    expect(sanitized[2], isNull);
    expect(sanitized[4], existingPath);
    expect(sanitized.where((s) => s != null).length, 2);
  });

  test('sanitizePhotoPaths encodes invalid entries as empty strings', () {
    final stored = MemoryService.encodePhotoGridSlots([
      existingPath,
      missingPath,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ]);

    final sanitized = MemoryService.sanitizePhotoPaths(stored);

    expect(sanitized.length, 9);
    expect(sanitized[0], existingPath);
    expect(sanitized[1], '');
    expect(sanitized.where((p) => p.trim().isNotEmpty).length, 1);
  });

  test('sanitizeMemoryEvent returns copyWith only when paths change', () {
    final dirty = MemoryEvent(
      id: 'ev1',
      title: '测试',
      date: DateTime.utc(2026, 6, 1),
      photoPaths: MemoryService.encodePhotoGridSlots([
        existingPath,
        missingPath,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
      ]),
    );

    final cleaned = MemoryService.sanitizeMemoryEvent(dirty);

    expect(identical(cleaned, dirty), isFalse);
    expect(cleaned.photoPaths[0], existingPath);
    expect(cleaned.photoPaths[1], '');
    expect(
      MemoryService.countPhotosInEvent(cleaned),
      MemoryService.existingPhotoPaths(cleaned).length,
    );
  });

  test('sanitizeMemoryEvent returns same instance when already clean', () {
    final event = MemoryEvent(
      id: 'ev2',
      title: '干净',
      date: DateTime.utc(2026, 6, 2),
      photoPaths: MemoryService.encodePhotoGridSlots([
        existingPath,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
      ]),
    );

    final cleaned = MemoryService.sanitizeMemoryEvent(event);

    expect(identical(cleaned, event), isTrue);
  });

  test('deletePhotoFileIfExists removes file silently', () {
    expect(File(existingPath).existsSync(), isTrue);
    MemoryService.deletePhotoFileIfExists(existingPath);
    expect(File(existingPath).existsSync(), isFalse);
    expect(() => MemoryService.deletePhotoFileIfExists(missingPath), returnsNormally);
  });
}
