import 'package:flutter/material.dart';
import 'package:sakuramedia/theme/app_component_tokens.dart';
import 'package:sakuramedia/theme/app_colors.dart';
import 'package:sakuramedia/theme/app_form_tokens.dart';
import 'package:sakuramedia/theme/app_layout_tokens.dart';
import 'package:sakuramedia/theme/app_navigation_tokens.dart';
import 'package:sakuramedia/theme/app_overlay_tokens.dart';
import 'package:sakuramedia/theme/app_radius.dart';
import 'package:sakuramedia/theme/app_shadows.dart';
import 'package:sakuramedia/theme/app_sidebar_tokens.dart';
import 'package:sakuramedia/theme/app_spacing.dart';

export 'package:sakuramedia/theme/app_component_tokens.dart';
export 'package:sakuramedia/theme/app_colors.dart';
export 'package:sakuramedia/theme/app_form_tokens.dart';
export 'package:sakuramedia/theme/app_layout_tokens.dart';
export 'package:sakuramedia/theme/app_navigation_tokens.dart';
export 'package:sakuramedia/theme/app_overlay_tokens.dart';
export 'package:sakuramedia/theme/app_page_insets.dart';
export 'package:sakuramedia/theme/app_radius.dart';
export 'package:sakuramedia/theme/app_shadows.dart';
export 'package:sakuramedia/theme/app_sidebar_tokens.dart';
export 'package:sakuramedia/theme/app_spacing.dart';

final sakuraThemeData = ThemeData.light(useMaterial3: true).copyWith(
  scaffoldBackgroundColor: const Color(0xFFF5F5F5),
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF6B2D2A),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF8B5E57),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1F1A18),
    primaryContainer: Color(0xFFE8D8D3),
    onPrimaryContainer: Color(0xFF2F1412),
    secondaryContainer: Color(0xFFF2E6E1),
    onSecondaryContainer: Color(0xFF2B201E),
    tertiary: Color(0xFF6C584C),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE8DDD6),
    onTertiaryContainer: Color(0xFF251C17),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surfaceTint: Color(0xFF6B2D2A),
    onSurfaceVariant: Color(0xFF707070),
    outline: Color(0xFFD6D6D6),
    outlineVariant: Color(0xFFE8E8E8),
    shadow: Color(0x1A2B1816),
    scrim: Color(0x66000000),
    inverseSurface: Color(0xFF362F2C),
    onInverseSurface: Color(0xFFF8EEEA),
    inversePrimary: Color(0xFFFFB4A9),
  ),
  textTheme: const TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1F1A18),
      letterSpacing: -0.6,
    ),
    titleLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1F1A18),
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1F1A18),
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1F1A18),
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF342D2A)),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF4D4440)),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF6B625E)),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1F1A18),
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w300,
      color: Color(0xFF4D4440),
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w100,
      color: Color(0xFF6B625E),
    ),
  ),
  extensions: const <ThemeExtension<dynamic>>[
    AppColors.defaults(),
    AppComponentTokens.defaults(),
    AppFormTokens.defaults(),
    AppLayoutTokens.defaults(),
    AppNavigationTokens.defaults(),
    AppOverlayTokens.defaults(),
    AppSpacing.defaults(),
    AppRadius.defaults(),
    AppSidebarTokens.defaults(),
    AppShadows.defaults(),
  ],
);
