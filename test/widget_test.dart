import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moble_app/main.dart';

void main() {
  testWidgets('AppLogo widget renders correctly with and without text', (WidgetTester tester) async {
    // Test AppLogo with text (default)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo(),
        ),
      ),
    );

    // Verify Image is present
    expect(find.byType(Image), findsOneWidget);

    // Test AppLogo without text
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo.small(),
        ),
      ),
    );

    // Verify Image is present
    expect(find.byType(Image), findsOneWidget);
  });
}
