import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'community.dart';
import 'notification_service.dart';
import 'profile.dart';
import 'course_quest.dart';
import 'podcast.dart';
import 'ebooks.dart';
import 'courses.dart';
import 'task.dart';
import 'firebase_notification_service.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SessionManager {
  static Future<File> _getSessionFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/session_state.txt');
  }

  static Future<bool> isLoggedIn() async {
    try {
      final file = await _getSessionFile();
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      return content.trim() == 'true';
    } catch (e) {
      return false;
    }
  }

  static Future<void> setLoggedIn(bool loggedIn) async {
    try {
      final file = await _getSessionFile();
      await file.writeAsString(loggedIn ? 'true' : 'false');
    } catch (e) {
      debugPrint('Error writing session: $e');
    }
  }
}

final ValueNotifier<ThemeMode> appThemeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.dark);

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class ThemeManager {
  static Future<File> _getThemeFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/theme_preference.txt');
  }

  static Future<ThemeMode> getThemeMode() async {
    try {
      final file = await _getThemeFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim() == 'light') {
          return ThemeMode.light;
        } else if (content.trim() == 'dark') {
          return ThemeMode.dark;
        }
      }
    } catch (e) {
      debugPrint('Error reading theme preference: $e');
    }
    return ThemeMode.dark;
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      final file = await _getThemeFile();
      await file.writeAsString(mode == ThemeMode.light ? 'light' : 'dark');
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme preference
  final savedTheme = await ThemeManager.getThemeMode();
  appThemeNotifier.value = savedTheme;

  // ── Firebase initialization ──────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseNotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase/FCM initialization failed: $e');
  }

  // ── Supabase initialization ──────────────────
  try {
    await Supabase.initialize(
      url: 'https://rhuskbutjlvxfyrujsos.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJodXNrYnV0amx2eGZ5cnVqc29zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NjU3ODIsImV4cCI6MjA5ODU0MTc4Mn0.h4kNLIUFINtIS3irBdPv_XQQedRa-6vdNAsC9AcKDRk',
    );
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentMode, child) {
        final isDark = currentMode == ThemeMode.dark ||
            (currentMode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor:
              isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF5F5F5),
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'Tamil Business Tribe',
          debugShowCheckedModeBanner: false,
          navigatorObservers: [routeObserver],
          themeMode: currentMode,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE50914),
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0B0B0F),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE50914),
              surface: Color(0xFF151515),
              onSurface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
            ),
          ),
          builder: (context, child) {
            return ConnectivityWrapper(child: child ?? const SizedBox());
          },
          home: const TBTVideoSplashScreen(),
        );
      },
    );
  }
}

class AppLogo extends StatelessWidget {
  final double width;
  final double height;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.width = 120.0,
    this.height = 36.0,
    this.fit = BoxFit.contain,
  });

  const AppLogo.appBar({super.key})
      : width = 120.0,
        height = 36.0,
        fit = BoxFit.contain;

  const AppLogo.card({super.key})
      : width = 140.0,
        height = 48.0,
        fit = BoxFit.contain;

  const AppLogo.small({super.key})
      : width = 80.0,
        height = 24.0,
        fit = BoxFit.contain;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark ||
            (currentMode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        return Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          child: Image.asset(
            isDark
                ? 'assets/images/TBT C Pvt Final logo-04.png'
                : 'assets/images/TBT C Pvt Final logo-light.png',
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => Text(
              'TBT',
              style: TextStyle(
                color: const Color(0xFFE50914),
                fontSize: height * 0.45,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Global Connectivity Wrapper — shows "No Internet" overlay
// ─────────────────────────────────────────────────────────────────
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _fastCheckTimer;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkInitial();

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });

    // Query hardware network state directly every 500ms to bypass OS broadcast delays
    _fastCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkInitial();
    });
  }

  void _checkInitial() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _updateStatus(results);
    } catch (_) {}
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final offline = results.isEmpty || results.contains(ConnectivityResult.none);
    if (mounted && _isOffline != offline) {
      setState(() => _isOffline = offline);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _fastCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline)
          Positioned.fill(
            child: const NoInternetOverlay(),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// No Internet Overlay — Animated, Premium, Responsive
// ─────────────────────────────────────────────────────────────────
class NoInternetOverlay extends StatefulWidget {
  const NoInternetOverlay({super.key});

  @override
  State<NoInternetOverlay> createState() => _NoInternetOverlayState();
}

class _NoInternetOverlayState extends State<NoInternetOverlay>
    with TickerProviderStateMixin {
  // Entrance fade
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeCurve;

  // WiFi icon pulse
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // WiFi icon bounce in
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  // Text slide up
  late AnimationController _textCtrl;
  late Animation<Offset> _textSlide;
  late Animation<double> _textFade;

  // Button slide up
  late AnimationController _btnCtrl;
  late Animation<Offset> _btnSlide;
  late Animation<double> _btnFade;

  // Signal bars animation
  late AnimationController _signalCtrl;

  @override
  void initState() {
    super.initState();

    // Overall entrance fade
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeCurve = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // WiFi icon elastic bounce
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _bounceAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));

    // WiFi icon pulse loop
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Title + subtitle slide up
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);

    // Retry button slide up
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _btnSlide = Tween<Offset>(
            begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOutCubic));
    _btnFade = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);

    // Signal bars stagger
    _signalCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    _startSequence();
  }

  void _startSequence() async {
    _fadeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _bounceCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _btnCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _bounceCtrl.dispose();
    _textCtrl.dispose();
    _btnCtrl.dispose();
    _signalCtrl.dispose();
    super.dispose();
  }

  void _onRetry() {
    // Trigger a recheck — the ConnectivityWrapper listener will auto-dismiss
    Connectivity().checkConnectivity();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final screenSize = MediaQuery.of(context).size;
    final isSmall = screenSize.width < 360;

    return FadeTransition(
      opacity: _fadeCurve,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF0B0B0F),
                      const Color(0xFF1A0A0A),
                      const Color(0xFF0B0B0F),
                    ]
                  : [
                      const Color(0xFFF8F8FC),
                      const Color(0xFFFFF0F0),
                      const Color(0xFFF8F8FC),
                    ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // ── Animated WiFi Icon with rings ──
                ScaleTransition(
                  scale: _bounceAnim,
                  child: ScaleTransition(
                    scale: _pulseAnim,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring
                        Container(
                          width: isSmall ? 130 : 160,
                          height: isSmall ? 130 : 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFE50914).withOpacity(0.08),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Middle ring
                        Container(
                          width: isSmall ? 100 : 120,
                          height: isSmall ? 100 : 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE50914).withOpacity(0.15),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Inner circle with icon
                        Container(
                          width: isSmall ? 80 : 96,
                          height: isSmall ? 80 : 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE50914).withOpacity(0.10),
                            border: Border.all(
                              color: const Color(0xFFE50914).withOpacity(0.25),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE50914).withOpacity(0.15),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.wifi_off_rounded,
                            color: const Color(0xFFE50914),
                            size: isSmall ? 36 : 44,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isSmall ? 28 : 40),

                // ── Animated signal bars ──
                AnimatedBuilder(
                  animation: _signalCtrl,
                  builder: (context, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final offset = (i * 0.25);
                        final t = (_signalCtrl.value + offset) % 1.0;
                        final opacity = (1.0 - t).clamp(0.15, 0.7);
                        final heights = [12.0, 18.0, 24.0, 30.0];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Container(
                            width: 6,
                            height: heights[i],
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914).withOpacity(opacity),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),

                SizedBox(height: isSmall ? 24 : 32),

                // ── Animated text ──
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFE50914), Color(0xFFFF6B35)],
                            ).createShader(bounds),
                            child: Text(
                              'No Internet Connection',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmall ? 22 : 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Please check your WiFi or mobile data and try again',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withOpacity(0.55)
                                  : Colors.black54,
                              fontSize: isSmall ? 13 : 14.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: isSmall ? 32 : 44),

                // ── Animated Retry Button ──
                FadeTransition(
                  opacity: _btnFade,
                  child: SlideTransition(
                    position: _btnSlide,
                    child: GestureDetector(
                      onTap: _onRetry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE50914), Color(0xFFB71C1C)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE50914).withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Retry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmall ? 14 : 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // Bottom branding
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    'Tamil Business Tribe',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.15),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────
/// Reusable animated sidebar drawer
/// ─────────────────────────────────────────────────────────────────
class TbtAppDrawer extends StatefulWidget {
  const TbtAppDrawer({super.key});

  @override
  State<TbtAppDrawer> createState() => _TbtAppDrawerState();
}

class _TbtAppDrawerState extends State<TbtAppDrawer>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  // 9 nav items + 1 logout = 10 staggered controllers
  final int _itemCount = 10;
  late List<AnimationController> _itemCtrls;
  late List<Animation<double>> _itemFades;
  late List<Animation<Offset>> _itemSlides;

  @override
  void initState() {
    super.initState();

    // Header animation
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _headerFade =
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
            begin: const Offset(-0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _headerCtrl, curve: Curves.easeOutCubic));

    // Staggered item animations
    _itemCtrls = List.generate(
      _itemCount,
      (i) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 380)),
    );
    _itemFades = _itemCtrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _itemSlides = _itemCtrls
        .map((c) => Tween<Offset>(
                begin: const Offset(-0.25, 0), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    _headerCtrl.forward();
    for (int i = 0; i < _itemCount; i++) {
      await Future.delayed(const Duration(milliseconds: 55));
      if (!mounted) return;
      _itemCtrls[i].forward();
    }
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    for (final c in _itemCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white60 : Colors.black54;
    final dividerColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.08);

    Widget animItem(int idx, Widget child) => FadeTransition(
          opacity: _itemFades[idx],
          child: SlideTransition(position: _itemSlides[idx], child: child),
        );

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        children: [
          // Glassmorphic blurred background
          Positioned.fill(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22.0, sigmaY: 22.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0A0A0C).withOpacity(0.93)
                        : Colors.white.withOpacity(0.94),
                    border: Border(
                      right: BorderSide(color: dividerColor, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Red accent gradient strip on the left edge
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 3,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE50914),
                    Color(0xFF8B0000),
                    Color(0xFFE50914),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Animated Header ─────────────────────────────────
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: dividerColor, width: 1.0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const AppLogo.appBar(),
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.black.withOpacity(0.04),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      color: textColor, size: 20),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            children: [
                              // Avatar with red ring
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE50914),
                                      Color(0xFF8B0000)
                                    ],
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(1.5),
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.transparent),
                                  child: ClipOval(
                                    child: ProfileScreen.profileImagePath !=
                                            null
                                        ? Image.file(
                                            File(ProfileScreen
                                                .profileImagePath!),
                                            width: 42.0,
                                            height: 42.0,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop&crop=face',
                                            width: 42.0,
                                            height: 42.0,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                Container(
                                                  width: 42.0,
                                                  height: 42.0,
                                                  color:
                                                      const Color(0xFF48484A),
                                                  child: const Icon(
                                                      Icons.person,
                                                      color: Colors.white70),
                                                ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Thrisha',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      'Co-Founder, Creative Studios',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: subTextColor,
                                          fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Animated Navigation Items ─────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      animItem(0, _TbtDrawerItem(
                        icon: Icons.home_rounded,
                        label: 'Home Feed',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                      )),
                      animItem(1, _TbtDrawerItem(
                        icon: Icons.emoji_events_rounded,
                        label: 'TBT Leaderboard',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                      )),
                      animItem(2, _TbtDrawerItem(
                        icon: Icons.groups_rounded,
                        label: 'Community Feed',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const CommunityScreen()),
                            (route) => route.isFirst,
                          );
                        },
                      )),
                      animItem(3, _TbtDrawerItem(
                        icon: Icons.school_rounded,
                        label: 'Courses Path',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const CoursesScreen()),
                            (route) => route.isFirst,
                          );
                        },
                      )),
                      animItem(4, _TbtDrawerItem(
                        icon: Icons.map_rounded,
                        label: 'Course Quest',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const CourseQuestScreen()),
                          );
                        },
                      )),
                      animItem(5, _TbtDrawerItem(
                        icon: Icons.podcasts_rounded,
                        label: 'Voice of Sakthi',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const PodcastScreen()),
                          );
                        },
                      )),
                      animItem(6, _TbtDrawerItem(
                        icon: Icons.menu_book_rounded,
                        label: 'E-Book Library',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const EBooksLibraryScreen()),
                          );
                        },
                      )),
                      animItem(7, _TbtDrawerItem(
                        icon: Icons.notifications_rounded,
                        label: 'Notifications',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationsScreen()),
                          );
                        },
                      )),
                      animItem(8, _TbtDrawerItem(
                        icon: Icons.person_rounded,
                        label: 'My Profile',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const ProfileScreen()),
                          );
                        },
                      )),
                    ],
                  ),
                ),

                // ── Animated Footer – Logout ──────────────────────
                animItem(
                  9,
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: dividerColor, width: 1.0)),
                    ),
                    child: _TbtDrawerItem(
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      iconColor: const Color(0xFFE50914),
                      labelColor: const Color(0xFFE50914),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const LogoutConfirmationScreen()),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated drawer item with scale + glow press effect
class _TbtDrawerItem extends StatefulWidget {
  const _TbtDrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final bool isSelected;

  @override
  State<_TbtDrawerItem> createState() => _TbtDrawerItemState();
}

class _TbtDrawerItemState extends State<_TbtDrawerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
        CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    setState(() => _isPressed = true);
    _pressCtrl.forward();
  }

  void _onTapUp(_) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() => _isPressed = false);
      _pressCtrl.reverse();
    }
    widget.onTap();
  }

  void _onTapCancel() {
    if (mounted) setState(() => _isPressed = false);
    _pressCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final resolvedLabel = widget.isSelected
        ? const Color(0xFFE50914)
        : (widget.labelColor ??
            (isDark ? Colors.white.withOpacity(0.88) : Colors.black87));
    final resolvedIcon = widget.isSelected || _isPressed
        ? const Color(0xFFE50914)
        : (widget.iconColor ??
            (isDark ? Colors.white60 : Colors.black54));

    final bgColor = _isPressed
        ? const Color(0xFFE50914).withOpacity(0.10)
        : widget.isSelected
            ? const Color(0xFFE50914).withOpacity(0.12)
            : Colors.transparent;

    final iconBgColor = _isPressed || widget.isSelected
        ? const Color(0xFFE50914).withOpacity(0.18)
        : isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.05);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.94).animate(
          CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3.0),
          padding:
              const EdgeInsets.symmetric(vertical: 13.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14.0),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFE50914).withOpacity(0.15),
                      blurRadius: 10,
                      spreadRadius: 0,
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Icon pill — only animates color (no border, safe for AnimatedContainer)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(7.0),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Icon(widget.icon, color: resolvedIcon, size: 20.0),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: resolvedLabel,
                    fontSize: 14.5,
                    fontWeight: widget.isSelected || _isPressed
                        ? FontWeight.bold
                        : FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              // Chevron arrow
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: _isPressed
                      ? const Color(0xFFE50914).withOpacity(0.7)
                      : resolvedIcon.withOpacity(0.4),
                  size: 18.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class TBTVideoSplashScreen extends StatefulWidget {
  const TBTVideoSplashScreen({super.key});

  @override
  State<TBTVideoSplashScreen> createState() => _TBTVideoSplashScreenState();
}

class _TBTVideoSplashScreenState extends State<TBTVideoSplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.asset('assets/images/tbt_logo_video.mp4');
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _controller.play();
      }
    }).catchError((error) {
      debugPrint('Error initializing video splash: $error');
      _navigateToMain();
    });

    _controller.addListener(() {
      if (mounted && _controller.value.position >= _controller.value.duration) {
        _navigateToMain();
      }
    });

    // Fallback timer to navigate to main app after 6 seconds in case of loading issues
    _fallbackTimer = Timer(const Duration(seconds: 6), () {
      _navigateToMain();
    });
  }

  void _navigateToMain() async {
    if (!_navigated && mounted) {
      _navigated = true;
      _fallbackTimer?.cancel();
      _controller.pause();

      final loggedIn = await SessionManager.isLoggedIn();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                loggedIn ? const PostPopupScreen() : const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFD30814)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}


class AchievementComposer extends StatefulWidget {
  final VoidCallback? onPosted;
  const AchievementComposer({super.key, this.onPosted});

  @override
  State<AchievementComposer> createState() => _AchievementComposerState();
}

class _AchievementComposerState extends State<AchievementComposer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showEmojiPicker = false;
  XFile? _pickedImage;
  XFile? _pickedVideo;
  PlatformFile? _pickedAudio;
  String _visibility = 'Public';
  String? _selectedMilestone;
  bool _showPostCard = true;
  bool _isPostCardExpanded = true;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Hide emoji picker when keyboard is focused
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _insertEmoji(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;

    if (selection.start < 0) {
      // If there's no active cursor position, append emoji to the end
      _textController.text = text + emoji;
      // Move cursor to the end
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    } else {
      // Insert emoji at current cursor selection
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      final int newOffset = selection.start + emoji.length;
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 1,
          requestType: RequestType.image,
        ),
      );
      if (result != null && result.isNotEmpty) {
        final File? file = await result.first.file;
        if (file != null) {
          setState(() {
            _pickedImage = XFile(file.path);
            _pickedVideo = null; // Clear video
            _pickedAudio = null; // Clear audio
            _showEmojiPicker = false; // Hide emoji drawer
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting photo: $e'),
          backgroundColor: const Color(0xFFD30814),
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 1,
          requestType: RequestType.video,
        ),
      );
      if (result != null && result.isNotEmpty) {
        final File? file = await result.first.file;
        if (file != null) {
          setState(() {
            _pickedVideo = XFile(file.path);
            _pickedImage = null; // Clear image
            _pickedAudio = null; // Clear audio
            _showEmojiPicker = false; // Hide emoji drawer
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting video: $e'),
          backgroundColor: const Color(0xFFD30814),
        ),
      );
    }
  }

  Future<void> _pickAudio() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _pickedAudio = result.files.single;
          _pickedImage = null; // Clear image
          _pickedVideo = null; // Clear video
          _showEmojiPicker = false; // Hide emoji drawer
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting audio: $e'),
          backgroundColor: const Color(0xFFD30814),
        ),
      );
    }
  }

  void _showVisibilitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 500),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12.0),
              // Drag handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderCol,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              const SizedBox(height: 20.0),
              Text(
                'Who can see this?',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16.0),
              ListTile(
                leading: Icon(Icons.public, color: context.subTextColor),
                title:
                    Text('Public', style: TextStyle(color: context.textColor)),
                subtitle: Text(
                  'Anyone on or off Tamil Business Tribe',
                  style: TextStyle(color: context.subTextColor, fontSize: 12.0),
                ),
                trailing: _visibility == 'Public'
                    ? const Icon(Icons.check, color: Color(0xFFE50914))
                    : null,
                onTap: () {
                  setState(() {
                    _visibility = 'Public';
                  });
                  Navigator.pop(context);
                },
              ),
              Divider(color: context.borderCol),
              ListTile(
                leading:
                    Icon(Icons.people_alt_rounded, color: context.subTextColor),
                title:
                    Text('Friends', style: TextStyle(color: context.textColor)),
                subtitle: Text(
                  'Your connections on Tamil Business Tribe',
                  style: TextStyle(color: context.subTextColor, fontSize: 12.0),
                ),
                trailing: _visibility == 'Friends'
                    ? const Icon(Icons.check, color: Color(0xFFE50914))
                    : null,
                onTap: () {
                  setState(() {
                    _visibility = 'Friends';
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        );
      },
    );
  }

  final List<String> _emojis = [
    // Smileys
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
    '🙂', '😉', '😌', '😍', '🥰', '😘', '😋', '😛', '😜', '😎',
    '🤩', '🥳', '😏', '🤔', '🤨', '😐', '😑', '🙄', '😬', '😴',
    // Hands & Gestures
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '👋', '👏', '🙏', '🙌',
    // Hearts & Miscellaneous
    '❤️', '💖', '🔥', '🚀', '🎉', '🌟', '✨', '💯', '🎈', '💼',
    '📈', '💡', '🏆', '🎯', '🤝', '📣', '🔔', '🌍', '🇮🇳', '💻'
  ];

  Widget _buildMediaItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 16.0,
          ),
          const SizedBox(width: 4.0),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: context.isDark ? const Color(0xFFD1D1D6) : const Color(0xFF6E6E73),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 16.0,
      width: 1.0,
      color: context.borderCol,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
                        if (_showPostCard)
                          Container(
                            padding: const EdgeInsets.all(20.0),
                            decoration: BoxDecoration(
                              color: context.cardBg.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                color: const Color(0xFFE50914).withOpacity(0.25),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(context.isDark ? 0.2 : 0.05),
                                  blurRadius: 10.0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Header Row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _isPostCardExpanded
                                                      ? 'What did you achieve today? 🚀'
                                                      : 'What did you achieve today?',
                                                  style: TextStyle(
                                                    color: context.textColor,
                                                    fontSize: 18.0,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8.0),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _isPostCardExpanded =
                                                        !_isPostCardExpanded;
                                                  });
                                                },
                                                child: Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: context.borderCol,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    _isPostCardExpanded
                                                        ? Icons
                                                            .keyboard_arrow_up_rounded
                                                        : Icons
                                                            .keyboard_arrow_down_rounded,
                                                    color: context.subTextColor,
                                                    size: 24.0,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_isPostCardExpanded) ...[
                                            const SizedBox(height: 6.0),
                                            const Text(
                                              'Share your progress, inspire others, celebrate wins!',
                                              style: TextStyle(
                                                color: Color(0xFF8E8E93),
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isPostCardExpanded) ...[
                                  const SizedBox(height: 16.0),
                                  // Avatar, Text Input & Smiley Row
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Avatar
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                        child: ProfileScreen.profileImagePath !=
                                                null
                                            ? Image.file(
                                                File(ProfileScreen
                                                    .profileImagePath!),
                                                width: 40.0,
                                                height: 40.0,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.network(
                                                'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop&crop=face',
                                                width: 40.0,
                                                height: 40.0,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    width: 40.0,
                                                    height: 40.0,
                                                    color: context.cardBg,
                                                    child: Icon(
                                                      Icons.person,
                                                      color:
                                                          context.subTextColor,
                                                      size: 20.0,
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                      const SizedBox(width: 12.0),
                                      // TextField Input
                                      Expanded(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
                                          child: TextField(
                                            controller: _textController,
                                            focusNode: _focusNode,
                                            maxLines: null,
                                            style: TextStyle(
                                              color: context.textColor,
                                              fontSize: 15.0,
                                            ),
                                            decoration:
                                                const InputDecoration.collapsed(
                                              hintText:
                                                  'Share your wins, big or small...',
                                              hintStyle: TextStyle(
                                                color: Color(0xFF7C7C80),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      // Smiley Face Icon
                                      IconButton(
                                        icon: const Icon(
                                          Icons.emoji_emotions_outlined,
                                          color: Color(0xFF8E8E93),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _showEmojiPicker =
                                                !_showEmojiPicker;
                                            if (_showEmojiPicker) {
                                              _focusNode.unfocus();
                                            } else {
                                              _focusNode.requestFocus();
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  if (_selectedMilestone != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0, left: 52.0),
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE50914).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(20.0),
                                              border: Border.all(
                                                color: const Color(0xFFE50914).withOpacity(0.25),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.rocket_launch_rounded,
                                                  color: Color(0xFFE50914),
                                                  size: 13.0,
                                                ),
                                                const SizedBox(width: 5.0),
                                                Flexible(
                                                  child: Text(
                                                  '${_selectedMilestone!.toUpperCase()} Growth Milestone',
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                    color: Color(0xFFE50914),
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6.0),
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedMilestone = null;
                                                    });
                                                  },
                                                  child: const Icon(
                                                    Icons.close_rounded,
                                                    color: Color(0xFFE50914),
                                                    size: 13.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // Custom Animated Emoji Picker Drawer
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                    child: _showEmojiPicker
                                        ? Container(
                                            margin: const EdgeInsets.only(
                                                top: 20.0),
                                            height: 180,
                                            decoration: BoxDecoration(
                                              color: context.scaffoldBg,
                                              borderRadius:
                                                  BorderRadius.circular(12.0),
                                              border: Border.all(
                                                color: context.borderCol,
                                                width: 1.0,
                                              ),
                                            ),
                                            child: GridView.builder(
                                              padding:
                                                  const EdgeInsets.all(12.0),
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 7,
                                                mainAxisSpacing: 8.0,
                                                crossAxisSpacing: 8.0,
                                              ),
                                              itemCount: _emojis.length,
                                              itemBuilder: (context, index) {
                                                return InkWell(
                                                  onTap: () => _insertEmoji(
                                                      _emojis[index]),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                  child: Center(
                                                    child: Text(
                                                      _emojis[index],
                                                      style: const TextStyle(
                                                          fontSize: 22.0),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  // Image Preview Widget
                                  if (_pickedImage != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 20.0),
                                      height: 200,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: context.cardBg,
                                        borderRadius:
                                            BorderRadius.circular(16.0),
                                        border: Border.all(
                                          color: context.borderCol,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(15.0),
                                            child: Image.file(
                                              File(_pickedImage!.path),
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Positioned(
                                            top: 8.0,
                                            right: 8.0,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _pickedImage = null;
                                                });
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(6.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // Video Preview Widget
                                  if (_pickedVideo != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 20.0),
                                      height: 120,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: context.cardBg,
                                        borderRadius:
                                            BorderRadius.circular(16.0),
                                        border: Border.all(
                                          color: context.borderCol,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.video_library_rounded,
                                                  color: Color(0xFF27AE60),
                                                  size: 40.0,
                                                ),
                                                const SizedBox(height: 8.0),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16.0),
                                                  child: Text(
                                                    _pickedVideo!.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: context.textColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Positioned(
                                            top: 8.0,
                                            right: 8.0,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _pickedVideo = null;
                                                });
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(6.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_pickedAudio != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 20.0),
                                      height: 100,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: context.cardBg,
                                        borderRadius:
                                            BorderRadius.circular(16.0),
                                        border: Border.all(
                                          color: context.borderCol,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const SizedBox(width: 16.0),
                                                const Icon(
                                                  Icons.audiotrack_rounded,
                                                  color: Color(0xFF9B51E0),
                                                  size: 32.0,
                                                ),
                                                const SizedBox(width: 12.0),
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 48.0),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          _pickedAudio!.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color: context
                                                                .textColor,
                                                            fontSize: 13.5,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4.0),
                                                        Text(
                                                          '${(_pickedAudio!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                                                          style:
                                                              const TextStyle(
                                                            color: Color(
                                                                0xFF8E8E93),
                                                            fontSize: 11.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Positioned(
                                            top: 8.0,
                                            right: 8.0,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _pickedAudio = null;
                                                });
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(6.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 36.0),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                      vertical: 12.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.scaffoldBg,
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(
                                        color: context.borderCol,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Flexible(
                                          child: _buildMediaItem(
                                            icon: Icons.image,
                                            color: const Color(0xFF2F80ED),
                                            label: 'Photo',
                                            onTap: _pickImage,
                                          ),
                                        ),
                                        _buildDivider(),
                                        Flexible(
                                          child: _buildMediaItem(
                                            icon: Icons.videocam,
                                            color: const Color(0xFF27AE60),
                                            label: 'Video',
                                            onTap: _pickVideo,
                                          ),
                                        ),
                                        _buildDivider(),
                                        Flexible(
                                          child: _buildMediaItem(
                                            icon: Icons.mic,
                                            color: const Color(0xFF9B51E0),
                                            label: 'Audio',
                                            onTap: _pickAudio,
                                          ),
                                        ),
                                        _buildDivider(),
                                         Flexible(
                                         child: PopupMenuButton<String>(
                                           onSelected: (String value) {
                                             setState(() {
                                               _selectedMilestone = value;
                                             });
                                           },
                                           color: context.cardBg,
                                           elevation: 4.0,
                                           shape: RoundedRectangleBorder(
                                             borderRadius: BorderRadius.circular(16.0),
                                             side: BorderSide(
                                               color: context.borderCol,
                                               width: 1.0,
                                             ),
                                           ),
                                           itemBuilder: (BuildContext context) => [
                                             const PopupMenuItem(
                                               value: '5x',
                                               child: Text('5x Growth', style: TextStyle(fontWeight: FontWeight.w600)),
                                             ),
                                             const PopupMenuItem(
                                               value: '10x',
                                               child: Text('10x Growth', style: TextStyle(fontWeight: FontWeight.w600)),
                                             ),
                                             const PopupMenuItem(
                                               value: '15x',
                                               child: Text('15x Growth', style: TextStyle(fontWeight: FontWeight.w600)),
                                             ),
                                             const PopupMenuItem(
                                               value: '20x',
                                               child: Text('20x Growth', style: TextStyle(fontWeight: FontWeight.w600)),
                                             ),
                                           ],
                                           child: Padding(
                                             padding: const EdgeInsets.symmetric(vertical: 4.0),
                                             child: Row(
                                               mainAxisSize: MainAxisSize.min,
                                               children: [
                                                 const Icon(
                                                   Icons.rocket_launch,
                                                   color: Color(0xFFEB5757),
                                                   size: 16.0,
                                                 ),
                                                 const SizedBox(width: 4.0),
                                                 Flexible(
                                                   child: Text(
                                                   _selectedMilestone != null
                                                       ? '${_selectedMilestone!.toUpperCase()} Milestone'
                                                       : 'Milestone',
                                                   overflow: TextOverflow.ellipsis,
                                                   maxLines: 1,
                                                   style: TextStyle(
                                                     color: _selectedMilestone != null
                                                         ? const Color(0xFFEB5757)
                                                         : (context.isDark ? const Color(0xFFD1D1D6) : const Color(0xFF6E6E73)),
                                                      fontSize: 11.5,
                                                     fontWeight: FontWeight.w500,
                                                   ),
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ),
                                         ),
                                         ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 24.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Public/Friends Selection Button
                            Flexible(
                              child: InkWell(
                                onTap: _showVisibilitySelector,
                                borderRadius: BorderRadius.circular(24.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10.0,
                                    vertical: 10.0,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24.0),
                                    border: Border.all(
                                      color: context.borderCol,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _visibility == 'Public'
                                            ? Icons.public
                                            : Icons.people_alt_rounded,
                                        color: context.textColor,
                                        size: 18.0,
                                      ),
                                      const SizedBox(width: 6.0),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            _visibility,
                                            style: TextStyle(
                                              color: context.textColor,
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4.0),
                                      const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Color(0xFF8E8E93),
                                        size: 18.0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),

                            // Post to Community Button
                            Flexible(
                              child: InkWell(
                                onTap: () async {
                                  if (_textController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Please enter post content!'),
                                        backgroundColor: Color(0xFFCC0000),
                                      ),
                                    );
                                    return;
                                  }

                                  // Upload the picked image to Supabase Storage first —
                                  // saving the local device file path instead of a real
                                  // public URL is why admin could never render it.
                                  String? uploadedImageUrl;
                                  if (_pickedImage != null) {
                                    try {
                                      final localFile = File(_pickedImage!.path);
                                      final fileName =
                                          'posts/${DateTime.now().millisecondsSinceEpoch}_${_pickedImage!.name}';
                                      await Supabase.instance.client.storage
                                          .from('community')
                                          .upload(fileName, localFile);
                                      uploadedImageUrl = Supabase.instance.client
                                          .storage
                                          .from('community')
                                          .getPublicUrl(fileName);
                                    } catch (e) {
                                      debugPrint(
                                          '[Supabase] Failed to upload post image: $e');
                                    }
                                  }

                                  // Insert new post to global communityPosts database
                                  final nowUtcIso =
                                      DateTime.now().toUtc().toIso8601String();
                                  communityPosts.insert(0, {
                                    'name': 'Sakthi (You)',
                                    'role': 'TBT Member',
                                    'createdAt': nowUtcIso,
                                    'badge': _selectedMilestone != null
                                        ? '${_selectedMilestone!.toUpperCase()} Growth'
                                        : '',
                                    'badgeColor': const Color(0xFFCC0000),
                                    'avatarUrl': 'assets/images/nav  bar.jpeg',
                                    'content': _textController.text.trim(),
                                    'likes': 0,
                                    'comments': 0,
                                    'shares': 0,
                                    'isLiked': false,
                                    'isBookmarked': false,
                                    'isFollowing': false,
                                    'isMentor': false,
                                    'hasImages': uploadedImageUrl != null,
                                    if (uploadedImageUrl != null)
                                      'images': [uploadedImageUrl],
                                    'hasVideo': _pickedVideo != null,
                                    if (_pickedVideo != null)
                                      'videoThumbnail':
                                          'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=600',
                                  });

                                  // Insert to Supabase as well
                                  final Map<String, dynamic> supabasePostData = {
                                    'name': 'Sakthi (You)',
                                    'role': 'TBT Member',
                                    'badge': _selectedMilestone != null
                                        ? '${_selectedMilestone!.toUpperCase()} Growth'
                                        : null,
                                    'badge_color': '#CC0000',
                                    'avatar_url': 'assets/images/nav  bar.jpeg',
                                    'content': _textController.text.trim(),
                                    'likes': 0,
                                    'comments': 0,
                                    'shares': 0,
                                    'is_liked': false,
                                    'is_bookmarked': false,
                                    'is_following': false,
                                    'is_mentor': false,
                                    'has_images': uploadedImageUrl != null,
                                    'images': uploadedImageUrl != null ? [uploadedImageUrl] : [],
                                    'has_video': _pickedVideo != null,
                                    'video_thumbnail': _pickedVideo != null
                                        ? 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=600'
                                        : '',
                                    'is_approved': false, // Requires admin approval before showing in the public feed
                                    'status': 'active',
                                  };
                                  try {
                                    await Supabase.instance.client
                                        .from('posts')
                                        .insert(supabasePostData);
                                    debugPrint('[Supabase] Successfully uploaded post');
                                  } catch (err) {
                                    debugPrint('[Supabase] Failed to upload post: $err');
                                  }

                                  // Enforce maximum of 10 posts in the feed
                                  if (communityPosts.length > 10) {
                                    communityPosts.removeRange(
                                        10, communityPosts.length);
                                  }

                                  // Persist updated posts list to local storage
                                  savePostsToLocal();

                                  if (!mounted) return;
                                  setState(() {
                                    _textController.clear();
                                    _pickedImage = null;
                                    _pickedVideo = null;
                                    _pickedAudio = null;
                                    _isPostCardExpanded = false;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Successfully posted to Community! 🎉'),
                                      backgroundColor: Color(0xFF27AE60),
                                    ),
                                  );

                                  widget.onPosted?.call();
                                },
                                borderRadius: BorderRadius.circular(24.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 10.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE50914),
                                    borderRadius: BorderRadius.circular(24.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE50914)
                                            .withOpacity(0.3),
                                        blurRadius: 10.0,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Post to Community',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 16.0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
      ],
    );
  }
}

class PostPopupScreen extends StatefulWidget {
  const PostPopupScreen({super.key});

  @override
  State<PostPopupScreen> createState() => _PostPopupScreenState();
}

class _PostPopupScreenState extends State<PostPopupScreen> {

  int _currentCarouselPage = 0;
  late final PageController _carouselPageController;
  Timer? _carouselTimer;
  Timer? _backupPollTimer;
  List<Map<String, dynamic>> _carouselItems = [];
  bool _isLoadingCarousel = true;
  RealtimeChannel? _carouselSubscription;
  RealtimeChannel? _habitsSubscription;
  RealtimeChannel? _buttonsSubscription;
  final ScrollController _scrollController = ScrollController();
  int _currentTabIndex = 0;
  final GlobalKey _mentorCardKey = GlobalKey();

  // Morning Ritual states
  bool _showMorningRitual = true;
  bool _isMorningRitualExpanded = true;
  int _currentRitualStep = 0;
  late final PageController _ritualPageController;
  List<bool?> _ritualAnswers = List<bool?>.filled(5, null);

  List<Map<String, String>> _dynamicHabits = [
    {
      'icon': 'fa-sun',
      'rawQuestion': 'Did you write your morning pages?',
      'highlightWord': 'morning pages',
      'subtitle': 'Build clarity. Boost focus. Start your day right.'
    },
    {
      'icon': 'fa-spa',
      'rawQuestion': 'Did you meditate for 10 minutes?',
      'highlightWord': 'for 10 minutes',
      'subtitle': 'Calm your mind. Find presence. Center yourself.'
    },
    {
      'icon': 'fa-bullseye',
      'rawQuestion': 'Did you plan your daily goals?',
      'highlightWord': 'daily goals',
      'subtitle': 'Prioritize tasks. Direct your energy. Stay productive.'
    },
    {
      'icon': 'fa-dumbbell',
      'rawQuestion': 'Did you exercise or stretch today?',
      'highlightWord': 'stretch today',
      'subtitle': 'Activate your body. Boost energy. Stay healthy.'
    },
    {
      'icon': 'fa-coffee',
      'rawQuestion': 'Did you eat a healthy breakfast?',
      'highlightWord': 'healthy breakfast',
      'subtitle': 'Nourish your body. Fuel your mind for the day.'
    }
  ];

  Map<String, String> _dynamicButtonsConfig = {
    'yesLabel': 'Yes',
    'notYetLabel': 'Not Yet',
  };

  Future<void> _fetchDynamicHabits() async {
    try {
      final habitsData = await Supabase.instance.client
          .from('habits')
          .select()
          .order('sort_order', ascending: true);
      
      final buttonsData = await Supabase.instance.client
          .from('buttons_config')
          .select()
          .eq('id', 'default')
          .maybeSingle();

      if (habitsData != null && habitsData.isNotEmpty) {
        final List<Map<String, String>> loadedHabits = [];
        for (var item in habitsData) {
          loadedHabits.add({
            'icon': item['icon']?.toString() ?? 'fa-sun',
            'rawQuestion': item['raw_question']?.toString() ?? '',
            'highlightWord': item['highlight_word']?.toString() ?? '',
            'subtitle': item['subtitle']?.toString() ?? '',
          });
        }

        bool habitsChanged = loadedHabits.length != _dynamicHabits.length;
        if (!habitsChanged) {
          for (int i = 0; i < loadedHabits.length; i++) {
            if (loadedHabits[i]['icon'] != _dynamicHabits[i]['icon'] ||
                loadedHabits[i]['rawQuestion'] != _dynamicHabits[i]['rawQuestion'] ||
                loadedHabits[i]['highlightWord'] != _dynamicHabits[i]['highlightWord'] ||
                loadedHabits[i]['subtitle'] != _dynamicHabits[i]['subtitle']) {
              habitsChanged = true;
              break;
            }
          }
        }

        if (habitsChanged && mounted) {
          setState(() {
            _dynamicHabits = loadedHabits;
            _ritualAnswers = List<bool?>.filled(loadedHabits.length, null);
            if (_currentRitualStep >= loadedHabits.length) {
              _currentRitualStep = 0;
            }
          });
        }
      }

      if (buttonsData != null) {
        final yes = buttonsData['yes_label']?.toString() ?? 'Yes';
        final notYet = buttonsData['not_yet_label']?.toString() ?? 'Not Yet';

        if ((_dynamicButtonsConfig['yesLabel'] != yes ||
                _dynamicButtonsConfig['notYetLabel'] != notYet) &&
            mounted) {
          setState(() {
            _dynamicButtonsConfig = {
              'yesLabel': yes,
              'notYetLabel': notYet,
            };
          });
        }
      }
      return;
    } catch (e) {
      debugPrint('[Supabase] Habits fetch failed, falling back to local Express server: $e');
    }

    final List<String> hostsToTry = ['192.168.0.115']; // Laptop LAN IP first for physical device testing
    if (kIsWeb) {
      hostsToTry.addAll(['localhost', '127.0.0.1']);
    } else {
      if (Platform.isAndroid) {
        hostsToTry.add('10.0.2.2');
      } else if (Platform.isIOS) {
        hostsToTry.addAll(['localhost', '127.0.0.1']);
      }
    }
    hostsToTry.add('192.168.0.123');

    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

    for (final host in hostsToTry) {
      try {
        final habitsUri = Uri.parse('http://$host:5000/api/habits');
        final requestH =
            await client.getUrl(habitsUri).timeout(const Duration(seconds: 1));
        final responseH = await requestH.close();

        if (responseH.statusCode == 200) {
          final bodyH = await responseH.transform(utf8.decoder).join();
          final List<dynamic> jsonList = jsonDecode(bodyH);
          if (jsonList.isNotEmpty) {
            final List<Map<String, String>> loadedHabits = [];
            for (var item in jsonList) {
              if (item is Map) {
                loadedHabits.add({
                  'icon': item['icon']?.toString() ?? 'fa-sun',
                  'rawQuestion': item['rawQuestion']?.toString() ?? '',
                  'highlightWord': item['highlightWord']?.toString() ?? '',
                  'subtitle': item['subtitle']?.toString() ?? '',
                });
              }
            }

            bool hasChanged = loadedHabits.length != _dynamicHabits.length;
            if (!hasChanged) {
              for (int i = 0; i < loadedHabits.length; i++) {
                if (loadedHabits[i]['icon'] != _dynamicHabits[i]['icon'] ||
                    loadedHabits[i]['rawQuestion'] !=
                        _dynamicHabits[i]['rawQuestion'] ||
                    loadedHabits[i]['highlightWord'] !=
                        _dynamicHabits[i]['highlightWord'] ||
                    loadedHabits[i]['subtitle'] !=
                        _dynamicHabits[i]['subtitle']) {
                  hasChanged = true;
                  break;
                }
              }
            }

            if (hasChanged && mounted) {
              setState(() {
                _dynamicHabits = loadedHabits;
                _ritualAnswers = List<bool?>.filled(loadedHabits.length, null);
                if (_currentRitualStep >= loadedHabits.length) {
                  _currentRitualStep = 0;
                }
              });
            }
          }
        }

        final buttonsUri = Uri.parse('http://$host:5000/api/buttons_config');
        final requestB =
            await client.getUrl(buttonsUri).timeout(const Duration(seconds: 1));
        final responseB = await requestB.close();

        if (responseB.statusCode == 200) {
          final bodyB = await responseB.transform(utf8.decoder).join();
          final Map<String, dynamic> jsonMap = jsonDecode(bodyB);
          final yes = jsonMap['yesLabel']?.toString() ?? 'Yes';
          final notYet = jsonMap['notYetLabel']?.toString() ?? 'Not Yet';

          if ((_dynamicButtonsConfig['yesLabel'] != yes ||
                  _dynamicButtonsConfig['notYetLabel'] != notYet) &&
              mounted) {
            setState(() {
              _dynamicButtonsConfig = {
                'yesLabel': yes,
                'notYetLabel': notYet,
              };
            });
          }
        }
        break;
      } catch (e) {
        // Silent catch for polling
      }
    }
  }

  // List of popular emojis grouped for a premium selection feel
  Future<void> _fetchCarouselItems() async {
    try {
      final response = await Supabase.instance.client
          .from('home_carousel')
          .select()
          .eq('status', 'active')
          .order('sort_order', ascending: true);

      if (mounted) {
        final newItems = List<Map<String, dynamic>>.from(response);
        final wasEmpty = _carouselItems.isEmpty;

        int targetIndex = -1;
        if (!wasEmpty && newItems.isNotEmpty) {
          for (int i = 0; i < newItems.length; i++) {
            final newItem = newItems[i];
            final Map<String, dynamic> oldItem = _carouselItems.firstWhere(
              (item) => item['id'] == newItem['id'],
              orElse: () => <String, dynamic>{},
            );
            if (oldItem.isEmpty) {
              targetIndex = i;
              break;
            } else {
              final changed = newItem['title'] != oldItem['title'] ||
                  newItem['subtitle'] != oldItem['subtitle'] ||
                  newItem['media_url'] != oldItem['media_url'] ||
                  newItem['description'] != oldItem['description'] ||
                  newItem['status'] != oldItem['status'];
              if (changed) {
                targetIndex = i;
                break;
              }
            }
          }
        }

        final int oldLength = _carouselItems.length;
        final int newLength = newItems.length;

        if (oldLength > 0 &&
            oldLength != newLength &&
            _carouselPageController.hasClients) {
          final currentPage = _carouselPageController.page?.round() ?? 1000;
          final currentRelativeIndex = currentPage % oldLength;

          final offset = currentPage % newLength;
          int diff = currentRelativeIndex - offset;
          if (diff > newLength / 2) {
            diff -= newLength;
          } else if (diff < -newLength / 2) {
            diff += newLength;
          }
          final adjustedPage = currentPage + diff;

          _carouselPageController.jumpToPage(adjustedPage);
          _currentCarouselPage = currentRelativeIndex;
        }

        setState(() {
          _carouselItems = newItems;
          _isLoadingCarousel = false;
        });

        if (wasEmpty &&
            newItems.isNotEmpty &&
            _carouselPageController.hasClients) {
          _carouselPageController.jumpToPage(1000 - (1000 % newItems.length));
        } else if (targetIndex != -1 && _carouselPageController.hasClients) {
          final currentPage = _carouselPageController.page?.round() ?? 1000;
          final currentRelativeIndex = currentPage % newItems.length;
          final diff = targetIndex - currentRelativeIndex;
          final targetPage = currentPage + diff;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_carouselPageController.hasClients) {
              _carouselPageController.animateToPage(
                targetPage,
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching carousel items: $e');
      if (mounted) {
        setState(() {
          _isLoadingCarousel = false;
        });
      }
    }
  }

  void _setupCarouselRealtime() {
    try {
      _carouselSubscription = Supabase.instance.client
          .channel('public:home_carousel')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'home_carousel',
            callback: (payload) {
              debugPrint(
                  'Realtime change detected in home_carousel: ${payload.toString()}');
              _fetchCarouselItems();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error setting up carousel realtime: $e');
    }
  }

  void _setupHabitsRealtime() {
    try {
      _habitsSubscription = Supabase.instance.client
          .channel('public:habits')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'habits',
            callback: (payload) {
              debugPrint('Realtime change detected in habits: ${payload.toString()}');
              _fetchDynamicHabits();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error setting up habits realtime: $e');
    }
  }

  void _setupButtonsRealtime() {
    try {
      _buttonsSubscription = Supabase.instance.client
          .channel('public:buttons_config')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'buttons_config',
            callback: (payload) {
              debugPrint('Realtime change detected in buttons_config: ${payload.toString()}');
              _fetchDynamicHabits();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error setting up buttons_config realtime: $e');
    }
  }

  Future<void> _launchUrlHelper(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch URL: $url');
      }
    } catch (e) {
      debugPrint('Error launching url: $e');
    }
  }

  void _shareCarouselQuote(int index) {
    String text = '';
    if (_carouselItems.isNotEmpty && index < _carouselItems.length) {
      final item = _carouselItems[index];
      final title = item['title'] ?? '';
      final subtitle = item['subtitle'] ?? '';
      text = '$title\n\n$subtitle';
      if (item['button_link'] != null &&
          (item['button_link'] as String).isNotEmpty) {
        text += '\n\nRead more: ${item['button_link']}';
      }
    } else {
      if (index == 0) {
        text =
            '“To get something you never had, you have to do something you never did.”\n\n- Tamil Business Tribe Mentor Quote';
      } else {
        text = 'Tamil Business Tribe - Guide. Inspire. Empower.';
      }
    }

    Share.share(
      text,
      subject: 'TBT Quote of the Day',
    );
  }

  @override
  void initState() {
    super.initState();
    NotificationBadge.instance.ensureLoaded();
    _fetchDynamicHabits();
    _ritualPageController = PageController(initialPage: 0);
    _carouselPageController = PageController(initialPage: 1000);
    _fetchCarouselItems();
    _setupCarouselRealtime();
    _setupHabitsRealtime();
    _setupButtonsRealtime();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_carouselPageController.hasClients) {
        _carouselPageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
    _backupPollTimer =
        Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      _fetchCarouselItems();
      _fetchDynamicHabits();
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _backupPollTimer?.cancel();
    if (_carouselSubscription != null) {
      try {
        Supabase.instance.client.removeChannel(_carouselSubscription!);
      } catch (e) {
        debugPrint('Error cleaning up carousel realtime channel: $e');
      }
    }
    if (_habitsSubscription != null) {
      try {
        Supabase.instance.client.removeChannel(_habitsSubscription!);
      } catch (e) {
        debugPrint('Error cleaning up habits realtime channel: $e');
      }
    }
    if (_buttonsSubscription != null) {
      try {
        Supabase.instance.client.removeChannel(_buttonsSubscription!);
      } catch (e) {
        debugPrint('Error cleaning up buttons realtime channel: $e');
      }
    }
    _carouselPageController.dispose();
    _ritualPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      drawer: const TbtAppDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.themeGradients,
          ),
        ),
        child: Column(
          children: [
            // Fixed TBT Header Section
            SafeArea(
              bottom: false,
              child: Container(
                alignment: Alignment.center,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SizedBox(
                    height: 70.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          // Left Menu Icon
                          Builder(
                            builder: (context) {
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Scaffold.of(context).openDrawer();
                                },
                                child: _buildCustomMenuIcon(),
                              );
                            },
                          ),
                          // Centered Logo
                          Expanded(
                            child: Container(
                              alignment: Alignment.center,
                              child: _buildTBTLogo(),
                            ),
                          ),
                          // Right Action Icons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildStreakWidget(),
                              const SizedBox(width: 16.0),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const NotificationsScreen(),
                                    ),
                                  ).then((_) =>
                                      NotificationBadge.instance.refresh());
                                },
                                child: _buildNotificationWidget(),
                              ),
                              const SizedBox(width: 16.0),
                              _buildProfileAvatar(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Scrollable Content Section
            Expanded(
              child: _currentTabIndex == 0
                  ? SingleChildScrollView(
                      controller: _scrollController,
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 8.0,
                  bottom: 120.0,
                ),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Greeting text
                        Text(
                          'Hi, Thrisha',
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        // Main Post Card
                        const AchievementComposer(),
                        const SizedBox(height: 24.0),
                        Container(
                            key: _mentorCardKey,
                            child: _buildMentorPosterCard()),
                        const SizedBox(height: 16.0),
                        _buildCarouselIndicator(),
                        if (_showMorningRitual) ...[
                          const SizedBox(height: 24.0),
                          _buildMorningRitualCard(),
                        ],
                        const SizedBox(height: 24.0),
                        _buildMenuGrid(),
                      ],
                    ),
                  ),
                ),
              )
            : _buildLeaderboardTab(),
          ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildLeaderboardTab() => const _LeaderboardTab();

  IconData _getRitualIcon(int index) {
    switch (index) {
      case 0:
        return Icons.wb_sunny_outlined;
      case 1:
        return Icons.self_improvement;
      case 2:
        return Icons.track_changes;
      case 3:
        return Icons.fitness_center;
      case 4:
      default:
        return Icons.local_cafe;
    }
  }

  String _getRitualSubtitle(int index) {
    switch (index) {
      case 0:
        return "Build clarity. Boost focus. Start your day right.";
      case 1:
        return "Calm your mind. Find presence. Center yourself.";
      case 2:
        return "Prioritize tasks. Direct your energy. Stay productive.";
      case 3:
        return "Activate your body. Boost energy. Stay healthy.";
      case 4:
      default:
        return "Nourish your body. Fuel your mind for the day.";
    }
  }

  List<TextSpan> _getRitualQuestionSpans(int index) {
    switch (index) {
      case 0:
        return const [
          TextSpan(text: 'Did you write your '),
          TextSpan(
            text: 'morning pages?',
            style: TextStyle(color: Color(0xFFFF3B30)),
          ),
        ];
      case 1:
        return const [
          TextSpan(text: 'Did you meditate '),
          TextSpan(
            text: 'for 10 minutes?',
            style: TextStyle(color: Color(0xFFFF3B30)),
          ),
        ];
      case 2:
        return const [
          TextSpan(text: 'Did you plan your '),
          TextSpan(
            text: 'daily goals?',
            style: TextStyle(color: Color(0xFFFF3B30)),
          ),
        ];
      case 3:
        return const [
          TextSpan(text: 'Did you exercise or '),
          TextSpan(
            text: 'stretch today?',
            style: TextStyle(color: Color(0xFFFF3B30)),
          ),
        ];
      case 4:
      default:
        return const [
          TextSpan(text: 'Did you eat a '),
          TextSpan(
            text: 'healthy breakfast?',
            style: TextStyle(color: Color(0xFFFF3B30)),
          ),
        ];
    }
  }

  void _handleRitualAnswer(bool answer) {
    setState(() {
      if (_currentRitualStep < _ritualAnswers.length) {
        _ritualAnswers[_currentRitualStep] = answer;
      }
      if (_currentRitualStep < _dynamicHabits.length - 1) {
        _currentRitualStep++;
        _ritualPageController.animateToPage(
          _currentRitualStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _currentRitualStep = _dynamicHabits.length; // Completion state
      }
    });
  }

  IconData _getDynamicIcon(String iconName) {
    switch (iconName) {
      case 'fa-sun':
        return Icons.wb_sunny_outlined;
      case 'fa-spa':
        return Icons.self_improvement;
      case 'fa-bullseye':
        return Icons.track_changes;
      case 'fa-dumbbell':
        return Icons.fitness_center;
      case 'fa-coffee':
        return Icons.local_cafe;
      default:
        return Icons.wb_sunny_outlined;
    }
  }

  List<TextSpan> _getDynamicQuestionSpans(int index, Color highlightColor) {
    if (index >= _dynamicHabits.length) return const [];
    final habit = _dynamicHabits[index];
    final question = habit['rawQuestion'] ?? '';
    final highlight = habit['highlightWord'] ?? '';

    if (highlight.isNotEmpty && question.contains(highlight)) {
      final parts = question.split(highlight);
      return [
        TextSpan(text: parts[0]),
        TextSpan(
          text: highlight,
          style: TextStyle(color: highlightColor),
        ),
        if (parts.length > 1) TextSpan(text: parts[1]),
      ];
    }
    return [TextSpan(text: question)];
  }

  Future<void> _shareAssetImage(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final tempDir = Directory.systemTemp;
      final fileName = assetPath.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(
        byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      debugPrint('Error sharing asset: $e');
    }
  }

  Widget _buildMorningRitualCard() {
    final isDark = context.isDark;
    final cardColor = context.cardBg;
    final borderColor = context.borderCol;
    final textColor = context.textColor;
    final pillColor =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              // Ritual Tag
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: pillColor,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: const Color(0xFFFF3B30).withOpacity(0.4),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_document,
                        color: Color(0xFFFF3B30),
                        size: 16.0,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    const Expanded(
                      child: Text(
                        'MORNING RITUAL',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              // Step counter pill
              if (_currentRitualStep < _dynamicHabits.length)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: const Color(0xFFFF3B30).withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    '${_currentRitualStep + 1} / ${_dynamicHabits.length}',
                    style: const TextStyle(
                      color: Color(0xFFFF3B30),
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.4),
                    ),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 12.0),
              // Dropdown button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isMorningRitualExpanded = !_isMorningRitualExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: pillColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMorningRitualExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8E8E93),
                    size: 16.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Progress lines
          Row(
            children: List.generate(_dynamicHabits.length, (index) {
              final isCompletedOrActive =
                  _currentRitualStep >= _dynamicHabits.length ||
                      index <= _currentRitualStep;
              return Expanded(
                child: Container(
                  margin:
                      EdgeInsets.symmetric(horizontal: index == 0 ? 0.0 : 4.0),
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: isCompletedOrActive
                        ? const Color(0xFFE50914)
                        : (isDark
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFE5E5EA)),
                    borderRadius: BorderRadius.circular(2.0),
                    boxShadow: isCompletedOrActive
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE50914).withOpacity(0.4),
                              blurRadius: 8.0,
                              spreadRadius: 1.0,
                            )
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
          if (_isMorningRitualExpanded) ...[
            const SizedBox(height: 24.0),

            // Main Step PageView or Completion screen
            if (_currentRitualStep < _dynamicHabits.length) ...[
              SizedBox(
                height: 200.0,
                child: PageView.builder(
                  controller: _ritualPageController,
                  itemCount: _dynamicHabits.length,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentRitualStep = page;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Glow Sun / Step Icon
                        Container(
                          width: 60.0,
                          height: 60.0,
                          decoration: BoxDecoration(
                            color: pillColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF3B30),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF3B30).withOpacity(0.3),
                                blurRadius: 12.0,
                                spreadRadius: 2.0,
                              ),
                            ],
                          ),
                          child: Icon(
                            _getDynamicIcon(
                                _dynamicHabits[index]['icon'] ?? 'fa-sun'),
                            color: const Color(0xFFFF3B30),
                            size: 26.0,
                          ),
                        ),
                        const SizedBox(height: 18.0),
                        // Question
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              height: 1.25,
                            ),
                            children: _getDynamicQuestionSpans(
                                index, const Color(0xFFFF3B30)),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        // Subtitle
                        Text(
                          _dynamicHabits[index]['subtitle'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 14.0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24.0),

              // Footer Actions
              Row(
                children: [
                  // Not Yet Button
                  Expanded(
                    child: InkWell(
                      onTap: () => _handleRitualAnswer(false),
                      borderRadius: BorderRadius.circular(16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        decoration: BoxDecoration(
                          color: pillColor,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: borderColor,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF8E8E93),
                              size: 18.0,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              _dynamicButtonsConfig['notYetLabel'] ?? 'Not Yet',
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  // Yes Button
                  Expanded(
                    child: InkWell(
                      onTap: () => _handleRitualAnswer(true),
                      borderRadius: BorderRadius.circular(16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF3B30),
                              Color(0xFFFF5E3A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF3B30).withOpacity(0.3),
                              blurRadius: 10.0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18.0,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              _dynamicButtonsConfig['yesLabel'] ?? 'Yes',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Completed State
              Column(
                children: [
                  const SizedBox(height: 20.0),
                  Container(
                    width: 60.0,
                    height: 60.0,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          blurRadius: 12.0,
                          spreadRadius: 2.0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 32.0,
                    ),
                  ),
                  const SizedBox(height: 18.0),
                  Text(
                    'Morning Ritual Completed!',
                    style: TextStyle(
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Success! You checked off ${_ritualAnswers.where((e) => e == true).length} of ${_dynamicHabits.length} morning habits.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14.0,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCustomMenuIcon() {
    final iconColor = context.textColor;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 2,
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: BorderRadius.circular(1.0),
          ),
        ),
        const SizedBox(height: 5.0),
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: BorderRadius.circular(1.0),
          ),
        ),
        const SizedBox(height: 5.0),
        Container(
          width: 11,
          height: 2,
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: BorderRadius.circular(1.0),
          ),
        ),
      ],
    );
  }

  Widget _buildTBTLogo() {
    return const AppLogo.appBar();
  }

  Widget _buildStreakWidget() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.scaffoldBg.withOpacity(0.3),
        border: Border.all(
          color: context.borderCol,
          width: 1.0,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ).createShader(bounds),
            child: const Icon(
              Icons.whatshot_rounded,
              color: Colors.white,
              size: 18.0,
            ),
          ),
          const Positioned(
            bottom: 2,
            child: Text(
              '12',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.0,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 3.0,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationWidget() {
    return AnimatedBuilder(
      animation: NotificationBadge.instance,
      builder: (context, _) {
        final count = NotificationBadge.instance.unreadCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications_outlined,
              color: context.textColor,
              size: 22.0,
            ),
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(2.0),
                  constraints:
                      const BoxConstraints(minWidth: 14, minHeight: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD30814),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.0,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFD30814),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: ProfileScreen.profileImagePath != null
              ? Image.file(
                  File(ProfileScreen.profileImagePath!),
                  width: 24.0,
                  height: 24.0,
                  fit: BoxFit.cover,
                )
              : Image.network(
                  'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop&crop=face',
                  width: 24.0,
                  height: 24.0,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 24.0,
                      height: 24.0,
                      color: const Color(0xFF48484A),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white70,
                        size: 14.0,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildMentorPosterCard() {
    if (_isLoadingCarousel) {
      return Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.0),
          color: context.cardBg,
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFCC0000)),
        ),
      );
    }

    final List<Map<String, dynamic>> slides = _carouselItems.isNotEmpty
        ? _carouselItems
        : [
            {
              'media_type': 'image',
              'media_url': 'assets/images/whatsapp_image.jpeg',
              'is_asset': true,
              'title': 'Tamil Business Tribe',
              'subtitle': 'Tamil Business Tribe - Guide. Inspire. Empower.',
            },
            {
              'media_type': 'image',
              'media_url': 'assets/images/tbt_2.jpeg',
              'is_asset': true,
              'title': 'TBT Quote of the Day',
              'subtitle':
                  '“To get something you never had, you have to do something you never did.”\n\n- Tamil Business Tribe Mentor Quote',
            }
          ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: context.borderCol,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.5),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: Stack(
            children: [
              PageView.builder(
                controller: _carouselPageController,
                onPageChanged: (int index) {
                  setState(() {
                    _currentCarouselPage = index % slides.length;
                  });
                },
                itemBuilder: (context, index) {
                  final itemIndex = index % slides.length;
                  final item = slides[itemIndex];
                  final mediaType = item['media_type'] ?? 'image';
                  final mediaUrl = item['media_url'] ?? '';
                  final thumbnailUrl = item['thumbnail_url'] as String? ?? '';
                  final isAsset = item['is_asset'] == true;

                  Widget mediaWidget;
                  if (isAsset) {
                    mediaWidget = Image.asset(
                      mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: context.cardBg);
                      },
                    );
                  } else if (mediaType == 'video') {
                    String finalVideoUrl = mediaUrl;
                    String? finalThumbnailUrl =
                        thumbnailUrl.isEmpty ? null : thumbnailUrl;

                    // Automatically swap back if they were pasted in reverse
                    final isMediaUrlImage =
                        mediaUrl.toLowerCase().contains('.jpg') ||
                            mediaUrl.toLowerCase().contains('.jpeg') ||
                            mediaUrl.toLowerCase().contains('.png') ||
                            mediaUrl.toLowerCase().contains('.webp') ||
                            mediaUrl.toLowerCase().contains('picsum.photos');
                    final isThumbnailUrlVideo =
                        thumbnailUrl.toLowerCase().contains('.mp4') ||
                            thumbnailUrl.toLowerCase().contains('.mov') ||
                            thumbnailUrl.toLowerCase().contains('.m3u8') ||
                            thumbnailUrl.toLowerCase().contains('.webm');

                    if (isMediaUrlImage && isThumbnailUrlVideo) {
                      finalVideoUrl = thumbnailUrl;
                      finalThumbnailUrl = mediaUrl;
                    }

                    mediaWidget = CarouselVideoPlayer(
                      videoUrl: finalVideoUrl,
                      thumbnailUrl: finalThumbnailUrl,
                    );
                  } else {
                    mediaWidget = Image.network(
                      mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF0F0F11),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image,
                              color: Colors.white24, size: 40),
                        );
                      },
                    );
                  }

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      mediaWidget,
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.15),
                              Colors.black.withOpacity(0.85),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              item['title'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              item['subtitle'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12.0,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            if (item['description'] != null &&
                                (item['description'] as String)
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 2.0),
                              Text(
                                item['description'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 10.0,
                                ),
                              ),
                            ],
                            if (item['button_text'] != null &&
                                (item['button_text'] as String)
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 6.0),
                              SizedBox(
                                height: 28.0,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final url = item['button_link'] ?? '';
                                    if (url.isNotEmpty) {
                                      _launchUrlHelper(url);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFCC0000),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6.0),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0, vertical: 0.0),
                                  ),
                                  child: Text(
                                    item['button_text'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              Positioned(
                top: 16.0,
                right: 16.0,
                child: BlinkingShareButton(
                  onTap: () {
                    if (_carouselItems.isNotEmpty) {
                      _shareCarouselQuote(_currentCarouselPage);
                    } else {
                      final fallbackImages = [
                        'assets/images/whatsapp_image.jpeg',
                        'assets/images/tbt_2.jpeg',
                      ];
                      _shareAssetImage(fallbackImages[_currentCarouselPage]);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselIndicator() {
    final List<Map<String, dynamic>> slides = _carouselItems.isNotEmpty
        ? _carouselItems
        : [
            {
              'media_type': 'image',
              'media_url': 'assets/images/whatsapp_image.jpeg',
              'is_asset': true,
              'title': 'Tamil Business Tribe',
              'subtitle': 'Tamil Business Tribe - Guide. Inspire. Empower.',
            },
            {
              'media_type': 'image',
              'media_url': 'assets/images/tbt_2.jpeg',
              'is_asset': true,
              'title': 'TBT Quote of the Day',
              'subtitle':
                  '“To get something you never had, you have to do something you never did.”\n\n- Tamil Business Tribe Mentor Quote',
            }
          ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(slides.length, (index) {
        final isSelected = _currentCarouselPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          width: isSelected ? 18.0 : 6.0,
          height: 4.0,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE50914) : const Color(0xFF48484A),
            borderRadius: BorderRadius.circular(2.0),
          ),
        );
      }),
    );
  }

  Widget _buildMenuGrid() {
    final List<_HomeMenuItem> menuItems = [
      _HomeMenuItem(
        title: 'Community',
        icon: Icons.groups_rounded,
        color: const Color(0xFF00F2FE),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CommunityScreen()),
          ).then((value) {
            if (value is int) {
              setState(() {
                _currentTabIndex = value;
              });
              if (value == 4) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                ).then((_) {
                  setState(() {
                    _currentTabIndex = 0;
                  });
                });
              }
            }
          });
        },
      ),
      _HomeMenuItem(
        title: 'Courses',
        icon: Icons.school_rounded,
        color: const Color(0xFFF2994A),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CoursesScreen()),
          );
        },
      ),
      _HomeMenuItem(
        title: 'Podcast',
        icon: Icons.podcasts_rounded,
        color: const Color(0xFFE285FF),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PodcastScreen()),
          );
        },
      ),
      _HomeMenuItem(
        title: 'Workshop',
        icon: Icons.co_present_rounded,
        color: const Color(0xFFFF5E62),
        onTap: () {},
      ),
      _HomeMenuItem(
        title: 'E-Book',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF38EF7D),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const EBooksLibraryScreen()),
          );
        },
      ),
      _HomeMenuItem(
        title: 'Task',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF2F80ED),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TasksScreen()),
          );
        },
      ),
    ];

    const List<Duration> rowDelays = [
      Duration(milliseconds: 100),
      Duration(milliseconds: 250),
      Duration(milliseconds: 400),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (rowIndex) {
        final rowItems = menuItems.sublist(rowIndex * 2, rowIndex * 2 + 2);
        return Padding(
          padding: EdgeInsets.only(top: rowIndex == 0 ? 0.0 : 14.0),
          child: FadeInSlideTransition(
            delay: rowDelays[rowIndex],
            child: Row(
              children: [
                for (int i = 0; i < rowItems.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14.0),
                  Expanded(
                    child: AnimatedGlassCard(
                      title: rowItems[i].title,
                      icon: rowItems[i].icon,
                      color: rowItems[i].color,
                      onTap: rowItems[i].onTap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomNavigationBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final barWidth = screenWidth > 500 ? 500.0 : screenWidth;

    return NativeGlassNavigationBar(
      tabs: const [
        NativeGlassTab(icon: 'home', label: 'HOME'),
        NativeGlassTab(icon: 'trophy', label: 'WINS'),
        NativeGlassTab(icon: 'avatar', label: 'VOICE OF SAKTHI'),
        NativeGlassTab(icon: 'school', label: 'COURSES'),
        NativeGlassTab(icon: 'person', label: 'PROFILE'),
      ],
      fallback: Container(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: barWidth,
                height: 75.0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Glassmorphic background layer
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24.0),
                          topRight: Radius.circular(24.0),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.isDark
                                  ? const Color(0xFF151515).withOpacity(0.85)
                                  : Colors.white.withOpacity(0.9),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24.0),
                                topRight: Radius.circular(24.0),
                              ),
                              border: Border.all(
                                color: context.borderCol,
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Navigation items layer (on top of background, no clipping)
                    Positioned.fill(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _buildNavItem(0, Icons.home, 'HOME')),
                          Expanded(
                              child:
                                  _buildNavItem(1, Icons.emoji_events, 'WINS')),
                          Expanded(child: _buildVoiceOfSakthiItem(2)),
                          Expanded(
                              child: _buildNavItem(3, Icons.school, 'COURSES')),
                          Expanded(
                              child: _buildNavItem(4, Icons.person, 'PROFILE')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isDark = context.isDark;
    final isSelected = _currentTabIndex == index;
    final activeColor = const Color(0xFFE50914);
    final inactiveColor = isDark ? Colors.white38 : Colors.black45;

    if (isSelected) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        height: 52.0,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.18)
                : Colors.black.withOpacity(0.12),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: activeColor,
              size: 20.0,
            ),
            const SizedBox(height: 3.0),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontSize: 10.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return InkWell(
        onTap: () {
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CoursesScreen()),
            ).then((_) {
              setState(() {
                _currentTabIndex = 0;
              });
            });
            return;
          }
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ).then((_) {
              setState(() {
                _currentTabIndex = 0;
              });
            });
            return;
          }
          setState(() {
            _currentTabIndex = index;
          });
        },
        child: Container(
          height: 52.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: inactiveColor,
                size: 22.0,
              ),
              const SizedBox(height: 4.0),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: inactiveColor,
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildVoiceOfSakthiItem(int index) {
    final isDark = context.isDark;
    final isSelected = _currentTabIndex == index;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PodcastScreen()),
        ).then((_) {
          setState(() {
            _currentTabIndex = 0;
          });
        });
      },
      child: Container(
        height: 75.0,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -24.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54.0,
                    height: 54.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFE50914)
                            : Colors.amber.shade700,
                        width: 2.0,
                      ),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/nav  bar.jpeg'),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 8.0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'VOICE OF SAKTHI',
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFE50914)
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Animated Leaderboard Tab
// ─────────────────────────────────────────────────────────────────
class _LeaderboardTab extends StatefulWidget {
  const _LeaderboardTab();

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab>
    with TickerProviderStateMixin {
  // Header fade-down animation
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  // Podium rise-up animations (3 columns)
  late List<AnimationController> _podiumCtrls;
  late List<Animation<double>> _podiumScales;
  late List<Animation<double>> _podiumFades;

  // Crown pulse animation
  late AnimationController _crownCtrl;
  late Animation<double> _crownPulse;

  // List item stagger animations (4 items: ranks 4-7)
  late List<AnimationController> _listCtrls;
  late List<Animation<double>> _listFades;
  late List<Animation<Offset>> _listSlides;

  final List<Map<String, dynamic>> leaders = [
    {
      'rank': 1,
      'name': 'Rajesh Kumar',
      'role': 'CEO, Tech Solutions',
      'points': '9,450',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face',
      'isCurrentUser': false,
    },
    {
      'rank': 2,
      'name': 'Priyadharshini',
      'role': 'Founder, Organic Foods',
      'points': '8,210',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop&crop=face',
      'isCurrentUser': false,
    },
    {
      'rank': 3,
      'name': 'Thrisha',
      'role': 'Co-Founder, Creative Studios',
      'points': '2,450',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop&crop=face',
      'isCurrentUser': true,
    },
    {
      'rank': 4,
      'name': 'Anand Dev',
      'role': 'CEO, Dev Agency',
      'points': '2,120',
      'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&crop=face',
      'isCurrentUser': false,
    },
    {
      'rank': 5,
      'name': 'Ramya S.',
      'role': 'Founder, Sparkle Design',
      'points': '1,840',
      'avatar': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop&crop=face',
      'isCurrentUser': false,
    },
    {
      'rank': 6,
      'name': 'Karthik Raja',
      'role': 'Director, Build Corp',
      'points': '1,590',
      'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face',
      'isCurrentUser': false,
    },
    {
      'rank': 7,
      'name': 'Shalini M.',
      'role': 'CEO, EduTech',
      'points': '1,320',
      'avatar': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100&h=100&fit=crop&crop=face',
      'isCurrentUser': false,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Header animation
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
            begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    // Podium animations — staggered [rank2, rank1, rank3]
    _podiumCtrls = List.generate(
      3,
      (i) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600)),
    );
    _podiumScales = _podiumCtrls
        .map((c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: c, curve: Curves.elasticOut)))
        .toList();
    _podiumFades = _podiumCtrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();

    // Crown pulse (loop)
    _crownCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _crownPulse = Tween<double>(begin: 1.0, end: 1.25)
        .animate(CurvedAnimation(parent: _crownCtrl, curve: Curves.easeInOut));

    // List item stagger
    _listCtrls = List.generate(
      4,
      (i) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 420)),
    );
    _listFades = _listCtrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _listSlides = _listCtrls
        .map((c) => Tween<Offset>(
                begin: const Offset(0.3, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _headerCtrl.forward();

    // Podium: center (rank1) first, then sides
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    _podiumCtrls[1].forward(); // rank 1 (center) rises first
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _podiumCtrls[0].forward(); // rank 2
    _podiumCtrls[2].forward(); // rank 3

    // List items stagger
    await Future.delayed(const Duration(milliseconds: 400));
    for (int i = 0; i < 4; i++) {
      if (!mounted) return;
      _listCtrls[i].forward();
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    for (final c in _podiumCtrls) c.dispose();
    _crownCtrl.dispose();
    for (final c in _listCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white60 : Colors.black87.withOpacity(0.7);

    final top3 = leaders.take(3).toList();
    // Podium arrangement: [rank2 left, rank1 center, rank3 right]
    final podium = [top3[1], top3[0], top3[2]];
    final otherLeaders = leaders.skip(3).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 120.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Animated Header ─────────────────────────────────
              FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(
                  position: _headerSlide,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFFFFD700),
                          size: 36,
                        ),
                        const SizedBox(height: 12),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFE50914), Color(0xFFFF6B35)],
                          ).createShader(bounds),
                          child: const Text(
                            'TBT LEADERBOARD',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          'Top performers of Tamil Business Tribe this week',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: subTextColor, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16.0),

              // ── Animated Podium ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(3, (idx) {
                  final leader = podium[idx];
                  final rank = leader['rank'] as int;
                  final isRank1 = rank == 1;
                  final isRank2 = rank == 2;
                  final isCurrentUser = leader['isCurrentUser'] == true;

                  final double avatarSize = isRank1 ? 72.0 : 56.0;
                  final double pedestalH = isRank1 ? 90.0 : (isRank2 ? 68.0 : 52.0);
                  final Color podiumColor = isRank1
                      ? const Color(0xFFFFD700)
                      : (isRank2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));

                  // Animation index: center=1(rank1), left=0(rank2), right=2(rank3)
                  final animIdx = idx;

                  return Expanded(
                    child: FadeTransition(
                      opacity: _podiumFades[animIdx],
                      child: ScaleTransition(
                        scale: _podiumScales[animIdx],
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Crown pulse for rank 1
                            if (isRank1)
                              ScaleTransition(
                                scale: _crownPulse,
                                child: const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: Color(0xFFFFD700),
                                  size: 26.0,
                                ),
                              )
                            else
                              const SizedBox(height: 26),

                            const SizedBox(height: 6),

                            // Avatar with glowing border
                            Container(
                              width: avatarSize + 8.0,
                              height: avatarSize + 8.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: podiumColor, width: 3.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: podiumColor.withOpacity(0.4),
                                    blurRadius: 16.0,
                                    spreadRadius: 2.0,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(avatarSize / 2 + 4),
                                child: isCurrentUser && ProfileScreen.profileImagePath != null
                                    ? Image.file(
                                        File(ProfileScreen.profileImagePath!),
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        leader['avatar'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(color: Colors.grey.shade800),
                                      ),
                              ),
                            ),

                            // Rank badge
                            Transform.translate(
                              offset: const Offset(0, -6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                                decoration: BoxDecoration(
                                  color: podiumColor,
                                  borderRadius: BorderRadius.circular(10.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: podiumColor.withOpacity(0.4),
                                      blurRadius: 6,
                                    )
                                  ],
                                ),
                                child: Text(
                                  '#$rank',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),

                            Text(
                              leader['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3.0),
                            Text(
                              '${leader['points']} PTS',
                              style: const TextStyle(
                                color: Color(0xFFE50914),
                                fontSize: 11.0,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10.0),

                            // Podium pedestal block
                            Container(
                              height: pedestalH,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    podiumColor.withOpacity(isDark ? 0.22 : 0.45),
                                    podiumColor.withOpacity(isDark ? 0.06 : 0.15),
                                  ],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(10.0)),
                                border: Border.all(
                                  color: podiumColor.withOpacity(isDark ? 0.45 : 0.75),
                                  width: isDark ? 1.5 : 2.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 28.0),

              // ── Animated Rank List (4–7) ─────────────────────────
              GlassmorphicCard(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  children: List.generate(otherLeaders.length, (i) {
                    final leader = otherLeaders[i];
                    final rank = leader['rank'] as int;
                    final isCurrentUser = leader['isCurrentUser'] == true;
                    final listIdx = i < 4 ? i : 3;

                    final item = FadeTransition(
                      opacity: _listFades[listIdx],
                      child: SlideTransition(
                        position: _listSlides[listIdx],
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10.0),
                              child: Row(
                                children: [
                                  // Rank number
                                  SizedBox(
                                    width: 34.0,
                                    child: Text(
                                      '#$rank',
                                      style: TextStyle(
                                        color: isCurrentUser
                                            ? const Color(0xFFE50914)
                                            : subTextColor,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // Avatar
                                  Container(
                                    width: 40.0,
                                    height: 40.0,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isCurrentUser
                                            ? const Color(0xFFE50914)
                                            : context.borderCol,
                                        width: 2.0,
                                      ),
                                      boxShadow: isCurrentUser
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFE50914)
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20.0),
                                      child: Image.network(
                                        leader['avatar'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(color: Colors.grey.shade800),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),
                                  // Name & role
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          leader['name'],
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 13.5,
                                            fontWeight: isCurrentUser
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2.0),
                                        Text(
                                          leader['role'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: subTextColor, fontSize: 10.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  // Points
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser
                                          ? const Color(0xFFE50914).withOpacity(0.12)
                                          : (isDark
                                              ? Colors.white.withOpacity(0.06)
                                              : Colors.black.withOpacity(0.04)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${leader['points']} PTS',
                                      style: TextStyle(
                                        color: isCurrentUser
                                            ? const Color(0xFFE50914)
                                            : textColor,
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (i < otherLeaders.length - 1)
                              Divider(color: context.borderCol, height: 1.0),
                          ],
                        ),
                      ),
                    );
                    return item;
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CarouselVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  const CarouselVideoPlayer(
      {super.key, required this.videoUrl, this.thumbnailUrl});

  @override
  State<CarouselVideoPlayer> createState() => _CarouselVideoPlayerState();
}

class _CarouselVideoPlayerState extends State<CarouselVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;

  void _initPlayer() {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri != null) {
      _controller = VideoPlayerController.networkUrl(uri)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
              _isPlaying = true;
            });
            _controller!.play();
            _controller!.setLooping(true);
          }
        }).catchError((err) {
          debugPrint('Error loading carousel video: $err');
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
        });
    } else {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.thumbnailUrl != null
          ? Image.network(
              widget.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.black),
            )
          : Container(color: Colors.black);
    }

    if (!_isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.thumbnailUrl != null)
            Image.network(
              widget.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.black),
            )
          else
            Container(color: Colors.black),
          Center(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon:
                    const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                onPressed: _initPlayer,
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_isPlaying) {
            _controller!.pause();
            _isPlaying = false;
          } else {
            _controller!.play();
            _isPlaying = true;
          }
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
          if (!_isPlaying)
            const Center(
              child: Icon(Icons.play_arrow, color: Colors.white, size: 48),
            ),
        ],
      ),
    );
  }
}

class BlinkingShareButton extends StatefulWidget {
  final VoidCallback onTap;

  const BlinkingShareButton({super.key, required this.onTap});

  @override
  State<BlinkingShareButton> createState() => _BlinkingShareButtonState();
}

class _BlinkingShareButtonState extends State<BlinkingShareButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 36.0,
              height: 36.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.2),
                border: Border.all(
                  color: const Color(0xFFD30814).withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.share_outlined,
                color: Colors.white,
                size: 18.0,
              ),
            ),
          ),
        );
      },
    );
  }
}

class FadeInSlideTransition extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const FadeInSlideTransition({
    super.key,
    required this.child,
    required this.delay,
  });

  @override
  State<FadeInSlideTransition> createState() => _FadeInSlideTransitionState();
}

class _FadeInSlideTransitionState extends State<FadeInSlideTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _offset =
        Tween<Offset>(begin: const Offset(0.0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

/// Data model for a Home page menu card. [color] is reused for both the
/// icon and the card's border so they always stay in sync.
class _HomeMenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HomeMenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class AnimatedGlassCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isFullWidth;
  final VoidCallback onTap;

  const AnimatedGlassCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  State<AnimatedGlassCard> createState() => _AnimatedGlassCardState();
}

class _AnimatedGlassCardState extends State<AnimatedGlassCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _scale = 0.94;
        });
      },
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
        });
        widget.onTap();
      },
      onTapCancel: () {
        setState(() {
          _scale = 1.0;
        });
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Container(
          height: widget.isFullWidth ? 80.0 : 110.0,
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: widget.color.withOpacity(0.6),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 10.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: widget.isFullWidth
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: widget.color, size: 30.0),
                      const SizedBox(width: 12.0),
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: widget.color, size: 32.0),
                      const SizedBox(height: 10.0),
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class GlassmorphicBackground extends StatelessWidget {
  final Widget child;

  const GlassmorphicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Stack(
      children: [
        // Base gradient background (adapts to light/dark mode)
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF070708), // Dark blackish grey
                      const Color(0xFF0F0E11), // Dark charcoal
                      const Color(0xFF020202), // Deep pure black
                    ]
                  : [
                      const Color(0xFFF7F7F9), // Soft light grey
                      const Color(0xFFECEFF1), // Silver frost
                      const Color(0xFFF0F2F5), // Bright clean grey
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Content
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}

class BorderPainter extends CustomPainter {
  final double animationValue;
  final double borderRadius;
  final double borderWidth;
  final bool isDark;

  BorderPainter({
    required this.animationValue,
    required this.borderRadius,
    required this.borderWidth,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final double angle = animationValue * 2.0 * math.pi;
    final List<Color> colors = isDark
        ? [
            Colors.black,
            const Color(0xFFE50914),
            Colors.black,
            const Color(0xFFE50914),
            Colors.black,
          ]
        : [
            Colors.white,
            const Color(0xFFE50914),
            Colors.white,
            const Color(0xFFE50914),
            Colors.white,
          ];

    paint.shader = SweepGradient(
      colors: colors,
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      transform: GradientRotation(angle),
    ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant BorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.isDark != isDark;
  }
}

class GlassmorphicCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double borderWidth;
  final EdgeInsetsGeometry padding;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.blur = 16.0,
    this.borderWidth = 1.8,
    this.padding = const EdgeInsets.all(28.0),
  });

  @override
  State<GlassmorphicCard> createState() => _GlassmorphicCardState();
}

class _GlassmorphicCardState extends State<GlassmorphicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE50914).withOpacity(isDark ? 0.08 : 0.05),
            blurRadius: 24.0,
            spreadRadius: 1.0,
          ),
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.45) : Colors.black.withOpacity(0.08),
            blurRadius: 16.0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          children: [
            // 1. Stroke-only Dynamic Rotating Border Loop (Draws strictly on the 1.8px boundary, center is empty)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: BorderPainter(
                      animationValue: _controller.value,
                      borderRadius: widget.borderRadius,
                      borderWidth: widget.borderWidth,
                      isDark: isDark,
                    ),
                  );
                },
              ),
            ),
            
            // 2. Frosted glass inner card content
            Padding(
              padding: EdgeInsets.all(widget.borderWidth),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius - widget.borderWidth),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
                  child: Container(
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F0E12).withOpacity(0.85)
                          : Colors.white.withOpacity(0.80),
                      borderRadius: BorderRadius.circular(widget.borderRadius - widget.borderWidth),
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignIn() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    SessionManager.setLoggedIn(true).then((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PostPopupScreen()),
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD30814),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassmorphicBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20.0),
                    const AppLogo.card(),
                    const SizedBox(height: 12.0),
                    Container(
                      width: 32.0,
                      height: 3.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      'YOUR BUSINESS. ELEVATED.',
                      style: TextStyle(
                        color: context.subTextColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    GlassmorphicCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'Sign In to access your courses, webinars & books',
                            style: TextStyle(
                              color: context.subTextColor,
                              fontSize: 12.0,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          TextField(
                            controller: _emailController,
                            style: TextStyle(color: context.textColor, fontSize: 14.0),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.04),
                              hintText: 'Enter your email address',
                              hintStyle: TextStyle(color: context.subTextColor, fontSize: 13.0),
                              prefixIcon: Icon(Icons.mail_outline_rounded, color: context.subTextColor, size: 20.0),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: context.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08), width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: context.textColor, fontSize: 14.0),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.04),
                              hintText: 'Enter your password',
                              hintStyle: TextStyle(color: context.subTextColor, fontSize: 13.0),
                              prefixIcon: Icon(Icons.lock_outline_rounded, color: context.subTextColor, size: 20.0),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: context.subTextColor,
                                  size: 20.0,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: context.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08), width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPasswordScreen()),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Color(0xFFE50914),
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          Container(
                            width: double.infinity,
                            height: 48.0,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE50914), Color(0xFF8B0000)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12.0),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE50914).withOpacity(0.35),
                                  blurRadius: 12.0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _handleSignIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28.0),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: context.subTextColor,
                            fontSize: 13.0,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const CreateAccountScreen()),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Join TBT',
                            style: TextStyle(
                              color: Color(0xFFE50914),
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'TERMS OF SERVICE',
                          style: TextStyle(
                            color: context.subTextColor.withOpacity(0.4),
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Container(
                          width: 3.0,
                          height: 3.0,
                          decoration: BoxDecoration(
                            color: context.subTextColor.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          'PRIVACY POLICY',
                          style: TextStyle(
                            color: context.subTextColor.withOpacity(0.4),
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      '© 2026 Tamil Business Tribe. All rights reserved.',
                      style: TextStyle(
                        color: context.subTextColor.withOpacity(0.3),
                        fontSize: 9.0,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendLink() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          backgroundColor: Color(0xFFD30814),
        ),
      );
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Color(0xFFD30814),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56.0,
                  height: 56.0,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 32.0,
                  ),
                ),
                const SizedBox(height: 20.0),
                const Text(
                  'Link Sent!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12.0),
                Text(
                  'A password reset link has been successfully sent to $email.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13.0,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24.0),
                SizedBox(
                  width: double.infinity,
                  height: 44.0,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD30814),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      elevation: 0.0,
                    ),
                    child: const Text(
                      'Back to Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFD30814), size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reset Password',
          style: TextStyle(
            color: context.textColor,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.themeGradients,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10.0),
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 90.0,
                          height: 90.0,
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(
                              color: context.borderCol,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(context.isDark ? 0.3 : 0.05),
                                blurRadius: 10.0,
                                spreadRadius: 1.0,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.mail_outline_rounded,
                            color: context.subTextColor,
                            size: 44.0,
                          ),
                        ),
                        Positioned(
                          bottom: -6.0,
                          right: -6.0,
                          child: Container(
                            width: 34.0,
                            height: 34.0,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD30814),
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFD30814).withOpacity(0.4),
                                  blurRadius: 8.0,
                                  spreadRadius: 1.0,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.white,
                              size: 16.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36.0),
                    Text(
                      'Forgot your password?',
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        "Enter your registered email and we'll send you a reset link.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.subTextColor,
                          fontSize: 13.0,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36.0),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'EMAIL ADDRESS',
                        style: TextStyle(
                          color: context.subTextColor,
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: context.borderCol,
                        ),
                      ),
                      child: TextField(
                        controller: _emailController,
                        style:
                            TextStyle(color: context.textColor, fontSize: 14.0),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Enter your email address',
                          hintStyle: TextStyle(
                              color: context.subTextColor, fontSize: 13.0),
                          prefixIcon: Icon(Icons.mail_outline_rounded,
                              color: context.subTextColor, size: 20.0),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 14.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: ElevatedButton(
                        onPressed: _handleSendLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD30814),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 0.0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Send Reset Link',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8.0),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 18.0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40.0),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Remember your password? ",
                          style: TextStyle(
                            color: context.subTextColor,
                            fontSize: 13.0,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Back to Sign In',
                            style: TextStyle(
                              color: Color(0xFFD30814),
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48.0),
                    Text(
                      'CONTACT SUPPORT IF YOU\'RE HAVING TROUBLE',
                      style: TextStyle(
                        color: context.subTextColor,
                        fontSize: 9.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  String _selectedInterest = 'Courses';
  bool _whatsAppUpdates = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleJoin() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showError('All fields are required');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WelcomeTBTScreen(userName: name),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD30814),
      ),
    );
  }

  Widget _buildInterestChip(String label, IconData icon) {
    final isSelected = _selectedInterest == label;
    final isDark = context.isDark;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedInterest = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE50914)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE50914)
                : (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE50914).withOpacity(0.25),
                    blurRadius: 8.0,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
              size: 16.0,
            ),
            const SizedBox(width: 8.0),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFE50914), size: 20.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CREATE ACCOUNT',
          style: TextStyle(
            color: context.textColor,
            fontSize: 15.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
      ),
      body: GlassmorphicBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10.0),
                    const AppLogo.card(),
                    const SizedBox(height: 28.0),
                    GlassmorphicCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _nameController,
                            style: TextStyle(color: context.textColor, fontSize: 14.0),
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.04),
                              hintText: 'Full Name',
                              hintStyle: TextStyle(color: context.subTextColor, fontSize: 13.0),
                              prefixIcon: Icon(Icons.person_outline_rounded, color: context.subTextColor, size: 20.0),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: context.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08), width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          TextField(
                            controller: _emailController,
                            style: TextStyle(color: context.textColor, fontSize: 14.0),
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.04),
                              hintText: 'Email Address',
                              hintStyle: TextStyle(color: context.subTextColor, fontSize: 13.0),
                              prefixIcon: Icon(Icons.mail_outline_rounded, color: context.subTextColor, size: 20.0),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: context.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08), width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          TextField(
                            controller: _phoneController,
                            style: TextStyle(color: context.textColor, fontSize: 14.0),
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.04),
                              hintText: 'Phone / WhatsApp',
                              hintStyle: TextStyle(color: context.subTextColor, fontSize: 13.0),
                              prefixIcon: Icon(Icons.phone_iphone_rounded, color: context.subTextColor, size: 20.0),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: context.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08), width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6.0),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Text(
                                'For exclusive webinar reminders',
                                style: TextStyle(
                                    color: context.subTextColor, fontSize: 10.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: context.textColor, fontSize: 14.0),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.04),
                              hintText: 'Password',
                              hintStyle: TextStyle(color: context.subTextColor, fontSize: 13.0),
                              prefixIcon: Icon(Icons.lock_outline_rounded, color: context.subTextColor, size: 20.0),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: context.subTextColor,
                                  size: 20.0,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: context.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08), width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: context.textColor, fontSize: 14.0),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.04),
                              hintText: 'Confirm Password',
                              hintStyle: TextStyle(color: context.subTextColor, fontSize: 13.0),
                              prefixIcon: Icon(Icons.shield_outlined, color: context.subTextColor, size: 20.0),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: context.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08), width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'PRIMARY INTEREST',
                              style: TextStyle(
                                color: context.subTextColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            alignment: WrapAlignment.start,
                            children: [
                              _buildInterestChip(
                                  'Courses', Icons.assignment_outlined),
                              _buildInterestChip(
                                  'Webinars', Icons.ondemand_video_rounded),
                              _buildInterestChip('Books', Icons.menu_book_rounded),
                              _buildInterestChip(
                                  'Networking', Icons.people_outline_rounded),
                            ],
                          ),
                          const SizedBox(height: 24.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'WhatsApp updates & reminders',
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Switch(
                                value: _whatsAppUpdates,
                                onChanged: (val) {
                                  setState(() {
                                    _whatsAppUpdates = val;
                                  });
                                },
                                activeColor: const Color(0xFFE50914),
                                activeTrackColor:
                                    const Color(0xFFE50914).withOpacity(0.4),
                                inactiveThumbColor: context.isDark ? Colors.grey : Colors.grey.shade400,
                                inactiveTrackColor:
                                    context.isDark ? Colors.white10 : Colors.black12,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24.0),
                          Container(
                            width: double.infinity,
                            height: 48.0,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE50914), Color(0xFF8B0000)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12.0),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE50914).withOpacity(0.35),
                                  blurRadius: 12.0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _handleJoin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child: const Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'JOIN TAMIL BUSINESS TRIBE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8.0),
                                  Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 16.0),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          Row(
                            children: [
                              Expanded(child: Divider(color: context.borderCol)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                      color: context.subTextColor,
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(child: Divider(color: context.borderCol)),
                            ],
                          ),
                          const SizedBox(height: 24.0),
                          SizedBox(
                            width: double.infinity,
                            height: 48.0,
                            child: OutlinedButton(
                              onPressed: () {
                                _showError('Google Sign-In is not configured yet');
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: context.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.03),
                                side: BorderSide(color: context.isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.png',
                                    height: 18.0,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.g_mobiledata_rounded,
                                          color: Colors.white);
                                    },
                                  ),
                                  const SizedBox(width: 12.0),
                                  Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      color: context.textColor,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Already a member? ",
                          style: TextStyle(
                            color: context.subTextColor,
                            fontSize: 13.0,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Color(0xFFE50914),
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeTBTScreen extends StatefulWidget {
  final String userName;
  const WelcomeTBTScreen({super.key, required this.userName});

  @override
  State<WelcomeTBTScreen> createState() => _WelcomeTBTScreenState();
}

class _WelcomeTBTScreenState extends State<WelcomeTBTScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _titleOpacity;
  late Animation<double> _titleSlide;
  late Animation<double> _checkScale;
  late Animation<double> _welcomeOpacity;
  late Animation<double> _welcomeSlide;
  late Animation<double> _nameOpacity;
  late Animation<double> _nameSlide;
  late Animation<double> _badgeScale;
  late Animation<double> _buttonOpacity;
  late Animation<double> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _titleSlide = Tween<double>(begin: -30.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.6, curve: Curves.elasticOut),
    ));

    _welcomeOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
    );
    _welcomeSlide =
        Tween<double>(begin: 20.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
    ));

    _nameOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
    );
    _nameSlide = Tween<double>(begin: 20.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
    ));

    _badgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.9, curve: Curves.elasticOut),
    ));

    _buttonOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );
    _buttonSlide = Tween<double>(begin: 30.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleExplore() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PostPopupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.themeGradients,
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20.0),
                        Transform.translate(
                          offset: Offset(0.0, _titleSlide.value),
                          child: Opacity(
                            opacity: _titleOpacity.value,
                            child: const Text(
                              'TAMIL BUSINESS\nTRIBE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFD30814),
                                fontSize: 28.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48.0),
                        Transform.scale(
                          scale: _checkScale.value,
                          child: Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 90.0,
                                  height: 90.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFD30814)
                                        .withOpacity(0.1),
                                    border: Border.all(
                                      color: const Color(0xFFD30814)
                                          .withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 60.0,
                                  height: 60.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFD30814),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD30814)
                                            .withOpacity(0.4),
                                        blurRadius: 12.0,
                                        spreadRadius: 1.0,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 32.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40.0),
                        Transform.translate(
                          offset: Offset(0.0, _welcomeSlide.value),
                          child: Opacity(
                            opacity: _welcomeOpacity.value,
                            child: const Text(
                              'Welcome to TBT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        Transform.translate(
                          offset: Offset(0.0, _nameSlide.value),
                          child: Opacity(
                            opacity: _nameOpacity.value,
                            child: Text(
                              'Hello, ${widget.userName} 👋',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        Transform.scale(
                          scale: _badgeScale.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18.0, vertical: 8.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141416),
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                color:
                                    const Color(0xFFD30814).withOpacity(0.35),
                                width: 1.0,
                              ),
                            ),
                            child: const Text(
                              'MASTER MEMBER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 80.0),
                        Transform.translate(
                          offset: Offset(0.0, _buttonSlide.value),
                          child: Opacity(
                            opacity: _buttonOpacity.value,
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 52.0,
                                  child: ElevatedButton(
                                    onPressed: _handleExplore,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD30814),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14.0),
                                      ),
                                      elevation: 0.0,
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Explore TBT',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8.0),
                                        Icon(Icons.arrow_forward_rounded,
                                            color: Colors.white, size: 18.0),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32.0),
                                const Text(
                                  'AUTHORIZED EXECUTIVE ACCESS ONLY',
                                  style: TextStyle(
                                    color: Colors.white24,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

extension ThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get primaryRed => const Color(0xFFE50914);
  Color get textColor => isDark ? Colors.white : Colors.black87;
  Color get subTextColor => isDark ? Colors.white54 : Colors.black54;
  Color get cardBg => isDark ? const Color(0xFF151515) : Colors.white;
  Color get borderCol =>
      isDark ? const Color(0xFF232326) : const Color(0xFFE5E5EA);
  Color get scaffoldBg =>
      isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5);
  List<Color> get themeGradients => isDark
      ? const [Color(0xFF000000), Color(0xFF010101), Color(0xFF000000)]
      : const [Color(0xFFFFECEE), Color(0xFFFAF2F3), Color(0xFFF5F5F5)];
}
