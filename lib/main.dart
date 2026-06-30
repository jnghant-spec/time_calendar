import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:time_calendar/app/user_app_context.dart';
import 'package:time_calendar/pages/main_navigation_page.dart';
import 'package:time_calendar/services/event_service.dart';
import 'package:time_calendar/services/festival_service.dart';
import 'package:time_calendar/services/membership_service.dart';
import 'package:time_calendar/services/memory_service.dart';
import 'package:time_calendar/services/tag_service.dart';
import 'package:time_calendar/services/notification_service.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

  await FestivalService.ensureFestivalSeedDataLoaded();

  await TagService.loadTags();

  await MemoryService.ensureDemoSeedIfEmpty();

  if (kDebugMode) {
    await EventService.clearAllEvents();
    await EventService.seedJune5Events();
  }

  await NotificationService.init(navigatorKey: appNavigatorKey);

  await UserSession.instance.ensureInitialized();
  if (kDebugMode) {
    final festivals = FestivalService.getFestivalsForMonth(2026, 5);
    debugPrint(
      '[FestivalService probe 2026-05]\n'
      '${festivals.map((f) => '${f.name}: ${f.gregorianDate}').join('\n')}',
    );
  }
  runApp(
    UserAppContext(
      tier: UserSubscriptionTier.free,
      child: MyApp(navigatorKey: appNavigatorKey),
    ),
  );

  /// 新用户体验卡 + 节日/体验提醒调度：不阻塞首帧与 `runApp`。
  unawaited(_postLaunchMembershipAndReminders());
}

Future<void> _postLaunchMembershipAndReminders() async {
  try {
    await MembershipService.maybeOfferNewUserPremiumTrial();
    await NotificationService.scheduleUpcomingFestivalReminders();
  } catch (e, st) {
    assert(() {
      debugPrint('_postLaunchMembershipAndReminders failed: $e\n$st');
      return true;
    }());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '时光集',
      theme: appTheme,
      debugShowCheckedModeBanner: false, // ← 加这一行
      home: const MainNavigationPage(initialIndex: 3),
    );
  }
}
