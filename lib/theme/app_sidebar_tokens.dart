import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppSidebarTokens extends ThemeExtension<AppSidebarTokens> {
  const AppSidebarTokens({
    required this.expandedWidth,
    required this.collapsedWidth,
    required this.itemHeight,
  });

  const AppSidebarTokens.defaults()
    : expandedWidth = 240,
      collapsedWidth = 72,
      itemHeight = 44;

  final double expandedWidth;
  final double collapsedWidth;
  final double itemHeight;

  @override
  AppSidebarTokens copyWith({
    double? expandedWidth,
    double? collapsedWidth,
    double? itemHeight,
  }) {
    return AppSidebarTokens(
      expandedWidth: expandedWidth ?? this.expandedWidth,
      collapsedWidth: collapsedWidth ?? this.collapsedWidth,
      itemHeight: itemHeight ?? this.itemHeight,
    );
  }

  @override
  AppSidebarTokens lerp(ThemeExtension<AppSidebarTokens>? other, double t) {
    if (other is! AppSidebarTokens) {
      return this;
    }
    return AppSidebarTokens(
      expandedWidth: lerpDouble(expandedWidth, other.expandedWidth, t)!,
      collapsedWidth: lerpDouble(collapsedWidth, other.collapsedWidth, t)!,
      itemHeight: lerpDouble(itemHeight, other.itemHeight, t)!,
    );
  }
}

extension AppSidebarTokensThemeDataX on ThemeData {
  AppSidebarTokens get appSidebarTokens =>
      extension<AppSidebarTokens>() ?? const AppSidebarTokens.defaults();
}

extension AppSidebarTokensBuildContextX on BuildContext {
  AppSidebarTokens get appSidebarTokens => Theme.of(this).appSidebarTokens;
}
