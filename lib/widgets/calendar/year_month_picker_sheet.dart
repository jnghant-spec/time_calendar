import 'package:flutter/material.dart';

class YearMonthPickerResult {
  const YearMonthPickerResult({required this.year, required this.month});

  final int year;
  final int month;
}

/// 双列：左年份、右月份，中文，顶部 取消/确定，中间选中行浅蓝高亮。
Future<YearMonthPickerResult?> showYearMonthPicker(
  BuildContext context, {
  required int initialYear,
  required int initialMonth,
  int yearMin = 1900,
  int yearMax = 2050,
}) {
  return showModalBottomSheet<YearMonthPickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _YearMonthBody(
        initialYear: initialYear,
        initialMonth: initialMonth,
        yearMin: yearMin,
        yearMax: yearMax,
      );
    },
  );
}

class _YearMonthBody extends StatefulWidget {
  const _YearMonthBody({
    required this.initialYear,
    required this.initialMonth,
    required this.yearMin,
    required this.yearMax,
  });

  final int initialYear;
  final int initialMonth;
  final int yearMin;
  final int yearMax;

  @override
  State<_YearMonthBody> createState() => _YearMonthBodyState();
}

class _YearMonthBodyState extends State<_YearMonthBody> {
  static const _muted = Color(0xFF64748B);
  static const _primary = Color(0xFF1D4ED8);
  static const _highlightFill = Color(0xFFDBEAFE);
  static const _textNormal = Color(0xFF0F172A);

  static const _itemH = 40.0;

  late int _y;
  late int _m;
  late final FixedExtentScrollController _yCtrl;
  late final FixedExtentScrollController _mCtrl;

  @override
  void initState() {
    super.initState();
    _y = widget.initialYear.clamp(widget.yearMin, widget.yearMax);
    _m = widget.initialMonth.clamp(1, 12);
    _yCtrl = FixedExtentScrollController(initialItem: _y - widget.yearMin);
    _mCtrl = FixedExtentScrollController(initialItem: _m - 1);
  }

  @override
  void dispose() {
    _yCtrl.dispose();
    _mCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yearCount = widget.yearMax - widget.yearMin + 1;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消', style: TextStyle(color: _muted, fontWeight: FontWeight.w500)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        YearMonthPickerResult(year: _y, month: _m),
                      );
                    },
                    child: const Text('确定', style: TextStyle(color: _primary, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 5 * _itemH,
                child: Row(
                  children: [
                    Expanded(
                      child: _wheel(
                        controller: _yCtrl,
                        itemCount: yearCount,
                        onChanged: (i) => setState(() => _y = widget.yearMin + i),
                        label: (i) => '${widget.yearMin + i}年',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _wheel(
                        controller: _mCtrl,
                        itemCount: 12,
                        onChanged: (i) => setState(() => _m = i + 1),
                        label: (i) => '${i + 1}月',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required void Function(int i) onChanged,
    required String Function(int i) label,
  }) {
    return Stack(
      children: [
        Center(
          child: IgnorePointer(
            child: Container(
              height: _itemH,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _highlightFill,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: _itemH,
          perspective: 0.003,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (context, i) {
              return RepaintBoundary(
                child: Center(
                  child: Text(
                    label(i),
                    style: const TextStyle(
                      color: _textNormal,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
