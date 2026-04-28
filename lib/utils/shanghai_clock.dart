/// 中国大陆常用时区逻辑（与 **Asia/Shanghai** 民用时间一致：全年 **UTC+8**，无夏令时）。
///
/// 等价于以 [DateTime.now] 的瞬时值为锚点，换算为上海（UTC+8）墙上的「今天」日历日。
/// 业务上按「上海日历日」比较日程时，请统一使用本工具，避免依赖设备本地时区。
abstract final class ShanghaiClock {
  ShanghaiClock._();

  /// 当前时刻对应的上海日历日（仅年月日，时间为 00:00:00，使用本地 DateTime 承载数值）。
  static DateTime todayDateOnly() {
    final utc = DateTime.now().toUtc();
    final shanghaiWall = utc.add(const Duration(hours: 8));
    return DateTime(shanghaiWall.year, shanghaiWall.month, shanghaiWall.day);
  }
}
