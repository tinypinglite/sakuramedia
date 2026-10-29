import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_placeholders.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_state.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_task_run_card.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/task_run_history_sheet.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 打开任务中心的可执行任务弹层：按来源筛选、查看运行历史并手动触发任务。
Future<void> showActivityJobsDialog(
  BuildContext context, {
  required Future<void> Function(JobMetadataDto job) onTriggerJob,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    modalKey: const Key('activity-executable-jobs-dialog'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    builder: (_) => ActivityJobsDialog(onTriggerJob: onTriggerJob),
  );
}

class ActivityJobsDialog extends ConsumerWidget {
  const ActivityJobsDialog({super.key, required this.onTriggerJob});

  final Future<void> Function(JobMetadataDto job) onTriggerJob;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activity = ref.watch(activityCenterProvider);
    final controller = ref.read(activityCenterProvider.notifier);
    final body = activity.when(
      // loading 用占位任务渲染真实任务卡，由 [AppSkeletonizer] 灰化。
      loading: () => AppSkeletonizer(
        enabled: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final job in jobMetadataPlaceholders()) ...[
              ActivityJobCard(job: job, isTriggering: false, onTrigger: () {}),
              SizedBox(height: context.appSpacing.md),
            ],
          ],
        ),
      ),
      error: (error, _) => AppEmptyState(
        key: const Key('activity-jobs-error'),
        message: apiErrorMessage(
          error,
          fallback: l10n.errorExecutableTaskLoadFailed,
          l10n: l10n,
        ),
        onRetry: controller.reloadAll,
        retryKey: const Key('activity-jobs-retry-button'),
      ),
      data: (state) => _ActivityJobsDialogContent(
        state: state,
        controller: controller,
        onTriggerJob: onTriggerJob,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ActivityJobsDialogHeader(),
        SizedBox(height: context.appSpacing.lg),
        // 弹窗可用高度有限：body 必须按剩余空间收缩，内部的列表再在剩余空间里滚动，
        // 不能按屏幕高度比例硬编码列表上限（会顶穿弹窗自身的边距和固定 chrome）。
        Flexible(child: body),
      ],
    );
  }
}

class _ActivityJobsDialogContent extends StatefulWidget {
  const _ActivityJobsDialogContent({
    required this.state,
    required this.controller,
    required this.onTriggerJob,
  });

  final ActivityCenterState state;
  final ActivityCenter controller;
  final Future<void> Function(JobMetadataDto job) onTriggerJob;

  @override
  State<_ActivityJobsDialogContent> createState() =>
      _ActivityJobsDialogContentState();
}

class _ActivityJobsDialogContentState
    extends State<_ActivityJobsDialogContent> {
  static const String _systemFilterValue = '__system__';

  String? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final jobs = state.jobs;
    final jobPlaceholders = jobMetadataPlaceholders();
    final pluginIds = <String>{};
    var hasSystemJobs = false;
    for (final job in jobs) {
      final pluginId = job.pluginId?.trim();
      if (pluginId == null || pluginId.isEmpty) {
        hasSystemJobs = true;
      } else {
        pluginIds.add(pluginId);
      }
    }
    final sortedPluginIds = pluginIds.toList()..sort();
    final filterItems = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(
        value: null,
        child: Text(l10n.activityFilterAllTasks),
      ),
      if (hasSystemJobs)
        DropdownMenuItem<String?>(
          value: _systemFilterValue,
          child: Text(l10n.activityFilterSystemTasks),
        ),
      ...sortedPluginIds.map(
        (pluginId) =>
            DropdownMenuItem<String?>(value: pluginId, child: Text(pluginId)),
      ),
    ];
    final selectedFilter =
        filterItems.any((item) => item.value == _selectedFilter)
        ? _selectedFilter
        : null;
    final visibleJobs = selectedFilter == null
        ? jobs
        : jobs
              .where((job) {
                final pluginId = job.pluginId?.trim();
                if (selectedFilter == _systemFilterValue) {
                  return pluginId == null || pluginId.isEmpty;
                }
                return pluginId == selectedFilter;
              })
              .toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.isLoadingJobs && jobs.isEmpty)
          // loading 用占位任务渲染真实任务卡，由 [AppSkeletonizer] 灰化。
          Flexible(
            child: AppSkeletonizer(
              enabled: true,
              child: ListView.separated(
                key: const Key('activity-executable-jobs-loading-list'),
                shrinkWrap: true,
                itemCount: jobPlaceholders.length,
                separatorBuilder: (_, _) => SizedBox(height: spacing.md),
                itemBuilder: (_, index) => ActivityJobCard(
                  job: jobPlaceholders[index],
                  isTriggering: false,
                  onTrigger: () {},
                ),
              ),
            ),
          )
        else if (state.jobErrorMessage != null && jobs.isEmpty)
          AppEmptyState(
            key: const Key('activity-jobs-error'),
            message: state.jobErrorMessage!,
            onRetry: widget.controller.refreshJobs,
            retryKey: const Key('activity-jobs-retry-button'),
          )
        else if (jobs.isEmpty)
          AppEmptyState(message: l10n.activityExecutableJobsEmpty)
        else ...[
          if (state.isLoadingJobs) ...[
            Row(
              children: [
                const AppInlineSpinner(),
                SizedBox(width: spacing.sm),
                Text(
                  l10n.activityJobsRefreshing,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.md),
          ],
          SizedBox(
            width: double.infinity,
            child: AppSelectField<String?>(
              key: const Key('activity-job-plugin-filter'),
              label: l10n.activityJobSourceLabel,
              value: selectedFilter,
              size: AppSelectFieldSize.compact,
              items: filterItems,
              onChanged: (value) {
                setState(() => _selectedFilter = value);
              },
            ),
          ),
          SizedBox(height: spacing.md),
          Flexible(
            child: ListView.separated(
              key: const Key('activity-executable-jobs-list'),
              shrinkWrap: true,
              itemCount: visibleJobs.length,
              separatorBuilder: (_, _) => SizedBox(height: spacing.md),
              itemBuilder: (_, index) {
                final job = visibleJobs[index];
                return ActivityJobCard(
                  job: job,
                  isTriggering: widget.controller.isTriggeringJob(job.taskKey),
                  onTrigger: () => unawaited(widget.onTriggerJob(job)),
                );
              },
            ),
          ),
          if (state.jobErrorMessage != null) ...[
            SizedBox(height: spacing.md),
            _ActivityJobsRefreshError(
              message: state.jobErrorMessage!,
              onRetry: widget.controller.refreshJobs,
            ),
          ],
        ],
      ],
    );
  }
}

/// 任务定义卡：定时计划、最近状态与时间、运行历史入口与手动执行。
class ActivityJobCard extends StatelessWidget {
  const ActivityJobCard({
    super.key,
    required this.job,
    required this.isTriggering,
    required this.onTrigger,
  });

  final JobMetadataDto job;
  final bool isTriggering;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lastTaskRun = job.lastTaskRun;
    final taskName = job.cliHelp.isEmpty ? job.taskKey : job.cliHelp;
    final canTrigger =
        job.disabledReason == null && job.manualTriggerAllowed && !isTriggering;

    return AppContentCard(
      key: Key('activity-job-${job.taskKey}'),
      padding: EdgeInsets.all(context.appSpacing.lg),
      title: taskName,
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.regular,
        tone: AppTextTone.secondary,
      ),
      headerBottomSpacing: context.appSpacing.sm,
      // 骨架态下品牌底主行动随整块灰化，避免看起来「加载中也可用」。
      headerTrailing: Skeleton.shade(
        child: AppButton(
          key: Key('activity-job-trigger-${job.taskKey}'),
          label: job.disabledReason != null
              ? l10n.activityJobDisabled
              : job.manualTriggerAllowed
              ? (isTriggering
                    ? l10n.activityJobSubmitting
                    : job.paramsSchema == null
                    ? l10n.activityJobRunNow
                    : l10n.activityJobFillParams)
              : l10n.activityJobNotManual,
          size: AppButtonSize.small,
          variant: AppButtonVariant.primary,
          isLoading: isTriggering,
          onPressed: canTrigger ? onTrigger : null,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                label: job.isScheduled
                    ? job.cronExpr
                    : l10n.activityJobNoSchedule,
                tone: AppBadgeTone.neutral,
              ),
              if (lastTaskRun != null)
                AppBadge(
                  label: activityTaskStateLabel(lastTaskRun.state, l10n),
                  tone: activityTaskStateTone(lastTaskRun.state),
                ),
              if (job.paramsSchema != null)
                AppBadge(
                  label: l10n.activityJobNeedsParams,
                  tone: AppBadgeTone.neutral,
                ),
            ],
          ),
          SizedBox(height: context.appSpacing.sm),
          Text(
            lastTaskRun == null
                ? l10n.activityJobNoRuns
                : l10n.activityJobLastRun(
                    activityTaskTimeSummary(lastTaskRun, l10n),
                  ),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppTextButton(
              key: Key('activity-job-history-${job.taskKey}'),
              label: l10n.activityTaskRunHistoryTitle,
              icon: const Icon(Icons.history_rounded),
              size: AppTextButtonSize.xSmall,
              onPressed: () => unawaited(
                showTaskRunHistorySheet(
                  context,
                  taskKey: job.taskKey,
                  taskName: taskName,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityJobsDialogHeader extends StatelessWidget {
  const _ActivityJobsDialogHeader();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(right: spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.activityExecutableJobsTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            l10n.activityExecutableJobsDialogDescription,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityJobsRefreshError extends StatelessWidget {
  const _ActivityJobsRefreshError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('activity-jobs-retry-button'),
          label: l10n.commonRetry,
          size: AppButtonSize.xSmall,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
