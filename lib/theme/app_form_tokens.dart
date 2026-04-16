import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppFormTokens extends ThemeExtension<AppFormTokens> {
  const AppFormTokens({
    required this.labelGap,
    required this.fieldHorizontalPadding,
    required this.fieldVerticalPadding,
    required this.compactFieldHeight,
    required this.menuItemHeight,
    required this.menuGap,
    required this.menuMaxHeight,
  });

  const AppFormTokens.defaults()
    : labelGap = 8,
      fieldHorizontalPadding = 16,
      fieldVerticalPadding = 14,
      compactFieldHeight = 36,
      menuItemHeight = 40,
      menuGap = 4,
      menuMaxHeight = 240;

  final double labelGap;
  final double fieldHorizontalPadding;
  final double fieldVerticalPadding;
  final double compactFieldHeight;
  final double menuItemHeight;
  final double menuGap;
  final double menuMaxHeight;

  @override
  AppFormTokens copyWith({
    double? labelGap,
    double? fieldHorizontalPadding,
    double? fieldVerticalPadding,
    double? compactFieldHeight,
    double? menuItemHeight,
    double? menuGap,
    double? menuMaxHeight,
  }) {
    return AppFormTokens(
      labelGap: labelGap ?? this.labelGap,
      fieldHorizontalPadding:
          fieldHorizontalPadding ?? this.fieldHorizontalPadding,
      fieldVerticalPadding: fieldVerticalPadding ?? this.fieldVerticalPadding,
      compactFieldHeight: compactFieldHeight ?? this.compactFieldHeight,
      menuItemHeight: menuItemHeight ?? this.menuItemHeight,
      menuGap: menuGap ?? this.menuGap,
      menuMaxHeight: menuMaxHeight ?? this.menuMaxHeight,
    );
  }

  @override
  AppFormTokens lerp(ThemeExtension<AppFormTokens>? other, double t) {
    if (other is! AppFormTokens) {
      return this;
    }
    return AppFormTokens(
      labelGap: lerpDouble(labelGap, other.labelGap, t)!,
      fieldHorizontalPadding:
          lerpDouble(fieldHorizontalPadding, other.fieldHorizontalPadding, t)!,
      fieldVerticalPadding:
          lerpDouble(fieldVerticalPadding, other.fieldVerticalPadding, t)!,
      compactFieldHeight:
          lerpDouble(compactFieldHeight, other.compactFieldHeight, t)!,
      menuItemHeight: lerpDouble(menuItemHeight, other.menuItemHeight, t)!,
      menuGap: lerpDouble(menuGap, other.menuGap, t)!,
      menuMaxHeight: lerpDouble(menuMaxHeight, other.menuMaxHeight, t)!,
    );
  }
}

extension AppFormTokensThemeDataX on ThemeData {
  AppFormTokens get appFormTokens =>
      extension<AppFormTokens>() ?? const AppFormTokens.defaults();
}

extension AppFormTokensBuildContextX on BuildContext {
  AppFormTokens get appFormTokens => Theme.of(this).appFormTokens;
}
