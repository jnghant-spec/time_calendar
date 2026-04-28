/// 事件条数与配额侧占位服务（后续可接入 [User]、会员档位与本地持久化）。
class EventUsageService {
  EventUsageService._();

  static int _currentCount = 0;

  /// 最近一次 [updateCount] 写入的数量（调试用/占位）
  static int get currentCount => _currentCount;

  /// 与清单中事件条数同步，便于后续与会员「剩余额度」等逻辑对接。
  static void updateCount(int count) {
    if (count < 0) return;
    _currentCount = count;
  }

  /// 预留：按业务规则重算并写回条数
  static void recalculateFromList(int length) {
    updateCount(length);
  }
}
