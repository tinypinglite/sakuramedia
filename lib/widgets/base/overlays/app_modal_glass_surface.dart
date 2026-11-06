import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';

enum AppModalGlassStrength {
  strong(0.65),
  solid(0.90);

  const AppModalGlassStrength(this.amount);

  final double amount;
}

/// 全局默认强度；单独弹层可通过 `glassStrength` 覆盖。
const kAppModalGlassStrength = AppModalGlassStrength.strong;

LiquidGlassSettings appModalGlassSettings(
  BuildContext context, {
  AppModalGlassStrength strength = kAppModalGlassStrength,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final base = isDark
      ? LiquidGlassSettings.ios27Dark
      : LiquidGlassSettings.ios27Light;
  final targetTint =
      (isDark
              ? context.appColors.surfaceElevated
              : context.appColors.surfaceCard)
          .withValues(alpha: 0.86);
  final amount = strength.amount;
  return base.copyWith(
    glassColor: Color.lerp(base.glassColor, targetTint, amount)!,
    frost: base.frost + 6 * amount,
    frostOpacity: (base.frostOpacity + 0.12 * amount).clamp(0.0, 1.0),
    saturation: isDark ? 1.4 + 0.4 * amount : 2.1 + 0.2 * amount,
    whitenStrength: isDark ? 0 : 0.05 * amount,
    bodyMode: GlassBodyMode.clear,
  );
}

/// 对话框和底部抽屉共用的模态玻璃。
///
/// 直接使用库里为 iOS 27 `glassEffect(.regular)` 调校的 premium 材质。
/// 不叠加自绘洗色、高光或描边，避免把液态玻璃降级成半透明色块。
class AppModalGlassSurface extends StatelessWidget {
  const AppModalGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.strength = kAppModalGlassStrength,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final AppModalGlassStrength strength;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? context.appRadius.xlBorder;

    return AppGlassSurface(
      tone: AppGlassTone.modal,
      borderRadius: radius,
      glassSettings: appModalGlassSettings(context, strength: strength),
      child: child,
    );
  }
}
