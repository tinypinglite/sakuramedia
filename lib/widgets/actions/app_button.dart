import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { medium, small, xSmall, xxSmall, xxxSmall }

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
    final (height, horizontal, gap, iconSize, textSize) = switch (size) {
      AppButtonSize.medium => (
        componentTokens.buttonHeightMd,
        componentTokens.buttonHorizontalPaddingMd,
        componentTokens.buttonGapMd,
        componentTokens.iconSizeSm,
        AppTextSize.s14,
      ),
      AppButtonSize.small => (
        componentTokens.buttonHeightSm,
        componentTokens.buttonHorizontalPaddingSm,
        componentTokens.buttonGapSm,
        componentTokens.iconSizeSm,
        AppTextSize.s14,
      ),
      AppButtonSize.xSmall => (
        componentTokens.buttonHeightXs,
        componentTokens.buttonHorizontalPaddingXs,
        componentTokens.buttonGapXs,
        componentTokens.iconSizeXs,
        AppTextSize.s12,
      ),
      AppButtonSize.xxSmall => (
        componentTokens.buttonHeight2xs,
        componentTokens.buttonHorizontalPadding2xs,
        componentTokens.buttonGap2xs,
        componentTokens.iconSize2xs,
        AppTextSize.s10,
      ),
      AppButtonSize.xxxSmall => (
        componentTokens.buttonHeight3xs,
        componentTokens.buttonHorizontalPadding3xs,
        componentTokens.buttonGap3xs,
        componentTokens.iconSize3xs,
        AppTextSize.s10,
      ),
    };
    final borderRadius = context.appRadius.smBorder;
    final isSecondarySelected =
        variant == AppButtonVariant.secondary && isSelected;
    final isGhostSelected = variant == AppButtonVariant.ghost && isSelected;

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
      AppButtonVariant.danger => colors.errorSurface,
    };

    final borderColor = switch (variant) {
      AppButtonVariant.primary => theme.colorScheme.primary,
      AppButtonVariant.secondary =>
        isSecondarySelected ? theme.colorScheme.primary : colors.borderStrong,
      AppButtonVariant.ghost =>
        isGhostSelected ? theme.colorScheme.primary : Colors.transparent,
      AppButtonVariant.danger => context.appTextPalette.error.withValues(
        alpha: 0.2,
      ),
    };

    final disabledColor = colors.borderSubtle;
    final tone = switch (variant) {
      AppButtonVariant.primary => AppTextTone.onMedia,
      AppButtonVariant.secondary =>
        isSecondarySelected ? AppTextTone.accent : AppTextTone.primary,
      AppButtonVariant.ghost => AppTextTone.accent,
      AppButtonVariant.danger => AppTextTone.error,
    };
    final foregroundColor = resolveAppTextToneColor(context, tone);
    final labelStyle = resolveAppTextStyle(
      context,
      size: textSize,
      tone: tone,
    ).copyWith(height: 1, leadingDistribution: TextLeadingDistribution.even);

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
                      width: iconSize,
                      height: iconSize,
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
                      style: labelStyle,
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
