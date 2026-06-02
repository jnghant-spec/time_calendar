import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:time_calendar/pages/tag_photo_crop_page.dart';
import 'package:time_calendar/widgets/tag_circle_widget.dart';

/// 新建/编辑标签弹窗中的「标签照片」预览与上传区。
class TagIconEditor extends StatelessWidget {
  const TagIconEditor({
    super.key,
    required this.accentColor,
    required this.photoPath,
    required this.iconName,
    required this.onPhotoPathChanged,
    required this.onIconNameChanged,
  });

  final Color accentColor;
  final String? photoPath;
  final String? iconName;
  final ValueChanged<String?> onPhotoPathChanged;
  final ValueChanged<String?> onIconNameChanged;

  static const double previewSize = 80;
  static const Color _hintColor = Color(0xFF94A3B8);

  Future<void> _pickPhoto(BuildContext context, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 95,
      );
      if (file == null || !context.mounted) return;
      final cropped = await TagPhotoCropPage.show(context, file.path);
      if (cropped != null) {
        onIconNameChanged(null);
        onPhotoPathChanged(cropped);
      }
    } catch (_) {}
  }

  Future<void> _showSourceSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Material(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.photo_library_outlined),
                      title: const Text('从相册选取'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickPhoto(context, ImageSource.gallery);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_camera_outlined),
                      title: const Text('拍照'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickPhoto(context, ImageSource.camera);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _previewContent() {
    final hasPhoto = photoPath != null &&
        photoPath!.isNotEmpty &&
        File(photoPath!).existsSync();
    if (hasPhoto) {
      return Image.file(
        File(photoPath!),
        fit: BoxFit.cover,
        width: previewSize,
        height: previewSize,
      );
    }
    final icon = TagPresetIcons.dataFor(iconName);
    if (icon != null) {
      return Icon(icon, color: Colors.white, size: 40);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null &&
        photoPath!.isNotEmpty &&
        File(photoPath!).existsSync();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _showSourceSheet(context),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: previewSize,
                height: previewSize,
                decoration: BoxDecoration(
                  color: hasPhoto ? null : accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: _previewContent(),
              ),
              const SizedBox(height: 8),
              const Text(
                '点击更换照片',
                style: TextStyle(
                  fontSize: 14,
                  color: _hintColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
