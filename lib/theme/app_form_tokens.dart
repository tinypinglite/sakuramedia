import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppFormTokens extends ThemeExtension<AppFormTokens> {
  const AppFormTokens({
    required this.labelGap,
    required this.fieldHorizontalPadding,
    required this.miniFieldHorizontalPadding,
    required this.fieldVerticalPadding,
    required this.miniFieldHeight,
    required this.miniMenuItemHeight,
    required this.compactFieldHeight,
    required this.menuItemHeight,
    required this.menuGap,
    required this.menuMaxHeight,
  });

  const AppFormTokens.defaults()
    : labelGap = 8,
      fieldHorizontalPadding = 16,
      miniFieldHorizontalPadding = 10,
      fieldVerticalPadding = 14,
      miniFieldHeight = 28,
      miniMenuItemHeight = 34,
      compactFieldHeight = 36,
      menuItemHeight = 40,
      menuGap = 4,
      menuMaxHeight = 240;

  const AppFormTokens.mobile()
    : labelGap = 8,
      fieldHorizontalPadding = 16,
      miniFieldHorizontalPadding = 12,
      fieldVerticalPadding = 16,
      miniFieldHeight = 32,
      miniMenuItemHeight = 38,
      compactFieldHeight = 40,
      menuItemHeight = 44,
      menuGap = 4,
      menuMaxHeight = 260;

  final double labelGap;
  final double fieldHorizontalPadding;
  final double miniFieldHorizontalPadding;
  final double fieldVerticalPadding;
  final double miniFieldHeight;
  final double miniMenuItemHeight;
  final double compactFieldHeight;
  final double menuItemHeight;
  final double menuGap;
  final double menuMaxHeight;

  @override
  AppFormTokens copyWith({
    double? labelGap,
    double? fieldHorizontalPadding,
    double? miniFieldHorizontalPadding,
    double? fieldVerticalPadding,
    double? miniFieldHeight,
    double? miniMenuItemHeight,
    double? compactFieldHeight,
    double? menuItemHeight,
    double? menuGap,
    double? menuMaxHeight,
  }) {
    return AppFormTokens(
      labelGap: labelGap ?? this.labelGap,
      fieldHorizontalPadding:
          fieldHorizontalPadding ?? this.fieldHorizontalPadding,
      miniFieldHorizontalPadding:
          miniFieldHorizontalPadding ?? this.miniFieldHorizontalPadding,
      fieldVerticalPadding: fieldVerticalPadding ?? this.fieldVerticalPadding,
      miniFieldHeight: miniFieldHeight ?? this.miniFieldHeight,
      miniMenuItemHeight: miniMenuItemHeight ?? this.miniMenuItemHeight,
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
      miniFieldHorizontalPadding:
          lerpDouble(
            miniFieldHorizontalPadding,
            other.miniFieldHorizontalPadding,
            t,
          )!,
      fieldVerticalPadding:
          lerpDouble(fieldVerticalPadding, other.fieldVerticalPadding, t)!,
      miniFieldHeight: lerpDouble(miniFieldHeight, other.miniFieldHeight, t)!,
      miniMenuItemHeight:
          lerpDouble(miniMenuItemHeight, other.miniMenuItemHeight, t)!,
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
