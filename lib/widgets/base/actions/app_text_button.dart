import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

enum AppTextButtonSize { medium, small, xSmall, xxSmall, xxxSmall }

enum AppTextButtonBackgroundStyle { transparent, muted }

/// 选中态外观。
///
/// [tinted] 为主色文字 + 淡主色底，用于弹层筛选面板里的 chip；
/// [plain] 只用主色文字 + 加粗，无底色，用于页面内联的排序/切换
/// （如「最新 / 最早」「最热 / 最新」）。
enum AppTextButtonSelectedStyle { tinted, plain }

/// 文字按钮的强调级别。
///
/// [normal] 为默认的 muted 文字；[secondary] 用 secondary 文字、无底色，
/// 适合「查看全部」这类可交互但不应抢主操作的导航链接；[accent] 用主色文字
/// + 淡主色底，适合「新建 / 添加 / 播放」这类需要突出的动作按钮。视觉同
/// [AppTextButtonSelectedStyle.tinted]，但语义独立于 `isSelected`（后者表达
/// 「当前选中」，如排序的最新/最早）。
enum AppTextButtonEmphasis { normal, secondary, accent }

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
    this.isLoading = false,
    this.selectedStyle = AppTextButtonSelectedStyle.tinted,
    this.emphasis = AppTextButtonEmphasis.normal,
    this.backgroundStyle = AppTextButtonBackgroundStyle.transparent,
  });
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? trailingIcon;
  final Key? labelKey;
  final AppTextButtonSize size;
  final bool isSelected;

  /// 忙碌态：不可点击，但沿用正常态配色，并把图标位换成转圈。
  final bool isLoading;

  final AppTextButtonSelectedStyle selectedStyle;
  final AppTextButtonEmphasis emphasis;
  final AppTextButtonBackgroundStyle backgroundStyle;

  bool get _isEnabled => onPressed != null && !isLoading;

  /// 加载中沿用正常态配色：内联强调按钮不应在等待时看起来像禁用。
  bool get _usesActiveStyle => _isEnabled || isLoading;

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
    final isPlainSelected =
        isSelected && selectedStyle == AppTextButtonSelectedStyle.plain;
    final tone = isSelected
        ? AppTextTone.accent
        : switch (emphasis) {
            AppTextButtonEmphasis.accent => AppTextTone.accent,
            AppTextButtonEmphasis.secondary => AppTextTone.secondary,
            AppTextButtonEmphasis.normal => AppTextTone.muted,
          };
    final foregroundColor = resolveAppTextToneColor(context, tone);
    final usesAccentBackground =
        (isSelected && selectedStyle == AppTextButtonSelectedStyle.tinted) ||
        emphasis == AppTextButtonEmphasis.accent;
    final backgroundColor = usesAccentBackground
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : switch (backgroundStyle) {
            AppTextButtonBackgroundStyle.transparent => Colors.transparent,
            AppTextButtonBackgroundStyle.muted => colors.surfaceMuted,
          };
    final disabledColor = colors.borderSubtle;
    final labelStyle = resolveAppTextStyle(
      context,
      size: textSize,
      weight: isPlainSelected ? AppTextWeight.semibold : AppTextWeight.regular,
      tone: tone,
    ).copyWith(height: 1, leadingDistribution: TextLeadingDistribution.even);

    return Opacity(
      opacity: _usesActiveStyle ? 1 : 0.56,
      child: AppInteractiveSurface(
        enabled: _isEnabled,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: height,
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          decoration: BoxDecoration(
            color: _usesActiveStyle
                ? backgroundColor
                : disabledColor.withValues(alpha: 0.32),
            borderRadius: borderRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: AppInlineSpinner(color: foregroundColor),
                )
              else if (icon != null)
                IconTheme(
                  data: IconThemeData(
                    size: iconSize,
                    color: _usesActiveStyle
                        ? foregroundColor
                        : colors.borderStrong,
                  ),
                  child: icon!,
                ),
              if (isLoading || icon != null) SizedBox(width: gap),
              Flexible(
                child: Text(
                  key: labelKey,
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle.copyWith(
                    color: _usesActiveStyle
                        ? foregroundColor
                        : colors.borderStrong,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                SizedBox(width: gap),
                IconTheme(
                  data: IconThemeData(
                    size: iconSize,
                    color: _usesActiveStyle
                        ? foregroundColor
                        : colors.borderStrong,
                  ),
                  child: trailingIcon!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
