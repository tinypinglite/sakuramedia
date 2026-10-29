import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/activity/presentation/activity_placeholders.dart';
import 'package:sakuramedia/features/activity/presentation/providers/task_run_history_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/task_run_history_state.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_task_run_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 单个任务的全量运行记录弹层。
///
/// 桌面端是居中弹窗，移动端是整屏底部抽屉；记录来自独立的
/// [taskRunHistoryProvider]，与任务中心默认的「最近操作」列表互不影响。
Future<void> showTaskRunHistorySheet(
  BuildContext context, {
  required String taskKey,
  required String taskName,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    modalKey: const Key('activity-history-sheet'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    mobileHeightFactor: 1,
    showDesktopCloseButton: true,
    showDrawerHandle: false,
    builder: (_) => TaskRunHistorySheet(taskKey: taskKey, taskName: taskName),
  );
}

class TaskRunHistorySheet extends ConsumerWidget {
  const TaskRunHistorySheet({
    super.key,
    required this.taskKey,
    required this.taskName,
  });

  final String taskKey;
  final String taskName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = taskRunHistoryProvider(taskKey);
    final async = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final isDrawer = AppAdaptiveModalShellScope.maybeIsDrawer(context);
    final spacing = context.appSpacing;

    final Widget body = async.when(
      loading: () => AppSkeletonizer(
        enabled: true,
        child: Column(
          key: const Key('activity-history-loading'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final run in taskRunPlaceholders(count: 3, l10n: l10n)) ...[
              ActivityTaskRunCard(taskRun: run),
              SizedBox(height: spacing.md),
            ],
          ],
        ),
      ),
      error: (error, _) => AppEmptyState(
        key: const Key('activity-history-error'),
        message: apiErrorMessage(
          error,
          fallback: l10n.errorActivityLoadFailed,
          l10n: l10n,
        ),
        onRetry: () => ref.invalidate(provider),
        retryKey: const Key('activity-history-retry-button'),
      ),
      data: (data) => _TaskRunHistoryList(state: data, controller: controller),
    );

    return Column(
      key: const Key('activity-history-sheet-content'),
      mainAxisSize: isDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TaskRunHistoryHeader(
          taskName: taskName,
          isLoading: async.isLoading || (async.value?.isRefreshing ?? false),
          onRefresh: () => unawaited(controller.refresh()),
        ),
        SizedBox(height: spacing.lg),
        if (async.hasValue && async.value!.refreshErrorMessage != null) ...[
          _HistoryRefreshError(
            message: async.value!.refreshErrorMessage!,
            onRetry: () => unawaited(controller.refresh()),
          ),
          SizedBox(height: spacing.md),
        ],
        // 抽屉高度固定，列表占满剩余空间；弹窗按内容收缩。
        if (isDrawer) Expanded(child: body) else Flexible(child: body),
      ],
    );
  }
}

class _TaskRunHistoryHeader extends StatelessWidget {
  const _TaskRunHistoryHeader({
    required this.taskName,
    required this.isLoading,
    required this.onRefresh,
  });

  final String taskName;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(right: spacing.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.activityTaskRunHistoryTitle,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s18,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  taskName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.md),
          AppTextButton(
            key: const Key('activity-history-refresh'),
            label: l10n.commonRefresh,
            icon: const Icon(Icons.refresh_rounded),
            size: AppTextButtonSize.small,
            isLoading: isLoading,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _HistoryRefreshError extends StatelessWidget {
  const _HistoryRefreshError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.error,
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        AppTextButton(
          label: l10n.commonRetry,
          size: AppTextButtonSize.xSmall,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _TaskRunHistoryList extends StatelessWidget {
  const _TaskRunHistoryList({required this.state, required this.controller});

  final TaskRunHistoryState state;
  final TaskRunHistory controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    if (state.runs.isEmpty) {
      return AppEmptyState(
        key: const Key('activity-history-empty'),
        message: l10n.activityHistoryEmpty,
      );
    }
    final isDrawer = AppAdaptiveModalShellScope.maybeIsDrawer(context);
    final list = AppPagedLoadMoreScope(
      canLoadMore: () => state.canAutoLoadMore,
      onLoadMore: controller.loadMore,
      child: ListView.separated(
        key: const Key('activity-history-list'),
        shrinkWrap: !isDrawer,
        itemCount: state.runs.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => SizedBox(height: spacing.md),
        itemBuilder: (context, index) {
          if (index >= state.runs.length) {
            return AppPagedLoadMoreFooter(
              isLoading: state.isLoadingMore,
              errorMessage: state.loadMoreErrorMessage,
              onRetry: () => unawaited(controller.loadMore()),
            );
          }
          return RepaintBoundary(
            child: ActivityTaskRunCard(taskRun: state.runs[index]),
          );
        },
      ),
    );
    if (isDrawer) return list;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: list,
    );
  }
}
