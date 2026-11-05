import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';

/// 概览页透明顶栏使用的液态玻璃搜索框。
///
/// 使用库的 [GlassTextField.search] 而不是 [GlassSearchBar]，因为当前顶栏
/// 搜索框还承载「文字图搜 / 图片图搜」两个后缀动作，[GlassSearchBar] 没有
/// 任意 suffix 槽位。后缀按钮保持透明，避免在玻璃内部再叠一层玻璃。
class AppTopBarGlassSearchField extends StatelessWidget {
  const AppTopBarGlassSearchField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.onSubmitted,
    this.onImageSearchTap,
    this.onTextImageSearchTap,
    this.imageSearchButtonKey,
    this.textImageSearchButtonKey,
    this.showImageSearchButton = false,
    this.showTextImageSearchButton = false,
  });

  static const double height = 32;

  final Key? fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onImageSearchTap;
  final VoidCallback? onTextImageSearchTap;
  final Key? imageSearchButtonKey;
  final Key? textImageSearchButtonKey;
  final bool showImageSearchButton;
  final bool showTextImageSearchButton;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final l10n = AppLocalizations.of(context);
    final themeFontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final textStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      weight: AppTextWeight.regular,
      tone: AppTextTone.primary,
    ).copyWith(fontFamily: themeFontFamily);
    final placeholderStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    ).copyWith(fontFamily: themeFontFamily);
    final suffix = showImageSearchButton || showTextImageSearchButton
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showTextImageSearchButton)
                AppIconButton(
                  key: textImageSearchButtonKey,
                  tooltip: l10n.widgetSearchTextImageTooltip,
                  semanticLabel: l10n.widgetSearchTextImageTooltip,
                  iconColor: context.appTextPalette.secondary,
                  icon: const Icon(Icons.text_fields_rounded),
                  onPressed: onTextImageSearchTap,
                ),
              if (showImageSearchButton)
                AppIconButton(
                  key: imageSearchButtonKey,
                  tooltip: l10n.widgetSearchImageSearchTooltip,
                  semanticLabel: l10n.widgetSearchImageSearchTooltip,
                  iconColor: context.appTextPalette.secondary,
                  icon: const Icon(Icons.image_search_outlined),
                  onPressed: onImageSearchTap,
                ),
            ],
          )
        : null;

    return GlassTextField.search(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      placeholder: hintText,
      suffixIcon: suffix,
      onSubmitted: onSubmitted,
      height: height,
      shape: const LiquidRoundedRectangle(borderRadius: height / 2),
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
      iconSpacing: context.appSpacing.sm,
      textStyle: textStyle,
      placeholderStyle: placeholderStyle,
      settings: highContrast ? null : _glassSettings(context),
      useOwnLayer: !highContrast,
      quality: highContrast ? null : GlassQuality.standard,
      surfaceStyle: highContrast
          ? GlassSurfaceStyle.solid
          : GlassSurfaceStyle.glass,
      color: highContrast ? context.appColors.surfaceMuted : null,
      interactionBehavior: highContrast || reduceMotion
          ? GlassInteractionBehavior.none
          : GlassInteractionBehavior.glowOnly,
    );
  }

  LiquidGlassSettings _glassSettings(BuildContext context) {
    return LiquidGlassSettings(
      thickness: 18,
      blur: 8,
      saturation: 1.25,
      chromaticAberration: 0.01,
      lightIntensity: 0.5,
      glassColor: context.appColors.surfaceElevated.withValues(alpha: 0.22),
      shadowElevation: 0,
    );
  }
}
