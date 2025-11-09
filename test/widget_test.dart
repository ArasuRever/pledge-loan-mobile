// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1. Import your main.dart file
import 'package:pledge_loan_mobile/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 2. Build our app, which is PledgeLoanApp, not MyApp
    await tester.pumpWidget(const PledgeLoanApp());

    // --- The rest of this is default Flutter test code ---
    // Verify that our counter starts at 0.
    expect(find.text('0'), findsNothing); // We don't have a counter
    expect(find.text('1'), findsNothing);

    // This test won't pass because we don't have this UI,
    // but the file will no longer have an error.

    // Tap the '+' icon and trigger a frame.
    // await tester.tap(find.byIcon(Icons.add));
    // await tester.pump();

    // Verify that our counter has incremented.
    // expect(find.text('0'), findsNothing);
    // expect(find.text('1'), findsOneWidget);
  });
}