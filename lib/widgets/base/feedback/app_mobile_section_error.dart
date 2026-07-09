import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

/// 移动端 section 级错误态卡片。
///
/// 跟桌面版 [`AppSectionError`](app_section_error.dart) 是姊妹关系——
/// 桌面无卡壳、左对齐；移动有卡壳、居中、全宽重试按钮。
/// 参数 `{title, message, onRetry}` 与桌面版对齐，方便调用方复用文案。
class AppMobileSectionError extends StatelessWidget {
  const AppMobileSectionError({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryButtonKey,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;
  final Key? retryButtonKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppEmptyState(message: title),
          SizedBox(height: spacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              key: retryButtonKey,
              label: '重试',
              variant: AppButtonVariant.primary,
              onPressed: () => onRetry(),
            ),
          ),
        ],
      ),
    );
  }
}
