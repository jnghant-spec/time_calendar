import 'package:flutter/foundation.dart';
import 'package:time_calendar/models/reminder_tag.dart';
import 'package:time_calendar/services/tag_service.dart';

/// 清单页 / 时光集页共享的标签栏选中状态。
class TagBarState extends ChangeNotifier {
  TagBarState._();

  static final TagBarState _instance = TagBarState._();

  factory TagBarState() => _instance;

  List<ReminderTag> tags = [];
  String? selectedTagId;

  Future<void> loadTags() async {
    tags = await TagService.loadTags();
    notifyListeners();
  }

  void selectTag(String? id) {
    if (id != null && id == selectedTagId) {
      selectedTagId = null;
    } else {
      selectedTagId = id;
    }
    notifyListeners();
  }
}
