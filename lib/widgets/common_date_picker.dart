import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lunar/lunar.dart';
import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/services/membership_service.dart';
import 'package:time_calendar/utils/event_date_utils.dart';
import 'package:time_calendar/widgets/membership_soft_paywall.dart';

// --- 与清单添加事件页 event_add_page 日期滚轮视觉一致 ---

const Color _kThemeBlue = Color(0xFF1A73E8);
const Color _kTitleColor = Color(0xFF0F172A);
const Color _kCloseGrey = Color(0xFF64748B);

Widget appDateWheelLabelCell(String text, bool isSelected) {
  final style = TextStyle(
    fontSize: 18,
    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
  );
  return SizedBox(
    height: 40,
    child: Center(
      child: isSelected
          ? Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                text,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                text,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
    ),
  );
}

class AppTransparentPickerOverlay extends StatelessWidget {
  const AppTransparentPickerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(child: SizedBox.expand());
  }
}

class AppDatePickerSheetShell extends StatelessWidget {
  const AppDatePickerSheetShell({
    super.key,
    required this.title,
    required this.child,
    required this.onCancel,
    required this.onConfirm,
    this.cancelLabel = '取消',
    this.confirmLabel = '确定',
  });

  final String title;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: onCancel,
                      child: Text(
                        cancelLabel,
                        style: const TextStyle(color: _kCloseGrey, fontSize: 16),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _kTitleColor,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onConfirm,
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          color: _kThemeBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 公历滚轮（与 event_add_page._SolarDatePickerModal 一致）。
class AppSolarDatePickerModal extends StatefulWidget {
  const AppSolarDatePickerModal({
    super.key,
    required this.initialDate,
    required this.onCancel,
    required this.onConfirm,
  });

  final DateTime initialDate;
  final VoidCallback onCancel;
  final ValueChanged<DateTime> onConfirm;

  @override
  State<AppSolarDatePickerModal> createState() =>
      _AppSolarDatePickerModalState();
}

class _AppSolarDatePickerModalState extends State<AppSolarDatePickerModal> {
  late int y;
  late int m;
  late int d;
  late FixedExtentScrollController _yearCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  void _clampDay() {
    final maxD = _daysInMonth(y, m);
    if (d > maxD) d = maxD;
    if (d < 1) d = 1;
  }

  void _remountDayController() {
    _clampDay();
    _dayCtrl.dispose();
    _dayCtrl = FixedExtentScrollController(initialItem: d - 1);
  }

  void _animatePickersToIndices() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await Future.wait([
          _yearCtrl.animateToItem(
            y - 1900,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
          _monthCtrl.animateToItem(
            m - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
          _dayCtrl.animateToItem(
            d - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
        ]);
      } catch (_) {}
    });
  }

  @override
  void initState() {
    super.initState();
    final i = widget.initialDate;
    y = i.year.clamp(1900, 2100);
    m = i.month.clamp(1, 12);
    d = i.day;
    _clampDay();
    _yearCtrl = FixedExtentScrollController(initialItem: y - 1900);
    _monthCtrl = FixedExtentScrollController(initialItem: m - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: d - 1);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxDay = _daysInMonth(y, m);

    return AppDatePickerSheetShell(
      title: '选择公历日期',
      onCancel: widget.onCancel,
      onConfirm: () => widget.onConfirm(DateTime(y, m, d)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () {
              final n = DateTime.now();
              final ny = n.year.clamp(1900, 2100);
              final nm = n.month;
              final nd = n.day.clamp(1, _daysInMonth(ny, nm));
              setState(() {
                y = ny;
                m = nm;
                d = nd;
                _remountDayController();
              });
              _animatePickersToIndices();
            },
            child: const Text('今天', style: TextStyle(color: _kThemeBlue, fontSize: 14)),
          ),
          SizedBox(
            height: 216,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: CupertinoPicker(
                    selectionOverlay: const AppTransparentPickerOverlay(),
                    scrollController: _yearCtrl,
                    itemExtent: 40,
                    diameterRatio: 1.2,
                    magnification: 1.0,
                    squeeze: 0.9,
                    looping: false,
                    onSelectedItemChanged: (i) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        y = 1900 + i;
                        _remountDayController();
                      });
                    },
                    children: List.generate(
                      201,
                      (i) =>
                          appDateWheelLabelCell('${1900 + i}年', (1900 + i) == y),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: CupertinoPicker(
                    selectionOverlay: const AppTransparentPickerOverlay(),
                    scrollController: _monthCtrl,
                    itemExtent: 40,
                    diameterRatio: 1.2,
                    magnification: 1.0,
                    squeeze: 0.9,
                    looping: false,
                    onSelectedItemChanged: (i) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        m = i + 1;
                        _remountDayController();
                      });
                    },
                    children: List.generate(
                      12,
                      (i) => appDateWheelLabelCell('${i + 1}月', (i + 1) == m),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: CupertinoPicker(
                    selectionOverlay: const AppTransparentPickerOverlay(),
                    scrollController: _dayCtrl,
                    itemExtent: 40,
                    diameterRatio: 1.2,
                    magnification: 1.0,
                    squeeze: 0.9,
                    looping: false,
                    onSelectedItemChanged: (i) {
                      HapticFeedback.lightImpact();
                      setState(() => d = i + 1);
                    },
                    children: List.generate(
                      maxDay,
                      (i) => appDateWheelLabelCell('${i + 1}日', (i + 1) == d),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 农历滚轮（与 event_add_page._LunarDatePickerModal 一致）。
class AppLunarDatePickerModal extends StatefulWidget {
  const AppLunarDatePickerModal({
    super.key,
    required this.initialYear,
    required this.initialMonthSigned,
    required this.initialDay,
    required this.onCancel,
    required this.onConfirm,
  });

  final int initialYear;
  final int initialMonthSigned;
  final int initialDay;
  final VoidCallback onCancel;
  final void Function(int year, int monthSigned, int day) onConfirm;

  @override
  State<AppLunarDatePickerModal> createState() =>
      _AppLunarDatePickerModalState();
}

class _AppLunarDatePickerModalState extends State<AppLunarDatePickerModal> {
  late int y;
  late int monthIndex;
  late int day;
  late FixedExtentScrollController _yearCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;

  List<LunarMonth> get _months => LunarYear.fromYear(y).getMonths();
  LunarMonth get _selMonth => _months[monthIndex];
  int get _maxDay => _selMonth.getDayCount();

  static String _monthLabel(LunarMonth m) {
    final abs = m.getMonth().abs();
    final leap = m.getMonth() < 0;
    return '${leap ? '闰' : ''}${LunarUtil.MONTH[abs]}月';
  }

  @override
  void initState() {
    super.initState();
    y = widget.initialYear;
    final months = LunarYear.fromYear(y).getMonths();
    monthIndex =
        months.indexWhere((m) => m.getMonth() == widget.initialMonthSigned);
    if (monthIndex < 0) monthIndex = 0;
    day = widget.initialDay.clamp(1, months[monthIndex].getDayCount());
    _yearCtrl = FixedExtentScrollController(initialItem: y - 1900);
    _monthCtrl = FixedExtentScrollController(initialItem: monthIndex);
    _dayCtrl = FixedExtentScrollController(initialItem: day - 1);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  void _remountMonthAndDayControllers() {
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    monthIndex = monthIndex.clamp(0, _months.length - 1);
    day = day.clamp(1, _selMonth.getDayCount());
    _monthCtrl = FixedExtentScrollController(initialItem: monthIndex);
    _dayCtrl = FixedExtentScrollController(initialItem: day - 1);
  }

  void _remountDayController() {
    _dayCtrl.dispose();
    day = day.clamp(1, _maxDay);
    _dayCtrl = FixedExtentScrollController(initialItem: day - 1);
  }

  @override
  Widget build(BuildContext context) {
    final months = _months;
    final sel = _selMonth;
    final md = _maxDay;

    return AppDatePickerSheetShell(
      title: '选择农历日期',
      onCancel: widget.onCancel,
      onConfirm: () => widget.onConfirm(y, sel.getMonth(), day),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () async {
              final n = DateTime.now();
              final lun = Lunar.fromDate(n);
              final newY = lun.getYear();
              final mList = LunarYear.fromYear(newY).getMonths();
              final idx = mList.indexWhere((x) => x.getMonth() == lun.getMonth());
              final newMi = idx >= 0 ? idx : 0;
              final newDay = lun.getDay().clamp(1, mList[newMi].getDayCount());
              final oldY = y;
              setState(() {
                y = newY;
                monthIndex = newMi;
                day = newDay;
                if (newY != oldY) {
                  _remountMonthAndDayControllers();
                } else {
                  _remountDayController();
                }
              });
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                try {
                  await Future.wait([
                    _yearCtrl.animateToItem(
                      y - 1900,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                    _monthCtrl.animateToItem(
                      monthIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                    _dayCtrl.animateToItem(
                      day - 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                  ]);
                } catch (_) {}
              });
            },
            child: const Text('今天', style: TextStyle(color: _kThemeBlue, fontSize: 14)),
          ),
          SizedBox(
            height: 216,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: CupertinoPicker(
                    selectionOverlay: const AppTransparentPickerOverlay(),
                    scrollController: _yearCtrl,
                    itemExtent: 40,
                    diameterRatio: 1.2,
                    magnification: 1.0,
                    squeeze: 0.9,
                    looping: false,
                    onSelectedItemChanged: (i) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        y = 1900 + i;
                        _remountMonthAndDayControllers();
                      });
                    },
                    children: List.generate(
                      201,
                      (i) =>
                          appDateWheelLabelCell('${1900 + i}年', (1900 + i) == y),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: CupertinoPicker(
                    selectionOverlay: const AppTransparentPickerOverlay(),
                    scrollController: _monthCtrl,
                    itemExtent: 40,
                    diameterRatio: 1.2,
                    magnification: 1.0,
                    squeeze: 0.9,
                    looping: false,
                    onSelectedItemChanged: (i) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        monthIndex = i;
                        _remountDayController();
                      });
                    },
                    children: [
                      for (var i = 0; i < months.length; i++)
                        appDateWheelLabelCell(_monthLabel(months[i]), i == monthIndex),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: CupertinoPicker(
                    selectionOverlay: const AppTransparentPickerOverlay(),
                    scrollController: _dayCtrl,
                    itemExtent: 40,
                    diameterRatio: 1.2,
                    magnification: 1.0,
                    squeeze: 0.9,
                    looping: false,
                    onSelectedItemChanged: (i) {
                      HapticFeedback.lightImpact();
                      setState(() => day = i + 1);
                    },
                    children: List.generate(
                      md,
                      (i) => appDateWheelLabelCell(
                        Lunar.fromYmd(y, sel.getMonth(), i + 1)
                            .getDayInChinese(),
                        (i + 1) == day,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarModePill extends StatelessWidget {
  const _CalendarModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kThemeBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _kCloseGrey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 时光集事件日期：公历/农历切换 + 与清单页相同的滚轮弹层。
class MemoryCompositeDatePickerSheet extends StatefulWidget {
  const MemoryCompositeDatePickerSheet({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<MemoryCompositeDatePickerSheet> createState() =>
      _MemoryCompositeDatePickerSheetState();
}

class _MemoryCompositeDatePickerSheetState
    extends State<MemoryCompositeDatePickerSheet> {
  late DateTime _solarDate;
  late int _lunarYear;
  late int _lunarMonthSigned;
  late int _lunarDay;
  bool _solarMode = true;
  MembershipTier _tier = MembershipTier.free;

  @override
  void initState() {
    super.initState();
    _solarDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    final lunar = Lunar.fromDate(_solarDate);
    _lunarYear = lunar.getYear();
    _lunarMonthSigned = lunar.getMonth();
    _lunarDay = lunar.getDay();
    _loadTier();
  }

  Future<void> _loadTier() async {
    final t = await MembershipService.currentTier();
    if (!mounted) return;
    setState(() => _tier = t);
  }

  String _lunarDisplayFull() {
    final lunar = Lunar.fromYmd(_lunarYear, _lunarMonthSigned, _lunarDay);
    return '${lunar.getYearInChinese()}年${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
  }

  Future<void> _openSolarWheel(BuildContext sheetCtx) async {
    await showModalBottomSheet<void>(
      context: sheetCtx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      builder: (ctx) => AppSolarDatePickerModal(
        initialDate: _solarDate,
        onCancel: () => Navigator.pop(ctx),
        onConfirm: (picked) {
          setState(() {
            _solarDate =
                DateTime(picked.year, picked.month, picked.day);
            final lunar = Lunar.fromDate(_solarDate);
            _lunarYear = lunar.getYear();
            _lunarMonthSigned = lunar.getMonth();
            _lunarDay = lunar.getDay();
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _openLunarWheel(BuildContext sheetCtx) async {
    await showModalBottomSheet<void>(
      context: sheetCtx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      builder: (ctx) => AppLunarDatePickerModal(
        initialYear: _lunarYear,
        initialMonthSigned: _lunarMonthSigned,
        initialDay: _lunarDay,
        onCancel: () => Navigator.pop(ctx),
        onConfirm: (year, monthSigned, dayLunar) {
          final lunar = Lunar.fromYmd(year, monthSigned, dayLunar);
          final s = lunar.getSolar();
          setState(() {
            _lunarYear = year;
            _lunarMonthSigned = monthSigned;
            _lunarDay = dayLunar;
            _solarDate = DateTime(s.getYear(), s.getMonth(), s.getDay());
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _onDateRowTap(BuildContext sheetCtx) async {
    if (_solarMode) {
      await _openSolarWheel(sheetCtx);
    } else {
      await _openLunarWheel(sheetCtx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '选择日期',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _kTitleColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _CalendarModePill(
                      label: '公历',
                      selected: _solarMode,
                      onTap: () => setState(() => _solarMode = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CalendarModePill(
                      label: '农历',
                      selected: !_solarMode,
                      onTap: () async {
                        if (!MembershipService.canUseLunarBirthday(_tier)) {
                          await showMembershipSoftPaywall(
                            context,
                            title: '农历提醒',
                            message: '农历生日提醒是基础版功能，升级即可使用',
                            primaryLabel: '升级会员',
                            onTierChanged: _loadTier,
                          );
                          return;
                        }
                        setState(() {
                          _solarMode = false;
                          final lunar = Lunar.fromDate(_solarDate);
                          _lunarYear = lunar.getYear();
                          _lunarMonthSigned = lunar.getMonth();
                          _lunarDay = lunar.getDay();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _onDateRowTap(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFECEFF5)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D111827),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _solarMode
                              ? formatMemoryStreamDayZh(_solarDate)
                              : _lunarDisplayFull(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _kTitleColor,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: _kCloseGrey,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        foregroundColor: _kCloseGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: _kThemeBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, _solarDate),
                      child: const Text(
                        '确定',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<DateTime?> showMemoryEventDatePicker(
  BuildContext context, {
  required DateTime initialDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black54,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: MemoryCompositeDatePickerSheet(initialDate: initialDate),
    ),
  );
}
