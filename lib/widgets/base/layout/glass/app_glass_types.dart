import 'package:flutter/widgets.dart';

const double appGlassCapsuleRadius = 9999.0;

enum AppGlassButtonStyle { filled, prominent, transparent }

class AppGlassSegmentData {
  const AppGlassSegmentData({
    required this.id,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  final Object id;
  final String label;
  final Widget? icon;
  final bool enabled;
}

class AppGlassTabData {
  const AppGlassTabData({
    required this.icon,
    this.activeIcon,
    required this.label,
  });

  final Widget icon;
  final Widget? activeIcon;
  final String label;
}
