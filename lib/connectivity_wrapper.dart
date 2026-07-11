import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'main.dart';

/// Wrap any screen with this widget to automatically show
/// a "No Internet" overlay when the device goes offline.
/// The overlay keeps the bottom navbar visible.
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  // Wifi / signal animation dots
  late final Timer _dotTimer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();

    // Fade animation for the no-internet overlay
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    // Animated dots timer
    _dotTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted && !_isOnline) {
        setState(() => _dotCount = (_dotCount + 1) % 4);
      }
    });

    // Check current connectivity immediately
    Connectivity().checkConnectivity().then(_handleResult);

    // Subscribe to future changes
    _sub = Connectivity()
        .onConnectivityChanged
        .listen(_handleResult);
  }

  void _handleResult(List<ConnectivityResult> results) {
    final online = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);

    if (online != _isOnline) {
      setState(() => _isOnline = online);
      if (!online) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _animController.dispose();
    _dotTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isOnline)
          FadeTransition(
            opacity: _fadeAnim,
            child: _NoInternetOverlay(dotCount: _dotCount),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
//  No Internet Overlay UI
// ─────────────────────────────────────────────────────
class _NoInternetOverlay extends StatefulWidget {
  final int dotCount;
  const _NoInternetOverlay({required this.dotCount});

  @override
  State<_NoInternetOverlay> createState() => _NoInternetOverlayState();
}

class _NoInternetOverlayState extends State<_NoInternetOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _dots => '.' * widget.dotCount;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: size.height,
      color: context.isDark ? const Color(0xFF0A0A0A).withOpacity(0.97) : const Color(0xFFF5F5F5).withOpacity(0.97),
      child: DefaultTextStyle(
        style: TextStyle(
          decoration: TextDecoration.none,
          fontFamily: '',
          color: context.textColor,
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                // Animated wifi-off icon
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.isDark ? const Color(0xFF1A1A1A) : Colors.white,
                      border: Border.all(
                        color: context.primaryRed.withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.primaryRed.withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: 56,
                      color: context.primaryRed,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'No Internet Connection',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Please check your Wi-Fi or mobile data\nand try again.',
                  style: TextStyle(
                    color: context.subTextColor,
                    fontSize: 14,
                    height: 1.6,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Animated signal bars
                _SignalBarsAnimation(dotCount: widget.dotCount),

                const SizedBox(height: 20),

                // Waiting text with animated dots
                Text(
                  'Waiting for connection$_dots',
                  style: TextStyle(
                    color: context.primaryRed.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    decoration: TextDecoration.none,
                  ),
                ),

                const SizedBox(height: 48),

                // Info card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.borderCol,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.primaryRed.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: context.primaryRed,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your app will automatically resume once the connection is restored.',
                          style: TextStyle(
                            color: context.subTextColor,
                            fontSize: 12,
                            height: 1.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Animated Signal Bars
// ─────────────────────────────────────────────────────
class _SignalBarsAnimation extends StatelessWidget {
  final int dotCount;
  const _SignalBarsAnimation({required this.dotCount});

  @override
  Widget build(BuildContext context) {
    // cycle through 0→3 bars active
    final activeBars = dotCount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final isActive = i < activeBars;
        final height = 8.0 + (i * 7.0);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 10,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: isActive
                ? context.primaryRed
                : (context.isDark ? const Color(0xFF333333) : const Color(0xFFD1D1D6)),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
