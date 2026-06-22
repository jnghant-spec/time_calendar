import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/models/partner_relation.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/services/user_session.dart';

enum PartnerShareDetailMode { none, active, historical }

class PartnerShareDetailInfo {
  const PartnerShareDetailInfo({
    required this.mode,
    this.partnerName,
    this.statusText,
  });

  final PartnerShareDetailMode mode;
  final String? partnerName;
  final String? statusText;
}

bool hasHistoricalPartnerShare(ListEvent event) {
  if (TagService.shouldShowPartnerShareMarker(event.tagId)) return false;
  if (event.historicalPartnerName?.trim().isNotEmpty == true) return true;
  if (!TagService.isPartnerTag(event.tagId)) return false;
  return TagService.getPartnerRelation().status != PartnerStatus.accepted;
}

String? resolveHistoricalPartnerName(ListEvent event) {
  final hist = event.historicalPartnerName?.trim();
  if (hist != null && hist.isNotEmpty) return hist;
  final relation = TagService.getPartnerRelation();
  final name = relation.partnerName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final modified = event.lastModifiedByName?.trim();
  if (modified != null && modified.isNotEmpty) return modified;
  return null;
}

PartnerShareDetailInfo resolvePartnerShareDetail(ListEvent event) {
  if (TagService.shouldShowPartnerShareMarker(event.tagId)) {
    final name = TagService.getPartnerRelation().partnerName?.trim();
    final displayName =
        name == null || name.isEmpty ? '另一半' : name;
    final autoSync = UserSession.instance.autoShareEnabled;
    final text = autoSync
        ? '已与 $displayName 绑定（实时同步）'
        : '已与 $displayName 绑定（修改仅自己可见）';
    return PartnerShareDetailInfo(
      mode: PartnerShareDetailMode.active,
      partnerName: displayName,
      statusText: text,
    );
  }
  if (hasHistoricalPartnerShare(event)) {
    final name = resolveHistoricalPartnerName(event);
    final displayName =
        name == null || name.isEmpty ? '另一半' : name;
    return PartnerShareDetailInfo(
      mode: PartnerShareDetailMode.historical,
      partnerName: displayName,
      statusText: '曾与 $displayName 共享',
    );
  }
  return const PartnerShareDetailInfo(mode: PartnerShareDetailMode.none);
}

/// 修改者称呼：与当前用户一致时显示「我」。
String resolvePartnerModifiedDisplayName(String modifierName) {
  final name = modifierName.trim();
  if (name.isEmpty) return name;
  final currentName = UserSession.instance.nickname.trim();
  if (currentName.isNotEmpty && name == currentName) return '我';
  return name;
}

/// 伴侣共享场景下的最后修改时间展示。
String formatPartnerModifiedAt(DateTime dt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  final time = '$hour:$minute';
  if (dt.year != reference.year) {
    return '${dt.year}年${dt.month}月${dt.day}日 $time';
  }
  return '${dt.month}月${dt.day}日 $time';
}

/// 生成「最新修改：…」文案；缺少修改者或时间时返回 null。
String? buildPartnerModifiedLabel({
  String? lastModifiedByName,
  DateTime? lastModifiedAt,
}) {
  final modifierName = lastModifiedByName?.trim();
  final at = lastModifiedAt;
  if (modifierName == null || modifierName.isEmpty || at == null) {
    return null;
  }
  final displayName = resolvePartnerModifiedDisplayName(modifierName);
  return '最新修改：$displayName ${formatPartnerModifiedAt(at)}';
}

bool shouldShowInactivePartnerEditAlert(ListEvent event) {
  if (!TagService.isPartnerTag(event.tagId)) return false;
  return TagService.getPartnerRelation().status != PartnerStatus.accepted;
}

Widget buildPartnerShareTitleMarker(
  PartnerShareDetailInfo info, {
  double size = 16,
}) {
  switch (info.mode) {
    case PartnerShareDetailMode.none:
      return const SizedBox.shrink();
    case PartnerShareDetailMode.active:
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: SvgPicture.asset(
          'assets/images/ic_couple_hearts.svg',
          width: size,
          height: size,
        ),
      );
    case PartnerShareDetailMode.historical:
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(
          Icons.favorite_border,
          size: size,
          color: const Color(0xFF9CA3AF),
        ),
      );
  }
}

Widget buildPartnerShareStatusRow(
  PartnerShareDetailInfo info, {
  double iconSize = 12,
  TextStyle? textStyle,
}) {
  if (info.mode == PartnerShareDetailMode.none ||
      info.statusText == null) {
    return const SizedBox.shrink();
  }
  final style = textStyle ??
      const TextStyle(
        fontSize: 12,
        color: Color(0xFF9CA3AF),
        height: 20 / 12,
      );
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (info.mode == PartnerShareDetailMode.active)
        SvgPicture.asset(
          'assets/images/ic_couple_hearts.svg',
          width: iconSize,
          height: iconSize,
        )
      else
        Icon(
          Icons.favorite_border,
          size: iconSize,
          color: const Color(0xFF9CA3AF),
        ),
      const SizedBox(width: 4),
      Text(info.statusText!, style: style),
    ],
  );
}

Future<bool> showInactivePartnerEditDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('对方已不在亲密关系中'),
      content: const Text('你仍可继续编辑此内容，但修改不会同步给对方。'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1A73E8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
  return result == true;
}
