import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:time_calendar/pages/edit_nickname_page.dart';
import 'package:time_calendar/pages/switch_account_page.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/utils/user_avatar_picker.dart';
import 'package:time_calendar/widgets/user_avatar_circle.dart';

/// 个人信息（头像、昵称、手机号、切换账号、退出登录）。
class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  /// 与编辑页、本地 [UserSession] 对齐的原始昵称，空时列表展示「用户昵称」
  late String _nickname;
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _nickname = UserSession.instance.nickname.trim();
    _avatarPath = loadUserAvatarPath();
  }

  String get _displayNickname => _nickname.isEmpty ? '用户昵称' : _nickname;

  Future<void> _pickAvatar(ImageSource source) async {
    final path = await pickAndPersistUserAvatar(context, source: source);
    if (!mounted || path == null) return;
    setState(() => _avatarPath = path);
  }

  void _showAvatarSourceBottomSheet() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: cs.onSurface.withValues(alpha: 0.4),
      builder: (ctx) {
        final w = MediaQuery.sizeOf(ctx).width;
        final h = MediaQuery.sizeOf(ctx).height;
        final hPad = w * 0.04;
        final maxH = h * 0.5;
        return SafeArea(
          top: false,
          bottom: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                            child: Center(
                              child: Text(
                                '选择头像来源',
                                style: textTheme.titleMedium?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: cs.outline,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: _AvatarSourceOption(
                              textTheme: textTheme,
                              colorScheme: cs,
                              icon: Icons.photo_library,
                              label: '从手机相册选择',
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _pickAvatar(ImageSource.gallery);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: Divider(
                              height: 0.5,
                              thickness: 0.5,
                              color: cs.outline,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: _AvatarSourceOption(
                              textTheme: textTheme,
                              colorScheme: cs,
                              icon: Icons.camera_alt,
                              label: '拍照上传',
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _pickAvatar(ImageSource.camera);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    borderRadius: BorderRadius.circular(12),
                    splashColor: cs.onSurfaceVariant.withValues(alpha: 0.1),
                    child: Ink(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outline, width: 0.7),
                      ),
                      child: Center(
                        child: Text(
                          '取消',
                          style: textTheme.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
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
      },
    );
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
    final displayPhone = session.phone;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: cs.surfaceContainerHigh,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: cs.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: cs.surface,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: cs.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '返回',
          ),
          title: Text(
            '个人信息',
            style: textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 0.7,
              color: cs.outline,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          minimum: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              hPad,
              (vBlock * 0.8).clamp(12.0, 20.0),
              hPad,
              (vBlock * 1.2),
            ),
            children: [
              _AvatarSection(
                colorScheme: cs,
                textTheme: textTheme,
                screenWidth: w,
                vBlock: vBlock,
                avatarPath: _avatarPath,
                onOpenAvatarSource: _showAvatarSourceBottomSheet,
              ),
              SizedBox(height: (vBlock * 0.3).clamp(8.0, 12.0)),
              _InfoCard(
                colorScheme: cs,
                textTheme: textTheme,
                leading: SvgPicture.asset(
                  'assets/images/ic_personal.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(cs.primary, BlendMode.srcIn),
                ),
                label: '昵称',
                value: _displayNickname,
                onTap: () async {
                  final result = await Navigator.of(context).push<String>(
                    MaterialPageRoute<String>(
                      builder: (context) => EditNicknamePage(
                        currentNickname: _nickname,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  if (result != null && result.isNotEmpty) {
                    setState(() {
                      _nickname = result;
                    });
                    // TODO(后端): 同步昵称到服务端
                    await UserSession.instance.setNickname(result);
                  }
                },
              ),
              const SizedBox(height: 12),
              _InfoCard(
                colorScheme: cs,
                textTheme: textTheme,
                leading: Icon(
                  Icons.smartphone,
                  size: 20,
                  color: cs.primary,
                ),
                label: '手机号',
                value: displayPhone,
                showChevron: false,
                onTap: () {
                  // 预留
                },
              ),
              const SizedBox(height: 12),
              _InfoCard(
                colorScheme: cs,
                textTheme: textTheme,
                leading: Icon(
                  Icons.sync,
                  size: 20,
                  color: cs.primary,
                ),
                label: '切换账号',
                value: null,
                showValue: false,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const SwitchAccountPage(),
                    ),
                  );
                },
              ),
              SizedBox(height: (vBlock * 1.0).clamp(20.0, 32.0)),
              _LogoutButton(
                colorScheme: cs,
                textTheme: textTheme,
                onTap: () {
                  // 预留：接登出
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarSourceOption extends StatelessWidget {
  const _AvatarSourceOption({
    required this.textTheme,
    required this.colorScheme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final tileBg = Color.lerp(
      cs.surfaceContainerHigh,
      cs.onSurface,
      0.045,
    )!;
    return Material(
      color: tileBg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: cs.primary.withValues(alpha: 0.1),
        highlightColor: cs.primary.withValues(alpha: 0.04),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, size: 24, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.colorScheme,
    required this.textTheme,
    required this.screenWidth,
    required this.vBlock,
    required this.avatarPath,
    required this.onOpenAvatarSource,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final double screenWidth;
  final double vBlock;
  final String? avatarPath;
  final VoidCallback onOpenAvatarSource;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final avatarD = (screenWidth * 0.24).clamp(80.0, 100.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenAvatarSource,
        borderRadius: BorderRadius.circular(12),
        splashColor: cs.primary.withValues(alpha: 0.1),
        highlightColor: cs.primary.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatarCircle.build(
                diameter: avatarD,
                colorScheme: cs,
                avatarPath: avatarPath,
                onPrimaryBackground: false,
              ),
              SizedBox(height: (vBlock * 0.45).clamp(8.0, 14.0)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '更换头像',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.colorScheme,
    required this.textTheme,
    required this.leading,
    required this.label,
    required this.onTap,
    this.value,
    this.showValue = true,
    this.showChevron = true,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final Widget leading;
  final String label;
  final String? value;
  final bool showValue;
  /// 为 `false` 时不显示右侧 `>`（如仅展示的手机号行）。
  final bool showChevron;
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline, width: 0.7),
            color: cs.surfaceContainerHigh,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (showValue && value != null)
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              value!,
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: textTheme.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          if (showChevron) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                    )
                  else if (!showValue)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
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

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: cs.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: cs.error.withValues(alpha: 0.2),
        highlightColor: cs.error.withValues(alpha: 0.1),
        child: Ink(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: cs.error.withValues(alpha: 0.1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 18, color: cs.error),
              const SizedBox(width: 6),
              Text(
                '退出登录',
                style: textTheme.bodyLarge?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
