import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

class AppPagedLoadMoreFooter extends StatelessWidget {
  const AppPagedLoadMoreFooter({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    this.retryKey,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  /// 页脚重试按钮的 Key，供页面或测试定位。
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    if (isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.md),
          child: SizedBox(
            width: componentTokens.movieCardLoaderSize,
            height: componentTokens.movieCardLoaderSize,
            child: CircularProgressIndicator.adaptive(
              strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }

    if (errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: componentTokens.iconSizeXl,
                color: context.appTextPalette.secondary,
              ),
              SizedBox(width: spacing.sm),
              Flexible(
                child: Text(
                  errorMessage!,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              AppTextButton(
                key: retryKey,
                label: l10n.commonRetry,
                onPressed: onRetry,
                size: AppTextButtonSize.xSmall,
                emphasis: AppTextButtonEmphasis.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
