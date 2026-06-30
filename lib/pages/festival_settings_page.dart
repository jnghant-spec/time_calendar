import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:time_calendar/models/membership_tier.dart';
import 'package:time_calendar/services/festival_service.dart';
import 'package:time_calendar/services/festival_data_loader.dart';
import 'package:time_calendar/services/membership_service.dart';
import 'package:time_calendar/services/notification_service.dart';
import 'package:time_calendar/utils/festival_category_icon.dart';
import 'package:time_calendar/widgets/membership_soft_paywall.dart';

import 'ethnic_festival_data.dart';

/// 节日设置页：主题蓝（「节日提醒」卡片 + 民族标签/chip）。
const Color _kThemeBlue = Color(0xFF1A73E8);

/// 将 JSON `years` 中优先当前年、其次固定锚点的 ISO 日期格式化为「YYYY年M月D日」展示串。
String _festivalGregorianDisplayCn(Map<String, dynamic> years) {
  final y = DateTime.now().year;
  String? pick(String k) {
    final v = years[k];
    return v is String && v.isNotEmpty ? v : null;
  }

  final iso = pick('$y') ?? pick('2027') ?? pick('2026') ?? pick('2028');
  if (iso == null) {
    for (final e in years.values) {
      if (e is String && e.isNotEmpty) {
        final d = DateTime.tryParse(e);
        if (d != null) return '${d.year}年${d.month}月${d.day}日';
        return e;
      }
    }
    return '';
  }
  final d = DateTime.tryParse(iso);
  if (d != null) return '${d.year}年${d.month}月${d.day}日';
  final parts = iso.split('-');
  if (parts.length == 3) {
    try {
      return '${parts[0]}年${int.parse(parts[1])}月${int.parse(parts[2])}日';
    } catch (_) {}
  }
  return iso;
}

String _ethnicCalendarLabelFromJson(String? calendarType, String dateRaw) {
  final cd = dateRaw.trim();
  if (cd.isEmpty) return '';
  const prefixes = <String, String>{
    'tibetan': '藏历',
    'dai': '傣历',
    'miao': '苗历',
    'yi': '彝历',
    'menggu': '蒙历',
    'hani': '哈尼历',
    'lunar': '农历',
    'solar': '',
  };
  final p = prefixes[calendarType ?? ''] ?? '';
  return p.isEmpty ? cd : '$p $cd';
}

String _religiousCalendarLabelFromJson(String? calendarType, String dateRaw) {
  final cd = dateRaw.trim();
  const prefixes = <String, String>{
    'lunar': '农历',
    'gregorian': '公历',
    'islamic': '伊斯兰历',
    'computus': '教历',
    'hindu': '印历',
  };
  if (cd.isEmpty) {
    final p = prefixes[calendarType ?? ''] ?? '';
    return calendarType == null || calendarType.isEmpty ? '' : p;
  }
  final p = prefixes[calendarType ?? ''] ?? '';
  return p.isEmpty ? cd : '$p $cd';
}

bool _ethnicFestivalMatchesQuery(EthnicFestival f, String ethnicName, String q) {
  if (f.name.toLowerCase().contains(q)) return true;
  if (ethnicName.toLowerCase().contains(q)) return true;
  if (f.description.toLowerCase().contains(q)) return true;
  for (final t in f.tags) {
    if (t.toLowerCase().contains(q)) return true;
  }
  return false;
}

bool _ethnicFestivalHasDetailBody(EthnicFestival item) =>
    item.description.trim().isNotEmpty ||
    item.customs.isNotEmpty ||
    item.foods.isNotEmpty;

bool _religiousFestivalHasDetailBody(ReligiousFestival item) =>
    item.description.trim().isNotEmpty ||
    item.customs.isNotEmpty ||
    item.foods.isNotEmpty;

Widget _ethnicFestivalDetailInkWell(
  BuildContext context,
  EthnicFestival item,
  Widget child,
) {
  if (!_ethnicFestivalHasDetailBody(item)) return child;
  return InkWell(
    onTap: () {
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final tt = Theme.of(ctx).textTheme;
          return AlertDialog(
            title: Text(item.name),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.description.trim().isNotEmpty)
                    Text(item.description.trim(), style: tt.bodyMedium),
                  if (item.customs.isNotEmpty) ...[
                    if (item.description.trim().isNotEmpty)
                      const SizedBox(height: 12),
                    Text('习俗', style: tt.titleSmall),
                    const SizedBox(height: 4),
                    Text(item.customs.join('、'), style: tt.bodyMedium),
                  ],
                  if (item.foods.isNotEmpty) ...[
                    if (item.description.trim().isNotEmpty ||
                        item.customs.isNotEmpty)
                      const SizedBox(height: 12),
                    Text('饮食', style: tt.titleSmall),
                    const SizedBox(height: 4),
                    Text(item.foods.join('、'), style: tt.bodyMedium),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      );
    },
    child: child,
  );
}

Widget _religiousFestivalDetailInkWell(
  BuildContext context,
  ReligiousFestival item,
  Widget child,
) {
  if (!_religiousFestivalHasDetailBody(item)) return child;
  return InkWell(
    onTap: () {
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final tt = Theme.of(ctx).textTheme;
          return AlertDialog(
            title: Text(item.name),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.description.trim().isNotEmpty)
                    Text(item.description.trim(), style: tt.bodyMedium),
                  if (item.customs.isNotEmpty) ...[
                    if (item.description.trim().isNotEmpty)
                      const SizedBox(height: 12),
                    Text('习俗', style: tt.titleSmall),
                    const SizedBox(height: 4),
                    Text(item.customs.join('、'), style: tt.bodyMedium),
                  ],
                  if (item.foods.isNotEmpty) ...[
                    if (item.description.trim().isNotEmpty ||
                        item.customs.isNotEmpty)
                      const SizedBox(height: 12),
                    Text('饮食', style: tt.titleSmall),
                    const SizedBox(height: 4),
                    Text(item.foods.join('、'), style: tt.bodyMedium),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      );
    },
    child: child,
  );
}


/// 节日分类——展开状态与子项计数（公历/农历总开关由子项推导，见 [_categoryHeaderSwitchValue]）。
class FestivalCategory {
  FestivalCategory({
    required this.id,
    required this.name,
    required this.subscribedCount,
    this.expanded = false,
    this.festivals = const [],
  });

  final String id;
  final String name;
  int subscribedCount;
  bool expanded;
  final List<String> festivals;
}

/// 节日子项：公历用 [date]；农历用 [lunarDate] + [gregorianDate]（与 [date] 互斥展示）。
/// [id] 与 [FestivalService] 中 [CalendarFestival.id] 一致。
class FestivalItem {
  FestivalItem({
    required this.id,
    required this.name,
    this.date = '',
    this.lunarDate,
    this.gregorianDate,
    this.icon,
    this.iconAsset,
    required this.isSubscribed,
  });

  final String id;
  final String name;
  final String date;
  final String? lunarDate;
  final String? gregorianDate;
  final IconData? icon;
  /// 情人节用 `ic_couple_hearts.svg`；[SvgPicture.asset] 需完整 [assets/] 路径。
  final String? iconAsset;
  bool isSubscribed;
}

/// 民族（标签选择，后续接 API）；展示顺序按名称拼音，与 [isSelected] 无关。
class EthnicGroup {
  EthnicGroup({
    required this.id,
    required this.name,
    this.isSelected = false,
  });

  final String id;
  final String name;
  bool isSelected;
}

/// 民族节日子项（[ethnicCalendar] 为历法标签；可为空）。
/// [id] 与 [CalendarFestival.id] 及 JSON `id` 一致。
class EthnicFestival {
  EthnicFestival({
    required this.id,
    required this.ethnicId,
    required this.name,
    required this.ethnicCalendar,
    required this.gregorianDate,
    this.description = '',
    this.tags = const [],
    this.customs = const [],
    this.foods = const [],
    this.defaultSubscribed = false,
    required this.isSubscribed,
    required this.calendarEligible,
    this.displayMode = 'calendar',
  });

  final String id;
  final String ethnicId;
  final String name;
  final String ethnicCalendar;
  final String gregorianDate;
  final String description;
  final List<String> tags;
  final List<String> customs;
  final List<String> foods;
  final bool defaultSubscribed;
  bool isSubscribed;

  /// JSON：`available` 且非 `culture_only` / `hidden`；仅此一类可走日历订阅。
  final bool calendarEligible;

  /// JSON：`calendar` | `culture_only`（hidden 已在加载时剔除）。
  final String displayMode;

  bool get isCultureOnly => displayMode == 'culture_only';
}

/// 单条宗教节日（与 [ReligionGroup] 组合展示）。
/// [id] 与 [CalendarFestival.id] 及 JSON `id` 一致。
class ReligiousFestival {
  ReligiousFestival({
    required this.id,
    required this.religionId,
    required this.name,
    required this.calendarDate,
    required this.gregorianDate,
    this.description = '',
    this.tags = const [],
    this.customs = const [],
    this.foods = const [],
    this.defaultSubscribed = false,
    required this.isSubscribed,
    required this.calendarEligible,
    this.displayMode = 'calendar',
  });

  final String id;
  final String religionId;
  final String name;
  final String calendarDate;
  final String gregorianDate;
  final String description;
  final List<String> tags;
  final List<String> customs;
  final List<String> foods;
  final bool defaultSubscribed;
  bool isSubscribed;
  final bool calendarEligible;
  final String displayMode;

  bool get isCultureOnly => displayMode == 'culture_only';
}

/// 一类宗教及其节日列表（二级展开状态 [isExpanded]）。
class ReligionGroup {
  ReligionGroup({
    required this.id,
    required this.name,
    required this.festivals,
    this.isExpanded = true,
  });

  final String id;
  final String name;
  bool isExpanded;
  final List<ReligiousFestival> festivals;
}

/// 用户可见的有效节日订阅（排除降级静默保留项）。
bool _isActiveEthnicSubscription(
  EthnicFestival f,
  Set<String> hiddenSilentIds,
) =>
    f.calendarEligible && f.isSubscribed && !hiddenSilentIds.contains(f.id);

bool _isActiveReligiousSubscription(
  ReligiousFestival f,
  Set<String> hiddenSilentIds,
) =>
    f.calendarEligible && f.isSubscribed && !hiddenSilentIds.contains(f.id);

int _activeEthnicSubscriptionCountFor(
  Map<String, List<EthnicFestival>> festivalsById,
  Set<String> hiddenSilentIds,
  String ethnicId,
) {
  final list = festivalsById[ethnicId] ?? const <EthnicFestival>[];
  return list
      .where((f) => _isActiveEthnicSubscription(f, hiddenSilentIds))
      .length;
}

int _activeEthnicSubscriptionCount(
  Map<String, List<EthnicFestival>> festivalsById,
  Set<String> hiddenSilentIds,
) {
  var n = 0;
  for (final list in festivalsById.values) {
    n += list
        .where((f) => _isActiveEthnicSubscription(f, hiddenSilentIds))
        .length;
  }
  return n;
}

int _activeReligiousSubscriptionCount(
  List<ReligionGroup> groups,
  Set<String> hiddenSilentIds,
) {
  var n = 0;
  for (final g in groups) {
    n += g.festivals
        .where((f) => _isActiveReligiousSubscription(f, hiddenSilentIds))
        .length;
  }
  return n;
}

/// 公历/农历/民族/宗教节日订阅与展示。
class FestivalSettingsPage extends StatefulWidget {
  const FestivalSettingsPage({super.key});

  @override
  State<FestivalSettingsPage> createState() => _FestivalSettingsPageState();
}

class _FestivalSettingsPageState extends State<FestivalSettingsPage> {
  static const _pageBg = Color(0xFFF8F9FA);
  static const _coupleHeartsAsset = 'assets/images/ic_couple_hearts.svg';
  static const String _kFestivalSubscriptionsKey =
      FestivalSubscriptionPrefs.storageKey;

  MembershipTier _membershipTier = MembershipTier.free;

  /// 降级后静默保留的民族/宗教节日（仍参与日历绘制，不参与推送）。
  Set<String> _hiddenFestivalIds = {};

  /// 公历：按日期顺序 12 项（母亲节/父亲节为浮动周日）；与设计稿 1–12 一致。
  static final List<FestivalItem> _gregorianSeed = [
    FestivalItem(
      id: 'new_year',
      name: '元旦',
      date: '1月1日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'valentine',
      name: '情人节',
      date: '2月14日',
      iconAsset: _coupleHeartsAsset,
      isSubscribed: false,
    ),
    FestivalItem(
      id: 'women_day',
      name: '妇女节',
      date: '3月8日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'arbor_day',
      name: '植树节',
      date: '3月12日',
      icon: Icons.calendar_today,
      isSubscribed: false,
    ),
    FestivalItem(
      id: 'labour_day',
      name: '劳动节',
      date: '5月1日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'mothers_day',
      name: '母亲节',
      date: '5月第二个周日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'children_day',
      name: '儿童节',
      date: '6月1日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'fathers_day',
      name: '父亲节',
      date: '6月第三个周日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'party_day',
      name: '建党节',
      date: '7月1日',
      icon: Icons.calendar_today,
      isSubscribed: false,
    ),
    FestivalItem(
      id: 'army_day',
      name: '建军节',
      date: '8月1日',
      icon: Icons.calendar_today,
      isSubscribed: false,
    ),
    FestivalItem(
      id: 'teacher_day',
      name: '教师节',
      date: '9月10日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'national_day',
      name: '国庆节',
      date: '10月1日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
  ];

  static final List<FestivalItem> _lunarSeed = [
    FestivalItem(
      id: 'spring_festival',
      name: '春节',
      lunarDate: '正月初一',
      gregorianDate: '2027年2月6日',
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'lantern_festival',
      name: '元宵节',
      lunarDate: '正月十五',
      gregorianDate: '2027年2月20日',
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'dragon_head',
      name: '龙抬头',
      lunarDate: '二月初二',
      gregorianDate: '2027年3月7日',
      isSubscribed: false,
    ),
    FestivalItem(
      id: 'qingming',
      name: '清明节',
      lunarDate: '二月廿九',
      gregorianDate: '2027年4月5日',
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'dragon_boat',
      name: '端午节',
      lunarDate: '五月初五',
      gregorianDate: '2027年6月19日',
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'qixi',
      name: '七夕节',
      lunarDate: '七月初七',
      gregorianDate: '2027年8月19日',
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'ghost_festival',
      name: '中元节',
      lunarDate: '七月十五',
      gregorianDate: '2027年8月25日',
      isSubscribed: false,
    ),
    FestivalItem(
      id: 'mid_autumn',
      name: '中秋节',
      lunarDate: '八月十五',
      gregorianDate: '2027年9月23日',
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'double_ninth',
      name: '重阳节',
      lunarDate: '九月初九',
      gregorianDate: '2027年10月2日',
      isSubscribed: true,
    ),
    FestivalItem(
      id: 'laba',
      name: '腊八节',
      lunarDate: '腊月初八',
      gregorianDate: '2027年1月18日',
      isSubscribed: false,
    ),
    FestivalItem(
      id: 'xiao_nian',
      name: '小年',
      lunarDate: '腊月廿三',
      gregorianDate: '2027年2月1日',
      isSubscribed: false,
    ),
    FestivalItem(
      id: 'new_year_eve',
      name: '除夕',
      lunarDate: '腊月廿九',
      gregorianDate: '2027年2月5日',
      isSubscribed: true,
    ),
  ];

  late final List<FestivalItem> _gregorianItems = _gregorianSeed
      .map(
        (e) => FestivalItem(
          id: e.id,
          name: e.name,
          date: e.date,
          lunarDate: e.lunarDate,
          gregorianDate: e.gregorianDate,
          icon: e.icon,
          iconAsset: e.iconAsset,
          isSubscribed: e.isSubscribed,
        ),
      )
      .toList();

  late final List<FestivalItem> _lunarItems = _lunarSeed
      .map(
        (e) => FestivalItem(
          id: e.id,
          name: e.name,
          date: e.date,
          lunarDate: e.lunarDate,
          gregorianDate: e.gregorianDate,
          icon: e.icon,
          iconAsset: e.iconAsset,
          isSubscribed: e.isSubscribed,
        ),
      )
      .toList();

  List<EthnicGroup> _ethnicGroups = [];
  Map<String, List<EthnicFestival>> _ethnicFestivalsById = {};
  Map<String, bool> _ethnicBlockExpanded = {};
  String _ethnicQuery = '';

  List<ReligionGroup> _religionGroups = [];

  bool _festivalReminderEnabled = true;

  late final List<FestivalCategory> _categories = [
    FestivalCategory(
      id: 'gregorian',
      name: '公历节日',
      subscribedCount: 8,
    ),
    FestivalCategory(
      id: 'lunar',
      name: '农历节日',
      subscribedCount: 8,
    ),
    FestivalCategory(
      id: 'ethnic',
      name: '民族节日',
      subscribedCount: 10,
    ),
    FestivalCategory(
      id: 'religious',
      name: '宗教节日',
      subscribedCount: 0,
    ),
  ];

  int get _gregorianOnCount =>
      _gregorianItems.where((e) => e.isSubscribed).length;

  int get _lunarOnCount => _lunarItems.where((e) => e.isSubscribed).length;

  int get _activeEthnicSubscriptionCountState =>
      _activeEthnicSubscriptionCount(_ethnicFestivalsById, _hiddenFestivalIds);

  int get _activeReligiousSubscriptionCountState =>
      _activeReligiousSubscriptionCount(_religionGroups, _hiddenFestivalIds);

  /// 公历/农历卡片头部 Switch：`true` 当且仅当该分类下全部子项已订阅。
  bool _categoryHeaderSwitchValue(String categoryId) {
    switch (categoryId) {
      case 'gregorian':
        return _gregorianItems.every((e) => e.isSubscribed);
      case 'lunar':
        return _lunarItems.every((e) => e.isSubscribed);
      default:
        return false;
    }
  }

  ValueChanged<bool>? _categoryHeaderSwitchOnChanged(FestivalCategory c) {
    switch (c.id) {
      case 'gregorian':
      case 'lunar':
        return (v) => _onCategorySwitchChanged(c, v);
      default:
        return null;
    }
  }

  String _statusSubtitle(FestivalCategory c) {
    switch (c.id) {
      case 'gregorian':
        return '已订阅 $_gregorianOnCount 个';
      case 'lunar':
        return '已订阅 $_lunarOnCount 个';
      case 'ethnic':
        return '已订阅 $_activeEthnicSubscriptionCountState 个';
      case 'religious':
        return '已订阅 $_activeReligiousSubscriptionCountState 个';
      default:
        return '已订阅 ${c.subscribedCount} 个';
    }
  }

  String _ethnicPaywallMessage() {
    final basic = MembershipConfig.benefits[MembershipTier.basic]!;
    final prem = MembershipConfig.benefits[MembershipTier.premium]!;
    switch (_membershipTier) {
      case MembershipTier.free:
        return '免费版可订阅 3 个民族节日，升级基础版可订阅 8 个 ¥${basic.priceMonthly}/月';
      case MembershipTier.basic:
        return '基础版可订阅 8 个民族节日，升级高级版可订阅 20 个 ¥${prem.priceMonthly}/月';
      case MembershipTier.premium:
        return '民族节日订阅已达上限';
    }
  }

  String _religiousPaywallMessage() {
    final basic = MembershipConfig.benefits[MembershipTier.basic]!;
    final prem = MembershipConfig.benefits[MembershipTier.premium]!;
    switch (_membershipTier) {
      case MembershipTier.free:
        return '免费版可订阅 3 个宗教节日，升级基础版可订阅 8 个 ¥${basic.priceMonthly}/月';
      case MembershipTier.basic:
        return '基础版可订阅 8 个宗教节日，升级高级版不限名额 ¥${prem.priceMonthly}/月';
      case MembershipTier.premium:
        return '宗教节日订阅已达上限';
    }
  }

  void _onCategorySwitchChanged(FestivalCategory c, bool v) {
    setState(() {
      if (c.id == 'gregorian') {
        for (final item in _gregorianItems) {
          item.isSubscribed = v;
        }
      } else if (c.id == 'lunar') {
        for (final item in _lunarItems) {
          item.isSubscribed = v;
        }
      }
    });
    _saveSubscriptions();
  }

  void _onGregorianItemSwitch(int index, bool v) {
    setState(() {
      _gregorianItems[index].isSubscribed = v;
    });
    _saveSubscriptions();
  }

  void _onLunarItemSwitch(int index, bool v) {
    setState(() {
      _lunarItems[index].isSubscribed = v;
    });
    _saveSubscriptions();
  }

  void _onEthnicFestivalSwitch(String ethnicId, int index, bool v) {
    final row = _ethnicFestivalsById[ethnicId]?[index];
    if (row == null || !row.calendarEligible) return;

    if (_hiddenFestivalIds.contains(row.id)) {
      return;
    }

    if (_membershipTier == MembershipTier.free) {
      if (v) {
        showMembershipSoftPaywall(
          context,
          title: '民族节日',
          message: _ethnicPaywallMessage(),
        );
        return;
      }
      setState(() {
        row.isSubscribed = false;
      });
      _saveSubscriptions();
      return;
    }

    if (!v) {
      setState(() {
        row.isSubscribed = false;
      });
      _saveSubscriptions();
      return;
    }

    final quota = MembershipService.benefits(_membershipTier).ethnicFestivalQuota;
    if (quota != -1) {
      final excludingCur = _activeEthnicSubscriptionCountState -
          (_isActiveEthnicSubscription(row, _hiddenFestivalIds) ? 1 : 0);
      if (MembershipService.remainingEthnicQuota(_membershipTier, excludingCur) <= 0) {
        showMembershipSoftPaywall(
          context,
          title: '民族节日',
          message: _ethnicPaywallMessage(),
        );
        return;
      }
    }

    setState(() {
      row.isSubscribed = true;
    });
    _saveSubscriptions();
  }

  void _onEthnicGroupTap(String id) {
    setState(() {
      final g = _ethnicGroups.firstWhere((e) => e.id == id);
      g.isSelected = !g.isSelected;
      if (g.isSelected) {
        _ethnicBlockExpanded[id] = true;
      }
    });
  }

  void _onEthnicBlockHeaderTap(String id) {
    setState(() {
      _ethnicBlockExpanded[id] = !(_ethnicBlockExpanded[id] ?? true);
    });
  }

  void _onEthnicSelectAll(String ethnicId, bool v) {
    final list = _ethnicFestivalsById[ethnicId];
    if (list == null) return;

    if (_membershipTier == MembershipTier.free) {
      if (v) {
        showMembershipSoftPaywall(
          context,
          title: '民族节日',
          message: _ethnicPaywallMessage(),
        );
        return;
      }
      setState(() {
        for (final f in list) {
          if (f.calendarEligible && !_hiddenFestivalIds.contains(f.id)) {
            f.isSubscribed = false;
          }
        }
      });
      _saveSubscriptions();
      return;
    }

    setState(() {
      if (!v) {
        for (final f in list) {
          if (f.calendarEligible && !_hiddenFestivalIds.contains(f.id)) {
            f.isSubscribed = false;
          }
        }
        return;
      }

      final quota =
          MembershipService.benefits(_membershipTier).ethnicFestivalQuota;
      for (final f in list) {
        if (!f.calendarEligible) continue;
        if (_hiddenFestivalIds.contains(f.id)) continue;
        if (f.isSubscribed) continue;
        if (quota != -1) {
          if (MembershipService.remainingEthnicQuota(
                _membershipTier,
                _activeEthnicSubscriptionCountState,
              ) <=
              0) {
            break;
          }
        }
        f.isSubscribed = true;
      }
    });
    _saveSubscriptions();
  }

  void _onReligiousFestivalSwitch(String religionId, int index, bool v) {
    final gIndex = _religionGroups.indexWhere((e) => e.id == religionId);
    if (gIndex < 0) return;
    final row = _religionGroups[gIndex].festivals[index];
    if (!row.calendarEligible) return;

    if (_hiddenFestivalIds.contains(row.id)) {
      return;
    }

    if (_membershipTier == MembershipTier.free) {
      if (v) {
        showMembershipSoftPaywall(
          context,
          title: '宗教节日',
          message: _religiousPaywallMessage(),
        );
        return;
      }
      setState(() {
        row.isSubscribed = false;
      });
      _saveSubscriptions();
      return;
    }

    if (!v) {
      setState(() {
        row.isSubscribed = false;
      });
      _saveSubscriptions();
      return;
    }

    final quota =
        MembershipService.benefits(_membershipTier).religiousFestivalQuota;
    if (quota != -1) {
      final excludingCur = _activeReligiousSubscriptionCountState -
          (_isActiveReligiousSubscription(row, _hiddenFestivalIds) ? 1 : 0);
      if (MembershipService.remainingReligiousQuota(
            _membershipTier,
            excludingCur,
          ) <=
          0) {
        showMembershipSoftPaywall(
          context,
          title: '宗教节日',
          message: _religiousPaywallMessage(),
        );
        return;
      }
    }

    setState(() {
      row.isSubscribed = true;
    });
    _saveSubscriptions();
  }

  void _onReligiousSelectAll(String religionId, bool v) {
    final gIndex = _religionGroups.indexWhere((e) => e.id == religionId);
    if (gIndex < 0) return;
    final g = _religionGroups[gIndex];

    if (_membershipTier == MembershipTier.free) {
      if (v) {
        showMembershipSoftPaywall(
          context,
          title: '宗教节日',
          message: _religiousPaywallMessage(),
        );
        return;
      }
      setState(() {
        for (final f in g.festivals) {
          if (f.calendarEligible && !_hiddenFestivalIds.contains(f.id)) {
            f.isSubscribed = false;
          }
        }
      });
      _saveSubscriptions();
      return;
    }

    setState(() {
      if (!v) {
        for (final f in g.festivals) {
          if (f.calendarEligible && !_hiddenFestivalIds.contains(f.id)) {
            f.isSubscribed = false;
          }
        }
        return;
      }

      final quota =
          MembershipService.benefits(_membershipTier).religiousFestivalQuota;
      for (final f in g.festivals) {
        if (!f.calendarEligible) continue;
        if (_hiddenFestivalIds.contains(f.id)) continue;
        if (f.isSubscribed) continue;
        if (quota != -1) {
          if (MembershipService.remainingReligiousQuota(
                _membershipTier,
                _activeReligiousSubscriptionCountState,
              ) <=
              0) {
            break;
          }
        }
        f.isSubscribed = true;
      }
    });
    _saveSubscriptions();
  }

  void _onReligiousCardExpand(String religionId) {
    setState(() {
      final g = _religionGroups.firstWhere((e) => e.id == religionId);
      g.isExpanded = !g.isExpanded;
    });
  }

  void _applySubscriptionSet(Set<String> subscribed) {
    for (final item in _gregorianItems) {
      item.isSubscribed = subscribed.contains(item.id);
    }
    for (final item in _lunarItems) {
      item.isSubscribed = subscribed.contains(item.id);
    }
    for (final list in _ethnicFestivalsById.values) {
      for (final f in list) {
        f.isSubscribed = f.calendarEligible && subscribed.contains(f.id);
      }
    }
    for (final g in _religionGroups) {
      for (final f in g.festivals) {
        f.isSubscribed = f.calendarEligible && subscribed.contains(f.id);
      }
    }
  }

  Future<void> _loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kFestivalSubscriptionsKey);
    final hidden = await MembershipService.loadHiddenFestivalIds();
    if (!mounted) return;

    setState(() {
      _hiddenFestivalIds = hidden;
    });

    if (jsonStr == null) {
      setState(() {
        _applySubscriptionSet(FestivalService.kDefaultSubscribedIds);
      });
      await _saveSubscriptions();
      return;
    }

    try {
      final activeOnly =
          (jsonDecode(jsonStr) as List).cast<String>().toSet();
      if (!mounted) return;
      setState(() {
        _applySubscriptionSet({...activeOnly, ...hidden});
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _applySubscriptionSet(FestivalService.kDefaultSubscribedIds);
      });
    }
  }

  Future<void> _saveSubscriptions() async {
    final subscribed = <String>{};
    for (final f in _gregorianItems) {
      if (f.isSubscribed) subscribed.add(f.id);
    }
    for (final f in _lunarItems) {
      if (f.isSubscribed) subscribed.add(f.id);
    }
    for (final list in _ethnicFestivalsById.values) {
      for (final f in list) {
        if (f.calendarEligible && f.isSubscribed) subscribed.add(f.id);
      }
    }
    for (final g in _religionGroups) {
      for (final f in g.festivals) {
        if (f.calendarEligible && f.isSubscribed) subscribed.add(f.id);
      }
    }
    await MembershipService.persistFestivalsFromFullUserIntent(subscribed);
    final hidden = await MembershipService.loadHiddenFestivalIds();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFestivalSubscriptionsKey);
    final activeOnly = raw != null && raw.isNotEmpty
        ? (jsonDecode(raw) as List).cast<String>().toSet()
        : <String>{};
    if (!mounted) return;
    setState(() {
      _hiddenFestivalIds = hidden;
      _applySubscriptionSet({...activeOnly, ...hidden});
    });
    if (_festivalReminderEnabled) {
      await NotificationService.scheduleUpcomingFestivalReminders();
    }
  }

  Future<void> _loadReminderEnabled() async {
    final enabled = await NotificationService.isReminderEnabled();
    if (!mounted) return;
    setState(() => _festivalReminderEnabled = enabled);
  }

  void _buildEthnicDataFromJson(List<Map<String, dynamic>> jsonList) {
    final byEthnic = <String, List<Map<String, dynamic>>>{};
    for (final m in jsonList) {
      final eid = FestivalDataLoader.safeString(m, 'ethnic_id');
      if (eid == null || eid.isEmpty) continue;
      byEthnic.putIfAbsent(eid, () => []).add(m);
    }

    _ethnicFestivalsById = {};
    for (final g in _ethnicGroups) {
      final rows = List<Map<String, dynamic>>.from(byEthnic[g.id] ?? []);
      rows.sort((a, b) {
        final na = FestivalDataLoader.safeString(a, 'name') ?? '';
        final nb = FestivalDataLoader.safeString(b, 'name') ?? '';
        return na.compareTo(nb);
      });
      _ethnicFestivalsById[g.id] = [
        for (final m in rows)
          if ((FestivalDataLoader.safeString(m, 'id') ?? '').isNotEmpty &&
              FestivalDataLoader.festivalShowInSettings(m))
            EthnicFestival(
              id: FestivalDataLoader.safeString(m, 'id')!,
              ethnicId: g.id,
              name: FestivalDataLoader.safeString(m, 'name') ?? '未知节日',
              ethnicCalendar:
                  FestivalDataLoader.safeString(m, 'display_mode') ==
                          'culture_only'
                      ? ''
                      : _ethnicCalendarLabelFromJson(
                          FestivalDataLoader.safeString(m, 'calendar_type'),
                          FestivalDataLoader.safeString(m, 'calendar_date') ??
                              '',
                        ),
              gregorianDate:
                  FestivalDataLoader.safeString(m, 'display_mode') ==
                          'culture_only'
                      ? ''
                      : _festivalGregorianDisplayCn(
                          (m['years'] is Map)
                              ? Map<String, dynamic>.from(m['years'] as Map)
                              : const {},
                        ),
              description:
                  FestivalDataLoader.safeString(m, 'description') ?? '',
              tags: FestivalDataLoader.safeStringList(m, 'tags'),
              customs: FestivalDataLoader.safeStringList(m, 'customs'),
              foods: FestivalDataLoader.safeStringList(m, 'foods'),
              defaultSubscribed:
                  FestivalDataLoader.safeBool(m, 'default_subscribed'),
              isSubscribed: false,
              calendarEligible:
                  FestivalDataLoader.festivalCalendarEligible(m),
              displayMode:
                  FestivalDataLoader.safeString(m, 'display_mode') ??
                      'calendar',
            ),
      ];
    }
    _ethnicBlockExpanded = {for (final x in _ethnicGroups) x.id: true};
  }

  void _buildReligiousDataFromJson(List<Map<String, dynamic>> jsonList) {
    final byReligion = <String, List<Map<String, dynamic>>>{};
    for (final m in jsonList) {
      var rid = FestivalDataLoader.safeString(m, 'religion_id');
      rid ??= FestivalDataLoader.safeString(m, 'religious_type');
      if (rid == null || rid.isEmpty) rid = 'other';
      byReligion.putIfAbsent(rid, () => []).add(m);
    }

    const order = [
      'buddhism',
      'christianity',
      'islam',
      'taoism',
      'hinduism',
    ];

    final groups = <ReligionGroup>[];

    void pushGroup(String id, List<Map<String, dynamic>> rows) {
      rows.sort((a, b) {
        final na = FestivalDataLoader.safeString(a, 'name') ?? '';
        final nb = FestivalDataLoader.safeString(b, 'name') ?? '';
        return na.compareTo(nb);
      });
      final typeName =
          FestivalDataLoader.safeString(rows.first, 'religious_type') ?? id;
      groups.add(
        ReligionGroup(
          id: id,
          name: typeName,
          isExpanded: true,
          festivals: [
            for (final m in rows)
              if ((FestivalDataLoader.safeString(m, 'id') ?? '').isNotEmpty &&
                  FestivalDataLoader.festivalShowInSettings(m))
                ReligiousFestival(
                  id: FestivalDataLoader.safeString(m, 'id')!,
                  religionId: id,
                  name: FestivalDataLoader.safeString(m, 'name') ?? '未知节日',
                  calendarDate:
                      FestivalDataLoader.safeString(m, 'display_mode') ==
                              'culture_only'
                          ? ''
                          : _religiousCalendarLabelFromJson(
                              FestivalDataLoader.safeString(m, 'calendar_type'),
                              FestivalDataLoader.safeString(m, 'calendar_date') ??
                                  '',
                            ),
                  gregorianDate:
                      FestivalDataLoader.safeString(m, 'display_mode') ==
                              'culture_only'
                          ? ''
                          : _festivalGregorianDisplayCn(
                              (m['years'] is Map)
                                  ? Map<String, dynamic>.from(
                                      m['years'] as Map,
                                    )
                                  : const {},
                            ),
                  description:
                      FestivalDataLoader.safeString(m, 'description') ?? '',
                  tags: FestivalDataLoader.safeStringList(m, 'tags'),
                  customs: FestivalDataLoader.safeStringList(m, 'customs'),
                  foods: FestivalDataLoader.safeStringList(m, 'foods'),
                  defaultSubscribed:
                      FestivalDataLoader.safeBool(m, 'default_subscribed'),
                  isSubscribed: false,
                  calendarEligible:
                      FestivalDataLoader.festivalCalendarEligible(m),
                  displayMode:
                      FestivalDataLoader.safeString(m, 'display_mode') ??
                          'calendar',
                ),
          ],
        ),
      );
    }

    for (final id in order) {
      final rows = byReligion[id];
      if (rows != null && rows.isNotEmpty) pushGroup(id, rows);
    }

    for (final entry in byReligion.entries) {
      if (order.contains(entry.key)) continue;
      if (entry.value.isEmpty) continue;
      pushGroup(entry.key, entry.value);
    }

    _religionGroups = groups;
  }

  Future<void> _initializeData() async {
    List<Map<String, dynamic>> ethnicJson;
    List<Map<String, dynamic>> religiousJson;
    try {
      ethnicJson = await FestivalDataLoader.loadEthnicFestivals();
    } catch (_) {
      ethnicJson = [];
    }
    try {
      religiousJson = await FestivalDataLoader.loadReligiousFestivals();
    } catch (_) {
      religiousJson = [];
    }

    final tier = await MembershipService.currentTier();
    if (!mounted) return;

    setState(() {
      _membershipTier = tier;
      _ethnicGroups = [
        for (final r in kEthnicGroupRows)
          EthnicGroup(
            id: r.$1,
            name: r.$2,
            isSelected: r.$3,
          ),
      ];
      _buildEthnicDataFromJson(ethnicJson);
      _buildReligiousDataFromJson(religiousJson);
    });

    await _loadSubscriptions();
    if (!mounted) return;
    await _loadReminderEnabled();
  }

  /// 民族节日来自 assets/data/ethnic_festivals.json；宗教节日来自 religious_festivals.json；
  /// 公历月推算见 [FestivalService.getFestivalsForMonth]。
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w * 0.04;
    final viewBottom = MediaQuery.viewInsetsOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: cs.surfaceContainerHigh,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: cs.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _pageBg,
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
            '节日设置',
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
              16,
              hPad,
              24 + viewBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D111827),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: _kThemeBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '节日提醒',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              _festivalReminderEnabled
                                  ? '前一天09:00推送节日通知'
                                  : '已关闭节日提醒，不再接收推送',
                              style: TextStyle(
                                fontSize: 12,
                                color: _festivalReminderEnabled
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _festivalReminderEnabled,
                        onChanged: (v) async {
                          setState(() => _festivalReminderEnabled = v);
                          await NotificationService.setReminderEnabled(v);
                        },
                        activeTrackColor: _kThemeBlue,
                        activeThumbColor: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final e in _categories.asMap().entries) ...[
                  if (e.key > 0) const SizedBox(height: 12),
                  _FestivalCategoryCard(
                    data: e.value,
                    colorScheme: cs,
                    textTheme: textTheme,
                    statusText: _statusSubtitle(e.value),
                    categorySwitchValue: _categoryHeaderSwitchValue(e.value.id),
                    onCategorySwitch: _categoryHeaderSwitchOnChanged(e.value),
                    onHeaderTap: () {
                      setState(() {
                        e.value.expanded = !e.value.expanded;
                      });
                    },
                    expansionOverride: e.value.expanded
                        ? (e.value.id == 'gregorian'
                              ? _GregorianFestivalListBody(
                                  items: _gregorianItems,
                                  categoryEnabled: true,
                                  colorScheme: cs,
                                  textTheme: textTheme,
                                  onItemChanged: _onGregorianItemSwitch,
                                )
                              : e.value.id == 'lunar'
                              ? _LunarFestivalListBody(
                                  items: _lunarItems,
                                  categoryEnabled: true,
                                  colorScheme: cs,
                                  textTheme: textTheme,
                                  onItemChanged: _onLunarItemSwitch,
                                )
                              : e.value.id == 'ethnic'
                              ? _EthnicFestivalListBody(
                                  membershipTier: _membershipTier,
                                  hiddenSilentIds: _hiddenFestivalIds,
                                  colorScheme: cs,
                                  textTheme: textTheme,
                                  searchQuery: _ethnicQuery,
                                  onSearchChanged: (q) {
                                    setState(() {
                                      _ethnicQuery = q;
                                    });
                                  },
                                  ethnicGroups: _ethnicGroups,
                                  festivalsById: _ethnicFestivalsById,
                                  blockExpanded: _ethnicBlockExpanded,
                                  onEthnicTagTap: _onEthnicGroupTap,
                                  onBlockHeaderTap: _onEthnicBlockHeaderTap,
                                  onSelectAll: _onEthnicSelectAll,
                                  onFestivalSwitch: _onEthnicFestivalSwitch,
                                )
                              : e.value.id == 'religious'
                              ? _ReligiousFestivalListBody(
                                  membershipTier: _membershipTier,
                                  hiddenSilentIds: _hiddenFestivalIds,
                                  categoryEnabled: true,
                                  colorScheme: cs,
                                  textTheme: textTheme,
                                  religionGroups: _religionGroups,
                                  onCardExpand: _onReligiousCardExpand,
                                  onSelectAll: _onReligiousSelectAll,
                                  onFestivalSwitch: _onReligiousFestivalSwitch,
                                )
                              : null)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FestivalCategoryCard extends StatelessWidget {
  const _FestivalCategoryCard({
    required this.data,
    required this.colorScheme,
    required this.textTheme,
    required this.statusText,
    required this.categorySwitchValue,
    required this.onCategorySwitch,
    required this.onHeaderTap,
    this.expansionOverride,
  });

  final FestivalCategory data;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final String statusText;
  /// 民族/宗教不传回调时隐藏头部 Switch。
  final bool categorySwitchValue;
  final ValueChanged<bool>? onCategorySwitch;
  final VoidCallback onHeaderTap;
  final Widget? expansionOverride;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: const Color(0x0A000000),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onHeaderTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              // TODO(设计): 非公历分类的 `ic_festival_*.svg` 若为占位矩形，可继续用 [\_CategoryIconBox]；公历子项已支持 SVG/Icon。
                              _CategoryIconBox(
                                colorScheme: cs,
                                categoryId: data.id,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      data.name,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      statusText,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                data.expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (onCategorySwitch != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, left: 4),
                      child: Switch.adaptive(
                        value: categorySwitchValue,
                        onChanged: onCategorySwitch,
                        activeTrackColor: cs.primary,
                        activeThumbColor: cs.onPrimary,
                      ),
                    ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: data.expanded
                  ? (expansionOverride ??
                      _ExpandedPlaceholder(
                        colorScheme: cs,
                        textTheme: textTheme,
                        festivalNames: data.festivals,
                      ))
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIconBox extends StatelessWidget {
  const _CategoryIconBox({
    required this.colorScheme,
    required this.categoryId,
  });

  final ColorScheme colorScheme;
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        festivalCategoryIcon(categoryId),
        size: 24,
        color: cs.primary,
      ),
    );
  }
}

/// 公历展开列表：不限制高度，与外层页面 [ListView] 统一滚动。
class _GregorianFestivalListBody extends StatelessWidget {
  const _GregorianFestivalListBody({
    required this.items,
    required this.categoryEnabled,
    required this.colorScheme,
    required this.textTheme,
    required this.onItemChanged,
  });

  final List<FestivalItem> items;
  final bool categoryEnabled;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final void Function(int index, bool v) onItemChanged;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, thickness: 0.7, color: Color(0xFFF3F4F6)),
        ListView.separated(
          padding: const EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 10),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, _) => Divider(
            height: 1,
            thickness: 0.7,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          itemBuilder: (context, i) {
            final e = items[i];
            return _GregorianFestivalRow(
              item: e,
              colorScheme: cs,
              textTheme: textTheme,
              onChanged: categoryEnabled
                  ? (v) => onItemChanged(i, v)
                  : null,
            );
          },
        ),
      ],
    );
  }
}

class _GregorianFestivalRow extends StatelessWidget {
  const _GregorianFestivalRow({
    required this.item,
    required this.colorScheme,
    required this.textTheme,
    this.onChanged,
  });

  final FestivalItem item;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final nameStyle = textTheme.bodyLarge?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w400,
    );
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle,
                ),
                const SizedBox(height: 2),
                Text(
                  item.date,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: item.isSubscribed,
            onChanged: onChanged,
            activeTrackColor: cs.primary,
            activeThumbColor: cs.onPrimary,
          ),
        ],
      ),
    );
  }
}

/// 农历日期标签色（设计稿 #EBF5FF / #1E40AF）
const Color _kLunarTagBackground = Color(0xFFEBF5FF);
const Color _kLunarTagForeground = Color(0xFF1E40AF);

/// 「文化介绍」条目标签（灰色）
const Color _kCultureOnlyTagBackground = Color(0xFFE5E7EB);
const Color _kCultureOnlyTagForeground = Color(0xFF6B7280);

/// 农历展开列表，与外层 [SingleChildScrollView] 统一滚动。
class _LunarFestivalListBody extends StatelessWidget {
  const _LunarFestivalListBody({
    required this.items,
    required this.categoryEnabled,
    required this.colorScheme,
    required this.textTheme,
    required this.onItemChanged,
  });

  final List<FestivalItem> items;
  final bool categoryEnabled;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final void Function(int index, bool v) onItemChanged;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, thickness: 0.7, color: Color(0xFFF3F4F6)),
        ListView.separated(
          padding: const EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 10),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, _) => Divider(
            height: 1,
            thickness: 0.7,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          itemBuilder: (context, i) {
            final e = items[i];
            return _LunarFestivalRow(
              item: e,
              colorScheme: cs,
              textTheme: textTheme,
              onChanged: categoryEnabled
                  ? (v) => onItemChanged(i, v)
                  : null,
            );
          },
        ),
      ],
    );
  }
}

class _LunarFestivalRow extends StatelessWidget {
  const _LunarFestivalRow({
    required this.item,
    required this.colorScheme,
    required this.textTheme,
    this.onChanged,
  });

  final FestivalItem item;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final lunar = item.lunarDate ?? '';
    final nameStyle = textTheme.bodyLarge?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w400,
    );
    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nameStyle,
                      ),
                    ),
                    if (lunar.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _kLunarTagBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '农历 $lunar',
                          style: const TextStyle(
                            color: _kLunarTagForeground,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.gregorianDate != null &&
                    item.gregorianDate!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.gregorianDate!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: item.isSubscribed,
            onChanged: onChanged,
            activeTrackColor: cs.primary,
            activeThumbColor: cs.onPrimary,
          ),
        ],
      ),
    );
  }
}

/// 按民族中文名全拼排序（A–Z）；[isSelected] 不参与排序。
int _compareEthnicByPinyin(EthnicGroup a, EthnicGroup b) {
  final ka = PinyinHelper.getPinyinE(a.name, separator: '', defPinyin: '');
  final kb = PinyinHelper.getPinyinE(b.name, separator: '', defPinyin: '');
  final c = ka.compareTo(kb);
  if (c != 0) return c;
  return a.id.compareTo(b.id);
}

int _compareEthnicNameStringsByPinyin(String nameA, String nameB) {
  final ka = PinyinHelper.getPinyinE(nameA, separator: '', defPinyin: '');
  final kb = PinyinHelper.getPinyinE(nameB, separator: '', defPinyin: '');
  final c = ka.compareTo(kb);
  if (c != 0) return c;
  return nameA.compareTo(nameB);
}

/// 民族标签 pill + 右上角有效订阅数字角标。
class _EthnicGroupTagChip extends StatelessWidget {
  const _EthnicGroupTagChip({
    required this.name,
    required this.isSelected,
    required this.subscriptionCount,
    required this.onTap,
    this.selectedBackground = _kThemeBlue,
    this.unselectedBackground = Colors.white,
    this.selectedForeground = Colors.white,
    this.unselectedForeground,
    this.unselectedBorderColor,
    this.horizontalPadding = 14,
    this.verticalPadding = 8,
    this.fontSize = 12,
  });

  final String name;
  final bool isSelected;
  final int subscriptionCount;
  final VoidCallback onTap;
  final Color selectedBackground;
  final Color unselectedBackground;
  final Color selectedForeground;
  final Color? unselectedForeground;
  final Color? unselectedBorderColor;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final idleFg = unselectedForeground ?? cs.onSurface;
    final idleBorder = unselectedBorderColor ?? cs.outlineVariant;
    final showBadge = subscriptionCount > 0;
    final badgeLabel = subscriptionCount > 99 ? '99+' : '$subscriptionCount';

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: isSelected ? selectedBackground : unselectedBackground,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? null
                  : Border.all(color: idleBorder),
            ),
            child: Text(
              name,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: isSelected ? selectedForeground : idleFg,
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: subscriptionCount > 9 ? 4 : 0,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : _kThemeBlue,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? _kThemeBlue : Colors.white,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: subscriptionCount > 9 ? 9 : 10,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: isSelected ? _kThemeBlue : Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 民族节日搜索命中（跨民族聚合列表用）。
class _EthnicSearchHit {
  const _EthnicSearchHit({
    required this.ethnicId,
    required this.ethnicName,
    required this.festivalIndex,
    required this.festival,
  });

  final String ethnicId;
  final String ethnicName;
  final int festivalIndex;
  final EthnicFestival festival;
}

int _compareEthnicSearchHits(_EthnicSearchHit a, _EthnicSearchHit b) {
  final c = _compareEthnicNameStringsByPinyin(a.ethnicName, b.ethnicName);
  if (c != 0) return c;
  final fa = PinyinHelper.getPinyinE(
    a.festival.name,
    separator: '',
    defPinyin: '',
  );
  final fb = PinyinHelper.getPinyinE(
    b.festival.name,
    separator: '',
    defPinyin: '',
  );
  final cf = fa.compareTo(fb);
  if (cf != 0) return cf;
  return a.festival.name.compareTo(b.festival.name);
}

/// 「藏」在「藏族」中读 zàng，词库常按 cáng 排序进入 C 组。在 [list] 已按
/// [_compareEthnicByPinyin] 排好序后，将 `zang` 紧挨置于 `zhuang` 之后，其余
/// 相对顺序不变（若列表中无壮族则 [藏族] 置尾）。
void _reorderZangAfterZhuang(List<EthnicGroup> list) {
  final zangI = list.indexWhere((g) => g.id == 'zang');
  if (zangI < 0) {
    return;
  }
  final zang = list.removeAt(zangI);
  final zhuangI = list.indexWhere((g) => g.id == 'zhuang');
  if (zhuangI < 0) {
    list.add(zang);
  } else {
    list.insert(zhuangI + 1, zang);
  }
}

/// 民族节日展开：固定高度标签区 + 各选中民族节日块（随页面整体滚动）。
/// 搜索模式下：区域 A 为匹配民族标签（可点击筛选），区域 B 为匹配节日列表。
class _EthnicFestivalListBody extends StatefulWidget {
  const _EthnicFestivalListBody({
    required this.membershipTier,
    required this.hiddenSilentIds,
    required this.colorScheme,
    required this.textTheme,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.ethnicGroups,
    required this.festivalsById,
    required this.blockExpanded,
    required this.onEthnicTagTap,
    required this.onBlockHeaderTap,
    required this.onSelectAll,
    required this.onFestivalSwitch,
  });

  final MembershipTier membershipTier;
  final Set<String> hiddenSilentIds;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final List<EthnicGroup> ethnicGroups;
  final Map<String, List<EthnicFestival>> festivalsById;
  final Map<String, bool> blockExpanded;
  final void Function(String id) onEthnicTagTap;
  final void Function(String id) onBlockHeaderTap;
  final void Function(String ethnicId, bool v) onSelectAll;
  final void Function(String ethnicId, int index, bool v) onFestivalSwitch;

  static String ethnicDisplayName(
    List<EthnicGroup> groups,
    String ethnicId,
  ) {
    for (final g in groups) {
      if (g.id == ethnicId) return g.name;
    }
    return ethnicId;
  }

  @override
  State<_EthnicFestivalListBody> createState() =>
      _EthnicFestivalListBodyState();
}

class _EthnicFestivalListBodyState extends State<_EthnicFestivalListBody> {
  /// 搜索模式下区域 A 选中的民族（再次点击取消）；查询变化或清空搜索时置 null。
  String? _selectedEthnicId;

  static const Color _searchEthnicSelectedBg = _kThemeBlue;
  static const Color _searchEthnicSelectedFg = Colors.white;
  static const Color _searchEthnicIdleBg = Color(0xFFDBEAFE);
  static const Color _searchEthnicIdleFg = _kThemeBlue;

  @override
  void didUpdateWidget(_EthnicFestivalListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldQ = oldWidget.searchQuery.trim().toLowerCase();
    final newQ = widget.searchQuery.trim().toLowerCase();
    if (oldQ != newQ) {
      _selectedEthnicId = null;
    }
  }

  Widget _textField(ColorScheme cs) {
    return TextField(
      enabled: true,
      onChanged: widget.onSearchChanged,
      style: widget.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        hintText: '搜索民族名称或节日名称',
        hintStyle: widget.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: cs.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          borderSide: BorderSide(color: Color(0xFFF1F5F9)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          borderSide: BorderSide(color: Color(0xFFF1F5F9)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          borderSide: BorderSide(color: Color(0xFF1A73E8), width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final tt = widget.textTheme;
    final q = widget.searchQuery.trim().toLowerCase();

    if (q.isEmpty) {
      final visible = widget.ethnicGroups.toList()
        ..sort(_compareEthnicByPinyin);
      _reorderZangAfterZhuang(visible);

      final selectedEthnic = widget.ethnicGroups
          .where((x) => x.isSelected)
          .toList()
        ..sort(_compareEthnicByPinyin);
      _reorderZangAfterZhuang(selectedEthnic);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, thickness: 0.7, color: Color(0xFFF3F4F6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _textField(cs),
                const SizedBox(height: 8),
                Text(
                  '按拼音首字母排序',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ClipRect(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final g in visible)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 4),
                              child: _EthnicGroupTagChip(
                                name: g.name,
                                isSelected: g.isSelected,
                                subscriptionCount:
                                    _activeEthnicSubscriptionCountFor(
                                  widget.festivalsById,
                                  widget.hiddenSilentIds,
                                  g.id,
                                ),
                                onTap: () => widget.onEthnicTagTap(g.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final g in selectedEthnic)
                  _EthnicGroupFestivalBlock(
                    membershipTier: widget.membershipTier,
                    hiddenSilentIds: widget.hiddenSilentIds,
                    group: g,
                    festivals: widget.festivalsById[g.id] ?? const [],
                    expanded: widget.blockExpanded[g.id] ?? true,
                    colorScheme: cs,
                    textTheme: tt,
                    onHeaderTap: () => widget.onBlockHeaderTap(g.id),
                    onSelectAll: (v) => widget.onSelectAll(g.id, v),
                    onFestivalSwitch: (i, v) =>
                        widget.onFestivalSwitch(g.id, i, v),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    final matchedEthnicGroups = widget.ethnicGroups.where((g) {
      if (g.name.toLowerCase().contains(q)) return true;
      final festivals = widget.festivalsById[g.id] ?? const <EthnicFestival>[];
      return festivals.any((f) => _ethnicFestivalMatchesQuery(f, g.name, q));
    }).toList()
      ..sort(_compareEthnicByPinyin);
    _reorderZangAfterZhuang(matchedEthnicGroups);

    final matchedFestivals = <_EthnicSearchHit>[];
    for (final entry in widget.festivalsById.entries) {
      final ethnicId = entry.key;
      final ethnicName =
          _EthnicFestivalListBody.ethnicDisplayName(widget.ethnicGroups, ethnicId);
      for (var i = 0; i < entry.value.length; i++) {
        final festival = entry.value[i];
        if (_ethnicFestivalMatchesQuery(festival, ethnicName, q)) {
          matchedFestivals.add(
            _EthnicSearchHit(
              ethnicId: ethnicId,
              ethnicName: ethnicName,
              festivalIndex: i,
              festival: festival,
            ),
          );
        }
      }
    }
    matchedFestivals.sort(_compareEthnicSearchHits);

    final List<_EthnicSearchHit> displayFestivals;
    if (_selectedEthnicId == null) {
      displayFestivals = matchedFestivals;
    } else {
      final list = widget.festivalsById[_selectedEthnicId!];
      if (list == null || list.isEmpty) {
        displayFestivals = const [];
      } else {
        final name = _EthnicFestivalListBody.ethnicDisplayName(
          widget.ethnicGroups,
          _selectedEthnicId!,
        );
        displayFestivals = [
          for (var i = 0; i < list.length; i++)
            _EthnicSearchHit(
              ethnicId: _selectedEthnicId!,
              ethnicName: name,
              festivalIndex: i,
              festival: list[i],
            ),
        ]..sort(_compareEthnicSearchHits);
      }
    }

    final noResults =
        matchedEthnicGroups.isEmpty && matchedFestivals.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, thickness: 0.7, color: Color(0xFFF3F4F6)),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _textField(cs),
              const SizedBox(height: 12),
              if (noResults)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '未找到相关民族或节日，试试"藏族"或"新年"',
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                )
              else ...[
                if (matchedEthnicGroups.isNotEmpty) ...[
                  SizedBox(
                    height: 120,
                    child: ClipRect(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final g in matchedEthnicGroups)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 4),
                                child: _EthnicGroupTagChip(
                                  name: g.name,
                                  isSelected: _selectedEthnicId == g.id,
                                  subscriptionCount:
                                      _activeEthnicSubscriptionCountFor(
                                    widget.festivalsById,
                                    widget.hiddenSilentIds,
                                    g.id,
                                  ),
                                  selectedBackground: _searchEthnicSelectedBg,
                                  unselectedBackground: _searchEthnicIdleBg,
                                  selectedForeground: _searchEthnicSelectedFg,
                                  unselectedForeground: _searchEthnicIdleFg,
                                  unselectedBorderColor: Colors.transparent,
                                  horizontalPadding: 12,
                                  verticalPadding: 6,
                                  fontSize: 14,
                                  onTap: () {
                                    setState(() {
                                      if (_selectedEthnicId == g.id) {
                                        _selectedEthnicId = null;
                                      } else {
                                        _selectedEthnicId = g.id;
                                      }
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (displayFestivals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '该筛选下暂无节日条目',
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var hi = 0; hi < displayFestivals.length; hi++) ...[
                          if (hi > 0)
                            Divider(
                              height: 1,
                              thickness: 0.7,
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _EthnicFestivalRow(
                              item: displayFestivals[hi].festival,
                              ethnicBadgeName: displayFestivals[hi].ethnicName,
                              colorScheme: cs,
                              textTheme: tt,
                              silentRetained: widget.hiddenSilentIds
                                  .contains(displayFestivals[hi].festival.id),
                              onChanged: (v) => widget.onFestivalSwitch(
                                displayFestivals[hi].ethnicId,
                                displayFestivals[hi].festivalIndex,
                                v,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EthnicGroupFestivalBlock extends StatelessWidget {
  const _EthnicGroupFestivalBlock({
    required this.membershipTier,
    required this.hiddenSilentIds,
    required this.group,
    required this.festivals,
    required this.expanded,
    required this.colorScheme,
    required this.textTheme,
    required this.onHeaderTap,
    required this.onSelectAll,
    required this.onFestivalSwitch,
  });

  final MembershipTier membershipTier;
  final Set<String> hiddenSilentIds;
  final EthnicGroup group;
  final List<EthnicFestival> festivals;
  final bool expanded;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onHeaderTap;
  final ValueChanged<bool> onSelectAll;
  final void Function(int index, bool v) onFestivalSwitch;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final eligible = festivals.where((e) => e.calendarEligible).toList();
    final total = eligible.length;
    final onCount = eligible.where((e) => e.isSubscribed).length;
    final allOn = total > 0 && onCount == total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        decoration: BoxDecoration(
          color: _kReligionCardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _FestivalSubgroupHeader(
              title: '${group.name}节日',
              expanded: expanded,
              allOn: allOn,
              switchEnabled: total > 0 && membershipTier != MembershipTier.free,
              onExpandTap: onHeaderTap,
              onSelectAll: onSelectAll,
              colorScheme: cs,
              textTheme: textTheme,
              titleStyle: textTheme.bodyLarge?.copyWith(
                color: _kReligionTitleBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: festivals.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    '暂无民族节日',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (int i = 0; i < festivals.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          thickness: 0.7,
                                          color: cs.outlineVariant.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: _EthnicFestivalRow(
                                          item: festivals[i],
                                          colorScheme: cs,
                                          textTheme: textTheme,
                                          silentRetained: hiddenSilentIds
                                              .contains(festivals[i].id),
                                          onChanged: (v) =>
                                              onFestivalSwitch(i, v),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EthnicFestivalRow extends StatelessWidget {
  const _EthnicFestivalRow({
    required this.item,
    required this.colorScheme,
    required this.textTheme,
    this.ethnicBadgeName,
    this.silentRetained = false,
    this.onChanged,
  });

  final EthnicFestival item;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  /// 搜索结果模式下显示民族小标签（如「藏族」）。
  final String? ethnicBadgeName;
  final bool silentRetained;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final nameStyle = textTheme.bodyLarge?.copyWith(
      color: item.isCultureOnly ? cs.onSurfaceVariant : cs.onSurface,
      fontWeight: FontWeight.w400,
    );
    final effectiveNameStyle = silentRetained && !item.isCultureOnly
        ? textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w400,
          )
        : nameStyle;
    final cal = item.ethnicCalendar.trim();
    final lockedInteraction = silentRetained;

    ValueChanged<bool>? effectiveOnChanged;
    if (item.calendarEligible) {
      effectiveOnChanged = lockedInteraction ? null : onChanged;
    }

    Widget inner = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _ethnicFestivalDetailInkWell(
              context,
              item,
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: effectiveNameStyle,
                        ),
                      ),
                      if ((ethnicBadgeName ?? '').trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            ethnicBadgeName!.trim(),
                            style: const TextStyle(
                              color: Color(0xFF1E40AF),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      if (item.isCultureOnly) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _kCultureOnlyTagBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '文化介绍',
                            style: TextStyle(
                              color: _kCultureOnlyTagForeground,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      if (cal.isNotEmpty && !item.isCultureOnly) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _kLunarTagBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            cal,
                            style: const TextStyle(
                              color: _kLunarTagForeground,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.gregorianDate.isNotEmpty && !item.isCultureOnly) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.gregorianDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: silentRetained
                            ? const Color(0xFF94A3B8)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (silentRetained) ...[
                    const SizedBox(height: 4),
                    Text(
                      '升级后可恢复提醒',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Switch.adaptive(
            value: item.calendarEligible ? item.isSubscribed : false,
            onChanged: effectiveOnChanged,
            activeTrackColor: cs.primary,
            activeThumbColor: cs.onPrimary,
          ),
        ],
      ),
    );

    if (silentRetained) {
      inner = Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: inner,
      );
    }

    return Opacity(
      opacity: silentRetained ? 0.6 : 1,
      child: inner,
    );
  }
}

/// 宗教列表浅蓝卡片（设计稿 #F0F9FF），标题 #1E40AF。
const Color _kReligionCardBackground = Color(0xFFF0F9FF);
const Color _kReligionTitleBlue = Color(0xFF1E40AF);

/// 民族/宗教分组标题行：左侧标题，右侧展开箭头 + 批量订阅开关。
class _FestivalSubgroupHeader extends StatelessWidget {
  const _FestivalSubgroupHeader({
    required this.title,
    required this.expanded,
    required this.allOn,
    required this.switchEnabled,
    required this.onExpandTap,
    required this.onSelectAll,
    required this.colorScheme,
    required this.textTheme,
    this.titleStyle,
  });

  final String title;
  final bool expanded;
  final bool allOn;
  final bool switchEnabled;
  final VoidCallback? onExpandTap;
  final ValueChanged<bool>? onSelectAll;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: onExpandTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: titleStyle ??
                            textTheme.titleSmall?.copyWith(
                              color: const Color(0xFF364153),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Switch.adaptive(
              value: allOn,
              onChanged: switchEnabled ? onSelectAll : null,
              activeTrackColor: colorScheme.primary,
              activeThumbColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReligiousFestivalListBody extends StatelessWidget {
  const _ReligiousFestivalListBody({
    required this.membershipTier,
    required this.hiddenSilentIds,
    required this.categoryEnabled,
    required this.colorScheme,
    required this.textTheme,
    required this.religionGroups,
    required this.onCardExpand,
    required this.onSelectAll,
    required this.onFestivalSwitch,
  });

  final MembershipTier membershipTier;
  final Set<String> hiddenSilentIds;
  final bool categoryEnabled;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final List<ReligionGroup> religionGroups;
  final void Function(String religionId) onCardExpand;
  final void Function(String religionId, bool v) onSelectAll;
  final void Function(String religionId, int index, bool v) onFestivalSwitch;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, thickness: 0.7, color: Color(0xFFF3F4F6)),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
          child: Opacity(
            opacity: categoryEnabled ? 1 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < religionGroups.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _ReligionCard(
                    group: religionGroups[i],
                    membershipTier: membershipTier,
                    hiddenSilentIds: hiddenSilentIds,
                    categoryEnabled: categoryEnabled,
                    colorScheme: cs,
                    textTheme: textTheme,
                    onHeaderTap: () => onCardExpand(religionGroups[i].id),
                    onSelectAll: (v) => onSelectAll(religionGroups[i].id, v),
                    onFestivalSwitch: (index, v) =>
                        onFestivalSwitch(religionGroups[i].id, index, v),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReligionCard extends StatelessWidget {
  const _ReligionCard({
    required this.group,
    required this.membershipTier,
    required this.hiddenSilentIds,
    required this.categoryEnabled,
    required this.colorScheme,
    required this.textTheme,
    required this.onHeaderTap,
    required this.onSelectAll,
    required this.onFestivalSwitch,
  });

  final ReligionGroup group;
  final MembershipTier membershipTier;
  final Set<String> hiddenSilentIds;
  final bool categoryEnabled;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onHeaderTap;
  final ValueChanged<bool> onSelectAll;
  final void Function(int index, bool v) onFestivalSwitch;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final eligible =
        group.festivals.where((e) => e.calendarEligible).toList();
    final total = eligible.length;
    final onCount = eligible.where((e) => e.isSubscribed).length;
    final allOn = total > 0 && onCount == total;
    final showList = categoryEnabled && group.isExpanded;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: _kReligionCardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FestivalSubgroupHeader(
            title: '${group.name}节日',
            expanded: group.isExpanded,
            allOn: allOn,
            switchEnabled: categoryEnabled &&
                total > 0 &&
                membershipTier != MembershipTier.free,
            onExpandTap: categoryEnabled ? onHeaderTap : null,
            onSelectAll: onSelectAll,
            colorScheme: cs,
            textTheme: textTheme,
            titleStyle: textTheme.bodyLarge?.copyWith(
              color: _kReligionTitleBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: showList
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: group.festivals.isEmpty
                            ? const SizedBox.shrink()
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int i = 0;
                                      i < group.festivals.length;
                                      i++) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        thickness: 0.7,
                                        color: cs.outlineVariant.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: _ReligiousFestivalRow(
                                        item: group.festivals[i],
                                        colorScheme: cs,
                                        textTheme: textTheme,
                                        silentRetained: hiddenSilentIds
                                            .contains(group.festivals[i].id),
                                        onChanged: categoryEnabled
                                            ? (v) => onFestivalSwitch(i, v)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ReligiousFestivalRow extends StatelessWidget {
  const _ReligiousFestivalRow({
    required this.item,
    required this.colorScheme,
    required this.textTheme,
    this.silentRetained = false,
    this.onChanged,
  });

  final ReligiousFestival item;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool silentRetained;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final nameStyle = textTheme.bodyLarge?.copyWith(
      color: item.isCultureOnly ? cs.onSurfaceVariant : cs.onSurface,
      fontWeight: FontWeight.w400,
    );
    final effectiveNameStyle = silentRetained && !item.isCultureOnly
        ? textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w400,
          )
        : nameStyle;
    final cal = item.calendarDate.trim();
    final lockedInteraction = silentRetained;

    ValueChanged<bool>? effectiveOnChanged;
    if (item.calendarEligible) {
      effectiveOnChanged = lockedInteraction ? null : onChanged;
    }

    Widget inner = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _religiousFestivalDetailInkWell(
              context,
              item,
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: effectiveNameStyle,
                        ),
                      ),
                      if (item.isCultureOnly) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _kCultureOnlyTagBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '文化介绍',
                            style: TextStyle(
                              color: _kCultureOnlyTagForeground,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      if (cal.isNotEmpty && !item.isCultureOnly) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: _kLunarTagBackground,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                            ),
                            child: Text(
                              cal,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _kLunarTagForeground,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.gregorianDate.isNotEmpty && !item.isCultureOnly) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.gregorianDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: silentRetained
                            ? const Color(0xFF94A3B8)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (silentRetained) ...[
                    const SizedBox(height: 4),
                    Text(
                      '升级后可恢复提醒',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Switch.adaptive(
            value: item.calendarEligible ? item.isSubscribed : false,
            onChanged: effectiveOnChanged,
            activeTrackColor: cs.primary,
            activeThumbColor: cs.onPrimary,
          ),
        ],
      ),
    );

    if (silentRetained) {
      inner = Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: inner,
      );
    }

    return Opacity(
      opacity: silentRetained ? 0.6 : 1,
      child: inner,
    );
  }
}

class _ExpandedPlaceholder extends StatelessWidget {
  const _ExpandedPlaceholder({
    required this.colorScheme,
    required this.textTheme,
    required this.festivalNames,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final List<String> festivalNames;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    if (festivalNames.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        child: Text(
          '节日列表待接入',
          style: textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      itemCount: festivalNames.length,
      separatorBuilder: (context, _) => Divider(
        height: 1,
        color: cs.outlineVariant,
      ),
      itemBuilder: (context, i) {
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            festivalNames[i],
            style: textTheme.bodyMedium?.copyWith(color: cs.onSurface),
          ),
        );
      },
    );
  }
}
