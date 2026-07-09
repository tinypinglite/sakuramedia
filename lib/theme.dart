import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:sakuramedia/theme/app_typography.dart';

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
export 'package:sakuramedia/theme/app_typography.dart';
export 'package:sakuramedia/widgets/base/typography/app_text.dart';

/// 应用内嵌字体族名,与 pubspec.yaml 的 fonts.family 一致。
/// Web(CanvasKit) 必须把它设为主 fontFamily,否则中日文首屏会因联网下载
/// Noto fallback 而出现方块字。子集字体由 tool/subset_font.py 生成。
const kAppFontFamily = 'NotoSansSC';

/// oktoast 在 MaterialApp 之外用独立 overlay 树显示 toast, 拿不到 ThemeData
/// 里的 fontFamily/fontVariations。Web 端 NotoSansSC 是可变字体, wght 轴不显式
/// 设就停在 Thin 100(发丝细几乎看不见); 桌面/移动用系统字体不受影响。
const TextStyle kAppToastTextStyle =
    kIsWeb
        ? TextStyle(
          fontSize: 15,
          color: Colors.white,
          fontFamily: kAppFontFamily,
          fontVariations: [FontVariation('wght', 400)],
        )
        : TextStyle(fontSize: 15, color: Colors.white);

final sakuraThemeData = sakuraDesktopThemeData;

const _desktopTextScale = AppTextScale.defaults();
const _desktopTextWeights = AppTextWeights.defaults();
const _desktopTextPalette = AppTextPalette.defaults();
const _mobileTextScale = AppTextScale.mobile();
const _mobileTextWeights = AppTextWeights.mobile();
const _mobileTextPalette = AppTextPalette.mobile();

final sakuraDesktopThemeData = _buildSakuraThemeData(
  componentTokens: const AppComponentTokens.defaults(),
  formTokens: const AppFormTokens.defaults(),
  navigationTokens: const AppNavigationTokens.defaults(),
  textScale: _desktopTextScale,
  textWeights: _desktopTextWeights,
  textPalette: _desktopTextPalette,
);

final sakuraMobileThemeData = _buildSakuraThemeData(
  componentTokens: const AppComponentTokens.mobile(),
  formTokens: const AppFormTokens.mobile(),
  navigationTokens: const AppNavigationTokens.mobile(),
  textScale: _mobileTextScale,
  textWeights: _mobileTextWeights,
  textPalette: _mobileTextPalette,
);

ThemeData _buildSakuraThemeData({
  required AppComponentTokens componentTokens,
  required AppFormTokens formTokens,
  required AppNavigationTokens navigationTokens,
  required AppTextScale textScale,
  required AppTextWeights textWeights,
  required AppTextPalette textPalette,
}) {
  return ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    // 仅 Web 用内嵌字体消除方块字;桌面/移动(mac/Win/iOS/Android)用系统原生字体。
    fontFamily: kIsWeb ? kAppFontFamily : null,
  ).copyWith(
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
    textTheme: kIsWeb
        ? textScale.toTextTheme(textWeights).apply(fontFamily: kAppFontFamily)
        : textScale.toTextTheme(textWeights),
    extensions: <ThemeExtension<dynamic>>[
      const AppColors.defaults(),
      componentTokens,
      formTokens,
      const AppLayoutTokens.defaults(),
      navigationTokens,
      const AppOverlayTokens.defaults(),
      const AppSpacing.defaults(),
      const AppRadius.defaults(),
      const AppSidebarTokens.defaults(),
      const AppShadows.defaults(),
      textScale,
      textWeights,
      textPalette,
    ],
  );
}
