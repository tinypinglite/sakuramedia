import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

enum AppIconButtonSize { mini, compact, inline, regular }

/// AppIconButton(compact) 的设计边长：iconSizeMd(20) + xs(4) × 2 = 28。
///
/// 布局计算需要常量时用（如侧栏收起按钮宽度、顶栏动作槽宽、封面悬停圆钮直径
/// ——它们按同一档视觉尺寸对齐）；运行时实际尺寸见 [AppIconButton] 内部的
/// `context.appComponentTokens` 求值，两者同源。
const double appCompactIconButtonSize = 28;

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    Key? key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.isSelected = false,
    this.size = AppIconButtonSize.compact,
    this.iconColor,
    this.selectedIconColor,
    this.semanticLabel,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
  }) : _buttonKey = key;

  final Widget icon;
  final Key? _buttonKey;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isSelected;
  final AppIconButtonSize size;
  final Color? iconColor;
  final Color? selectedIconColor;
  final String? semanticLabel;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resolvedBorderRadius = borderRadius ?? context.appRadius.smBorder;
    final resolvedPadding = padding ?? EdgeInsets.all(context.appSpacing.xs);
    final resolvedBackgroundColor = isSelected
        ? colors.surfaceCard
        : backgroundColor ?? Colors.transparent;
    final resolvedBorderColor = isSelected
        ? colors.borderStrong
        : borderColor ?? Colors.transparent;
    final resolvedIconColor = isSelected
        ? selectedIconColor ?? iconColor ?? context.appTextPalette.primary
        : iconColor ?? context.appTextPalette.muted;
    final (buttonDimension, iconSize) = switch (size) {
      AppIconButtonSize.mini => (
        context.appComponentTokens.iconSizeSm + context.appSpacing.xs * 2,
        context.appComponentTokens.iconSizeSm,
      ),
      AppIconButtonSize.compact => (
        context.appComponentTokens.iconSizeMd + context.appSpacing.xs * 2,
        context.appComponentTokens.iconSizeMd,
      ),
      AppIconButtonSize.inline => (
        context.appLayoutTokens.inlineActionButtonSize,
        context.appComponentTokens.iconSizeSm,
      ),
      AppIconButtonSize.regular => (
        context.appComponentTokens.iconSizeMd + context.appSpacing.md * 2,
        context.appComponentTokens.iconSizeMd,
      ),
    };

    Widget child = Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: resolvedBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: resolvedBorderRadius,
          side: BorderSide(color: resolvedBorderColor),
        ),
        child: AppInteractiveSurface(
          key: _buttonKey,
          enabled: onPressed != null,
          onTap: onPressed,
          child: SizedBox(
            width: buttonDimension,
            height: buttonDimension,
            child: Padding(
              padding: resolvedPadding,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(size: iconSize, color: resolvedIconColor),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      child = Tooltip(message: tooltip!, child: child);
    }

    return child;
  }
}
