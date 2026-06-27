import 'package:time_calendar/models/list_event.dart';
import 'package:time_calendar/services/user_session.dart';

/// 按当前登录手机号过滤可见提醒（DEBUG 多账号本地测试）。
bool isEventVisibleToCurrentUser(ListEvent event) {
  final phone = UserSession.instance.phone.trim();
  final owner = event.ownerPhone?.trim();
  if (owner == null || owner.isEmpty) {
    if (event.isShareIncoming) return true;
    return phone == UserPreferenceDefaults.defaultPhone;
  }
  return owner == phone;
}

List<ListEvent> filterEventsForCurrentUser(List<ListEvent> all) {
  return all.where(isEventVisibleToCurrentUser).toList();
}

/// 将当前用户可见列表的变更合并回全量列表（保留其他账号数据）。
List<ListEvent> mergeEventsForCurrentUser(
  List<ListEvent> allEvents,
  List<ListEvent> updatedForCurrentUser,
) {
  final others =
      allEvents.where((e) => !isEventVisibleToCurrentUser(e)).toList();
  return [...others, ...updatedForCurrentUser];
}

bool isEventOwnedByCurrentUser(ListEvent event) {
  final phone = UserSession.instance.phone.trim();
  final owner = event.ownerPhone?.trim();
  if (owner == null || owner.isEmpty) {
    return !event.isShareIncoming && phone == UserPreferenceDefaults.defaultPhone;
  }
  return owner == phone;
}
