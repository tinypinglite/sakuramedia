import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sakuramedia/theme.dart';

const _testThemeColor = AppThemeColor(
  id: 'test-accent',
  light: AppBrandColors(
    primary: Color(0xFF126B3A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD8E8D3),
    onPrimaryContainer: Color(0xFF0F2F14),
    secondary: Color(0xFF5E8B57),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE6F2E1),
    onSecondaryContainer: Color(0xFF202B1E),
    tertiary: Color(0xFF4C6C58),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD6E8DD),
    onTertiaryContainer: Color(0xFF17251C),
    surfaceTint: Color(0xFF126B3A),
    inversePrimary: Color(0xFFA9D6B4),
    selectionSurface: Color(0xFFECF7EC),
    selectionBorder: Color(0xFF126B3A),
    selectedPlotBorder: Color(0xFF126B3A),
    accent: Color(0xFF126B3A),
  ),
  dark: AppBrandColors(
    primary: Color(0xFF9BD4A8),
    onPrimary: Color(0xFF10391A),
    primaryContainer: Color(0xFF2A5C33),
    onPrimaryContainer: Color(0xFFD5F0DA),
    secondary: Color(0xFFB3D1AF),
    onSecondary: Color(0xFF253825),
    secondaryContainer: Color(0xFF3A5540),
    onSecondaryContainer: Color(0xFFD5EEDC),
    tertiary: Color(0xFFBED8C4),
    onTertiary: Color(0xFF22371F),
    tertiaryContainer: Color(0xFF435943),
    onTertiaryContainer: Color(0xFFE0F0E3),
    surfaceTint: Color(0xFF9BD4A8),
    inversePrimary: Color(0xFF3F7A4C),
    selectionSurface: Color(0xFF223A26),
    selectionBorder: Color(0xFF9BD4A8),
    selectedPlotBorder: Color(0xFF9BD4A8),
    accent: Color(0xFF9BD4A8),
  ),
);

void main() {
  test('light theme keeps the current palette bit-for-bit', () {
    final theme = buildSakuraDesktopThemeData();
    final colors = theme.appColors;
    final textPalette = theme.appTextPalette;

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, const Color(0xFF6B2D2A));
    expect(colors.surfacePage, const Color(0xFFF5F5F5));
    expect(colors.surfaceCard, const Color(0xFFFFFFFF));
    expect(colors.selectionSurface, const Color(0xFFF7ECEB));
    expect(colors.selectionBorder, const Color(0xFF6B2D2A));
    expect(textPalette.primary, const Color(0xFF1F1A18));
    expect(textPalette.accent, const Color(0xFF6B2D2A));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F5F5));
  });

  test('dark theme exposes the dark neutral spec and brand anchors', () {
    final theme = buildSakuraDesktopThemeData(brightness: Brightness.dark);
    final colors = theme.appColors;
    final textPalette = theme.appTextPalette;
    final shadows = theme.appShadows;

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF121212));
    expect(colors.surfacePage, const Color(0xFF121212));
    expect(colors.surfaceCard, const Color(0xFF1E1E1E));
    expect(colors.surfaceElevated, const Color(0xFF262626));
    expect(colors.sidebarBackground, const Color(0xFF1A1A1A));
    expect(colors.selectionSurface, const Color(0xFF3A2422));
    expect(colors.selectionBorder, const Color(0xFFE9A29B));
    expect(colors.movieDetailSelectedPlotBorder, const Color(0xFFE9A29B));
    expect(colors.desktopSidebarGlassTint, const Color(0x4D181315));
    expect(colors.windowsSidebarGlassTint, const Color(0xEB1E1E1E));
    expect(textPalette.primary, const Color(0xFFECE6E4));
    expect(textPalette.accent, const Color(0xFFE9A29B));
    expect(theme.colorScheme.primary, const Color(0xFFE9A29B));
    expect(theme.colorScheme.onPrimary, const Color(0xFF4A1310));
    expect(theme.colorScheme.surface, const Color(0xFF1E1E1E));
    expect(theme.colorScheme.onSurface, const Color(0xFFECE6E4));
    expect(shadows.color, const Color(0x40000000));
    // 媒体域在设计上不随明暗切换。
    expect(colors.mediaMaskOverlay, const Color(0xE6000000));
    expect(colors.movieDetailHeroBackgroundStart, const Color(0xFF000000));
  });

  test('mobile dark theme keeps mobile sizes and dark colors', () {
    final theme = buildSakuraMobileThemeData(brightness: Brightness.dark);

    expect(theme.appComponentTokens.mobileBottomNavHeight, 56);
    expect(theme.appColors.surfacePage, const Color(0xFF121212));
    expect(theme.appTextScale.s16, sakuraMobileThemeData.appTextScale.s16);
  });

  test('a different theme color only needs brand anchors to switch', () {
    final light = buildSakuraDesktopThemeData(themeColor: _testThemeColor);
    final dark = buildSakuraDesktopThemeData(
      themeColor: _testThemeColor,
      brightness: Brightness.dark,
    );

    expect(light.colorScheme.primary, const Color(0xFF126B3A));
    expect(light.appColors.selectionSurface, const Color(0xFFECF7EC));
    expect(light.appColors.selectionBorder, const Color(0xFF126B3A));
    expect(
      light.appColors.movieDetailSelectedPlotBorder,
      const Color(0xFF126B3A),
    );
    expect(light.appTextPalette.accent, const Color(0xFF126B3A));
    expect(light.appColors.surfacePage, const Color(0xFFF5F5F5));

    expect(dark.colorScheme.primary, const Color(0xFF9BD4A8));
    expect(dark.appColors.selectionSurface, const Color(0xFF223A26));
    expect(dark.appColors.surfacePage, const Color(0xFF121212));
  });

  test('every theme color keeps key contrast pairs in both modes', () {
    for (final themeColor in AppThemeColor.values) {
      for (final brightness in Brightness.values) {
        final theme = buildSakuraDesktopThemeData(
          themeColor: themeColor,
          brightness: brightness,
        );
        final colors = theme.appColors;
        final textPalette = theme.appTextPalette;
        final scheme = theme.colorScheme;
        final label = '${themeColor.id}/${brightness.name}';

        expect(
          _contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: '$label onPrimary / primary',
        );
        expect(
          _contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$label onPrimaryContainer / primaryContainer',
        );
        expect(
          _contrast(scheme.onSecondary, scheme.secondary),
          greaterThanOrEqualTo(4.5),
          reason: '$label onSecondary / secondary',
        );
        expect(
          _contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$label onSecondaryContainer / secondaryContainer',
        );
        expect(
          _contrast(scheme.onTertiary, scheme.tertiary),
          greaterThanOrEqualTo(4.5),
          reason: '$label onTertiary / tertiary',
        );
        expect(
          _contrast(scheme.onTertiaryContainer, scheme.tertiaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$label onTertiaryContainer / tertiaryContainer',
        );
        expect(
          _contrast(textPalette.accent, colors.surfacePage),
          greaterThanOrEqualTo(4.5),
          reason: '$label 主题强调色 / 页面底',
        );
        expect(
          _contrast(textPalette.accent, colors.surfaceCard),
          greaterThanOrEqualTo(4.5),
          reason: '$label 主题强调色 / 卡片',
        );
      }
    }
  });

  test('key text and brand pairs meet contrast targets in both modes', () {
    for (final brightness in Brightness.values) {
      final theme = buildSakuraDesktopThemeData(brightness: brightness);
      final colors = theme.appColors;
      final textPalette = theme.appTextPalette;
      final scheme = theme.colorScheme;
      final label = brightness == Brightness.dark ? 'dark' : 'light';

      expect(
        _contrast(textPalette.primary, colors.surfacePage),
        greaterThanOrEqualTo(7),
        reason: '$label 主文字 / 页面底',
      );
      expect(
        _contrast(textPalette.primary, colors.surfaceCard),
        greaterThanOrEqualTo(7),
        reason: '$label 主文字 / 卡片',
      );
      expect(
        _contrast(textPalette.secondary, colors.surfaceCard),
        greaterThanOrEqualTo(4.5),
        reason: '$label 次文字 / 卡片',
      );
      expect(
        _contrast(textPalette.accent, colors.surfacePage),
        greaterThanOrEqualTo(4.5),
        reason: '$label 主题强调色 / 页面底',
      );
      expect(
        _contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
        reason: '$label onPrimary / primary',
      );
      expect(
        _contrast(textPalette.error, colors.errorSurface),
        greaterThanOrEqualTo(4.5),
        reason: '$label 错误文字 / 错误浅底',
      );
    }
  });
}

double _contrast(Color foreground, Color background) {
  final a = _relativeLuminance(Color.alphaBlend(foreground, background));
  final b = _relativeLuminance(background);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}
