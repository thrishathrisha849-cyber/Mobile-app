import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'notification_service.dart';
import 'profile.dart' show NotificationsScreen;

// ─────────────────────────────────────────────
//  Background message handler (top-level function, REQUIRED by FCM)
// ─────────────────────────────────────────────
// Runs in a separate isolate while the app is in the background or closed.
// Pushes sent by admin-app (services/pushService.js) always carry a
// `notification` block, which Android already shows in the system tray in
// those states — so this handler must NOT show a local notification too, or
// every push would appear twice.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Already initialized in this isolate.
  }
  debugPrint('[FCM Background] id=${message.messageId} data=${message.data}');
}

// ─────────────────────────────────────────────
//  Firebase Notification Service
// ─────────────────────────────────────────────
class FirebaseNotificationService {
  /// FCM topic every device subscribes to; admin-app sends broadcast pushes
  /// (one per `mobile_notifications` row) to this topic.
  static const String allUsersTopic = 'all_users';

  /// Must match `com.google.firebase.messaging.default_notification_channel_id`
  /// in AndroidManifest.xml, so tray notifications (background/closed) and
  /// locally shown ones (foreground) land in the same channel.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'tbt_notifications',
    'TBT Notifications',
    description: 'Updates from Tamil Business Tribe',
    importance: Importance.high,
  );

  /// White-on-transparent drawable (res/drawable/ic_stat_notification.xml).
  static const String _smallIcon = 'ic_stat_notification';

  /// Passed to MaterialApp so a notification tap can navigate without a
  /// BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // FCM token stored here after initialization (diagnostics only — delivery
  // is by topic, so the token is never sent to a server).
  static String? fcmToken;

  // Stream controller so the app can listen to incoming messages
  static final ValueNotifier<RemoteMessage?> onMessageReceived =
      ValueNotifier(null);

  // Message ids already shown as a local notification, so a redelivered
  // message is never shown twice.
  static final Set<String> _shownMessageIds = <String>{};

  // A tapped notification waiting for the home screen to exist (e.g. on a
  // cold start the splash screen would otherwise pushReplacement over it).
  static Map<String, dynamic>? _pendingTap;
  static int _homeScreensMounted = 0;

  /// Call once from main() after Firebase.initializeApp() succeeds. Every
  /// step is individually guarded so one failure (e.g. no network for the
  /// token) doesn't skip the others. Slow network/permission steps run in
  /// the background so they never delay app startup.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Background handler (must be a top-level function).
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    // 2. Local notifications plugin + Android channel.
    await _guard('local notifications setup', _initLocalNotifications);

    // 3. Listeners.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp
        .listen((message) => _handleTap(message.data));
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    // 4. iOS only: let the OS present pushes while in the foreground.
    // (Android ignores this; there we show a local notification instead.)
    if (Platform.isIOS) {
      await _guard('foreground presentation options', () =>
          _messaging.setForegroundNotificationPresentationOptions(
              alert: true, badge: true, sound: true));
    }

    // 5. App launched by tapping a notification while it was closed.
    await _guard('initial message', () async {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App opened from terminated via notification');
        _handleTap(initialMessage.data);
      }
    });
    await _guard('local notification launch details', () async {
      final details =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        _handleTap(_decodePayload(details!.notificationResponse?.payload));
      }
    });

    // 6. Permission, token and topic subscription (network/user dependent).
    unawaited(_requestPermissionAndSubscribe());
  }

  static Future<void> _guard(String step, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      debugPrint('[FCM] $step failed: $e');
    }
  }

  // ── Local notifications ───────────────────────
  static Future<void> _initLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings(_smallIcon),
      // Permission is requested via FirebaseMessaging, not here.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) =>
          _handleTap(_decodePayload(response.payload)),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // ── Permission / token / topic ────────────────
  static Future<void> _requestPermissionAndSubscribe() async {
    await _guard('permission request', () async {
      // On Android 13+ this shows the POST_NOTIFICATIONS runtime prompt.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
    });

    await _guard('token fetch', () async {
      fcmToken = await _messaging.getToken();
      _logToken('FCM token', fcmToken);
    });

    await _subscribeToAllUsers();
  }

  /// Subscribing is idempotent, so this runs on every app start (and after a
  /// token refresh). Retries with backoff, e.g. for a first launch offline.
  static Future<void> _subscribeToAllUsers() async {
    const retryDelays = [Duration(seconds: 10), Duration(seconds: 60)];
    for (var attempt = 0;; attempt++) {
      try {
        await _messaging.subscribeToTopic(allUsersTopic);
        debugPrint('[FCM] Subscribed to topic "$allUsersTopic"');
        return;
      } catch (e) {
        debugPrint('[FCM] Subscribe to "$allUsersTopic" failed '
            '(attempt ${attempt + 1}): $e');
        if (attempt >= retryDelays.length) return;
        await Future.delayed(retryDelays[attempt]);
      }
    }
  }

  static void _onTokenRefresh(String newToken) {
    fcmToken = newToken;
    _logToken('FCM token refreshed', newToken);
    unawaited(_subscribeToAllUsers());
  }

  // The full token is only printed in debug builds (for sending a test from
  // the Firebase Console); release logs get a short prefix.
  static void _logToken(String label, String? token) {
    if (token == null) {
      debugPrint('[FCM] $label: null');
    } else if (kDebugMode) {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('  $label (use in Firebase Console):');
      debugPrint('  $token');
      debugPrint('═══════════════════════════════════════════');
    } else {
      final prefix = token.length > 12 ? token.substring(0, 12) : token;
      debugPrint('[FCM] $label: $prefix…');
    }
  }

  /// Get FCM token programmatically (e.g. to send to your server)
  static Future<String?> getFcmToken() async {
    return await _messaging.getToken();
  }

  // ── Foreground handler ─────────────────────────
  // Android never displays FCM notifications while the app is open, so show
  // it ourselves via the local notifications plugin.
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] id=${message.messageId} data=${message.data}');

    // Notify any listening widgets, and refresh the in-app bell count since
    // every push corresponds to a new mobile_notifications row.
    onMessageReceived.value = message;
    NotificationBadge.instance.refresh();

    if (!Platform.isAndroid) return;

    final messageId = message.messageId;
    if (messageId != null && !_shownMessageIds.add(messageId)) return;

    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    unawaited(_guard('show local notification', () {
      return _localNotifications.show(
        (messageId ?? DateTime.now().toIso8601String()).hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: _smallIcon,
            color: const Color(0xFFD30814), // @color/notification_color
            styleInformation: BigTextStyleInformation(body ?? ''),
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }));
  }

  static Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(payload) as Map);
    } catch (_) {
      return {};
    }
  }

  // ── Notification tap handler ───────────────────
  // Opens the Notifications screen, which then routes to the referenced
  // content using its existing per-type tap logic. The keys mirror the
  // `data` payload sent by admin-app's pushService.js, mapped to the item
  // shape NotificationService.fetchNotifications() returns.
  static void _handleTap(Map<String, dynamic> data) {
    debugPrint('[FCM Tap] data=$data');
    _pendingTap = {
      'id': data['notification_id'],
      'type': data['type'],
      'referenceId': data['reference_id'],
      'referenceType': data['reference_type'],
    };
    _openPendingTap();
  }

  /// Called by the home screen (PostPopupScreen) when it mounts/unmounts;
  /// a tap is only acted on once the user is past splash/login.
  static void homeScreenMounted() {
    _homeScreensMounted++;
    _openPendingTap();
  }

  static void homeScreenUnmounted() {
    if (_homeScreensMounted > 0) _homeScreensMounted--;
  }

  static void _openPendingTap() {
    final tap = _pendingTap;
    if (tap == null || _homeScreensMounted == 0) return;
    _pendingTap = null;
    // Deferred: homeScreenMounted() is called from initState, while the
    // navigator is still mid-build and can't accept a push.
    scheduleMicrotask(() {
      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        _pendingTap = tap;
        return;
      }
      navigator.push(MaterialPageRoute(
        builder: (_) => NotificationsScreen(openNotification: tap),
      ));
    });
  }
}
