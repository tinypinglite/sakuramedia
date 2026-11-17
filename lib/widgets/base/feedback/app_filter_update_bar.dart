import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

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
    final l10n = appL10n(context);
    if (!state.hasFailed) return const SizedBox.shrink();

    if (state.hasFailed && !hasPreviousItems) {
      return AppErrorState(
        key: const Key('app-filter-update-empty-error'),
        icon: Icons.sync_problem_rounded,
        title: l10n.baseFilterUpdateFailedTitle,
        message: state.errorMessage ?? l10n.baseFilterUpdateFailedMessage,
        onRetry: onRetry,
        retryKey: const Key('app-filter-update-empty-retry'),
        variant: AppStatePanelVariant.section,
      );
    }

    final spacing = context.appSpacing;
    final detail = state.errorMessage?.trim();
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sync_problem_rounded,
            size: context.appComponentTokens.iconSizeXs,
            color: resolveAppTextToneColor(context, AppTextTone.error),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.baseFilterUpdateStale,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.error,
                  ),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    detail,
                    key: const Key('app-filter-update-error-detail'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onRetry != null)
            AppTextButton(
              key: const Key('app-filter-update-retry'),
              label: l10n.commonRetry,
              size: AppTextButtonSize.xSmall,
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}
