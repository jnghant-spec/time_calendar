import 'package:flutter/foundation.dart';
import 'package:time_calendar/models/share_contact.dart';
import 'package:time_calendar/services/event_share_service.dart';
import 'package:time_calendar/services/user_session.dart';

/// DEBUG 专用：模拟切换登录身份，便于本地验证好友分享接收流程。
abstract final class DebugAccountSwitch {
  static const String userAPhone = '17701601082';
  static const String userANickname = UserPreferenceDefaults.defaultNickname;
  static const String fallbackLaowangPhone = '13800000002';
  static const String fallbackLaowangName = '老王';
  static const String debugVerificationCode = '123456';

  static ShareContact resolveLaowangContact(List<ShareContact> contacts) {
    for (final c in contacts) {
      if (c.name.trim().contains('老王')) return c;
    }
    if (contacts.isNotEmpty) return contacts.first;
    return ShareContact(
      name: fallbackLaowangName,
      phone: fallbackLaowangPhone,
    );
  }

  static String _displayLabel(String name, String phone) {
    final n = name.trim();
    return n.isNotEmpty ? '$n（$phone）' : phone;
  }

  static Future<String> switchToLaowang(List<ShareContact> contacts) async {
    assert(kDebugMode);
    final contact = resolveLaowangContact(contacts);
    await UserSession.instance.ensureInitialized();
    await UserSession.instance.setPhone(contact.phone.trim());
    await UserSession.instance.setNickname(
      contact.name.trim().isNotEmpty ? contact.name.trim() : fallbackLaowangName,
    );
    EventShareService.revision.value++;
    return _displayLabel(contact.name, contact.phone.trim());
  }

  static Future<String> switchToUserA() async {
    assert(kDebugMode);
    await UserSession.instance.ensureInitialized();
    await UserSession.instance.setPhone(userAPhone);
    await UserSession.instance.setNickname(userANickname);
    EventShareService.revision.value++;
    return _displayLabel(userANickname, userAPhone);
  }

  /// DEBUG 切换账号页：验证码 [debugVerificationCode] + 11 位手机号。
  static Future<String?> switchToPhone({
    required String phone,
    required String code,
    List<ShareContact> contacts = const [],
  }) async {
    if (!kDebugMode) return null;
    final trimmedPhone = phone.trim();
    if (code.trim() != debugVerificationCode || trimmedPhone.length != 11) {
      return null;
    }
    var nickname = trimmedPhone;
    for (final c in contacts) {
      if (c.phone.trim() == trimmedPhone) {
        final name = c.name.trim();
        if (name.isNotEmpty) nickname = name;
        break;
      }
    }
    await UserSession.instance.ensureInitialized();
    await UserSession.instance.setPhone(trimmedPhone);
    await UserSession.instance.setNickname(nickname);
    EventShareService.revision.value++;
    return _displayLabel(nickname, trimmedPhone);
  }
}
