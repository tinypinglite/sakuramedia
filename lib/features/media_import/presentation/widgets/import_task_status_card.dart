import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_task_run_card.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/import_task_run_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/domain/media_import/import_failed_items_dialog.dart';

/// 导入页「最近一次导入」状态卡：进度、结果与失败条目处理入口。
class ImportTaskStatusCard extends ConsumerWidget {
  const ImportTaskStatusCard({
    super.key,
    required this.taskRunId,
    required this.taskName,
  });

  final int taskRunId;
  final String taskName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final runAsync = ref.watch(importTaskRunProvider(taskRunId));
    return AppContentCard(
      key: const Key('media-import-last-task-card'),
      title: l10n.mediaImportLastTaskTitle,
      child: runAsync.when(
        loading: () => Padding(
          padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
          child: const Center(child: AppInlineSpinner()),
        ),
        error: (_, _) => Row(
          children: [
            Expanded(
              child: Text(
                l10n.mediaImportLastTaskLoadFailed,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
            AppTextButton(
              key: const Key('media-import-last-task-retry'),
              label: l10n.commonRetry,
              size: AppTextButtonSize.small,
              onPressed: () => ref.invalidate(importTaskRunProvider(taskRunId)),
            ),
          ],
        ),
        data: (run) => _buildBody(context, ref, l10n, run, isMobile),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TaskRunDto run,
    bool isMobile,
  ) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final progressText = run.progressText?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                activityTaskStateLabel(run.state, l10n),
                key: const Key('media-import-last-task-state'),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
            if (run.isActive && run.hasDeterminateProgress)
              Text(
                formatAppPercent(run.progressValue!, decimals: 0),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
          ],
        ),
        if (run.isActive) ...[
          SizedBox(height: spacing.sm),
          // 与任务中心一致：有确定进度才用动画进度条，否则静态灰条占位。
          if (run.hasDeterminateProgress)
            ClipRRect(
              borderRadius: context.appRadius.pillBorder,
              child: LinearProgressIndicator(
                minHeight: 6,
                value: run.progressValue,
                backgroundColor: colors.surfaceMuted,
              ),
            )
          else
            ClipRRect(
              borderRadius: context.appRadius.pillBorder,
              child: Container(height: 6, color: colors.surfaceMuted),
            ),
          if (progressText.isNotEmpty) ...[
            SizedBox(height: spacing.xs),
            Text(
              progressText,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ),
            ),
          ],
        ] else if (run.resultText?.trim().isNotEmpty ?? false) ...[
          SizedBox(height: spacing.xs),
          Text(
            run.resultText!.trim(),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
        if (run.errorMessage?.trim().isNotEmpty ?? false) ...[
          SizedBox(height: spacing.xs),
          Text(
            run.errorMessage!.trim(),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.error,
            ),
          ),
        ],
        if (!run.isActive &&
            (run.unresolvedFailedFileCount > 0 ||
                run.skippedFileCount > 0)) ...[
          SizedBox(height: spacing.sm),
          AppTextButton(
            key: const Key('media-import-last-task-failed-items'),
            label: run.unresolvedFailedFileCount > 0
                ? l10n.activityHandleFailedFiles(run.unresolvedFailedFileCount)
                : l10n.activityViewSkippedFiles(run.skippedFileCount),
            size: AppTextButtonSize.small,
            emphasis: AppTextButtonEmphasis.accent,
            onPressed: () => unawaited(_openFailedItems(context, ref)),
          ),
        ],
        SizedBox(height: spacing.sm),
        AppTextButton(
          key: const Key('media-import-last-task-open-center'),
          label: l10n.mediaImportViewTasksAction,
          size: AppTextButtonSize.small,
          trailingIcon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => _openTaskCenter(context, isMobile),
        ),
      ],
    );
  }

  Future<void> _openFailedItems(BuildContext context, WidgetRef ref) async {
    await showImportFailedItemsDialog(
      context: context,
      taskRunId: taskRunId,
      taskName: taskName,
    );
    if (context.mounted) {
      ref.invalidate(importTaskRunProvider(taskRunId));
    }
  }

  void _openTaskCenter(BuildContext context, bool isMobile) {
    if (isMobile) {
      context.push(mobileActivityPath);
      return;
    }
    context.goPrimary(AppRouteId.desktopActivity);
  }
}
