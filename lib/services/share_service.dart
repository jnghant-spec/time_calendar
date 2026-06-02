import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:time_calendar/widgets/calendar/calendar_models.dart';
import 'package:time_calendar/widgets/festival_share_card.dart';

/// 节日分享卡片：Widget → PNG → 系统分享。
class ShareService {
  ShareService._();

  static const int _shareCardWidth = 1080;
  static const int _shareCardHeight = 1920;

  static String _descriptionLine(EventReminderData e) {
    final jsonIntro = (e.festivalDescription ?? '').trim();
    if (jsonIntro.isNotEmpty) return jsonIntro;
    return '';
  }

  static List<String> _secondaryCalendarLines(EventReminderData e) {
    final out = <String>[];
    final lunar = (e.festivalLunarLine ?? '').trim();
    final ethnic = (e.festivalEthnicLine ?? '').trim();
    final religious = (e.festivalReligiousLine ?? '').trim();
    if (lunar.isNotEmpty) out.add('农历：$lunar');
    if (ethnic.isNotEmpty) out.add('民族历：$ethnic');
    if (religious.isNotEmpty) out.add('宗教历：$religious');
    return out;
  }

  static String _truncateDescription(String raw, {int maxChars = 120}) {
    final t = raw.trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars)}…';
  }

  /// 在 **overlay 仍挂载** 的根 [navigatorContext] 下截图分享。
  static Future<void> shareFestivalReminder(
    BuildContext navigatorContext,
    EventReminderData e,
    String solarDisplayStr,
  ) async {
    final bg =
        FestivalShareCard.backgroundForCategoryKey(e.festivalCategoryKey);
    final rawDesc = _descriptionLine(e);
    final excerpt = rawDesc.isEmpty
        ? '用时光集记录每一个值得记住的日子。'
        : _truncateDescription(rawDesc);

    final card = FestivalShareCard(
      festivalName: e.title,
      solarLine: '公历：$solarDisplayStr',
      secondaryLines: _secondaryCalendarLines(e),
      descriptionExcerpt: excerpt,
      backgroundColor: bg,
      photoPaths: e.sourceListEvent?.photoPaths ?? const [],
    );

    final bytes = await _captureCardToPng(navigatorContext, card);
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/festival_share_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    if (!navigatorContext.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: '${e.title} · 时光集',
      ),
    );
  }

  static Future<Uint8List?> _captureCardToPng(
    BuildContext navigatorContext,
    Widget card,
  ) async {
    final overlay = Overlay.maybeOf(navigatorContext);
    if (overlay == null) return null;

    final boundaryKey = GlobalKey();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: -10000,
        top: 0,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: _shareCardWidth.toDouble(),
              height: _shareCardHeight.toDouble(),
              child: card,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    Uint8List? out;
    try {
      final ro = boundaryKey.currentContext?.findRenderObject();
      if (ro is RenderRepaintBoundary) {
        final img = await ro.toImage(pixelRatio: 1);
        final bd =
            await img.toByteData(format: ui.ImageByteFormat.png);
        if (bd != null) {
          out = bd.buffer.asUint8List();
        }
        img.dispose();
      }
    } finally {
      entry.remove();
    }
    return out;
  }
}
