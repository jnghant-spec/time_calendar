import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_calendar/pages/personal_info_page.dart';
import 'package:time_calendar/pages/festival_settings_page.dart';
import 'package:time_calendar/pages/preference_settings_page.dart';
import 'package:time_calendar/pages/share_management_page.dart';
import 'package:time_calendar/services/user_session.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 与稿期一致，后续可接会员 / 使用额度服务
  static const int _usedEvents = 9;
  static const int _eventCap = 20;

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: cs.surface,
        child: SafeArea(
          top: true,
          bottom: true,
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
                usedEvents: _usedEvents,
                eventCap: _eventCap,
              ),
              Expanded(
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    required this.usedEvents,
    required this.eventCap,
  });

  final double hPad;
  final double vBlock;
  final double screenWidth;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final String nickname;
  final String phone;
  final int usedEvents;
  final int eventCap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final ratio = (usedEvents / eventCap).clamp(0.0, 1.0);
    final avatarD = (screenWidth * 0.22).clamp(72.0, 100.0);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, (vBlock * 0.8).clamp(16.0, 24.0)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            Color.lerp(cs.primary, cs.onPrimary, 0.1)!,
            Color.lerp(cs.primary, cs.onPrimary, 0.18)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: avatarD,
                height: avatarD,
                padding: EdgeInsets.symmetric(
                  horizontal: avatarD * 0.2,
                  vertical: avatarD * 0.1,
                ),
                decoration: BoxDecoration(
                  color: cs.onPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.onPrimary.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/ic_avatar.svg',
                    width: avatarD * 0.4,
                    height: avatarD * 0.4,
                    fit: BoxFit.contain,
                  ),
                ),
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
            ],
          ),
          SizedBox(height: (vBlock * 0.5).clamp(12.0, 16.0)),
          Material(
            color: cs.onPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                // 预留：跳转会员
              },
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
                            '基础版会员',
                            style: textTheme.bodyLarge?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;

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
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const PersonalInfoPage(),
                  ),
                );
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
