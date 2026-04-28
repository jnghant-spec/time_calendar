import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calendar/models/event.dart';

/// 用户偏好与会话侧轻量状态（[SharedPreferences]）。
///
/// 所有 **读** 接口在 [SharedPreferences] 未就绪时仍返回 [UserPreferenceDefaults]，
/// 避免 `null`/缺键或原生通道失败导致上层逻辑崩溃；**UI 应始终能拿到可展示的字符串。**
///
/// 启动时请在 `main()` 中先调用 [WidgetsFlutterBinding.ensureInitialized]，
/// 再 `await UserSession.instance.ensureInitialized()`。
class UserSession {
  UserSession._();

  static final UserSession instance = UserSession._();

  SharedPreferences? _prefs;

  /// [SharedPreferences.getInstance] 是否曾失败（仅内存态，便于调试/可选重试）
  bool get isPreferencesAvailable => _prefs != null;

  Future<void> ensureInitialized() async {
    if (_prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e, st) {
      _prefs = null;
      debugPrint('UserSession: SharedPreferences.getInstance failed: $e\n$st');
    }
  }

  /// 展示用昵称；存储为空或缺键时返回 [UserPreferenceDefaults.defaultNickname]。
  String get nickname {
    final raw = _prefs?.getString(_kNickname);
    if (raw == null || raw.trim().isEmpty) {
      return UserPreferenceDefaults.defaultNickname;
    }
    return raw;
  }

  /// 展示用手机号；缺键时返回 [UserPreferenceDefaults.defaultPhone]。
  String get phone {
    final raw = _prefs?.getString(_kPhone);
    if (raw == null || raw.trim().isEmpty) {
      return UserPreferenceDefaults.defaultPhone;
    }
    return raw;
  }

  /// 本地头像文件路径；未设置或空串时返回 [UserPreferenceDefaults.defaultAvatarPath]（由 UI 用占位图）。
  String get avatar {
    final raw = _prefs?.getString(_kAvatar);
    if (raw == null || raw.trim().isEmpty) {
      return UserPreferenceDefaults.defaultAvatarPath;
    }
    return raw;
  }

  /// 同 [avatar]，空表示未设置资源，便于与 [User] 的 `avatarLocalPath` 对照。
  String? get avatarLocalPath {
    final a = avatar;
    return a.isEmpty ? null : a;
  }

  Future<bool> setNickname(String value) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    return _prefs!.setString(_kNickname, value);
  }

  Future<bool> setPhone(String value) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    return _prefs!.setString(_kPhone, value);
  }

  Future<bool> setAvatarPath(String value) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    return _prefs!.setString(_kAvatar, value);
  }

  /// 自动将新事件共享给伴侣（或好友）相关能力总开关
  bool get autoShareEnabled =>
      _prefs?.getBool(_kAutoShareEnabled) ?? UserPreferenceDefaults.autoShareEnabled;

  Future<bool> setAutoShareEnabled(bool value) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    return _prefs!.setBool(_kAutoShareEnabled, value);
  }

  /// 是否默认接受他人共享到本账号（与 [AppConfig.acceptSharingFromOthersDefault] 对齐）
  bool get acceptOthersShareDefault =>
      _prefs?.getBool(_kAcceptOthersShare) ?? UserPreferenceDefaults.acceptOthersShareDefault;

  Future<bool> setAcceptOthersShareDefault(bool value) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    return _prefs!.setBool(_kAcceptOthersShare, value);
  }

  /// 新建事件默认：提前 [N] 天提醒（与 [Event.preReminderOffsetDays] 一致）
  int get defaultPreReminderOffsetDays => _readInt(
        _kDefaultPreOffsetDays,
        UserPreferenceDefaults.defaultPreReminderOffsetDays,
        min: 0,
        max: 365,
      );

  Future<bool> setDefaultPreReminderOffsetDays(int days) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    return _prefs!.setInt(
      _kDefaultPreOffsetDays,
      days.clamp(0, 365),
    );
  }

  /// 新建事件默认：提前提醒的当日时间（小时 0–23）
  int get defaultPreReminderHour => _readInt(
        _kDefaultPreReminderHour,
        UserPreferenceDefaults.defaultPreReminderHour,
        min: 0,
        max: 23,
      );

  /// 新建事件默认：提前提醒的分钟 0–59
  int get defaultPreReminderMinute => _readInt(
        _kDefaultPreReminderMinute,
        UserPreferenceDefaults.defaultPreReminderMinute,
        min: 0,
        max: 59,
      );

  Future<bool> setDefaultPreReminderTime({required int hour, required int minute}) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    final h = hour.clamp(0, 23);
    final m = minute.clamp(0, 59);
    final ok1 = await _prefs!.setInt(_kDefaultPreReminderHour, h);
    final ok2 = await _prefs!.setInt(_kDefaultPreReminderMinute, m);
    return ok1 && ok2;
  }

  /// 新建事件默认：当天提醒时间（小时）
  int get defaultSameDayReminderHour => _readInt(
        _kDefaultSameDayHour,
        UserPreferenceDefaults.defaultSameDayReminderHour,
        min: 0,
        max: 23,
      );

  int get defaultSameDayReminderMinute => _readInt(
        _kDefaultSameDayMinute,
        UserPreferenceDefaults.defaultSameDayReminderMinute,
        min: 0,
        max: 59,
      );

  Future<bool> setDefaultSameDayReminderTime({required int hour, required int minute}) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    final h = hour.clamp(0, 23);
    final m = minute.clamp(0, 59);
    final ok1 = await _prefs!.setInt(_kDefaultSameDayHour, h);
    final ok2 = await _prefs!.setInt(_kDefaultSameDayMinute, m);
    return ok1 && ok2;
  }

  /// 与 [Event] 模型对齐的默认「提前提醒」 [DayTime]
  DayTime get defaultPreReminderDayTime => DayTime(
        hour: defaultPreReminderHour,
        minute: defaultPreReminderMinute,
      );

  /// 与 [Event] 模型对齐的默认「当天提醒」 [DayTime]
  DayTime get defaultSameDayReminderDayTime => DayTime(
        hour: defaultSameDayReminderHour,
        minute: defaultSameDayReminderMinute,
      );

  /// 主题：light / dark / system
  String get themeMode =>
      _prefs?.getString(_kThemeMode) ?? UserPreferenceDefaults.themeMode;

  Future<bool> setThemeMode(String mode) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    return _prefs!.setString(_kThemeMode, mode);
  }

  bool get enablePush => _prefs?.getBool(_kEnablePush) ?? UserPreferenceDefaults.enablePush;

  Future<bool> setEnablePush(bool value) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    return _prefs!.setBool(_kEnablePush, value);
  }

  bool get firstLaunch => _prefs?.getBool(_kFirstLaunch) ?? UserPreferenceDefaults.firstLaunch;

  Future<bool> setFirstLaunch(bool value) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    return _prefs!.setBool(_kFirstLaunch, value);
  }

  bool get hasShownPartnerAutoShareOnboarding =>
      _prefs?.getBool(_kPartnerAutoShareOnboarding) ??
      UserPreferenceDefaults.hasShownPartnerAutoShareOnboarding;

  Future<bool> setHasShownPartnerAutoShareOnboarding(bool value) async {
    await ensureInitialized();
    if (_prefs == null) return false;
    return _prefs!.setBool(_kPartnerAutoShareOnboarding, value);
  }

  int _readInt(String key, int fallback, {required int min, required int max}) {
    final raw = _prefs?.getInt(key);
    if (raw == null) return fallback;
    if (raw < min || raw > max) return fallback;
    return raw;
  }
}

/// 与 [UserSession] 读路径一致的**编译期**默认值，便于单测与文档对照。
abstract final class UserPreferenceDefaults {
  /// 个人中心等处展示用默认昵称
  static const String defaultNickname = '冰山一角';

  /// 展示用默认手机号
  static const String defaultPhone = '17701601082';

  /// 头像本地路径默认值：空串表示未设置，UI 使用占位图
  static const String defaultAvatarPath = '';

  static const bool autoShareEnabled = true;
  static const bool acceptOthersShareDefault = true;
  static const int defaultPreReminderOffsetDays = 1;
  static const int defaultPreReminderHour = 9;
  static const int defaultPreReminderMinute = 0;
  static const int defaultSameDayReminderHour = 9;
  static const int defaultSameDayReminderMinute = 0;
  static const String themeMode = 'system';
  static const bool enablePush = true;
  static const bool firstLaunch = true;
  static const bool hasShownPartnerAutoShareOnboarding = false;
}

// --- preference keys (single namespace) ---

const String _kAutoShareEnabled = 'tc.prefs.auto_share_enabled';
const String _kAcceptOthersShare = 'tc.prefs.accept_others_share_default';
const String _kDefaultPreOffsetDays = 'tc.prefs.default_pre_offset_days';
const String _kDefaultPreReminderHour = 'tc.prefs.default_pre_reminder_hour';
const String _kDefaultPreReminderMinute = 'tc.prefs.default_pre_reminder_minute';
const String _kDefaultSameDayHour = 'tc.prefs.default_same_day_hour';
const String _kDefaultSameDayMinute = 'tc.prefs.default_same_day_minute';
const String _kThemeMode = 'tc.prefs.theme_mode';
const String _kEnablePush = 'tc.prefs.enable_push';
const String _kFirstLaunch = 'tc.prefs.first_launch';
const String _kPartnerAutoShareOnboarding = 'tc.prefs.partner_auto_share_onboarding';
const String _kNickname = 'tc.prefs.user_nickname';
const String _kPhone = 'tc.prefs.user_phone_display';
const String _kAvatar = 'tc.prefs.user_avatar_path';
