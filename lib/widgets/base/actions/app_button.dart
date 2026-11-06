import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button_content.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { large, medium, small, xSmall, xxSmall, xxxSmall }

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
    this.borderRadius,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.disabledOpacity = 0.56,
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

  /// 覆盖默认圆角（默认 [AppRadius.smBorder]）；品牌主 CTA 可用 pill 圆角。
  final BorderRadius? borderRadius;

  /// 覆盖禁用态背景/文字色（默认灰底 + 主题前景色）；仅在确有品牌禁用样式时使用。
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final double disabledOpacity;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final (height, horizontalPadding, gap, iconSize, textSize) =
        resolveAppButtonContentMetrics(context, size._contentSize);
    final isSecondarySelected =
        variant == AppButtonVariant.secondary && isSelected;
    final isGhostSelected = variant == AppButtonVariant.ghost && isSelected;

    final backgroundColor = switch (variant) {
      AppButtonVariant.primary => theme.colorScheme.primary,
      AppButtonVariant.secondary =>
        isSecondarySelected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
      AppButtonVariant.ghost =>
        isGhostSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
      AppButtonVariant.danger => colors.errorSurface,
    };

    final borderColor = switch (variant) {
      AppButtonVariant.primary => theme.colorScheme.primary,
      AppButtonVariant.secondary =>
        isSecondarySelected ? theme.colorScheme.primary : Colors.transparent,
      AppButtonVariant.ghost =>
        isGhostSelected ? theme.colorScheme.primary : Colors.transparent,
      AppButtonVariant.danger => context.appTextPalette.error.withValues(
        alpha: 0.2,
      ),
    };

    final disabledBackground = disabledBackgroundColor ?? colors.borderSubtle;
    final tone = switch (variant) {
      AppButtonVariant.primary => AppTextTone.onMedia,
      AppButtonVariant.secondary =>
        isSecondarySelected ? AppTextTone.accent : AppTextTone.primary,
      AppButtonVariant.ghost => AppTextTone.accent,
      AppButtonVariant.danger => AppTextTone.error,
    };
    final foregroundColor = resolveAppTextToneColor(context, tone);
    final effectiveForeground = _isEnabled
        ? foregroundColor
        : (disabledForegroundColor ?? foregroundColor);
    final labelStyle = resolveAppTextStyle(context, size: textSize, tone: tone)
        .copyWith(
          color: effectiveForeground,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        );

    return Opacity(
      opacity: _isEnabled ? 1 : disabledOpacity,
      child: AppInteractiveSurface(
        enabled: _isEnabled,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: height,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: _isEnabled ? backgroundColor : disabledBackground,
            borderRadius: borderRadius ?? context.appRadius.smBorder,
            border: Border.all(
              color: _isEnabled ? borderColor : disabledBackground,
            ),
          ),
          child: buildAppButtonContent(
            label: label,
            labelKey: labelKey,
            labelStyle: labelStyle,
            icon: icon,
            trailingIcon: trailingIcon,
            isLoading: isLoading,
            iconSize: iconSize,
            gap: gap,
            iconColor: effectiveForeground,
          ),
        ),
      ),
    );
  }
}

extension on AppButtonSize {
  AppButtonContentSize get _contentSize => switch (this) {
    AppButtonSize.large => AppButtonContentSize.large,
    AppButtonSize.medium => AppButtonContentSize.medium,
    AppButtonSize.small => AppButtonContentSize.small,
    AppButtonSize.xSmall => AppButtonContentSize.xSmall,
    AppButtonSize.xxSmall => AppButtonContentSize.xxSmall,
    AppButtonSize.xxxSmall => AppButtonContentSize.xxxSmall,
  };
}
