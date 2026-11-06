import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 全局固定的玻璃配置。
///
/// 全站只有一套材质：premium shader 档 + 最淡的 `track` 配方。
abstract final class AppGlassStyle {
  static const GlassQuality quality = GlassQuality.premium;

  static LiquidGlassSettings settings(BuildContext context) {
    return LiquidGlassSettings(
      thickness: 12,
      blur: 10,
      saturation: 2,
      chromaticAberration: 0,
      lightIntensity: 0.35,
      glassColor: context.appColors.surfaceMuted.withValues(alpha: 0.6),
      shadowElevation: 0,
    );
  }

  static AppGlassFallbackRecipe fallbackRecipe(BuildContext context) {
    return AppGlassFallbackRecipe(
      tint: context.appColors.surfaceMuted,
      tintAlpha: 0.10,
      blurSigma: 10,
      saturation: 1.0,
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
