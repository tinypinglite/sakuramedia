import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppShadows extends ThemeExtension<AppShadows> {
  const AppShadows({
    required this.color,
    required this.cardBlur,
    required this.panelBlur,
    required this.offsetY,
  });

  const AppShadows.defaults()
    : color = const Color(0x142B1816),
      cardBlur = 16,
      panelBlur = 24,
      offsetY = 8;

  final Color color;
  final double cardBlur;
  final double panelBlur;
  final double offsetY;

  List<BoxShadow> get card => [
    BoxShadow(
      color: color,
      blurRadius: cardBlur,
      offset: Offset(0, offsetY / 2),
    ),
  ];

  List<BoxShadow> get panel => [
    BoxShadow(color: color, blurRadius: panelBlur, offset: Offset(0, offsetY)),
  ];

  @override
  AppShadows copyWith({
    Color? color,
    double? cardBlur,
    double? panelBlur,
    double? offsetY,
  }) {
    return AppShadows(
      color: color ?? this.color,
      cardBlur: cardBlur ?? this.cardBlur,
      panelBlur: panelBlur ?? this.panelBlur,
      offsetY: offsetY ?? this.offsetY,
    );
  }

  @override
  AppShadows lerp(ThemeExtension<AppShadows>? other, double t) {
    if (other is! AppShadows) {
      return this;
    }
    return AppShadows(
      color: Color.lerp(color, other.color, t)!,
      cardBlur: lerpDouble(cardBlur, other.cardBlur, t)!,
      panelBlur: lerpDouble(panelBlur, other.panelBlur, t)!,
      offsetY: lerpDouble(offsetY, other.offsetY, t)!,
    );
  }
}

extension AppShadowsThemeDataX on ThemeData {
  AppShadows get appShadows =>
      extension<AppShadows>() ?? const AppShadows.defaults();
}

extension AppShadowsBuildContextX on BuildContext {
  AppShadows get appShadows => Theme.of(this).appShadows;
}
