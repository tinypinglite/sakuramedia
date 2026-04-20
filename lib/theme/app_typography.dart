import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

enum AppTextSize { s20, s18, s16, s14, s12, s10 }

enum AppTextWeight { regular, medium, semibold }

enum AppTextTone {
  primary,
  secondary,
  tertiary,
  muted,
  accent,
  onMedia,
  info,
  warning,
  error,
  success,
}

@immutable
class AppTextScale extends ThemeExtension<AppTextScale> {
  const AppTextScale({
    required this.s20,
    required this.s18,
    required this.s16,
    required this.s14,
    required this.s12,
    required this.s10,
  });

  const AppTextScale.defaults()
    : s20 = 20,
      s18 = 18,
      s16 = 16,
      s14 = 14,
      s12 = 12,
      s10 = 10;

  const AppTextScale.mobile()
    : s20 = 20,
      s18 = 18,
      s16 = 16,
      s14 = 14,
      s12 = 12,
      s10 = 10;

  final double s20;
  final double s18;
  final double s16;
  final double s14;
  final double s12;
  final double s10;

  double sizeOf(AppTextSize size) {
    return switch (size) {
      AppTextSize.s20 => s20,
      AppTextSize.s18 => s18,
      AppTextSize.s16 => s16,
      AppTextSize.s14 => s14,
      AppTextSize.s12 => s12,
      AppTextSize.s10 => s10,
    };
  }

  TextTheme toTextTheme(AppTextWeights weights) {
    TextStyle style(AppTextSize size, AppTextWeight weight) => TextStyle(
      fontSize: sizeOf(size),
      fontWeight: weights.weightFor(weight),
    );

    return TextTheme(
      displaySmall: style(AppTextSize.s20, AppTextWeight.semibold),
      headlineSmall: style(AppTextSize.s20, AppTextWeight.semibold),
      titleLarge: style(AppTextSize.s20, AppTextWeight.semibold),
      titleMedium: style(AppTextSize.s18, AppTextWeight.semibold),
      titleSmall: style(AppTextSize.s16, AppTextWeight.regular),
      bodyLarge: style(AppTextSize.s14, AppTextWeight.regular),
      bodyMedium: style(AppTextSize.s14, AppTextWeight.regular),
      bodySmall: style(AppTextSize.s12, AppTextWeight.regular),
      labelLarge: style(AppTextSize.s14, AppTextWeight.regular),
      labelMedium: style(AppTextSize.s12, AppTextWeight.regular),
      labelSmall: style(AppTextSize.s10, AppTextWeight.regular),
    );
  }

  @override
  AppTextScale copyWith({
    double? s20,
    double? s18,
    double? s16,
    double? s14,
    double? s12,
    double? s10,
  }) {
    return AppTextScale(
      s20: s20 ?? this.s20,
      s18: s18 ?? this.s18,
      s16: s16 ?? this.s16,
      s14: s14 ?? this.s14,
      s12: s12 ?? this.s12,
      s10: s10 ?? this.s10,
    );
  }

  @override
  AppTextScale lerp(ThemeExtension<AppTextScale>? other, double t) {
    if (other is! AppTextScale) {
      return this;
    }
    return AppTextScale(
      s20: lerpDouble(s20, other.s20, t)!,
      s18: lerpDouble(s18, other.s18, t)!,
      s16: lerpDouble(s16, other.s16, t)!,
      s14: lerpDouble(s14, other.s14, t)!,
      s12: lerpDouble(s12, other.s12, t)!,
      s10: lerpDouble(s10, other.s10, t)!,
    );
  }
}

@immutable
class AppTextWeights extends ThemeExtension<AppTextWeights> {
  const AppTextWeights({
    required this.regular,
    required this.medium,
    required this.semibold,
  });

  const AppTextWeights.defaults()
    : regular = FontWeight.w400,
      medium = FontWeight.w500,
      semibold = FontWeight.w600;

  const AppTextWeights.mobile()
    : regular = FontWeight.w400,
      medium = FontWeight.w500,
      semibold = FontWeight.w600;

  final FontWeight regular;
  final FontWeight medium;
  final FontWeight semibold;

  FontWeight weightFor(AppTextWeight weight) {
    return switch (weight) {
      AppTextWeight.regular => regular,
      AppTextWeight.medium => medium,
      AppTextWeight.semibold => semibold,
    };
  }

  @override
  AppTextWeights copyWith({
    FontWeight? regular,
    FontWeight? medium,
    FontWeight? semibold,
  }) {
    return AppTextWeights(
      regular: regular ?? this.regular,
      medium: medium ?? this.medium,
      semibold: semibold ?? this.semibold,
    );
  }

  @override
  AppTextWeights lerp(ThemeExtension<AppTextWeights>? other, double t) {
    if (other is! AppTextWeights) {
      return this;
    }
    return AppTextWeights(
      regular: FontWeight.lerp(regular, other.regular, t)!,
      medium: FontWeight.lerp(medium, other.medium, t)!,
      semibold: FontWeight.lerp(semibold, other.semibold, t)!,
    );
  }
}

@immutable
class AppTextPalette extends ThemeExtension<AppTextPalette> {
  const AppTextPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.muted,
    required this.accent,
    required this.onMedia,
    required this.info,
    required this.warning,
    required this.error,
    required this.success,
  });

  const AppTextPalette.defaults()
    : primary = const Color(0xFF1F1A18),
      secondary = const Color(0xFF342D2A),
      tertiary = const Color(0xFF4D4440),
      muted = const Color(0xFF6B625E),
      accent = const Color(0xFF6B2D2A),
      onMedia = const Color(0xFFFFFFFF),
      info = const Color(0xFF175CD3),
      warning = const Color(0xFFB54708),
      error = const Color(0xFFB42318),
      success = const Color(0xFF027A48);

  const AppTextPalette.mobile()
    : primary = const Color(0xFF1F1A18),
      secondary = const Color(0xFF342D2A),
      tertiary = const Color(0xFF4D4440),
      muted = const Color(0xFF6B625E),
      accent = const Color(0xFF6B2D2A),
      onMedia = const Color(0xFFFFFFFF),
      info = const Color(0xFF175CD3),
      warning = const Color(0xFFB54708),
      error = const Color(0xFFB42318),
      success = const Color(0xFF027A48);

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color muted;
  final Color accent;
  final Color onMedia;
  final Color info;
  final Color warning;
  final Color error;
  final Color success;

  Color colorFor(AppTextTone tone) {
    return switch (tone) {
      AppTextTone.primary => primary,
      AppTextTone.secondary => secondary,
      AppTextTone.tertiary => tertiary,
      AppTextTone.muted => muted,
      AppTextTone.accent => accent,
      AppTextTone.onMedia => onMedia,
      AppTextTone.info => info,
      AppTextTone.warning => warning,
      AppTextTone.error => error,
      AppTextTone.success => success,
    };
  }

  @override
  AppTextPalette copyWith({
    Color? primary,
    Color? secondary,
    Color? tertiary,
    Color? muted,
    Color? accent,
    Color? onMedia,
    Color? info,
    Color? warning,
    Color? error,
    Color? success,
  }) {
    return AppTextPalette(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      onMedia: onMedia ?? this.onMedia,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      success: success ?? this.success,
    );
  }

  @override
  AppTextPalette lerp(ThemeExtension<AppTextPalette>? other, double t) {
    if (other is! AppTextPalette) {
      return this;
    }
    return AppTextPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onMedia: Color.lerp(onMedia, other.onMedia, t)!,
      info: Color.lerp(info, other.info, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

double resolveAppTextFontSize(BuildContext context, AppTextSize size) {
  return Theme.of(context).appTextScale.sizeOf(size);
}

FontWeight resolveAppTextWeight(BuildContext context, AppTextWeight weight) {
  return Theme.of(context).appTextWeights.weightFor(weight);
}

Color resolveAppTextToneColor(BuildContext context, AppTextTone tone) {
  return Theme.of(context).appTextPalette.colorFor(tone);
}

AppTextSize appTextSizeForStyle(TextStyle? style) {
  final fontSize = style?.fontSize?.round();
  return switch (fontSize) {
    20 => AppTextSize.s20,
    18 => AppTextSize.s18,
    16 => AppTextSize.s16,
    12 => AppTextSize.s12,
    10 => AppTextSize.s10,
    _ => AppTextSize.s14,
  };
}

TextStyle resolveAppTextStyle(
  BuildContext context, {
  required AppTextSize size,
  AppTextWeight weight = AppTextWeight.regular,
  AppTextTone tone = AppTextTone.primary,
}) {
  return TextStyle(
    fontSize: resolveAppTextFontSize(context, size),
    fontWeight: resolveAppTextWeight(context, weight),
    color: resolveAppTextToneColor(context, tone),
  );
}

extension AppTextScaleThemeDataX on ThemeData {
  AppTextScale get appTextScale =>
      extension<AppTextScale>() ?? const AppTextScale.defaults();
}

extension AppTextScaleBuildContextX on BuildContext {
  AppTextScale get appTextScale => Theme.of(this).appTextScale;
}

extension AppTextWeightsThemeDataX on ThemeData {
  AppTextWeights get appTextWeights =>
      extension<AppTextWeights>() ?? const AppTextWeights.defaults();
}

extension AppTextWeightsBuildContextX on BuildContext {
  AppTextWeights get appTextWeights => Theme.of(this).appTextWeights;
}

extension AppTextPaletteThemeDataX on ThemeData {
  AppTextPalette get appTextPalette =>
      extension<AppTextPalette>() ?? const AppTextPalette.defaults();
}

extension AppTextPaletteBuildContextX on BuildContext {
  AppTextPalette get appTextPalette => Theme.of(this).appTextPalette;
}
