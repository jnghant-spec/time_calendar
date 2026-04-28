import 'package:time_calendar/models/membership_tier.dart';

/// 端侧全局设置（不登录也可用的偏好 + 与版本/能力开关相关）。
class AppConfig {
  const AppConfig({
    this.schemaVersion = 1,
    this.locale = 'zh_CN',
    this.firstLaunch = true,
    this.themeMode = 'system',
    this.enablePush = true,
    this.acceptSharingFromOthersDefault = true,
    this.hasShownPartnerAutoShareOnboarding = false,
    this.minSupportedBuild,
    this.lastEventsSyncAt,
    this.lastProfileSyncAt,
    this.apiBaseUrl,
    this.featureFlags = const {},
  });

  /// 本地数据结构的版本号，便于以后迁移
  final int schemaVersion;

  /// BCP-47 语言区（如 `zh_CN`）
  final String locale;

  /// 是否首次冷启动后尚未完成引导/隐私确认
  final bool firstLaunch;

  /// 主题：light / dark / system
  final String themeMode;

  /// 总推送总开关
  final bool enablePush;

  /// 新安装时「接受他人共享」默认值（可写入首启向导）
  final bool acceptSharingFromOthersDefault;

  /// 是否已展示过伴侣自动共享等说明（避免反复弹教育页）
  final bool hasShownPartnerAutoShareOnboarding;

  /// 最低支持的 app build（可强制升级）
  final int? minSupportedBuild;

  /// 上次从服务端同步「事件/清单」成功时间
  final DateTime? lastEventsSyncAt;

  /// 上次同步个人资料/会员信息时间
  final DateTime? lastProfileSyncAt;

  /// 自定义 API 根 URL（内测/灰度）；正式环境可留空用编译时常量
  final String? apiBaseUrl;

  /// 功能开关，如 `{ "festivalIcs": true }`
  final Map<String, bool> featureFlags;

  /// 解析功能开关
  bool isFeatureOn(String key, {bool defaultValue = false}) {
    return featureFlags[key] ?? defaultValue;
  }

  /// 为默认会员策略提供 PRD 数值（可合并服务端下发的覆盖，存在 User 上）
  int defaultEventQuotaFor(MembershipTier tier) => eventQuotaForTier(tier);

  AppConfig copyWith({
    int? schemaVersion,
    String? locale,
    bool? firstLaunch,
    String? themeMode,
    bool? enablePush,
    bool? acceptSharingFromOthersDefault,
    bool? hasShownPartnerAutoShareOnboarding,
    int? minSupportedBuild,
    DateTime? lastEventsSyncAt,
    DateTime? lastProfileSyncAt,
    String? apiBaseUrl,
    Map<String, bool>? featureFlags,
  }) {
    return AppConfig(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      locale: locale ?? this.locale,
      firstLaunch: firstLaunch ?? this.firstLaunch,
      themeMode: themeMode ?? this.themeMode,
      enablePush: enablePush ?? this.enablePush,
      acceptSharingFromOthersDefault: acceptSharingFromOthersDefault ?? this.acceptSharingFromOthersDefault,
      hasShownPartnerAutoShareOnboarding: hasShownPartnerAutoShareOnboarding ?? this.hasShownPartnerAutoShareOnboarding,
      minSupportedBuild: minSupportedBuild ?? this.minSupportedBuild,
      lastEventsSyncAt: lastEventsSyncAt ?? this.lastEventsSyncAt,
      lastProfileSyncAt: lastProfileSyncAt ?? this.lastProfileSyncAt,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      featureFlags: featureFlags ?? this.featureFlags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'locale': locale,
      'firstLaunch': firstLaunch,
      'themeMode': themeMode,
      'enablePush': enablePush,
      'acceptSharingFromOthersDefault': acceptSharingFromOthersDefault,
      'hasShownPartnerAutoShareOnboarding': hasShownPartnerAutoShareOnboarding,
      'minSupportedBuild': minSupportedBuild,
      'lastEventsSyncAt': lastEventsSyncAt?.toIso8601String(),
      'lastProfileSyncAt': lastProfileSyncAt?.toIso8601String(),
      'apiBaseUrl': apiBaseUrl,
      'featureFlags': featureFlags,
    };
  }

  static AppConfig fromJson(Map<String, dynamic> m) {
    return AppConfig(
      schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
      locale: m['locale'] as String? ?? 'zh_CN',
      firstLaunch: m['firstLaunch'] as bool? ?? true,
      themeMode: m['themeMode'] as String? ?? 'system',
      enablePush: m['enablePush'] as bool? ?? true,
      acceptSharingFromOthersDefault: m['acceptSharingFromOthersDefault'] as bool? ?? true,
      hasShownPartnerAutoShareOnboarding:
          m['hasShownPartnerAutoShareOnboarding'] as bool? ?? false,
      minSupportedBuild: (m['minSupportedBuild'] as num?)?.toInt(),
      lastEventsSyncAt: (m['lastEventsSyncAt'] as String?) != null
          ? DateTime.tryParse(m['lastEventsSyncAt'] as String)
          : null,
      lastProfileSyncAt: (m['lastProfileSyncAt'] as String?) != null
          ? DateTime.tryParse(m['lastProfileSyncAt'] as String)
          : null,
      apiBaseUrl: m['apiBaseUrl'] as String?,
      featureFlags: m['featureFlags'] != null
          ? Map<String, bool>.from(
              (m['featureFlags'] as Map).map(
                (k, v) => MapEntry(k as String, v as bool),
              ),
            )
          : const {},
    );
  }
}
