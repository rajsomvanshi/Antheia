import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:antheia/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AntheiaApp(dbReady: true));
    await tester.pump();

    expect(find.text('Antheia'), findsOneWidget);

    // Pump for 10 seconds to let the splash timer run out and navigate, disposing the splash controllers.
    await tester.pump(const Duration(seconds: 10));
  });
}

