import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:time_calendar/pages/tag_photo_crop_page.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/widgets/user_avatar_circle.dart';

/// 从相册/相机选取头像，1:1 裁剪后写入 Application Support。
Future<String?> pickAndPersistUserAvatar(
  BuildContext context, {
  required ImageSource source,
}) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (file == null || !context.mounted) return null;

    final cropped = await TagPhotoCropPage.show(context, file.path);
    if (cropped == null || !context.mounted) return null;

    final dir = await getApplicationSupportDirectory();
    final dest = File('${dir.path}/avatar.jpg');
    await File(cropped).copy(dest.path);
    await UserSession.instance.setAvatarPath(dest.path);
    return dest.path;
  } on PlatformException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? '无法访问相机，请在系统设置中开启权限'
                : '无法访问相册，请在系统设置中开启权限',
          ),
        ),
      );
    }
    return null;
  }
}

String? loadUserAvatarPath() {
  return UserAvatarCircle.resolveAvatarPath(
    UserSession.instance.avatarLocalPath,
  );
}
