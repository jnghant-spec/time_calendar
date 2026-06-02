import 'dart:typed_data';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:time_calendar/models/list_event.dart';

/// 单条可导入的生日（通讯录）。
class ContactBirthdayCandidate {
  ContactBirthdayCandidate({
    required this.contactId,
    required this.displayName,
    required this.month,
    required this.day,
    required this.anchorYear,
    required this.unknownYear,
    this.photoBytes,
  });

  final String contactId;
  final String displayName;
  final int month;
  final int day;

  /// 无年份时用占位年（1900），仅用于 [DateTime] 锚点。
  final int anchorYear;
  final bool unknownYear;
  final Uint8List? photoBytes;

  String get stableKey => '$contactId-$month-$day';

  static String normalizeTitle(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), '');
}

/// 通讯录读取与生日解析。
class ContactImportService {
  ContactImportService._();

  static const int _unknownYear = 1900;

  /// 使用 flutter_contacts 权限 API。
  static Future<bool> ensureFlutterContactsReadPermission() async {
    final st =
        await FlutterContacts.permissions.request(PermissionType.read);
    return st == PermissionStatus.granted || st == PermissionStatus.limited;
  }

  static Future<List<ContactBirthdayCandidate>> loadBirthdayCandidates() async {
    final ok = await ensureFlutterContactsReadPermission();
    if (!ok) return [];

    final contacts = await FlutterContacts.getAll(
      properties: {
        ContactProperty.event,
        ContactProperty.photoThumbnail,
      },
    );

    final out = <ContactBirthdayCandidate>[];
    for (final c in contacts) {
      final id = c.id ?? '';
      final name = (c.displayName ?? '').trim();
      if (id.isEmpty || name.isEmpty) continue;

      for (final ev in c.events) {
        if (!_isBirthdayLike(ev)) continue;
        final md = _monthDay(ev);
        if (md == null) continue;
        final yearInfo = _year(ev);
        final unknownYear = yearInfo == null;
        final anchorYear = yearInfo ?? _unknownYear;

        out.add(
          ContactBirthdayCandidate(
            contactId: id,
            displayName: name,
            month: md.$1,
            day: md.$2,
            anchorYear: anchorYear,
            unknownYear: unknownYear,
            photoBytes: c.photo?.thumbnail,
          ),
        );
      }
    }

    out.sort((a, b) {
      final c = a.displayName.compareTo(b.displayName);
      if (c != 0) return c;
      final d = a.month.compareTo(b.month);
      if (d != 0) return d;
      return a.day.compareTo(b.day);
    });

    return out;
  }

  static bool _isBirthdayLike(Event ev) {
    return ev.label.label == EventLabel.birthday;
  }

  static (int, int)? _monthDay(Event ev) {
    final m = ev.month;
    final d = ev.day;
    if (m >= 1 && m <= 12 && d >= 1 && d <= 31) return (m, d);
    return null;
  }

  static int? _year(Event ev) {
    final y = ev.year;
    if (y == null || y <= 0 || y == _unknownYear) return null;
    return y;
  }

  /// 过滤清单中已存在的同名同月同日生日（去重）。
  static List<ContactBirthdayCandidate> filterAlreadyImported({
    required List<ListEvent> existingEvents,
    required List<ContactBirthdayCandidate> candidates,
  }) {
    final taken = <String>{};
    for (final e in existingEvents) {
      if (e.tagId != 'birthday') continue;
      taken.add(_dedupeKey(e.title, e.baseDate.month, e.baseDate.day));
    }
    return candidates
        .where(
          (c) =>
              !taken.contains(_dedupeKey(c.displayName, c.month, c.day)),
        )
        .toList();
  }

  static String _dedupeKey(String title, int month, int day) {
    final n = ContactBirthdayCandidate.normalizeTitle(title);
    return '$n|$month|$day';
  }

  /// 生成清单事件：每年循环，默认当年前置+当天提醒。
  static ListEvent toBirthdayListEvent(ContactBirthdayCandidate c) {
    final title = _displayTitle(c);
    return ListEvent(
      id:
          'contact_${c.contactId}_${c.month}_${c.day}_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      baseDate: DateTime(c.anchorYear, c.month, c.day),
      tagId: 'birthday',
      isPinned: false,
      isLunarRecurring: false,
      isLunarDate: false,
      repeatRule: EventRepeatRule.yearly,
      reminderType: EventReminderType.advanceAndSameDay,
      advanceDaysOption: EventAdvanceDaysOption.oneDay,
      advanceTimeHm: '09:00',
      sameDayTimeHm: '09:00',
      isExpired: false,
    );
  }

  static String _displayTitle(ContactBirthdayCandidate c) {
    final rel = _relationHint(c.displayName);
    final suffix = c.unknownYear ? '（未知年份）' : '';
    if (rel.isEmpty) return '${c.displayName}的生日$suffix';
    return '${c.displayName}的生日 · $rel$suffix';
  }

  static String _relationHint(String name) {
    if (name.contains('爸爸') ||
        name.contains('父亲') ||
        name.contains('爸')) {
      return '家人';
    }
    if (name.contains('妈妈') ||
        name.contains('母亲') ||
        name.contains('妈')) {
      return '家人';
    }
    return '';
  }
}
