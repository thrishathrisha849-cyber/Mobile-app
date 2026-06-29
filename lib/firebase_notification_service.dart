import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  Background message handler (top-level function, REQUIRED by FCM)
// ─────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM Background] Title: ${message.notification?.title}');
  debugPrint('[FCM Background] Body:  ${message.notification?.body}');
  debugPrint('[FCM Background] Data:  ${message.data}');
}

// ─────────────────────────────────────────────
//  Firebase Notification Service
// ─────────────────────────────────────────────
class FirebaseNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Stream controller so the app can listen to incoming messages
  static final ValueNotifier<RemoteMessage?> onMessageReceived =
      ValueNotifier(null);

  /// Call once from main() after Firebase.initializeApp()
  static Future<void> initialize() async {
    // 1. Request permission (Android 13+ / iOS)
    await _requestPermission();

    // 2. Get & print FCM token (use this in Firebase Console to test)
    await _printFcmToken();

    // 3. Listen while app is FOREGROUND
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 4. Notification tapped while app was in BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 5. Check if app was launched via a notification tap (terminated state)
    final RemoteMessage? initialMessage =
        await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] App opened from terminated via notification');
      _handleNotificationTap(initialMessage);
    }

    // 6. Register background handler (must be top-level)
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    // 7. Android: create notification channel
    if (Platform.isAndroid) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // ── Permission ────────────────────────────────
  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
  }

  // ── Token ─────────────────────────────────────
  static Future<void> _printFcmToken() async {
    final token = await _messaging.getToken();
    debugPrint('═══════════════════════════════════════════');
    debugPrint('  FCM TOKEN (use in Firebase Console):');
    debugPrint('  $token');
    debugPrint('═══════════════════════════════════════════');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed: $newToken');
      // TODO: send newToken to your backend server here
    });
  }

  /// Get FCM token programmatically (e.g. to send to your server)
  static Future<String?> getFcmToken() async {
    return await _messaging.getToken();
  }

  // ── Foreground handler ─────────────────────────
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] Title: ${message.notification?.title}');
    debugPrint('[FCM Foreground] Body:  ${message.notification?.body}');
    debugPrint('[FCM Foreground] Data:  ${message.data}');

    // Notify any listening widgets
    onMessageReceived.value = message;
  }

  // ── Notification tap handler ───────────────────
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM Tap] Title: ${message.notification?.title}');
    debugPrint('[FCM Tap] Data:  ${message.data}');

    // TODO: Navigate to a specific screen based on message.data
    // Example:
    // final route = message.data['route'];
    // if (route == 'community') navigatorKey.currentState?.pushNamed('/community');
  }
}
