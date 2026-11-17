import 'package:flutter/widgets.dart';

const double appGlassCapsuleRadius = 9999.0;

/// 液态玻璃的内部角色。业务层只使用公开的 [AppSurfaceRole]/[AppGlassTone]，
/// 不直接依赖这里的细分语气。
enum AppGlassRole {
  surface,
  popover,
  control,
  toolbarControl,
  input,
  toolbarInput,
  bar,
  overlay,
  mediaOverlay,
}

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
