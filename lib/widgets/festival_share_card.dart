import 'package:flutter/material.dart';

/// 节日分享图预览（1080×1920 逻辑像素，导出时 pixelRatio=1）。
class FestivalShareCard extends StatelessWidget {
  const FestivalShareCard({
    super.key,
    required this.festivalName,
    required this.solarLine,
    required this.secondaryLines,
    required this.descriptionExcerpt,
    required this.backgroundColor,
  });

  final String festivalName;
  final String solarLine;
  final List<String> secondaryLines;
  final String descriptionExcerpt;
  final Color backgroundColor;

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
    const padH = 40.0;
    const padV = 60.0;
    const brandH = 60.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 1080,
        height: 1920,
        color: backgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(padH, padV, padH, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    festivalName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 44,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    solarLine,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (secondaryLines.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...secondaryLines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),
                  Expanded(
                    child: Text(
                      descriptionExcerpt,
                      maxLines: 14,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.55,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: brandH,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A73E8),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 36,
                    errorBuilder: (_, _, _) => const SizedBox(width: 36),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '时光日历',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}
