import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/domain/media_import/import_failed_items_dialog.dart';

/// 单条任务运行记录卡：活动区、最近操作列表与单个任务的历史弹层共用。
class ActivityTaskRunCard extends StatelessWidget {
  const ActivityTaskRunCard({
    super.key,
    required this.taskRun,
    this.highlighted = false,
  });

  final TaskRunDto taskRun;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final progressValue = taskRun.progressValue;
    final summary = taskRun.displaySummary(l10n);

    return Container(
      key: Key('activity-task-${taskRun.id}'),
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(
          color: highlighted
              ? Theme.of(context).colorScheme.primary
              : colors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taskRun.taskName,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                    if ((taskRun.progressText ?? '').trim().isNotEmpty) ...[
                      SizedBox(height: context.appSpacing.xs),
                      Text(
                        taskRun.progressText!,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: context.appSpacing.md),
              AppBadge(
                label: activityTaskStateLabel(taskRun.state, l10n),
                tone: activityTaskStateTone(taskRun.state),
              ),
            ],
          ),
          if (taskRun.isActive) ...[
            SizedBox(height: context.appSpacing.md),
            // 仅在有确定进度时渲染带动画的进度条；否则用静态灰条占位。
            // value 为 null 时 LinearProgressIndicator 是无限循环动画，
            // 会让 GPU 持续光栅化（核显吃满）。
            if (taskRun.hasDeterminateProgress)
              ClipRRect(
                borderRadius: context.appRadius.pillBorder,
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progressValue,
                  backgroundColor: colors.surfaceMuted,
                ),
              )
            else
              ClipRRect(
                borderRadius: context.appRadius.pillBorder,
                child: Container(height: 6, color: colors.surfaceMuted),
              ),
          ],
          SizedBox(height: context.appSpacing.md),
          Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.sm,
            children: [
              AppBadge(
                label: activityTriggerTypeLabel(taskRun.triggerType, l10n),
                tone: AppBadgeTone.neutral,
              ),
              if (taskRun.hasWarning)
                AppBadge(
                  label: l10n.activityRunCompletedWithWarning,
                  tone: AppBadgeTone.warning,
                ),
              Text(
                activityTaskTimeSummary(taskRun, l10n),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
          ),
          if ((summary ?? '').trim().isNotEmpty) ...[
            SizedBox(height: context.appSpacing.md),
            Text(
              summary!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ],
          if ((taskRun.unresolvedFailedFileCount > 0 ||
                  taskRun.skippedFileCount > 0) &&
              !taskRun.isActive) ...[
            SizedBox(height: context.appSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppTextButton(
                key: Key('activity-task-failed-items-${taskRun.id}'),
                label: taskRun.unresolvedFailedFileCount > 0
                    ? l10n.activityHandleFailedFiles(
                        taskRun.unresolvedFailedFileCount,
                      )
                    : l10n.activityViewSkippedFiles(taskRun.skippedFileCount),
                size: AppTextButtonSize.small,
                emphasis: AppTextButtonEmphasis.accent,
                onPressed: () => showImportFailedItemsDialog(
                  context: context,
                  taskRunId: taskRun.id,
                  taskName: taskRun.taskName,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String activityTaskTimeSummary(TaskRunDto item, AppLocalizations l10n) {
  if (item.finishedAt != null) {
    return l10n.activityFinishedAt(
      formatUpdatedAtLabel(item.finishedAt) ?? l10n.activityTimeUnknown,
    );
  }
  if (item.startedAt != null) {
    return l10n.activityStartedAt(
      formatUpdatedAtLabel(item.startedAt) ?? l10n.activityTimeUnknown,
    );
  }
  return l10n.activityCreatedAt(
    formatUpdatedAtLabel(item.createdAt) ?? l10n.activityTimeUnknown,
  );
}

AppBadgeTone activityTaskStateTone(String state) {
  return switch (state) {
    'failed' => AppBadgeTone.error,
    'completed' => AppBadgeTone.success,
    'running' => AppBadgeTone.primary,
    'pending' => AppBadgeTone.warning,
    _ => AppBadgeTone.neutral,
  };
}

String activityTaskStateLabel(String value, AppLocalizations l10n) {
  return switch (value) {
    'running' => l10n.activityTaskStateRunning,
    'completed' => l10n.activityTaskStateCompleted,
    'failed' => l10n.activityTaskStateFailed,
    'pending' => l10n.activityTaskStatePending,
    _ => value,
  };
}

String activityTriggerTypeLabel(String value, AppLocalizations l10n) {
  return switch (value) {
    'scheduled' => l10n.activityTriggerScheduled,
    'manual' => l10n.activityTriggerManual,
    'startup' => l10n.activityTriggerStartup,
    'internal' => l10n.activityTriggerInternal,
    'plugin' => l10n.activityTriggerPlugin,
    _ => value,
  };
}
