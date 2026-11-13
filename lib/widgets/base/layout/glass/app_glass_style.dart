import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_flat_style.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_types.dart';

/// 液态玻璃的唯一材质入口。
///
/// 业务组件只选 [AppGlassRole]；这里负责把角色的 tint、厚度、模糊、
/// 饱和度、边缘光、内阴影和 quality 映射成 `liquid_glass_widgets` 参数。
abstract final class AppGlassStyle {
  static LiquidGlassSettings settingsFor(
    BuildContext context,
    AppGlassRole role, {
    Color? tintOverride,
  }) {
    final dark = GlassTheme.brightnessOf(context) == Brightness.dark;
    final base = dark
        ? LiquidGlassSettings.ios27Dark
        : LiquidGlassSettings.ios27Light;
    final recipe = recipeFor(context, role);

    return base.copyWith(
      glassColor: tintOverride ?? recipe.tint,
      thickness: recipe.thickness,
      blur: recipe.blur,
      saturation: recipe.saturation,
      lightIntensity: recipe.lightIntensity,
      chromaticAberration: recipe.quality == GlassQuality.standard ? 0.008 : 0,
      shadowElevation: 0,
      shadow: recipe.shadow ?? const <BoxShadow>[],
      frost: recipe.frost,
      frostOpacity: recipe.frostOpacity,
      frostClamp: recipe.frostClamp,
      frostWeight: recipe.frostWeight,
      rimShade: recipe.rimShade,
      rimLight: recipe.rimLight,
      bodyShade: recipe.bodyShade,
      whitenStrength: recipe.whitenStrength,
      edgeAbsorption: recipe.edgeAbsorption,
      backerColor: recipe.backerColor,
      bodyMode: recipe.clearBody ? GlassBodyMode.clear : GlassBodyMode.adaptive,
    );
  }

  static GlassQuality qualityFor(AppGlassRole role) {
    return switch (role) {
      AppGlassRole.surface => GlassQuality.standard,
      AppGlassRole.popover => GlassQuality.premium,
      AppGlassRole.control => GlassQuality.standard,
      AppGlassRole.toolbarControl => GlassQuality.premium,
      AppGlassRole.input => GlassQuality.standard,
      AppGlassRole.toolbarInput => GlassQuality.premium,
      AppGlassRole.bar => GlassQuality.premium,
      AppGlassRole.overlay => GlassQuality.premium,
      AppGlassRole.mediaOverlay => GlassQuality.standard,
    };
  }

  static AppFlatSurfaceRole flatRoleFor(AppGlassRole role) {
    return switch (role) {
      AppGlassRole.surface => AppFlatSurfaceRole.surface,
      AppGlassRole.popover => AppFlatSurfaceRole.popover,
      AppGlassRole.control => AppFlatSurfaceRole.buttonFilled,
      AppGlassRole.toolbarControl => AppFlatSurfaceRole.toolbarControl,
      AppGlassRole.input => AppFlatSurfaceRole.input,
      AppGlassRole.toolbarInput => AppFlatSurfaceRole.toolbarInput,
      AppGlassRole.bar => AppFlatSurfaceRole.bar,
      AppGlassRole.overlay => AppFlatSurfaceRole.overlay,
      AppGlassRole.mediaOverlay => AppFlatSurfaceRole.mediaOverlay,
    };
  }

  static AppGlassRecipe recipeFor(BuildContext context, AppGlassRole role) {
    final dark = GlassTheme.brightnessOf(context) == Brightness.dark;
    final colors = context.appColors;
    final noShadow = const <BoxShadow>[];
    final floatingShadow = context.appShadows.panel;
    final whiteTint = colors.highlight;

    return switch (role) {
      AppGlassRole.surface => AppGlassRecipe(
        tint: dark
            ? whiteTint.withValues(alpha: 0.10)
            : colors.surfaceElevated.withValues(alpha: 0.48),
        thickness: 20,
        blur: 6,
        saturation: 1.45,
        lightIntensity: 0.42,
        rimShade: 0.85,
        rimLight: 0.85,
        bodyShade: dark ? 0.08 : 0,
        whitenStrength: dark ? 0 : 0.08,
        shadow: noShadow,
        quality: GlassQuality.standard,
      ),
      AppGlassRole.popover => AppGlassRecipe(
        tint: colors.surfaceElevated.withValues(alpha: dark ? 0.76 : 0.88),
        thickness: 24,
        blur: 2.5,
        saturation: 1.55,
        lightIntensity: 0.20,
        frost: 14,
        frostOpacity: dark ? 0.92 : 0.88,
        frostClamp: dark ? -0.45 : 0.4,
        frostWeight: dark ? 0.5 : 2.0,
        rimShade: 1,
        rimLight: 1,
        bodyShade: dark ? 0.22 : 0,
        whitenStrength: dark ? 0 : 0.10,
        shadow: floatingShadow,
        quality: GlassQuality.premium,
      ),
      AppGlassRole.control => AppGlassRecipe(
        tint: dark
            ? whiteTint.withValues(alpha: 0.09)
            : colors.surfaceElevated.withValues(alpha: 0.56),
        thickness: 16,
        blur: 5,
        saturation: 1.55,
        lightIntensity: 0.48,
        rimShade: 0.85,
        rimLight: 0.95,
        bodyShade: dark ? 0.06 : 0,
        whitenStrength: dark ? 0 : 0.10,
        shadow: noShadow,
        quality: GlassQuality.standard,
      ),
      AppGlassRole.toolbarControl => AppGlassRecipe(
        tint: dark
            ? whiteTint.withValues(alpha: 0.08)
            : colors.surfaceElevated.withValues(alpha: 0.52),
        thickness: 14,
        blur: 0.6,
        saturation: 1.50,
        lightIntensity: 0.20,
        frost: 10,
        frostOpacity: dark ? 0.82 : 0.70,
        frostClamp: dark ? -0.40 : 0.35,
        frostWeight: dark ? 0.55 : 1.8,
        rimShade: 0.8,
        rimLight: 0.9,
        bodyShade: dark ? 0.05 : 0,
        whitenStrength: dark ? 0 : 0.10,
        shadow: noShadow,
        quality: GlassQuality.premium,
      ),
      AppGlassRole.input => AppGlassRecipe(
        // 输入框不染色：体色直接取背后的玻璃面，只靠 1px 边光和边缘吸收
        // 区分，避免在浅色卡片上再叠出一块更白的底。
        tint: Colors.transparent,
        thickness: 18,
        blur: 8,
        saturation: 1.45,
        lightIntensity: 0.40,
        frost: 0,
        frostOpacity: 0,
        frostClamp: 0,
        frostWeight: 1,
        rimShade: 0.9,
        rimLight: 0.9,
        bodyShade: dark ? 0.10 : 0,
        whitenStrength: 0,
        shadow: noShadow,
        quality: GlassQuality.standard,
      ),
      AppGlassRole.toolbarInput => AppGlassRecipe(
        tint: dark
            ? whiteTint.withValues(alpha: 0.08)
            : colors.surfaceElevated.withValues(alpha: 0.50),
        thickness: 16,
        blur: 0.6,
        saturation: 1.55,
        lightIntensity: 0.30,
        frost: 12,
        frostOpacity: dark ? 0.82 : 0.76,
        frostClamp: dark ? -0.40 : 0.35,
        frostWeight: dark ? 0.55 : 1.8,
        rimShade: 0.9,
        rimLight: 0.95,
        bodyShade: dark ? 0.14 : 0,
        whitenStrength: dark ? 0 : 0.10,
        shadow: noShadow,
        quality: GlassQuality.premium,
      ),
      AppGlassRole.bar => AppGlassRecipe(
        tint: dark
            ? whiteTint.withValues(alpha: 0.12)
            : colors.surfaceElevated.withValues(alpha: 0.58),
        thickness: 24,
        blur: 0.6,
        saturation: 1.55,
        lightIntensity: 0.20,
        frost: 12,
        frostOpacity: dark ? 0.85 : 0.73,
        frostClamp: dark ? -0.45 : 0.4,
        frostWeight: dark ? 0.5 : 2.0,
        rimShade: 1,
        rimLight: 1,
        bodyShade: dark ? 0.12 : 0,
        whitenStrength: dark ? 0 : 0.08,
        shadow: floatingShadow,
        quality: GlassQuality.premium,
      ),
      AppGlassRole.overlay => AppGlassRecipe(
        tint: dark
            ? whiteTint.withValues(alpha: 0.16)
            : colors.surfaceElevated.withValues(alpha: 0.72),
        thickness: 20,
        blur: 0.6,
        saturation: 1.50,
        lightIntensity: 0.20,
        frost: 14,
        frostOpacity: dark ? 0.85 : 0.73,
        frostClamp: dark ? -0.45 : 0.4,
        frostWeight: dark ? 0.5 : 2.0,
        rimShade: 1,
        rimLight: 1,
        bodyShade: dark ? 0.16 : 0,
        whitenStrength: dark ? 0 : 0.05,
        shadow: floatingShadow,
        quality: GlassQuality.premium,
      ),
      AppGlassRole.mediaOverlay => AppGlassRecipe(
        tint: colors.mediaOverlayStrong.withValues(alpha: 0),
        backerColor: colors.mediaOverlayStrong.withValues(
          alpha: dark ? 0.55 : 0.48,
        ),
        thickness: 12,
        blur: 8,
        saturation: 1.20,
        lightIntensity: 0.25,
        rimShade: 0.4,
        rimLight: 0.9,
        bodyShade: 0.20,
        whitenStrength: 0,
        shadow: noShadow,
        quality: GlassQuality.standard,
        clearBody: true,
      ),
    };
  }

  static AppGlassFallbackRecipe fallbackRecipe(
    BuildContext context,
    AppGlassRole role,
  ) {
    final dark = GlassTheme.brightnessOf(context) == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final lightTint = dark
        ? Color.lerp(scheme.primary, AppColors.glassFallbackTintDark, 0.35)!
        : context.appColors.surfaceElevated;
    final (
      tint,
      tintAlpha,
      blurSigma,
      topRim,
      sideRim,
      bottomRim,
    ) = switch (role) {
      AppGlassRole.surface => (
        lightTint,
        dark ? 0.38 : 0.30,
        dark ? 4.0 : 5.0,
        0.35,
        0.12,
        0.06,
      ),
      AppGlassRole.popover => (
        lightTint,
        dark ? 0.72 : 0.78,
        dark ? 6.0 : 8.0,
        0.45,
        0.16,
        0.10,
      ),
      AppGlassRole.control => (
        lightTint,
        dark ? 0.34 : 0.28,
        dark ? 4.0 : 5.0,
        0.38,
        0.14,
        0.07,
      ),
      AppGlassRole.toolbarControl => (
        lightTint,
        dark ? 0.28 : 0.22,
        dark ? 4.0 : 5.0,
        0.32,
        0.12,
        0.06,
      ),
      AppGlassRole.input => (
        // 与玻璃路径一致：输入框降级时也不染色，只留边光和高光。
        Colors.transparent,
        0.0,
        dark ? 5.0 : 7.0,
        0.40,
        0.14,
        0.08,
      ),
      AppGlassRole.toolbarInput => (
        lightTint,
        dark ? 0.28 : 0.22,
        dark ? 4.0 : 6.0,
        0.34,
        0.12,
        0.07,
      ),
      AppGlassRole.bar => (
        lightTint,
        dark ? 0.44 : 0.38,
        dark ? 6.0 : 8.0,
        0.45,
        0.16,
        0.10,
      ),
      AppGlassRole.overlay => (
        lightTint,
        dark ? 0.50 : 0.44,
        dark ? 6.0 : 8.0,
        0.48,
        0.18,
        0.10,
      ),
      AppGlassRole.mediaOverlay => (
        context.appColors.mediaOverlayStrong,
        dark ? 0.55 : 0.48,
        8.0,
        0.55,
        0.18,
        0.10,
      ),
    };
    final floating =
        role == AppGlassRole.popover ||
        role == AppGlassRole.bar ||
        role == AppGlassRole.overlay;
    return AppGlassFallbackRecipe(
      tint: tint,
      tintAlpha: tintAlpha,
      blurSigma: blurSigma,
      saturation: role == AppGlassRole.mediaOverlay ? 1.1 : 1.2,
      topRimAlpha: topRim,
      sideRimAlpha: sideRim,
      lowRimAlpha: topRim * 0.12,
      bottomRimAlpha: bottomRim,
      topSheenAlpha: role == AppGlassRole.mediaOverlay ? 0.10 : 0.08,
      topSheenHeight: floating ? 16 : 14,
      innerBottomShadowAlpha: role == AppGlassRole.mediaOverlay ? 0.20 : 0.10,
      shadow: floating ? context.appShadows.panel : null,
    );
  }
}

/// 一个液态玻璃角色的完整材质参数。
class AppGlassRecipe {
  const AppGlassRecipe({
    required this.tint,
    required this.thickness,
    required this.blur,
    required this.saturation,
    required this.lightIntensity,
    required this.rimShade,
    required this.rimLight,
    required this.bodyShade,
    required this.shadow,
    required this.quality,
    this.frost = 0,
    this.frostOpacity = 1,
    this.frostClamp = 0,
    this.frostWeight = 1,
    this.whitenStrength = 0,
    this.edgeAbsorption = 0.035,
    this.clearBody = false,
    this.backerColor,
  });

  final Color tint;
  final Color? backerColor;
  final double thickness;
  final double blur;
  final double saturation;
  final double lightIntensity;
  final double frost;
  final double frostOpacity;
  final double frostClamp;
  final double frostWeight;
  final double whitenStrength;
  final double rimShade;
  final double rimLight;
  final double bodyShade;
  final double edgeAbsorption;
  final bool clearBody;
  final List<BoxShadow>? shadow;
  final GlassQuality quality;
}

/// shader 不可用、关闭模糊或无法映射圆角时使用的本地光感配方。
class AppGlassFallbackRecipe {
  const AppGlassFallbackRecipe({
    required this.tint,
    required this.tintAlpha,
    required this.blurSigma,
    required this.saturation,
    required this.topRimAlpha,
    required this.sideRimAlpha,
    required this.lowRimAlpha,
    required this.bottomRimAlpha,
    required this.topSheenAlpha,
    required this.topSheenHeight,
    required this.innerBottomShadowAlpha,
    this.shadow,
  });

  final Color tint;
  final double tintAlpha;
  final double blurSigma;
  final double saturation;
  final double topRimAlpha;
  final double sideRimAlpha;
  final double lowRimAlpha;
  final double bottomRimAlpha;
  final double topSheenAlpha;
  final double topSheenHeight;
  final double innerBottomShadowAlpha;
  final List<BoxShadow>? shadow;
}
