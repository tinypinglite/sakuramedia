import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

@immutable
class AppToastTokens extends ThemeExtension<AppToastTokens> {
  const AppToastTokens({
    required this.maxWidth,
    required this.horizontalScreenInset,
    required this.minWidth,
    required this.minHeight,
    required this.borderRadius,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.textSize,
  });

  const AppToastTokens.defaults()
    : maxWidth = 420,
      horizontalScreenInset = 24,
      minWidth = 96,
      minHeight = 44,
      borderRadius = 22,
      horizontalPadding = 22,
      verticalPadding = 14,
      textSize = 15;

  final double maxWidth;
  final double horizontalScreenInset;
  final double minWidth;
  final double minHeight;
  final double borderRadius;
  final double horizontalPadding;
  final double verticalPadding;
  final double textSize;

  BorderRadius get borderRadiusValue => BorderRadius.circular(borderRadius);

  @override
  AppToastTokens copyWith({
    double? maxWidth,
    double? horizontalScreenInset,
    double? minWidth,
    double? minHeight,
    double? borderRadius,
    double? horizontalPadding,
    double? verticalPadding,
    double? textSize,
  }) {
    return AppToastTokens(
      maxWidth: maxWidth ?? this.maxWidth,
      horizontalScreenInset:
          horizontalScreenInset ?? this.horizontalScreenInset,
      minWidth: minWidth ?? this.minWidth,
      minHeight: minHeight ?? this.minHeight,
      borderRadius: borderRadius ?? this.borderRadius,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      verticalPadding: verticalPadding ?? this.verticalPadding,
      textSize: textSize ?? this.textSize,
    );
  }

  @override
  AppToastTokens lerp(ThemeExtension<AppToastTokens>? other, double t) {
    if (other is! AppToastTokens) {
      return this;
    }
    return AppToastTokens(
      maxWidth: lerpDouble(maxWidth, other.maxWidth, t)!,
      horizontalScreenInset: lerpDouble(
        horizontalScreenInset,
        other.horizontalScreenInset,
        t,
      )!,
      minWidth: lerpDouble(minWidth, other.minWidth, t)!,
      minHeight: lerpDouble(minHeight, other.minHeight, t)!,
      borderRadius: lerpDouble(borderRadius, other.borderRadius, t)!,
      horizontalPadding: lerpDouble(
        horizontalPadding,
        other.horizontalPadding,
        t,
      )!,
      verticalPadding: lerpDouble(verticalPadding, other.verticalPadding, t)!,
      textSize: lerpDouble(textSize, other.textSize, t)!,
    );
  }
}

extension AppToastTokensThemeDataX on ThemeData {
  AppToastTokens get appToastTokens =>
      extension<AppToastTokens>() ?? const AppToastTokens.defaults();
}

extension AppToastTokensBuildContextX on BuildContext {
  AppToastTokens get appToastTokens => Theme.of(this).appToastTokens;
}
