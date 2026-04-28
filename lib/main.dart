import 'package:flutter/material.dart';
import 'package:time_calendar/app/user_app_context.dart';
import 'package:time_calendar/pages/main_navigation_page.dart';
import 'package:time_calendar/services/user_session.dart';
import 'package:time_calendar/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserSession.instance.ensureInitialized();
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
