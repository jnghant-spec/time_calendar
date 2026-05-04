import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:time_calendar/app/user_app_context.dart';
import 'package:time_calendar/pages/main_navigation_page.dart';
import 'package:time_calendar/services/festival_service.dart';
import 'package:time_calendar/services/notification_service.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

  await NotificationService.init();
  await NotificationService.scheduleUpcomingFestivalReminders();

  await UserSession.instance.ensureInitialized();
  if (kDebugMode) {
    final festivals = FestivalService.getFestivalsForMonth(2026, 5);
    debugPrint(
      '[FestivalService probe 2026-05]\n'
      '${festivals.map((f) => '${f.name}: ${f.gregorianDate}').join('\n')}',
    );
  }
  runApp(UserAppContext(tier: UserSubscriptionTier.free, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '时光日历',
      theme: appTheme,
      // 主界面为三 Tab 外壳；[LoginPage] 内使用独立 Navigator 进入 [MainNavigationPage]（initialIndex 默认 0）。
      home: const MainNavigationPage(initialIndex: 2),
    );
  }
}
