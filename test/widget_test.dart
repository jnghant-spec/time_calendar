import 'package:flutter_test/flutter_test.dart';

import 'package:time_calendar/app/user_app_context.dart';
import 'package:time_calendar/main.dart';

void main() {
  testWidgets('主 Tab 外壳可见', (WidgetTester tester) async {
    await tester.pumpWidget(
      UserAppContext(
        tier: UserSubscriptionTier.free,
        child: MyApp(navigatorKey: appNavigatorKey),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('日历'), findsOneWidget);
    expect(find.text('清单'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
