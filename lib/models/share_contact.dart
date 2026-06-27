import 'package:shared_preferences/shared_preferences.dart';

/// TODO(后端): 增加 registered、avatarUrl，toJson/fromJson 一并持久化
class ShareContact {
  ShareContact({required this.name, required this.phone});

  static const _kPrefsContactsKey = 'tc.share_management.contacts_v1';

  final String name;
  final String phone;

  /// 清空 SharedPreferences 中持久化的常用联系人列表。
  static Future<void> clearAllContacts() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kPrefsContactsKey);
  }

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory ShareContact.fromJson(Map<String, dynamic> m) {
    final phoneRaw = m['phone'];
    final phoneStr = phoneRaw is int
        ? '$phoneRaw'
        : (phoneRaw as String? ?? '');
    return ShareContact(
      name: m['name']?.toString() ?? '',
      phone: phoneStr,
    );
  }

  /// 脱敏手机号，如 `136****8888`。
  String get maskedPhone {
    final p = phone.trim();
    if (p.length >= 11) {
      return '${p.substring(0, 3)}****${p.substring(p.length - 4)}';
    }
    if (p.length >= 7) {
      return '${p.substring(0, 3)}****${p.substring(p.length - 4)}';
    }
    return p;
  }

  /// 头像内展示文字：称呼前 2 字或手机号后 4 位。
  String get avatarText {
    final n = name.trim();
    if (n.length >= 2) return n.substring(0, 2);
    if (n.isNotEmpty) return n;
    final p = phone.trim();
    if (p.length >= 4) return p.substring(p.length - 4);
    if (p.isNotEmpty) return p;
    return '?';
  }
}
