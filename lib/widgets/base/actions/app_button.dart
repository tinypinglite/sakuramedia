import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button_content.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

enum AppButtonVariant { primary, secondary, tonal, ghost, danger }

enum AppButtonSize { tvLarge, large, medium, small, xSmall, xxSmall }

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
    this.autofocus = false,
    this.borderRadius,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.disabledOpacity = 1,
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

  /// 是否在首帧自动获取焦点；电视端进入页面时给主操作使用。
  final bool autofocus;

  /// 覆盖默认圆角（默认 [AppRadius.smBorder]）；品牌主 CTA 可用 pill 圆角。
  final BorderRadius? borderRadius;

  /// 覆盖禁用态背景/文字色（默认灰底 + 可读的中性前景）；仅在确有品牌禁用样式时使用。
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;

  /// 禁用态整体透明度；默认 1，禁用态的可读性由前景/背景 token 直接保证。
  final double disabledOpacity;

  bool get _isInteractive => onPressed != null && !isLoading;

  /// 加载中沿用正常配色，只屏蔽点击；避免提交中的主按钮看起来像被禁用。
  bool get _usesActiveStyle => onPressed != null || isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final (height, horizontalPadding, gap, iconSize, textSize) =
        resolveAppButtonContentMetrics(context, size._contentSize);
    final minWidth = size == AppButtonSize.tvLarge
        ? AppTvTokens.actionMinWidth
        : null;
    final isSecondarySelected =
        variant == AppButtonVariant.secondary && isSelected;
    final isGhostSelected = variant == AppButtonVariant.ghost && isSelected;

    final backgroundColor = switch (variant) {
      AppButtonVariant.primary => theme.colorScheme.primary,
      AppButtonVariant.secondary =>
        isSecondarySelected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
      AppButtonVariant.tonal => colors.surfaceElevated,
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
      AppButtonVariant.tonal => colors.borderSubtle,
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
      AppButtonVariant.tonal => AppTextTone.primary,
      AppButtonVariant.ghost => AppTextTone.accent,
      AppButtonVariant.danger => AppTextTone.error,
    };
    final foregroundColor = variant == AppButtonVariant.primary
        ? theme.colorScheme.onPrimary
        : resolveAppTextToneColor(context, tone);
    final disabledForeground =
        disabledForegroundColor ??
        resolveAppTextToneColor(
          context,
          variant == AppButtonVariant.danger
              ? AppTextTone.error
              : theme.brightness == Brightness.dark
              ? AppTextTone.secondary
              : AppTextTone.muted,
        );
    final effectiveForeground = _usesActiveStyle
        ? foregroundColor
        : disabledForeground;
    final labelStyle = resolveAppTextStyle(context, size: textSize, tone: tone)
        .copyWith(
          color: effectiveForeground,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        );

    return Opacity(
      opacity: _usesActiveStyle ? 1 : disabledOpacity,
      child: AppInteractiveSurface(
        enabled: _isInteractive,
        onTap: onPressed,
        autofocus: autofocus,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: height,
          constraints: minWidth == null
              ? null
              : BoxConstraints(minWidth: minWidth),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: _usesActiveStyle ? backgroundColor : disabledBackground,
            borderRadius: borderRadius ?? context.appRadius.smBorder,
            border: Border.all(
              color: _usesActiveStyle ? borderColor : disabledBackground,
            ),
          ),
          // widthFactor/heightFactor 让按钮在宽松约束下按内容收缩；父级给
          // Expanded / 通栏约束时仍会撑满，保持原有 CTA 用法。
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
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
      ),
    );
  }
}

extension on AppButtonSize {
  AppButtonContentSize get _contentSize => switch (this) {
    AppButtonSize.tvLarge => AppButtonContentSize.tvLarge,
    AppButtonSize.large => AppButtonContentSize.large,
    AppButtonSize.medium => AppButtonContentSize.medium,
    AppButtonSize.small => AppButtonContentSize.small,
    AppButtonSize.xSmall => AppButtonContentSize.xSmall,
    AppButtonSize.xxSmall => AppButtonContentSize.xxSmall,
  };
}
