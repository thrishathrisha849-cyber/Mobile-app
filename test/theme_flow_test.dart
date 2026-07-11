import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moble_app/main.dart';
import 'package:moble_app/profile.dart';

// Mock Http Overrides to prevent Network Image asset errors in tests
class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => MockHttpClient();
}

class MockHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() {
    HttpOverrides.global = MockHttpOverrides();
  });

  testWidgets('Theme Flow Automation Test - Light and Dark Mode Contrast', (WidgetTester tester) async {
    // 1. Test LoginScreen in Dark Theme Mode
    appThemeNotifier.value = ThemeMode.dark;
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.dark,
        home: LoginScreen(),
      ),
    );
    await tester.pump();

    // Verify dark mode login screen elements render correctly
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In to access your courses, webinars & books'), findsOneWidget);
    expect(find.byType(AppLogo), findsOneWidget);

    // 2. Test LoginScreen in Light Theme Mode
    appThemeNotifier.value = ThemeMode.light;
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: LoginScreen(),
      ),
    );
    await tester.pump();

    // Verify light mode login screen elements render correctly
    expect(find.text('Welcome Back'), findsOneWidget);

    // 3. Test CreateAccountScreen in Light and Dark Mode
    appThemeNotifier.value = ThemeMode.dark;
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.dark,
        home: CreateAccountScreen(),
      ),
    );
    await tester.pump();
    expect(find.text('PRIMARY INTEREST'), findsOneWidget);

    appThemeNotifier.value = ThemeMode.light;
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: CreateAccountScreen(),
      ),
    );
    await tester.pump();
    expect(find.text('PRIMARY INTEREST'), findsOneWidget);

    // 4. Test ForgotPasswordScreen in Light and Dark Mode
    appThemeNotifier.value = ThemeMode.dark;
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.dark,
        home: ForgotPasswordScreen(),
      ),
    );
    await tester.pump();
    expect(find.text('Forgot your password?'), findsOneWidget);

    appThemeNotifier.value = ThemeMode.light;
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: ForgotPasswordScreen(),
      ),
    );
    await tester.pump();
    expect(find.text('Forgot your password?'), findsOneWidget);
  });
}
