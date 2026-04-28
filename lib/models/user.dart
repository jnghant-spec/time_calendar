import 'package:time_calendar/models/membership_tier.dart';

/// 当前登录用户（含头像本地路径、会员、剩余事件额度、会话等）。
///
/// 说明：`avatarLocalPath` 指向应用内持久化后的本地文件（如 `ApplicationSupport/.../avatar.jpg`）；
/// `authToken` 仅存本地需自行加密或迁移至安全存储。
class User {
  const User({
    required this.id,
    required this.nickname,
    this.phoneE164,
    this.avatarLocalPath,
    this.membershipTier = MembershipTier.free,
    this.eventsUsedCount = 0,
    this.eventQuota,
    this.authToken,
    this.boundSharePhones = const [],
    this.serverSyncedAt,
    this.metadata,
  });

  /// 用户唯一标识（业务侧 / 对接登录接口）
  final String id;

  /// 展示用昵称
  final String nickname;

  /// 绑定手机号，大陆 11 位，不含区号时也可仅存 11 位数字串
  final String? phoneE164;

  /// 头像在设备上的**本地绝对路径**（由相册/拍照缓存后写入）
  final String? avatarLocalPath;

  /// 会员等级
  final MembershipTier membershipTier;

  /// 当前已创建/占用事件条数（与清单、日历条数统计对齐）
  final int eventsUsedCount;

  /// 该等级下允许的最大事件数；为 null 时可用 [eventQuotaForTier] 按 [membershipTier] 推导
  final int? eventQuota;

  /// 登录会话 Token（清退出登录时置空）
  final String? authToken;

  /// 为共享/伴侣流程绑定过的目标手机号列表（可后续迁到关系表）
  final List<String> boundSharePhones;

  /// 最后一次与服务器同步时间（可选）
  final DateTime? serverSyncedAt;

  /// 透传业务扩展字段（如第三方 openId 等），不落库时可为空
  final Map<String, String>? metadata;

  /// 事件额度：优先 [eventQuota]，否则使用 PRD 默认档
  int get effectiveEventQuota => eventQuota ?? eventQuotaForTier(membershipTier);

  /// 剩余可创建事件条数（非负）
  int get remainingEventSlots {
    final cap = effectiveEventQuota;
    final u = eventsUsedCount;
    if (u >= cap) return 0;
    return cap - u;
  }

  User copyWith({
    String? id,
    String? nickname,
    String? phoneE164,
    String? avatarLocalPath,
    MembershipTier? membershipTier,
    int? eventsUsedCount,
    int? eventQuota,
    String? authToken,
    bool clearAuthToken = false,
    bool clearPhone = false,
    bool clearAvatar = false,
    List<String>? boundSharePhones,
    DateTime? serverSyncedAt,
    Map<String, String>? metadata,
  }) {
    return User(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      phoneE164: clearPhone ? null : (phoneE164 ?? this.phoneE164),
      avatarLocalPath: clearAvatar ? null : (avatarLocalPath ?? this.avatarLocalPath),
      membershipTier: membershipTier ?? this.membershipTier,
      eventsUsedCount: eventsUsedCount ?? this.eventsUsedCount,
      eventQuota: eventQuota ?? this.eventQuota,
      authToken: clearAuthToken ? null : (authToken ?? this.authToken),
      boundSharePhones: boundSharePhones ?? this.boundSharePhones,
      serverSyncedAt: serverSyncedAt ?? this.serverSyncedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'phoneE164': phoneE164,
      'avatarLocalPath': avatarLocalPath,
      'membershipTier': membershipTier.name,
      'eventsUsedCount': eventsUsedCount,
      'eventQuota': eventQuota,
      'authToken': authToken,
      'boundSharePhones': boundSharePhones,
      'serverSyncedAt': serverSyncedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  static User fromJson(Map<String, dynamic> m) {
    return User(
      id: m['id'] as String,
      nickname: m['nickname'] as String? ?? '',
      phoneE164: m['phoneE164'] as String?,
      avatarLocalPath: m['avatarLocalPath'] as String?,
      membershipTier: _tierFromName(m['membershipTier'] as String?),
      eventsUsedCount: (m['eventsUsedCount'] as num?)?.toInt() ?? 0,
      eventQuota: (m['eventQuota'] as num?)?.toInt(),
      authToken: m['authToken'] as String?,
      boundSharePhones: (m['boundSharePhones'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      serverSyncedAt: (m['serverSyncedAt'] as String?) != null
          ? DateTime.tryParse(m['serverSyncedAt'] as String)
          : null,
      metadata: m['metadata'] != null
          ? Map<String, String>.from(
              (m['metadata'] as Map).map((k, v) => MapEntry('$k', '$v')),
            )
          : null,
    );
  }
}

MembershipTier _tierFromName(String? name) {
  if (name == null) return MembershipTier.free;
  return MembershipTier.values.asNameMap()[name] ?? MembershipTier.free;
}
