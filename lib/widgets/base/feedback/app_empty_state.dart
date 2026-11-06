import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 状态面板的布局档位。
///
/// - [page]：整页空态，保持原有大留白与最大宽度。
/// - [section]：区块空态，收紧留白并把图标降一档。
/// - [inline]：单行提示，只渲染说明文字和可选文字重试按钮。
enum AppStatePanelVariant { page, section, inline }

/// 重试操作的视觉权重。
enum AppEmptyStateRetryStyle { primary, text }

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.title,
    this.onRetry,
    this.retryLabel,
    this.retryKey,
    this.variant = AppStatePanelVariant.page,
    this.retryStyle = AppEmptyStateRetryStyle.primary,
  });

  const AppEmptyState.section({
    super.key,
    required this.message,
    this.icon,
    this.title,
    this.onRetry,
    this.retryLabel,
    this.retryKey,
    this.retryStyle = AppEmptyStateRetryStyle.primary,
  }) : variant = AppStatePanelVariant.section;

  const AppEmptyState.inline({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.retryKey,
  }) : icon = null,
       title = null,
       variant = AppStatePanelVariant.inline,
       retryStyle = AppEmptyStateRetryStyle.text;

  final String message;
  final IconData? icon;
  final String? title;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final Key? retryKey;
  final AppStatePanelVariant variant;
  final AppEmptyStateRetryStyle retryStyle;

  @override
  Widget build(BuildContext context) {
    if (variant == AppStatePanelVariant.inline) {
      return _buildInline(context);
    }

    final l10n = appL10n(context);
    final spacing = context.appSpacing;
    final isSection = variant == AppStatePanelVariant.section;
    final iconColor = resolveAppTextToneColor(context, AppTextTone.secondary);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: isSection ? spacing.lg : spacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isSection ? 420 : 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: isSection
                      ? context.appComponentTokens.iconSize3xl
                      : context.appComponentTokens.iconSize4xl,
                  color: iconColor,
                ),
                SizedBox(height: spacing.md),
              ],
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s16,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.sm),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              if (onRetry != null) ...[
                SizedBox(height: spacing.lg),
                _buildRetryButton(context, l10n.commonRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInline(BuildContext context) {
    final l10n = appL10n(context);
    final retry = onRetry;
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ),
        if (retry != null) ...[
          SizedBox(width: context.appSpacing.sm),
          _buildRetryButton(context, l10n.commonRetry),
        ],
      ],
    );
  }

  Widget _buildRetryButton(BuildContext context, String fallbackLabel) {
    final retry = onRetry;
    if (retry == null) {
      return const SizedBox.shrink();
    }
    final label = retryLabel ?? fallbackLabel;
    return switch (retryStyle) {
      AppEmptyStateRetryStyle.primary => AppButton(
        key: retryKey,
        label: label,
        onPressed: retry,
      ),
      AppEmptyStateRetryStyle.text => AppTextButton(
        key: retryKey,
        label: label,
        onPressed: retry,
        size: AppTextButtonSize.xSmall,
        emphasis: AppTextButtonEmphasis.accent,
      ),
    };
  }
}
