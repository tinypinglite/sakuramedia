import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

enum AppTextButtonSize { medium, small, xSmall, xxSmall, xxxSmall }

enum AppTextButtonBackgroundStyle { transparent, muted }

class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.labelKey,
    this.size = AppTextButtonSize.medium,
    this.isSelected = false,
    this.backgroundStyle = AppTextButtonBackgroundStyle.transparent,
  });
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? trailingIcon;
  final Key? labelKey;
  final AppTextButtonSize size;
  final bool isSelected;
  final AppTextButtonBackgroundStyle backgroundStyle;

  bool get _isEnabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final componentTokens = context.appComponentTokens;
    final colors = context.appColors;
    final (height, horizontal, gap, iconSize, textSize) = switch (size) {
      AppTextButtonSize.medium => (
          componentTokens.buttonHeightMd,
          componentTokens.buttonHorizontalPaddingMd,
          componentTokens.buttonGapMd,
          componentTokens.iconSizeSm,
          AppTextSize.s14,
        ),
      AppTextButtonSize.small => (
          componentTokens.buttonHeightSm,
          componentTokens.buttonHorizontalPaddingSm,
          componentTokens.buttonGapSm,
          componentTokens.iconSizeSm,
          AppTextSize.s14,
        ),
      AppTextButtonSize.xSmall => (
          componentTokens.buttonHeightXs,
          componentTokens.buttonHorizontalPaddingXs,
          componentTokens.buttonGapXs,
          componentTokens.iconSizeXs,
          AppTextSize.s12,
        ),
      AppTextButtonSize.xxSmall => (
          componentTokens.buttonHeight2xs,
          componentTokens.buttonHorizontalPadding2xs,
          componentTokens.buttonGap2xs,
          componentTokens.iconSize2xs,
          AppTextSize.s10,
        ),
      AppTextButtonSize.xxxSmall => (
          componentTokens.buttonHeight3xs,
          componentTokens.buttonHorizontalPadding3xs,
          componentTokens.buttonGap3xs,
          componentTokens.iconSize3xs,
          AppTextSize.s10,
        ),
    };
    final borderRadius = context.appRadius.smBorder;
    final tone = isSelected ? AppTextTone.accent : AppTextTone.muted;
    final foregroundColor = resolveAppTextToneColor(context, tone);
    final backgroundColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : switch (backgroundStyle) {
            AppTextButtonBackgroundStyle.transparent => Colors.transparent,
            AppTextButtonBackgroundStyle.muted => colors.surfaceMuted,
          };
    final disabledColor = colors.borderSubtle;
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
                color: _isEnabled
                    ? backgroundColor
                    : disabledColor.withValues(alpha: 0.32),
                borderRadius: borderRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null)
                    IconTheme(
                      data: IconThemeData(
                        size: iconSize,
                        color:
                            _isEnabled ? foregroundColor : colors.borderStrong,
                      ),
                      child: icon!,
                    ),
                  if (icon != null) SizedBox(width: gap),
                  Flexible(
                    child: Text(
                      key: labelKey,
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle.copyWith(
                        color:
                            _isEnabled ? foregroundColor : colors.borderStrong,
                      ),
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    SizedBox(width: gap),
                    IconTheme(
                      data: IconThemeData(
                        size: iconSize,
                        color:
                            _isEnabled ? foregroundColor : colors.borderStrong,
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
