import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { medium, small, xSmall }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.labelKey,
    this.variant = AppButtonVariant.secondary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isSelected = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? trailingIcon;
  final Key? labelKey;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isSelected;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final componentTokens = context.appComponentTokens;
    final (height, horizontal, gap, iconSize, textStyle) = switch (size) {
      AppButtonSize.medium => (
        36.0,
        14.0,
        8.0,
        componentTokens.iconSizeSm,
        theme.textTheme.labelMedium,
      ),
      AppButtonSize.small => (
        32.0,
        10.0,
        6.0,
        componentTokens.iconSizeSm,
        theme.textTheme.labelMedium,
      ),
      AppButtonSize.xSmall => (
        28.0,
        8.0,
        4.0,
        componentTokens.iconSizeXs,
        theme.textTheme.labelSmall,
      ),
    };
    final borderRadius = context.appRadius.smBorder;
    final isSecondarySelected =
        variant == AppButtonVariant.secondary && isSelected;
    final isGhostSelected = variant == AppButtonVariant.ghost && isSelected;

    final foregroundColor = switch (variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.secondary =>
        isSecondarySelected ? theme.colorScheme.primary : colors.textPrimary,
      AppButtonVariant.ghost => theme.colorScheme.primary,
      AppButtonVariant.danger => const Color(0xFFB42318),
    };

    final backgroundColor = switch (variant) {
      AppButtonVariant.primary => theme.colorScheme.primary,
      AppButtonVariant.secondary =>
        isSecondarySelected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : colors.surfaceCard,
      AppButtonVariant.ghost =>
        isGhostSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
      AppButtonVariant.danger => const Color(0xFFFEECEB),
    };

    final borderColor = switch (variant) {
      AppButtonVariant.primary => theme.colorScheme.primary,
      AppButtonVariant.secondary =>
        isSecondarySelected ? theme.colorScheme.primary : colors.borderStrong,
      AppButtonVariant.ghost =>
        isGhostSelected ? theme.colorScheme.primary : Colors.transparent,
      AppButtonVariant.danger => const Color(0xFFF6C7C4),
    };

    final disabledColor = colors.borderSubtle;

    return MouseRegion(
      cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Opacity(
        opacity: _isEnabled ? 1 : 0.56,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: _isEnabled ? onPressed : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: height,
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              decoration: BoxDecoration(
                color: _isEnabled ? backgroundColor : disabledColor,
                borderRadius: borderRadius,
                border: Border.all(
                  color: _isEnabled ? borderColor : disabledColor,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          foregroundColor,
                        ),
                      ),
                    )
                  else if (icon != null)
                    IconTheme(
                      data: IconThemeData(
                        size: iconSize,
                        color: foregroundColor,
                      ),
                      child: icon!,
                    ),
                  if (isLoading || icon != null) SizedBox(width: gap),
                  Flexible(
                    child: Text(
                      key: labelKey,
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    SizedBox(width: gap),
                    IconTheme(
                      data: IconThemeData(
                        size: iconSize,
                        color: foregroundColor,
                      ),
                      child: trailingIcon!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
