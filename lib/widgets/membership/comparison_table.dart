import 'package:flutter/material.dart';

import 'package:time_calendar/models/membership_tier.dart';

class MembershipComparisonTable extends StatelessWidget {
  const MembershipComparisonTable({
    super.key,
    required this.currentTier,
  });

  final MembershipTier currentTier;

  static const _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Color(0xFF94A3B8),
  );

  static const _featureStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF334155),
  );

  Color _columnTint(MembershipTier column) {
    if (column != currentTier) return Colors.transparent;
    return column == MembershipTier.premium
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFEFF6FF);
  }

  TextStyle _cellStyle(MembershipTier column, {bool bold = false}) {
    final base = _featureStyle;
    if (column != currentTier) return base;
    final color = column == MembershipTier.premium
        ? const Color(0xFFB45309)
        : const Color(0xFF1A73E8);
    return base.copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    const tiers = MembershipTier.values;
    const rowH = 44.0;
    const featureW = 132.0;
    const colW = 96.0;

    Widget cell(String text, MembershipTier col,
        {bool check = false, bool dash = false}) {
      final tint = _columnTint(col);
      Widget inner;
      if (check) {
        inner = Icon(
          Icons.check_rounded,
          size: 20,
          color: col == MembershipTier.premium
              ? const Color(0xFFF59E0B)
              : const Color(0xFF1A73E8),
        );
      } else if (dash) {
        inner = Container(
          width: 14,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      } else {
        inner = Text(
          text,
          textAlign: TextAlign.center,
          style: _cellStyle(col),
        );
      }
      return Container(
        width: colW,
        height: rowH,
        color: tint,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: inner,
      );
    }

    Widget featureCell(String label) {
      return SizedBox(
        width: featureW,
        height: rowH,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(label, style: _featureStyle),
          ),
        ),
      );
    }

    Widget headerCell(String label, MembershipTier? col) {
      final tint =
          col == null ? Colors.white : _columnTint(col);
      return Container(
        width: col == null ? featureW : colW,
        height: rowH,
        color: tint,
        alignment: col == null ? Alignment.centerLeft : Alignment.center,
        padding: EdgeInsets.only(left: col == null ? 4 : 0),
        child: Text(
          label,
          textAlign: col == null ? TextAlign.left : TextAlign.center,
          style: _headerStyle,
        ),
      );
    }

    final rows = <List<Widget>>[
      [
        headerCell('功能项', null),
        ...tiers.map((t) => headerCell(MembershipConfig.benefits[t]!.label, t)),
      ],
      [
        featureCell('提醒事项总数'),
        cell('8 个', MembershipTier.free),
        cell('20 个', MembershipTier.basic),
        cell('200 个', MembershipTier.premium),
      ],
      [
        featureCell('农历生日循环'),
        cell('', MembershipTier.free, dash: true),
        cell('', MembershipTier.basic, check: true),
        cell('', MembershipTier.premium, check: true),
      ],
      [
        featureCell('民族节日名额'),
        cell('3 个', MembershipTier.free),
        cell('8 个', MembershipTier.basic),
        cell('20 个', MembershipTier.premium),
      ],
      [
        featureCell('宗教节日名额'),
        cell('3 个', MembershipTier.free),
        cell('8 个', MembershipTier.basic),
        cell('全部', MembershipTier.premium),
      ],
      [
        featureCell('照片上传'),
        cell('', MembershipTier.free, dash: true),
        cell('3 张/事件', MembershipTier.basic),
        cell('10 张/事件', MembershipTier.premium),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFE2E8F0),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: rows[i],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
