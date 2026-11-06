import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 桌面顶栏和列表玻璃控制条共用的 iOS 27 玻璃参数。
///
/// 页面只负责组织按钮和弹层内容，不再各自复制 iOS 27 的 glass settings。
LiquidGlassSettings appGlassHeaderSettings(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? LiquidGlassSettings.ios27Dark
      : LiquidGlassSettings.ios27Light;
}

/// 右键 / 长按菜单的统一玻璃参数。
///
/// 比模态玻璃更轻，保留内容透出和 27 风格的 frost，但不把整块页面压暗。
LiquidGlassSettings appGlassContextMenuSettings(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return LiquidGlassSettings(
    glassColor:
        (isDark
                ? context.appColors.surfaceElevated
                : context.appColors.surfaceCard)
            .withValues(alpha: isDark ? 0.82 : 0.86),
    thickness: 16,
    blur: 22,
    saturation: 1.2,
    lightIntensity: isDark ? 0.28 : 0.35,
    shadowElevation: isDark ? 0 : 2,
  );
}

/// 玻璃筛选 / 排序弹层的统一参数。
///
/// 弹层保持轻量：关闭 backdrop blur 和 frost，只保留玻璃表面与描边，避免每次
/// 展开都为整块面板支付模糊成本。
LiquidGlassSettings appGlassPopoverSettings(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return appGlassHeaderSettings(context).copyWith(
    glassColor: isDark
        ? context.appColors.surfaceCard
        : context.appColors.surfaceMuted,
    blur: 0,
    frost: 0,
    frostOpacity: 0,
    bodyMode: GlassBodyMode.clear,
    shadowElevation: isDark ? 0 : 2,
  );
}
