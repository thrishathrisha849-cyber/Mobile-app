import 'package:flutter/material.dart';

class NativeGlassNavigationBar extends StatelessWidget {
  final Widget fallback;
  const NativeGlassNavigationBar({
    super.key,
    required this.fallback,
    required List<NativeGlassTab> tabs,
  });

  @override
  Widget build(BuildContext context) {
    return fallback;
  }
}

class NativeGlassTab {
  final String icon;
  final String label;
  const NativeGlassTab({required this.icon, required this.label});
}
