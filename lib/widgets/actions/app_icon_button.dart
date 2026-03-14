import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

enum AppIconButtonSize { compact, regular }

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
    this.selectedBackgroundColor,
    this.borderColor,
    this.selectedBorderColor,
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
  final Color? selectedBackgroundColor;
  final Color? borderColor;
  final Color? selectedBorderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resolvedBorderRadius = borderRadius ?? context.appRadius.smBorder;
    final resolvedPadding = padding ?? EdgeInsets.all(context.appSpacing.xs);
    final resolvedBackgroundColor =
        isSelected
            ? selectedBackgroundColor ?? colors.surfaceCard
            : backgroundColor ?? Colors.transparent;
    final resolvedBorderColor =
        isSelected
            ? selectedBorderColor ?? colors.borderStrong
            : borderColor ?? Colors.transparent;
    final resolvedIconColor =
        isSelected
            ? selectedIconColor ?? iconColor ?? colors.textPrimary
            : iconColor ?? colors.textMuted;
    final buttonDimension = switch (size) {
      AppIconButtonSize.compact =>
        context.appComponentTokens.iconSizeMd + context.appSpacing.xs * 2,
      AppIconButtonSize.regular =>
        context.appComponentTokens.iconSizeMd + context.appSpacing.md * 2,
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
        child: InkWell(
          key: _buttonKey,
          onTap: onPressed,
          borderRadius: resolvedBorderRadius,
          child: SizedBox(
            width: buttonDimension,
            height: buttonDimension,
            child: Padding(
              padding: resolvedPadding,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    size: context.appComponentTokens.iconSizeMd,
                    color: resolvedIconColor,
                  ),
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
