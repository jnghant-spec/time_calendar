import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpinyin/lpinyin.dart';

import 'ethnic_festival_data.dart';
import 'religious_festival_data.dart';

/// 节日分类——订阅与展开状态（[festivals] 接 API 后用于非公历分类占位）。
class FestivalCategory {
  FestivalCategory({
    required this.id,
    required this.name,
    required this.isSubscribed,
    required this.subscribedCount,
    this.expanded = false,
    this.festivals = const [],
  });

  final String id;
  final String name;
  bool isSubscribed;
  int subscribedCount;
  bool expanded;
  final List<String> festivals;
}

/// 节日子项：公历用 [date]；农历用 [lunarDate] + [gregorianDate]（与 [date] 互斥展示）。
class FestivalItem {
  FestivalItem({
    required this.name,
    this.date = '',
    this.lunarDate,
    this.gregorianDate,
    this.icon,
    this.iconAsset,
    required this.isSubscribed,
  });

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

/// 民族节日子项（[ethnicCalendar] 为标签全文，如 `藏历 木羊年一月初一`；可为空如朝鲜族回甲节）。
class EthnicFestival {
  EthnicFestival({
    required this.ethnicId,
    required this.name,
    required this.ethnicCalendar,
    required this.gregorianDate,
    required this.isSubscribed,
  });

  final String ethnicId;
  final String name;
  final String ethnicCalendar;
  final String gregorianDate;
  bool isSubscribed;
}

/// 单条宗教节日（与 [ReligionGroup] 组合展示）。
class ReligiousFestival {
  ReligiousFestival({
    required this.religionId,
    required this.name,
    required this.calendarDate,
    required this.gregorianDate,
    required this.isSubscribed,
  });

  final String religionId;
  final String name;
  final String calendarDate;
  final String gregorianDate;
  bool isSubscribed;
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

/// 公历/农历/民族/宗教节日订阅与展示。
class FestivalSettingsPage extends StatefulWidget {
  const FestivalSettingsPage({super.key});

  @override
  State<FestivalSettingsPage> createState() => _FestivalSettingsPageState();
}

class _FestivalSettingsPageState extends State<FestivalSettingsPage> {
  static const _pageBg = Color(0xFFF8F9FA);
  static const _coupleHeartsAsset = 'assets/images/ic_couple_hearts.svg';

  /// 公历：按日期顺序 12 项（母亲节/父亲节为浮动周日）；与设计稿 1–12 一致。
  static final List<FestivalItem> _gregorianSeed = [
    FestivalItem(
      name: '元旦',
      date: '1月1日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      name: '情人节',
      date: '2月14日',
      iconAsset: _coupleHeartsAsset,
      isSubscribed: false,
    ),
    FestivalItem(
      name: '妇女节',
      date: '3月8日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      name: '植树节',
      date: '3月12日',
      icon: Icons.calendar_today,
      isSubscribed: false,
    ),
    FestivalItem(
      name: '劳动节',
      date: '5月1日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      name: '母亲节',
      date: '5月第二个周日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      name: '儿童节',
      date: '6月1日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      name: '父亲节',
      date: '6月第三个周日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      name: '建党节',
      date: '7月1日',
      icon: Icons.calendar_today,
      isSubscribed: false,
    ),
    FestivalItem(
      name: '建军节',
      date: '8月1日',
      icon: Icons.calendar_today,
      isSubscribed: false,
    ),
    FestivalItem(
      name: '教师节',
      date: '9月10日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
    FestivalItem(
      name: '国庆节',
      date: '10月1日',
      icon: Icons.calendar_today,
      isSubscribed: true,
    ),
  ];

  static final List<FestivalItem> _lunarSeed = [
    FestivalItem(
      name: '春节',
      lunarDate: '正月初一',
      gregorianDate: '2027年2月6日',
      isSubscribed: true,
    ),
    FestivalItem(
      name: '元宵节',
      lunarDate: '正月十五',
      gregorianDate: '2027年2月20日',
      isSubscribed: true,
    ),
    FestivalItem(
      name: '龙抬头',
      lunarDate: '二月初二',
      gregorianDate: '2027年3月7日',
      isSubscribed: false,
    ),
    FestivalItem(
      name: '清明节',
      lunarDate: '二月廿九',
      gregorianDate: '2027年4月5日',
      isSubscribed: true,
    ),
    FestivalItem(
      name: '端午节',
      lunarDate: '五月初五',
      gregorianDate: '2027年6月19日',
      isSubscribed: true,
    ),
    FestivalItem(
      name: '七夕节',
      lunarDate: '七月初七',
      gregorianDate: '2027年8月19日',
      isSubscribed: true,
    ),
    FestivalItem(
      name: '中元节',
      lunarDate: '七月十五',
      gregorianDate: '2027年8月25日',
      isSubscribed: false,
    ),
    FestivalItem(
      name: '中秋节',
      lunarDate: '八月十五',
      gregorianDate: '2027年9月23日',
      isSubscribed: true,
    ),
    FestivalItem(
      name: '重阳节',
      lunarDate: '九月初九',
      gregorianDate: '2027年10月2日',
      isSubscribed: true,
    ),
    FestivalItem(
      name: '腊八节',
      lunarDate: '腊月初八',
      gregorianDate: '2027年1月18日',
      isSubscribed: false,
    ),
    FestivalItem(
      name: '小年',
      lunarDate: '腊月廿三',
      gregorianDate: '2027年2月1日',
      isSubscribed: false,
    ),
    FestivalItem(
      name: '除夕',
      lunarDate: '腊月廿九',
      gregorianDate: '2027年2月5日',
      isSubscribed: true,
    ),
  ];

  late final List<FestivalItem> _gregorianItems = _gregorianSeed
      .map(
        (e) => FestivalItem(
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

  late List<EthnicGroup> _ethnicGroups;
  late Map<String, List<EthnicFestival>> _ethnicFestivalsById;
  late Map<String, bool> _ethnicBlockExpanded;
  String _ethnicQuery = '';

  late List<ReligionGroup> _religionGroups;

  late final List<FestivalCategory> _categories = [
    FestivalCategory(
      id: 'gregorian',
      name: '公历节日',
      isSubscribed: true,
      subscribedCount: 8,
    ),
    FestivalCategory(
      id: 'lunar',
      name: '农历节日',
      isSubscribed: true,
      subscribedCount: 8,
    ),
    FestivalCategory(
      id: 'ethnic',
      name: '民族节日',
      isSubscribed: true,
      subscribedCount: 10,
    ),
    FestivalCategory(
      id: 'religious',
      name: '宗教节日',
      isSubscribed: false,
      subscribedCount: 0,
    ),
  ];

  int get _gregorianOnCount =>
      _gregorianItems.where((e) => e.isSubscribed).length;

  int get _lunarOnCount => _lunarItems.where((e) => e.isSubscribed).length;

  int get _ethnicOnCount {
    var n = 0;
    for (final list in _ethnicFestivalsById.values) {
      n += list.where((e) => e.isSubscribed).length;
    }
    return n;
  }

  int get _religiousOnCount {
    var n = 0;
    for (final g in _religionGroups) {
      n += g.festivals.where((e) => e.isSubscribed).length;
    }
    return n;
  }

  String _statusSubtitle(FestivalCategory c) {
    if (!c.isSubscribed) {
      return '未订阅';
    }
    if (c.id == 'gregorian') {
      return '已订阅 $_gregorianOnCount 个';
    }
    if (c.id == 'lunar') {
      return '已订阅 $_lunarOnCount 个';
    }
    if (c.id == 'ethnic') {
      return '已订阅 $_ethnicOnCount 个';
    }
    if (c.id == 'religious') {
      return '已订阅 $_religiousOnCount 个';
    }
    return '已订阅 ${c.subscribedCount} 个';
  }

  void _onCategorySwitchChanged(FestivalCategory c, bool v) {
    setState(() {
      c.isSubscribed = v;
    });
    if (v) {
      // TODO(后端): 订阅本分类节日
    } else {
      // TODO(后端): 取消本分类节日订阅
    }
  }

  void _onGregorianItemSwitch(int index, bool v) {
    setState(() {
      _gregorianItems[index].isSubscribed = v;
    });
    // TODO(后端): 单节日在日历中显示/隐藏
  }

  void _onLunarItemSwitch(int index, bool v) {
    setState(() {
      _lunarItems[index].isSubscribed = v;
    });
    // TODO(后端): 单农历节日在日历中显示/隐藏
  }

  void _onEthnicFestivalSwitch(String ethnicId, int index, bool v) {
    setState(() {
      _ethnicFestivalsById[ethnicId]![index].isSubscribed = v;
    });
    // TODO(后端): 单民族节日在日历中显示/隐藏
  }

  void _onEthnicGroupTap(String id) {
    if (!_categories.firstWhere((c) => c.id == 'ethnic').isSubscribed) {
      return;
    }
    setState(() {
      final g = _ethnicGroups.firstWhere((e) => e.id == id);
      g.isSelected = !g.isSelected;
      if (g.isSelected) {
        _ethnicBlockExpanded[id] = true;
      }
    });
  }

  void _onEthnicBlockHeaderTap(String id) {
    if (!_categories.firstWhere((c) => c.id == 'ethnic').isSubscribed) {
      return;
    }
    setState(() {
      _ethnicBlockExpanded[id] = !(_ethnicBlockExpanded[id] ?? true);
    });
  }

  void _onReligiousFestivalSwitch(String religionId, int index, bool v) {
    setState(() {
      final g = _religionGroups.firstWhere((e) => e.id == religionId);
      g.festivals[index].isSubscribed = v;
    });
  }

  void _onReligiousSelectAll(String religionId, bool v) {
    setState(() {
      final g = _religionGroups.firstWhere((e) => e.id == religionId);
      for (final f in g.festivals) {
        f.isSubscribed = v;
      }
    });
  }

  void _onReligiousCardExpand(String religionId) {
    if (!_categories.firstWhere((c) => c.id == 'religious').isSubscribed) {
      return;
    }
    setState(() {
      final g = _religionGroups.firstWhere((e) => e.id == religionId);
      g.isExpanded = !g.isExpanded;
    });
  }

  @override
  void initState() {
    super.initState();
    _ethnicGroups = [
      for (final r in kEthnicGroupRows)
        EthnicGroup(
          id: r.$1,
          name: r.$2,
          isSelected: r.$3,
        ),
    ];
    _ethnicFestivalsById = {
      for (final g in _ethnicGroups)
        g.id: [
          for (final t in (kEthnicFestivalsByGroup[g.id] ?? const []))
            EthnicFestival(
              ethnicId: g.id,
              name: t.$1,
              ethnicCalendar: t.$2,
              gregorianDate: t.$3,
              isSubscribed: t.$4,
            ),
        ],
    };
    _ethnicBlockExpanded = {for (final g in _ethnicGroups) g.id: true};

    _religionGroups = [
      for (final s in kReligionFestivalSeeds)
        ReligionGroup(
          id: s.$1,
          name: s.$2,
          isExpanded: true,
          festivals: [
            for (final t in s.$3)
              ReligiousFestival(
                religionId: s.$1,
                name: t.$1,
                calendarDate: t.$2,
                gregorianDate: t.$3,
                isSubscribed: false,
              ),
          ],
        ),
    ];
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
                for (final e in _categories.asMap().entries) ...[
                  if (e.key > 0) const SizedBox(height: 12),
                  _FestivalCategoryCard(
                    data: e.value,
                    colorScheme: cs,
                    textTheme: textTheme,
                    statusText: _statusSubtitle(e.value),
                    onHeaderTap: () {
                      setState(() {
                        e.value.expanded = !e.value.expanded;
                      });
                    },
                    onSwitch: (v) => _onCategorySwitchChanged(e.value, v),
                    expansionOverride: e.value.expanded
                        ? (e.value.id == 'gregorian'
                              ? _GregorianFestivalListBody(
                                  items: _gregorianItems,
                                  categoryEnabled: e.value.isSubscribed,
                                  colorScheme: cs,
                                  textTheme: textTheme,
                                  onItemChanged: _onGregorianItemSwitch,
                                )
                              : e.value.id == 'lunar'
                              ? _LunarFestivalListBody(
                                  items: _lunarItems,
                                  categoryEnabled: e.value.isSubscribed,
                                  colorScheme: cs,
                                  textTheme: textTheme,
                                  onItemChanged: _onLunarItemSwitch,
                                )
                              : e.value.id == 'ethnic'
                              ? _EthnicFestivalListBody(
                                  categoryEnabled: e.value.isSubscribed,
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
                                  onFestivalSwitch: _onEthnicFestivalSwitch,
                                )
                              : e.value.id == 'religious'
                              ? _ReligiousFestivalListBody(
                                  categoryEnabled: e.value.isSubscribed,
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
    required this.onHeaderTap,
    required this.onSwitch,
    this.expansionOverride,
  });

  final FestivalCategory data;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final String statusText;
  final VoidCallback onHeaderTap;
  final ValueChanged<bool> onSwitch;
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
                  Padding(
                    padding: const EdgeInsets.only(right: 8, left: 4),
                    child: Switch.adaptive(
                      value: data.isSubscribed,
                      onChanged: onSwitch,
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

  static const Color _gregorianBlue = Color(0xFF1E40AF);

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = _resolveIcon();

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 24,
        color: color,
      ),
    );
  }

  (IconData, Color) _resolveIcon() {
    final cs = colorScheme;
    switch (categoryId) {
      case 'gregorian':
        return (Icons.public, _gregorianBlue);
      case 'lunar':
        return (Icons.celebration, cs.primary);
      case 'ethnic':
        return (Icons.diversity_3, cs.primary);
      case 'religious':
        return (Icons.mosque, cs.primary);
      default:
        return (Icons.event, cs.primary);
    }
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
      color: item.name == '情人节' ? const Color(0xFFEF4444) : cs.onSurface,
      fontWeight: item.name == '情人节' ? FontWeight.w500 : FontWeight.w400,
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
class _EthnicFestivalListBody extends StatelessWidget {
  const _EthnicFestivalListBody({
    required this.categoryEnabled,
    required this.colorScheme,
    required this.textTheme,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.ethnicGroups,
    required this.festivalsById,
    required this.blockExpanded,
    required this.onEthnicTagTap,
    required this.onBlockHeaderTap,
    required this.onFestivalSwitch,
  });

  final bool categoryEnabled;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final List<EthnicGroup> ethnicGroups;
  final Map<String, List<EthnicFestival>> festivalsById;
  final Map<String, bool> blockExpanded;
  final void Function(String id) onEthnicTagTap;
  final void Function(String id) onBlockHeaderTap;
  final void Function(String ethnicId, int index, bool v) onFestivalSwitch;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final q = searchQuery.trim().toLowerCase();
    final visible = ethnicGroups.where((g) {
      if (q.isEmpty) return true;
      return g.name.toLowerCase().contains(q);
    }).toList()
      ..sort(_compareEthnicByPinyin);
    _reorderZangAfterZhuang(visible);

    final selectedEthnic = ethnicGroups
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
              TextField(
                enabled: categoryEnabled,
                onChanged: onSearchChanged,
                style: textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  hintText: '搜索民族名称',
                  hintStyle: textTheme.bodyMedium?.copyWith(
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '按拼音首字母排序',
                style: textTheme.bodySmall?.copyWith(
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
                          GestureDetector(
                            onTap: categoryEnabled
                                ? () => onEthnicTagTap(g.id)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: g.isSelected
                                    ? cs.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: g.isSelected
                                    ? null
                                    : Border.all(color: cs.outlineVariant),
                              ),
                              child: Text(
                                g.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: g.isSelected
                                      ? cs.onPrimary
                                      : cs.onSurface,
                                ),
                              ),
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
                  group: g,
                  categoryEnabled: categoryEnabled,
                  festivals: festivalsById[g.id] ?? const [],
                  expanded: blockExpanded[g.id] ?? true,
                  colorScheme: cs,
                  textTheme: textTheme,
                  onHeaderTap: () => onBlockHeaderTap(g.id),
                  onFestivalSwitch: (i, v) => onFestivalSwitch(g.id, i, v),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EthnicGroupFestivalBlock extends StatelessWidget {
  const _EthnicGroupFestivalBlock({
    required this.group,
    required this.categoryEnabled,
    required this.festivals,
    required this.expanded,
    required this.colorScheme,
    required this.textTheme,
    required this.onHeaderTap,
    required this.onFestivalSwitch,
  });

  final EthnicGroup group;
  final bool categoryEnabled;
  final List<EthnicFestival> festivals;
  final bool expanded;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onHeaderTap;
  final void Function(int index, bool v) onFestivalSwitch;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${group.name}节日',
                  style: textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF364153),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: categoryEnabled ? onHeaderTap : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    expanded ? '收起' : '展开',
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (expanded) ...[
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
    this.onChanged,
  });

  final EthnicFestival item;
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
    final cal = item.ethnicCalendar.trim();
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
                    if (cal.isNotEmpty) ...[
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
                if (item.gregorianDate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.gregorianDate,
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

/// 宗教列表浅蓝卡片（设计稿 #F0F9FF），标题 #1E40AF。
const Color _kReligionCardBackground = Color(0xFFF0F9FF);
const Color _kReligionTitleBlue = Color(0xFF1E40AF);

class _ReligiousFestivalListBody extends StatelessWidget {
  const _ReligiousFestivalListBody({
    required this.categoryEnabled,
    required this.colorScheme,
    required this.textTheme,
    required this.religionGroups,
    required this.onCardExpand,
    required this.onSelectAll,
    required this.onFestivalSwitch,
  });

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
    required this.categoryEnabled,
    required this.colorScheme,
    required this.textTheme,
    required this.onHeaderTap,
    required this.onSelectAll,
    required this.onFestivalSwitch,
  });

  final ReligionGroup group;
  final bool categoryEnabled;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onHeaderTap;
  final ValueChanged<bool> onSelectAll;
  final void Function(int index, bool v) onFestivalSwitch;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final total = group.festivals.length;
    final onCount = group.festivals.where((e) => e.isSubscribed).length;
    final allOn = total > 0 && onCount == total;
    final showList = categoryEnabled && group.isExpanded;

    return Material(
      color: _kReligionCardBackground,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: categoryEnabled ? onHeaderTap : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: _kReligionTitleBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '已订阅 $onCount/$total',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            group.isExpanded
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
                Text(
                  '全选',
                  style: textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF6A7282),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Switch.adaptive(
                    value: allOn,
                    onChanged: (categoryEnabled && total > 0)
                        ? (v) {
                            onSelectAll(v);
                          }
                        : null,
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
            child: showList
                ? Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: group.festivals.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < group.festivals.length; i++) ...[
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
                                    vertical: 0,
                                  ),
                                  child: _ReligiousFestivalRow(
                                    item: group.festivals[i],
                                    colorScheme: cs,
                                    textTheme: textTheme,
                                    onChanged: categoryEnabled
                                        ? (v) => onFestivalSwitch(i, v)
                                        : null,
                                  ),
                                ),
                              ],
                            ],
                          ),
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
    this.onChanged,
  });

  final ReligiousFestival item;
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
    final cal = item.calendarDate.trim();
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
                    if (cal.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: _kLunarTagBackground,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
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
                if (item.gregorianDate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.gregorianDate,
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
