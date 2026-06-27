import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 圆形用户头像：有本地文件且存在则 [Image.file] cover，否则 ic_avatar.svg 占位。
class UserAvatarCircle {
  UserAvatarCircle._();

  static String? resolveAvatarPath(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    if (!File(avatarPath).existsSync()) return null;
    return avatarPath;
  }

  static Widget build({
    required double diameter,
    required ColorScheme colorScheme,
    String? avatarPath,
    bool onPrimaryBackground = false,
  }) {
    final cs = colorScheme;
    final resolved = resolveAvatarPath(avatarPath);
    final bgColor = onPrimaryBackground
        ? cs.onPrimary.withValues(alpha: 0.2)
        : cs.primary.withValues(alpha: 0.1);
    final borderColor = onPrimaryBackground
        ? cs.onPrimary.withValues(alpha: 0.3)
        : cs.primary.withValues(alpha: 0.2);
    final placeholderColor = onPrimaryBackground ? cs.onPrimary : cs.primary;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: resolved == null ? bgColor : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: onPrimaryBackground ? 1.2 : 1.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolved != null
          ? Image.file(
              File(resolved),
              fit: BoxFit.cover,
              width: diameter,
              height: diameter,
            )
          : Center(
              child: SvgPicture.asset(
                'assets/images/ic_avatar.svg',
                width: diameter * (onPrimaryBackground ? 0.4 : 0.45),
                height: diameter * (onPrimaryBackground ? 0.4 : 0.45),
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(
                  placeholderColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
    );
  }
}
