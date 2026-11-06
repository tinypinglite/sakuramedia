import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_chrome_settings.dart';

/// 页面内和顶栏玻璃搜索框共用的 [GlassTextField.search] 外壳。
///
/// 调用方保留各自的尺寸、焦点和前后缀语义，只共享玻璃质感与字体配置。
Widget buildAppGlassSearchField({
  Key? key,
  required BuildContext context,
  required TextEditingController controller,
  required String placeholder,
  required double height,
  FocusNode? focusNode,
  Widget? prefixIcon,
  Widget? suffixIcon,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
}) {
  final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  final inheritedFontFamily = resolveAppFontFamily(context);
  final textStyle = resolveAppTextStyle(
    context,
    size: AppTextSize.s14,
    weight: AppTextWeight.regular,
    tone: AppTextTone.primary,
  ).copyWith(fontFamily: inheritedFontFamily);
  final placeholderStyle = resolveAppTextStyle(
    context,
    size: AppTextSize.s14,
    weight: AppTextWeight.regular,
    tone: AppTextTone.muted,
  ).copyWith(fontFamily: inheritedFontFamily);

  return GlassTextField.search(
    key: key,
    controller: controller,
    focusNode: focusNode,
    placeholder: placeholder,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    height: height,
    shape: LiquidRoundedRectangle(borderRadius: height / 2),
    padding: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
    iconSpacing: context.appSpacing.sm,
    textStyle: textStyle,
    placeholderStyle: placeholderStyle,
    settings: highContrast ? null : appGlassHeaderSettings(context),
    useOwnLayer: !highContrast,
    quality: highContrast ? null : GlassQuality.premium,
    surfaceStyle: highContrast
        ? GlassSurfaceStyle.solid
        : GlassSurfaceStyle.glass,
    color: highContrast ? context.appColors.surfaceMuted : null,
    interactionBehavior: highContrast || reduceMotion
        ? GlassInteractionBehavior.none
        : GlassInteractionBehavior.glowOnly,
  );
}
