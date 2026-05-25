import 'package:flutter_test/flutter_test.dart';

import 'package:flowjournal/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FlowJournalApp());
    await tester.pump();

    expect(find.text('FlowJournal'), findsOneWidget);
  });
}
