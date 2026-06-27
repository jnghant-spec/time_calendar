import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/pages/membership_sheet.dart';
import 'package:time_calendar/pages/personal_info_page.dart';
import 'package:time_calendar/pages/festival_settings_page.dart';
import 'package:time_calendar/pages/preference_settings_page.dart';
import 'package:time_calendar/pages/share_management_page.dart';
import 'package:time_calendar/services/event_usage_service.dart';
import 'package:time_calendar/services/membership_service.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/utils/user_avatar_picker.dart';
import 'package:time_calendar/widgets/user_avatar_circle.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.onMembershipTierChanged,
  });

  final VoidCallback? onMembershipTierChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  MembershipTier _tier = MembershipTier.free;
  bool _trialActive = false;
  int? _trialDays;

  @override
  void initState() {
    super.initState();
    _reloadTier();
    // `maybeOfferNewUserPremiumTrial` 在首帧后异步写入 prefs，再读一次避免短暂显示非体验状态。
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadTier());
  }

  Future<void> _reloadTier() async {
    final t = await MembershipService.currentTier();
    final trialOn = await MembershipService.isPremiumTrialActive();
    final days = await MembershipService.trialRemainingWholeDays();
    if (!mounted) return;
    setState(() {
      _tier = t;
      _trialActive = trialOn;
      _trialDays = trialOn ? days : null;
    });
  }

  Future<void> _openMembershipSheet() async {
    await showMembershipSheet(
      context,
      onTierChanged: () {
        widget.onMembershipTierChanged?.call();
        _reloadTier();
      },
    );
    await _reloadTier();
  }

  Future<void> _openPersonalInfo() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PersonalInfoPage()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    final hPad = w * 0.04;
    final vBlock = h * 0.025;
    final session = UserSession.instance;
    final nickname = session.nickname;
    final phone = session.phone;
    final quota =
        MembershipService.benefits(_tier).reminderQuota.clamp(1, 999999);
    final used = EventUsageService.currentCount;
    final avatarPath = loadUserAvatarPath();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: cs.surface,
        child: Column(
          children: [
            _ProfileHeader(
              hPad: hPad,
              vBlock: vBlock,
              screenWidth: w,
              textTheme: textTheme,
              colorScheme: cs,
              nickname: nickname,
              phone: phone,
              avatarPath: avatarPath,
              usedEvents: used,
              eventCap: quota,
              membershipTitle:
                  '${MembershipConfig.benefits[_tier]!.label}会员',
              trialBadgeText: _trialActive && _trialDays != null
                  ? '高级体验还剩 $_trialDays 天'
                  : null,
              onProfileTap: _openPersonalInfo,
              onMembershipTap: _openMembershipSheet,
            ),
            Expanded(
              child: SafeArea(
                top: false,
                bottom: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    hPad,
                    vBlock * 0.5,
                    hPad,
                    vBlock * 1.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '功能设置',
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: (vBlock * 0.3).clamp(8.0, 12.0)),
                      _FeatureMenu(
                        colorScheme: cs,
                        textTheme: textTheme,
                        onOpenPersonalInfo: _openPersonalInfo,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  hPad.clamp(16.0, 24.0),
                  6,
                  hPad.clamp(16.0, 24.0),
                  10,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _openMembershipSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      height: 50,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFF1A73E8),
                            Color(0xFF60A5FA),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '升级会员，解锁全部功能',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.hPad,
    required this.vBlock,
    required this.screenWidth,
    required this.textTheme,
    required this.colorScheme,
    required this.nickname,
    required this.phone,
    this.avatarPath,
    required this.usedEvents,
    required this.eventCap,
    required this.membershipTitle,
    this.trialBadgeText,
    required this.onProfileTap,
    required this.onMembershipTap,
  });

  final double hPad;
  final double vBlock;
  final double screenWidth;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final String nickname;
  final String phone;
  final String? avatarPath;
  final int usedEvents;
  final int eventCap;
  final String membershipTitle;
  final String? trialBadgeText;
  final VoidCallback onProfileTap;
  final VoidCallback onMembershipTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final ratio = (usedEvents / eventCap).clamp(0.0, 1.0);
    final avatarD = (screenWidth * 0.22).clamp(72.0, 100.0);
    final safeTop = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        hPad,
        safeTop + 12,
        hPad,
        (vBlock * 0.8).clamp(16.0, 24.0),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface,
            const Color(0xFFEFF6FF),
            Color.lerp(cs.primary, Colors.white, 0.35)!,
            cs.primary,
          ],
          stops: const [0.0, 0.18, 0.45, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(12),
              splashColor: cs.onPrimary.withValues(alpha: 0.12),
              highlightColor: cs.onPrimary.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    UserAvatarCircle.build(
                      diameter: avatarD,
                      colorScheme: cs,
                      avatarPath: avatarPath,
                      onPrimaryBackground: true,
                    ),
                    SizedBox(width: (vBlock * 0.6).clamp(12.0, 16.0)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleLarge?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: (vBlock * 0.15).clamp(4.0, 6.0)),
                          Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyLarge?.copyWith(
                              color: cs.onPrimary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: cs.onPrimary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: (vBlock * 0.5).clamp(12.0, 16.0)),
          Material(
            color: cs.onPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onMembershipTap,
              borderRadius: BorderRadius.circular(12),
              splashColor: cs.onPrimary.withValues(alpha: 0.1),
              highlightColor: cs.onPrimary.withValues(alpha: 0.06),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.onPrimary.withValues(alpha: 0.2),
                    width: 0.7,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: SvgPicture.asset(
                            'assets/images/ic_crown.svg',
                            fit: BoxFit.contain,
                            colorFilter: ColorFilter.mode(
                              cs.tertiary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            membershipTitle,
                            style: textTheme.bodyLarge?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if ((trialBadgeText ?? '').isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              trialBadgeText!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: cs.onPrimary.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                    SizedBox(height: (vBlock * 0.3).clamp(6.0, 10.0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '已用事件',
                          style: textTheme.bodySmall?.copyWith(
                            color: cs.onPrimary.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          '$usedEvents/$eventCap',
                          style: textTheme.bodySmall?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: ratio),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Stack(
                            children: [
                              Container(
                                height: 6,
                                color: cs.onPrimary.withValues(alpha: 0.2),
                              ),
                              FractionallySizedBox(
                                widthFactor: value,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  height: 6,
                                  color: cs.onPrimary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureMenu extends StatelessWidget {
  const _FeatureMenu({
    required this.colorScheme,
    required this.textTheme,
    required this.onOpenPersonalInfo,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final Future<void> Function() onOpenPersonalInfo;

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItemData>[
      _MenuItemData(
        asset: 'assets/images/ic_personal.svg',
        title: '个人信息',
        subtitle: '头像、昵称设置',
      ),
      _MenuItemData(
        asset: 'assets/images/ic_share.svg',
        title: '共享管理',
        subtitle: '邀请与响应',
      ),
      _MenuItemData(
        asset: 'assets/images/ic_fastival.svg',
        title: '节日设置',
        subtitle: '节日订阅管理',
      ),
      _MenuItemData(
        asset: 'assets/images/ic_preference.svg',
        title: '偏好设置',
        subtitle: '通知、隐私等',
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _MenuTile(
            data: items[i],
            colorScheme: colorScheme,
            textTheme: textTheme,
            onTap: () {
              if (items[i].title == '个人信息') {
                onOpenPersonalInfo();
              } else if (items[i].title == '共享管理') {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const ShareManagementPage(),
                  ),
                );
              } else if (items[i].title == '节日设置') {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const FestivalSettingsPage(),
                  ),
                );
              } else if (items[i].title == '偏好设置') {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const PreferenceSettingsPage(),
                  ),
                );
              }
            },
          ),
        ],
      ],
    );
  }
}

class _MenuItemData {
  const _MenuItemData({
    required this.asset,
    required this.title,
    required this.subtitle,
  });

  final String asset;
  final String title;
  final String subtitle;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.data,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  final _MenuItemData data;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: cs.primary.withValues(alpha: 0.08),
        highlightColor: cs.primary.withValues(alpha: 0.04),
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outline,
              width: 0.7,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SvgPicture.asset(
                    data.asset,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(
                      cs.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.06,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}
