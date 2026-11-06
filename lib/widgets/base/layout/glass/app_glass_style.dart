import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 液态玻璃材质配置。
///
/// 正常路径不覆盖 [LiquidGlassSettings] / [GlassQuality]，完全使用
/// `liquid_glass_widgets` 内置的 light/dark 默认材质与各控件默认质量档位。
/// 这里只保留共享玻璃面的染色、本地 fallback 配方，以及需要替换
/// `glassColor` 的文本输入材质。
abstract final class AppGlassStyle {
  /// 以包当前明暗默认材质为基底，只覆盖玻璃染色。
  static LiquidGlassSettings settingsWithColor(
    BuildContext context,
    Color color,
  ) {
    final override = GlassThemeData.of(context).settingsFor(context);
    final base = (override ?? const GlassThemeSettings()).applyTo(
      const LiquidGlassSettings(),
    );
    return base.copyWith(glassColor: color);
  }

  /// 共享玻璃面的默认染色；只覆盖 `glassColor`，其余仍走包默认。
  static LiquidGlassSettings surfaceSettings(BuildContext context) {
    final dark = GlassTheme.brightnessOf(context) == Brightness.dark;
    final tint =
        (dark
                ? context.appColors.surfaceElevated
                : context.appColors.surfaceCard)
            .withValues(alpha: dark ? 0.38 : 0.30);
    return settingsWithColor(context, tint);
  }

  static AppGlassFallbackRecipe fallbackRecipe(BuildContext context) {
    final dark = GlassTheme.brightnessOf(context) == Brightness.dark;
    return AppGlassFallbackRecipe(
      tint: dark
          ? AppColors.glassFallbackTintDark
          : AppColors.glassFallbackTintLight,
      tintAlpha: dark ? 0.38 : 0.30,
      blurSigma: dark ? 4 : 5,
      saturation: 1.2,
      topRimAlpha: 0.35,
      sideRimAlpha: 0.12,
      lowRimAlpha: 0.04,
      bottomRimAlpha: 0.06,
      topSheenAlpha: 0.08,
      topSheenHeight: 14,
      innerBottomShadowAlpha: 0.10,
    );
  }
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
