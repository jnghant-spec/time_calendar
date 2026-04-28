import 'package:flutter_test/flutter_test.dart';

import 'package:time_calendar/app/user_app_context.dart';
import 'package:time_calendar/main.dart';

void main() {
  testWidgets('登录页展示', (WidgetTester tester) async {
    await tester.pumpWidget(
      UserAppContext(
        tier: UserSubscriptionTier.free,
        child: const MyApp(),
      ),
    );

    expect(find.text('欢迎使用时光日历'), findsOneWidget);
  });
}
