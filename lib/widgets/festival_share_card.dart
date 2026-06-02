import 'package:flutter/material.dart';
import 'package:time_calendar/widgets/share_card_widget.dart';

/// 节日分享图预览（1080×1920 逻辑像素，导出时 pixelRatio=1）。
class FestivalShareCard extends StatelessWidget {
  const FestivalShareCard({
    super.key,
    required this.festivalName,
    required this.solarLine,
    required this.secondaryLines,
    required this.descriptionExcerpt,
    required this.backgroundColor,
    this.photoPaths = const [],
  });

  final String festivalName;
  final String solarLine;
  final List<String> secondaryLines;
  final String descriptionExcerpt;
  final Color backgroundColor;

  /// 可选本地照片（如关联 [ListEvent.photoPaths]）；节日分享默认不传。
  final List<String> photoPaths;

  static Color backgroundForCategoryKey(String? key) {
    switch (key) {
      case 'ethnic':
        return const Color(0xFFEFF6FF);
      case 'religious':
        return const Color(0xFFFFFBEB);
      case 'lunar':
      case 'gregorian':
      default:
        return const Color(0xFFECFDF5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShareCardWidget(
      title: festivalName,
      primaryDateLine: solarLine,
      secondaryLines: secondaryLines,
      descriptionExcerpt: descriptionExcerpt,
      backgroundColor: backgroundColor,
      photoPaths: photoPaths,
    );
  }
}
