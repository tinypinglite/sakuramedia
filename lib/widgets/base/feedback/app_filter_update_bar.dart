import 'package:flutter/material.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

/// 服务端筛选失败反馈。
///
/// 控件选中态由业务 State 同步更新；请求中的反馈由
/// [AppFilterResultLoadingOverlay] 贴在结果区中央，本组件只保留失败说明和重试。
class AppFilterUpdateBar extends StatelessWidget {
  const AppFilterUpdateBar({
    super.key,
    required this.state,
    required this.hasPreviousItems,
    this.onRetry,
  });

  final FilterUpdateState state;
  final bool hasPreviousItems;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!state.hasFailed) return const SizedBox.shrink();

    if (state.hasFailed && !hasPreviousItems) {
      return AppEmptyState(
        key: const Key('app-filter-update-empty-error'),
        icon: Icons.sync_problem_rounded,
        title: '筛选结果更新失败',
        message: state.errorMessage ?? '暂时无法获取当前筛选结果，请稍后重试',
        onRetry: onRetry,
        retryKey: const Key('app-filter-update-empty-retry'),
      );
    }

    final spacing = context.appSpacing;
    return Container(
      key: const Key('app-filter-update-error'),
      margin: EdgeInsets.only(top: spacing.xs),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.appColors.errorSurface,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Row(
        children: [
          Icon(
            Icons.sync_problem_rounded,
            size: context.appComponentTokens.iconSizeXs,
            color: resolveAppTextToneColor(context, AppTextTone.error),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              '筛选结果更新失败，仍显示上一次结果',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
          ),
          if (onRetry != null)
            AppTextButton(
              label: '重试',
              size: AppTextButtonSize.xSmall,
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}
