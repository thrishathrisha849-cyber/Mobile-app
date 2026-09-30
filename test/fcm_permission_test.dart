import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moble_app/firebase_notification_service.dart';

void main() {
  group('FirebaseNotificationService.shouldRequestPermission', () {
    bool ask(AuthorizationStatus status, {required bool alreadyAsked}) =>
        FirebaseNotificationService.shouldRequestPermission(
            status, alreadyAsked);

    test('asks once when not granted and never asked before', () {
      expect(ask(AuthorizationStatus.denied, alreadyAsked: false), isTrue);
      expect(
          ask(AuthorizationStatus.notDetermined, alreadyAsked: false), isTrue);
    });

    test('never asks again after the prompt was shown once', () {
      for (final status in AuthorizationStatus.values) {
        expect(ask(status, alreadyAsked: true), isFalse, reason: '$status');
      }
    });

    test('never asks when already granted (e.g. Android 12 and below)', () {
      expect(ask(AuthorizationStatus.authorized, alreadyAsked: false), isFalse);
      expect(
          ask(AuthorizationStatus.provisional, alreadyAsked: false), isFalse);
    });
  });
}
