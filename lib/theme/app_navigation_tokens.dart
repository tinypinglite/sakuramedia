import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppNavigationTokens extends ThemeExtension<AppNavigationTokens> {
  const AppNavigationTokens({
    required this.desktopTabHeight,
    required this.compactTabHeight,
    required this.mobileTopTabHeight,
    required this.desktopTabLabelTrailingPadding,
    required this.compactIndicatorThickness,
    required this.desktopIndicatorThickness,
    required this.mobileIndicatorThickness,
  });

  const AppNavigationTokens.defaults()
    : desktopTabHeight = 40,
      compactTabHeight = 32,
      mobileTopTabHeight = 52,
      desktopTabLabelTrailingPadding = 10,
      compactIndicatorThickness = 3,
      desktopIndicatorThickness = 3,
      mobileIndicatorThickness = 5;

  const AppNavigationTokens.mobile()
    : desktopTabHeight = 42,
      compactTabHeight = 36,
      mobileTopTabHeight = 36,
      desktopTabLabelTrailingPadding = 12,
      compactIndicatorThickness = 3,
      desktopIndicatorThickness = 3,
      mobileIndicatorThickness = 5;

  final double desktopTabHeight;
  final double compactTabHeight;
  final double mobileTopTabHeight;
  final double desktopTabLabelTrailingPadding;
  final double compactIndicatorThickness;
  final double desktopIndicatorThickness;
  final double mobileIndicatorThickness;

  @override
  AppNavigationTokens copyWith({
    double? desktopTabHeight,
    double? compactTabHeight,
    double? mobileTopTabHeight,
    double? desktopTabLabelTrailingPadding,
    double? compactIndicatorThickness,
    double? desktopIndicatorThickness,
    double? mobileIndicatorThickness,
  }) {
    return AppNavigationTokens(
      desktopTabHeight: desktopTabHeight ?? this.desktopTabHeight,
      compactTabHeight: compactTabHeight ?? this.compactTabHeight,
      mobileTopTabHeight: mobileTopTabHeight ?? this.mobileTopTabHeight,
      desktopTabLabelTrailingPadding:
          desktopTabLabelTrailingPadding ?? this.desktopTabLabelTrailingPadding,
      compactIndicatorThickness:
          compactIndicatorThickness ?? this.compactIndicatorThickness,
      desktopIndicatorThickness:
          desktopIndicatorThickness ?? this.desktopIndicatorThickness,
      mobileIndicatorThickness:
          mobileIndicatorThickness ?? this.mobileIndicatorThickness,
    );
  }

  @override
  AppNavigationTokens lerp(
    ThemeExtension<AppNavigationTokens>? other,
    double t,
  ) {
    if (other is! AppNavigationTokens) {
      return this;
    }
    return AppNavigationTokens(
      desktopTabHeight:
          lerpDouble(desktopTabHeight, other.desktopTabHeight, t)!,
      compactTabHeight:
          lerpDouble(compactTabHeight, other.compactTabHeight, t)!,
      mobileTopTabHeight:
          lerpDouble(mobileTopTabHeight, other.mobileTopTabHeight, t)!,
      desktopTabLabelTrailingPadding:
          lerpDouble(
            desktopTabLabelTrailingPadding,
            other.desktopTabLabelTrailingPadding,
            t,
          )!,
      compactIndicatorThickness:
          lerpDouble(
            compactIndicatorThickness,
            other.compactIndicatorThickness,
            t,
          )!,
      desktopIndicatorThickness:
          lerpDouble(
            desktopIndicatorThickness,
            other.desktopIndicatorThickness,
            t,
          )!,
      mobileIndicatorThickness:
          lerpDouble(
            mobileIndicatorThickness,
            other.mobileIndicatorThickness,
            t,
          )!,
    );
  }
}

extension AppNavigationTokensThemeDataX on ThemeData {
  AppNavigationTokens get appNavigationTokens =>
      extension<AppNavigationTokens>() ?? const AppNavigationTokens.defaults();
}

extension AppNavigationTokensBuildContextX on BuildContext {
  AppNavigationTokens get appNavigationTokens =>
      Theme.of(this).appNavigationTokens;
}
