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
    required this.glassBackground,
    required this.glassHighlight,
    required this.glassShade,
    required this.glassBorder,
    required this.glassShadow,
  });

  const AppToastTokens.defaults()
    : maxWidth = 420,
      horizontalScreenInset = 24,
      minWidth = 96,
      minHeight = 44,
      borderRadius = 22,
      horizontalPadding = 22,
      verticalPadding = 14,
      textSize = 15,
      glassBackground = const Color(0x9AFBFAF8),
      glassHighlight = const Color(0x6BFFFFFF),
      glassShade = const Color.fromRGBO(0x2B, 0x18, 0x16, 0.045),
      glassBorder = const Color(0x80FFFFFF),
      glassShadow = const Color(0x1A1F1A18);

  const AppToastTokens.dark()
    : maxWidth = 420,
      horizontalScreenInset = 24,
      minWidth = 96,
      minHeight = 44,
      borderRadius = 22,
      horizontalPadding = 22,
      verticalPadding = 14,
      textSize = 15,
      glassBackground = const Color(0xAA181618),
      glassHighlight = const Color(0x26FFFFFF),
      glassShade = const Color(0x24000000),
      glassBorder = const Color(0x2EFFFFFF),
      glassShadow = const Color(0x59000000);

  final double maxWidth;
  final double horizontalScreenInset;
  final double minWidth;
  final double minHeight;
  final double borderRadius;
  final double horizontalPadding;
  final double verticalPadding;
  final double textSize;
  final Color glassBackground;
  final Color glassHighlight;
  final Color glassShade;
  final Color glassBorder;
  final Color glassShadow;

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
    Color? glassBackground,
    Color? glassHighlight,
    Color? glassShade,
    Color? glassBorder,
    Color? glassShadow,
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
      glassBackground: glassBackground ?? this.glassBackground,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      glassShade: glassShade ?? this.glassShade,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
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
      glassBackground: Color.lerp(glassBackground, other.glassBackground, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      glassShade: Color.lerp(glassShade, other.glassShade, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
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
