import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_task_run_card.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/task_run_history_sheet.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 概览中的任务卡：说明、运行状态、最近运行与直接执行入口。
class ActivityJobOverviewCard extends StatelessWidget {
  const ActivityJobOverviewCard({
    super.key,
    required this.job,
    required this.icon,
    required this.emphasizeIcon,
    required this.isTriggering,
    required this.onTrigger,
  });

  final JobMetadataDto job;
  final IconData icon;
  final bool emphasizeIcon;
  final bool isTriggering;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final lastTaskRun = job.lastTaskRun;
    final isRunning = lastTaskRun?.isActive ?? false;
    final taskName = job.cliHelp.trim().isEmpty ? job.taskKey : job.cliHelp;
    final canTrigger =
        job.disabledReason == null &&
        job.manualTriggerAllowed &&
        !isTriggering &&
        !isRunning;
    final scheduleLabel = job.isScheduled
        ? l10n.activityJobScheduled
        : l10n.activityJobManualTask;
    final lastRunLabel = lastTaskRun == null
        ? l10n.activityJobNoRuns
        : l10n.activityJobLastRun(activityTaskTimeSummary(lastTaskRun, l10n));
    final statusBadge = _buildStatusBadge(l10n, lastTaskRun);
    final iconTileSize = context.appComponentTokens.iconSizeXl + spacing.xs;

    return AppContentCard(
      key: Key('activity-job-overview-${job.taskKey}'),
      title: null,
      borderColor: context.appColors.borderSubtle,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: Key('activity-job-overview-icon-${job.taskKey}'),
                width: iconTileSize,
                height: iconTileSize,
                decoration: BoxDecoration(
                  color: emphasizeIcon
                      ? context.appColors.selectionSurface
                      : context.appColors.surfaceCard,
                  borderRadius: context.appRadius.smBorder,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: context.appComponentTokens.iconSizeXs,
                  color: emphasizeIcon
                      ? context.appTextPalette.accent
                      : context.appTextPalette.secondary,
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Tooltip(
                  message: taskName,
                  child: Text(
                    taskName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      weight: AppTextWeight.medium,
                      tone: AppTextTone.primary,
                    ),
                  ),
                ),
              ),
              if (statusBadge != null) ...[
                SizedBox(width: spacing.sm),
                statusBadge,
              ],
            ],
          ),
          SizedBox(height: spacing.sm),
          Text(
            '$scheduleLabel · $lastRunLabel',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          if (job.disabledReason != null) ...[
            SizedBox(height: spacing.xs),
            Text(
              job.disabledReason!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.warning,
              ),
            ),
          ],
          SizedBox(height: spacing.sm),
          Row(
            children: [
              if (lastTaskRun != null)
                AppIconButton(
                  key: Key('activity-job-overview-history-${job.taskKey}'),
                  tooltip: l10n.activityTaskRunHistoryTitle,
                  semanticLabel: l10n.activityTaskRunHistoryTitle,
                  icon: const Icon(Icons.history_rounded),
                  size: AppIconButtonSize.mini,
                  onPressed: () => unawaited(
                    showTaskRunHistorySheet(
                      context,
                      taskKey: job.taskKey,
                      taskName: taskName,
                    ),
                  ),
                ),
              const Spacer(),
              AppTextButton(
                key: Key('activity-job-overview-trigger-${job.taskKey}'),
                label: _primaryActionLabel(l10n, lastTaskRun),
                icon: Icon(_primaryActionIcon(lastTaskRun)),
                size: AppTextButtonSize.xSmall,
                emphasis: AppTextButtonEmphasis.accent,
                isLoading: isTriggering,
                onPressed: canTrigger ? onTrigger : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildStatusBadge(AppLocalizations l10n, TaskRunDto? lastTaskRun) {
    if (job.disabledReason != null) {
      return AppBadge(
        label: l10n.activityJobDisabled,
        tone: AppBadgeTone.warning,
        size: AppBadgeSize.compact,
      );
    }
    if (lastTaskRun == null) return null;
    if (lastTaskRun.isActive) {
      return AppBadge(
        label: activityTaskStateLabel(lastTaskRun.state, l10n),
        tone: activityTaskStateTone(lastTaskRun.state),
        size: AppBadgeSize.compact,
      );
    }
    if (lastTaskRun.needsAttention) {
      return AppBadge(
        label: lastTaskRun.hasWarning
            ? l10n.activityRunCompletedWithWarning
            : activityTaskStateLabel(lastTaskRun.state, l10n),
        tone: lastTaskRun.hasWarning
            ? AppBadgeTone.warning
            : AppBadgeTone.error,
        size: AppBadgeSize.compact,
      );
    }
    return null;
  }

  String _primaryActionLabel(AppLocalizations l10n, TaskRunDto? lastTaskRun) {
    if (job.disabledReason != null) return l10n.activityJobDisabled;
    if (!job.manualTriggerAllowed) return l10n.activityJobNotManual;
    if (isTriggering) return l10n.activityJobSubmitting;
    if (lastTaskRun?.isActive ?? false) {
      return activityTaskStateLabel(lastTaskRun!.state, l10n);
    }
    if (job.paramsSchema != null) return l10n.activityJobFillParams;
    return l10n.activityJobRunNow;
  }

  IconData _primaryActionIcon(TaskRunDto? lastTaskRun) {
    if (job.disabledReason != null) return Icons.block_rounded;
    if (!job.manualTriggerAllowed) return Icons.lock_outline_rounded;
    if (isTriggering) return Icons.sync_rounded;
    if (lastTaskRun?.isActive ?? false) return Icons.hourglass_top_rounded;
    if (job.paramsSchema != null) return Icons.tune_rounded;
    return Icons.play_arrow_rounded;
  }
}
