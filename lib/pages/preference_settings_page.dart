import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 应用偏好：通知、默认提醒、夜间静默等（后续接 [SharedPreferences] 持久化）。
class PreferenceSettingsPage extends StatefulWidget {
  const PreferenceSettingsPage({super.key});

  @override
  State<PreferenceSettingsPage> createState() => _PreferenceSettingsPageState();
}

const Color _kPageBg = Color(0xFFFAFBFC);
const Color _kSectionShellBg = Color(0xFFF8F9FA);
const Color _kIconBoxBg = Color(0xFFEBF5FF);

class _PreferenceSettingsPageState extends State<PreferenceSettingsPage> {

  // TODO(持久化): SharedPreferences
  bool _reminderSoundEnabled = true;
  bool _vibrationEnabled = true;
  bool _nightSilenceEnabled = false;

  /// 提前时间单选，值为 [kAdvanceTimeOptions] 的 $1。
  String _selectedAdvanceId = 'day_1';

  // TODO(持久化): SharedPreferences
  // ignore: prefer_final_fields
  String _reminderTime = '09:00';

  static const List<({String id, String label})> kAdvanceTimeOptions = [
    (id: 'same_day', label: '当天'),
    (id: 'day_1', label: '前1天'),
    (id: 'day_3', label: '前3天'),
    (id: 'week_1', label: '前1周'),
    (id: 'month_1', label: '前1个月'),
  ];

  void _onOpenTimePicker() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ReminderTimePicker(
          currentTime: _reminderTime,
          onConfirm: (time) {
            setState(() {
              _reminderTime = time;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.04;
    final viewBottom = MediaQuery.viewPaddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: cs.surfaceContainerHigh,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: cs.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _kPageBg,
        appBar: AppBar(
          backgroundColor: cs.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '返回',
          ),
          title: Text(
            '偏好设置',
            style: textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 0.7, color: cs.outline),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              hPad,
              20,
              hPad,
              24 + viewBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel(
                  text: '通知设置',
                  textTheme: textTheme,
                  colorScheme: cs,
                ),
                const SizedBox(height: 8),
                _GreyShell(
                  child: Column(
                    children: [
                      _SettingsSwitchRow(
                        height: 56,
                        colorScheme: cs,
                        textTheme: textTheme,
                        icon: Icons.volume_up,
                        label: '提醒声音',
                        value: _reminderSoundEnabled,
                        onChanged: (v) {
                          setState(() => _reminderSoundEnabled = v);
                        },
                      ),
                      const SizedBox(height: 4),
                      _SettingsSwitchRow(
                        height: 56,
                        colorScheme: cs,
                        textTheme: textTheme,
                        icon: Icons.vibration,
                        label: '振动提醒',
                        value: _vibrationEnabled,
                        onChanged: (v) {
                          setState(() => _vibrationEnabled = v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _SectionLabel(
                  text: '默认提醒策略',
                  textTheme: textTheme,
                  colorScheme: cs,
                ),
                const SizedBox(height: 8),
                _GreyShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '提前时间',
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final o in kAdvanceTimeOptions)
                            _AdvanceChip(
                              label: o.label,
                              selected: _selectedAdvanceId == o.id,
                              colorScheme: cs,
                              textTheme: textTheme,
                              onTap: () {
                                setState(() {
                                  _selectedAdvanceId = o.id;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _onOpenTimePicker,
                          child: SizedBox(
                            height: 56,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  _IconBox(
                                    icon: Icons.access_time,
                                    colorScheme: cs,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '默认提醒时刻',
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _reminderTime,
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '新建事件时将自动应用此策略，您也可以在创建时单独修改。',
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _SectionLabel(
                  text: '高级反馈',
                  textTheme: textTheme,
                  colorScheme: cs,
                ),
                const SizedBox(height: 8),
                _GreyShell(
                  child: _NightSilenceRow(
                    colorScheme: cs,
                    textTheme: textTheme,
                    value: _nightSilenceEnabled,
                    onChanged: (v) {
                      setState(() => _nightSilenceEnabled = v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部弹窗：选择默认提醒时刻（整点列表）。
class ReminderTimePicker extends StatefulWidget {
  const ReminderTimePicker({
    super.key,
    required this.currentTime,
    required this.onConfirm,
  });

  final String currentTime;
  final ValueChanged<String> onConfirm;

  static const List<String> kTimeOptions = [
    '07:00',
    '08:00',
    '09:00',
    '10:00',
    '12:00',
    '18:00',
    '20:00',
    '21:00',
  ];

  @override
  State<ReminderTimePicker> createState() => _ReminderTimePickerState();
}

class _ReminderTimePickerState extends State<ReminderTimePicker> {
  static const double _cellHeight = 48;
  static const double _gridGap = 12;

  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = ReminderTimePicker.kTimeOptions.contains(widget.currentTime)
        ? widget.currentTime
        : '09:00';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '取消',
                          style: textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '选择提醒时刻',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: TextButton(
                        onPressed: () {
                          widget.onConfirm(_selected);
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '确定',
                          style: textTheme.labelLarge?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    const cols = 4;
                    final maxW = c.maxWidth;
                    final cellW = (maxW - _gridGap * (cols - 1)) / cols;
                    return Wrap(
                      spacing: _gridGap,
                      runSpacing: _gridGap,
                      children: [
                        for (final t in ReminderTimePicker.kTimeOptions)
                          SizedBox(
                            width: cellW,
                            height: _cellHeight,
                            child: Material(
                              color: _selected == t
                                  ? cs.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selected = t);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: _selected == t
                                        ? null
                                        : Border.all(
                                            color: cs.outlineVariant,
                                          ),
                                  ),
                                  child: Text(
                                    t,
                                    textAlign: TextAlign.center,
                                    style: textTheme.labelLarge?.copyWith(
                                      color: _selected == t
                                          ? cs.onPrimary
                                          : cs.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    required this.textTheme,
    required this.colorScheme,
  });

  final String text;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _GreyShell extends StatelessWidget {
  const _GreyShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _kSectionShellBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.colorScheme,
  });

  final IconData icon;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kIconBoxBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 18,
        color: colorScheme.primary,
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.height,
    required this.colorScheme,
    required this.textTheme,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final double height;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _IconBox(icon: icon, colorScheme: cs),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: cs.primary,
                activeThumbColor: cs.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvanceChip extends StatelessWidget {
  const _AdvanceChip({
    required this.label,
    required this.selected,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: selected ? cs.primary : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? null
                : Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: selected ? cs.onPrimary : cs.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _NightSilenceRow extends StatelessWidget {
  const _NightSilenceRow({
    required this.colorScheme,
    required this.textTheme,
    required this.value,
    required this.onChanged,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBox(
              icon: Icons.nightlight_round,
              colorScheme: cs,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '夜间静默模式',
                    style: textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '23:00 - 07:00 不触发推送',
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: cs.primary,
                activeThumbColor: cs.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
