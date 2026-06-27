import 'package:flutter/material.dart';
import 'package:time_calendar/models/memory_collection.dart';
import 'package:time_calendar/pages/memory_photo_stream_sheet.dart';

/// 竖向时间线视图入口，与横向卡片视图共用同一弹窗，通过 PageView 局部切换。
Future<void> showMemoryCollectionTimelineSheet(
  BuildContext context, {
  required MemoryCollection collection,
}) {
  return showMemoryPhotoStreamSheet(
    context,
    collection: collection,
    initialViewIndex: 0,
  );
}
