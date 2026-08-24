import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/screens/auth/customer_login_screen.dart';

void main() {
  testWidgets('Customer Login Screen Google 1-Tap UI test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerLoginScreen(),
      ),
    );

    // Verify brand header
    expect(find.text('QueueLess'), findsOneWidget);

    // Verify Google 1-Tap Sign-In / Auto-Register button
    expect(find.text('Continue with Google'), findsOneWidget);

    // Verify feature highlights
    expect(find.text('Digital Queue Tokens'), findsOneWidget);
    expect(find.text('Live Turn Notifications'), findsOneWidget);
    expect(find.text('Instant QR Check-in'), findsOneWidget);

    // Verify NO text input fill boxes exist on the screen
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });
}
