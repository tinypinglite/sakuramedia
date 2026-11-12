import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_job_sections.dart';
import 'package:sakuramedia/features/activity/presentation/activity_placeholders.dart';
import 'package:sakuramedia/features/activity/presentation/activity_plugin_names.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_provider.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_job_overview_card.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_wrap.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';

/// 概览中的可执行任务区：常用 / 系统 / 各插件分组。
class ActivityExecutableJobsSliver extends ConsumerWidget {
  const ActivityExecutableJobsSliver({
    super.key,
    required this.isInitialLoading,
    required this.onTriggerJob,
  });

  final bool isInitialLoading;
  final Future<void> Function(JobMetadataDto job) onTriggerJob;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(
      activityCenterProvider.select((asyncValue) {
        final state = asyncValue.value;
        return (
          jobs: state?.jobs ?? const <JobMetadataDto>[],
          isLoading: state?.isLoadingJobs ?? false,
          errorMessage: state?.jobErrorMessage,
          triggeringTaskKeys: state?.triggeringTaskKeys ?? const <String>{},
        );
      }),
    );
    final controller = ref.read(activityCenterProvider.notifier);
    final isLoading = isInitialLoading || view.isLoading;
    final statsEnabled = ref.watch(statsFeaturesEnabledProvider);
    final jobs = visibleActivityJobs(view.jobs, statsEnabled: statsEnabled);
    final pluginNames = jobs.any(_isPluginJob)
        ? activityPluginDisplayNames(
            ref.watch(pluginsProvider).value?.plugins ?? const [],
          )
        : const <String, String>{};
    final l10n = AppLocalizations.of(context);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _ExecutableJobsHeader(
            countLabel: _jobsCountLabel(
              l10n,
              jobs: jobs,
              isLoading: isLoading,
              errorMessage: view.errorMessage,
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
        ..._buildBody(
          context,
          l10n: l10n,
          jobs: jobs,
          errorMessage: view.errorMessage,
          triggeringTaskKeys: view.triggeringTaskKeys,
          isLoading: isLoading,
          pluginNames: pluginNames,
          onTriggerJob: onTriggerJob,
          controller: controller,
        ),
      ],
    );
  }

  List<Widget> _buildBody(
    BuildContext context, {
    required AppLocalizations l10n,
    required List<JobMetadataDto> jobs,
    required String? errorMessage,
    required Set<String> triggeringTaskKeys,
    required bool isLoading,
    required Map<String, String> pluginNames,
    required Future<void> Function(JobMetadataDto job) onTriggerJob,
    required ActivityCenter controller,
  }) {
    final spacing = context.appSpacing;
    if (isLoading && jobs.isEmpty) {
      return _buildLoadingSlivers(context, l10n);
    }
    if (errorMessage != null && jobs.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: AppErrorState(
            key: const Key('activity-jobs-overview-error'),
            title: l10n.baseActionFailed,
            message: errorMessage,
            onRetry: controller.refreshJobs,
            retryKey: const Key('activity-jobs-overview-retry'),
          ),
        ),
      ];
    }
    if (jobs.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: AppEmptyState(
            key: const Key('activity-jobs-overview-empty'),
            message: l10n.activityExecutableJobsEmpty,
          ),
        ),
      ];
    }

    final sections = buildActivityJobSections(jobs);
    final sectionSlivers = <Widget>[];
    for (var index = 0; index < sections.length; index++) {
      sectionSlivers.addAll(
        _buildSectionSlivers(
          context,
          section: sections[index],
          pluginNames: pluginNames,
          triggeringTaskKeys: triggeringTaskKeys,
          onTriggerJob: onTriggerJob,
        ),
      );
      if (index != sections.length - 1) {
        sectionSlivers.add(
          SliverToBoxAdapter(child: SizedBox(height: spacing.lg)),
        );
      }
    }
    return <Widget>[
      if (errorMessage != null) ...[
        SliverToBoxAdapter(
          child: AppInlineErrorBanner(
            message: errorMessage,
            onRetry: controller.refreshJobs,
            retryKey: const Key('activity-jobs-overview-retry'),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: spacing.lg)),
      ],
      ...sectionSlivers,
    ];
  }

  List<Widget> _buildLoadingSlivers(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final spacing = context.appSpacing;
    final placeholders = jobMetadataPlaceholders(count: 4);
    return <Widget>[
      SliverToBoxAdapter(
        child: _JobSectionHeader(
          title: l10n.activityCommonTasks,
          countLabel: l10n.activityJobsLoading,
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: spacing.sm)),
      AppSkeletonizer.sliver(
        enabled: true,
        child: AppAdaptiveCardWrapSliver<JobMetadataDto>(
          items: placeholders.take(2).toList(growable: false),
          orientation: AppCardGridOrientation.mixed,
          minColumns: 1,
          maxColumns: 2,
          stretchRows: true,
          itemBuilder: (context, job, index) => ActivityJobOverviewCard(
            job: job,
            icon: Icons.bolt_rounded,
            emphasizeIcon: true,
            isTriggering: false,
            onTrigger: () {},
          ),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: spacing.lg)),
      SliverToBoxAdapter(
        child: _JobSectionHeader(
          title: l10n.activityFilterSystemTasks,
          countLabel: l10n.activityJobsLoading,
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: spacing.sm)),
      AppSkeletonizer.sliver(
        enabled: true,
        child: AppAdaptiveCardWrapSliver<JobMetadataDto>(
          items: placeholders.skip(2).toList(growable: false),
          orientation: AppCardGridOrientation.mixed,
          minColumns: 1,
          maxColumns: 2,
          stretchRows: true,
          itemBuilder: (context, job, index) => ActivityJobOverviewCard(
            job: job,
            icon: Icons.tune_rounded,
            emphasizeIcon: false,
            isTriggering: false,
            onTrigger: () {},
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSectionSlivers(
    BuildContext context, {
    required ActivityJobSection section,
    required Map<String, String> pluginNames,
    required Set<String> triggeringTaskKeys,
    required Future<void> Function(JobMetadataDto job) onTriggerJob,
  }) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final title = switch (section.kind) {
      ActivityJobSectionKind.common => l10n.activityCommonTasks,
      ActivityJobSectionKind.system => l10n.activityFilterSystemTasks,
      ActivityJobSectionKind.plugin => activityPluginDisplayName(
        section.pluginId ?? '',
        pluginNames,
      ),
    };
    final icon = switch (section.kind) {
      ActivityJobSectionKind.common => Icons.bolt_rounded,
      ActivityJobSectionKind.system => Icons.tune_rounded,
      ActivityJobSectionKind.plugin => Icons.extension_rounded,
    };
    final sectionKey = section.kind == ActivityJobSectionKind.plugin
        ? 'activity-job-section-plugin-${section.pluginId}'
        : 'activity-job-section-${section.kind.name}';

    return <Widget>[
      SliverToBoxAdapter(
        child: _JobSectionHeader(
          key: Key(sectionKey),
          title: title,
          countLabel: l10n.activityJobsCount(section.jobs.length),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: spacing.sm)),
      AppAdaptiveCardWrapSliver<JobMetadataDto>(
        key: Key('$sectionKey-grid'),
        items: section.jobs,
        orientation: AppCardGridOrientation.mixed,
        minColumns: 1,
        maxColumns: 2,
        stretchRows: true,
        itemBuilder: (context, job, index) => ActivityJobOverviewCard(
          job: job,
          icon: icon,
          emphasizeIcon: section.kind == ActivityJobSectionKind.common,
          isTriggering: triggeringTaskKeys.contains(job.taskKey),
          onTrigger: () => unawaited(onTriggerJob(job)),
        ),
      ),
    ];
  }

  static bool _isPluginJob(JobMetadataDto job) =>
      (job.pluginId ?? '').trim().isNotEmpty;

  static String _jobsCountLabel(
    AppLocalizations l10n, {
    required List<JobMetadataDto> jobs,
    required bool isLoading,
    required String? errorMessage,
  }) {
    if (isLoading && jobs.isEmpty) return l10n.activityJobsLoading;
    if (errorMessage != null && jobs.isEmpty) {
      return l10n.activityJobsLoadFailed;
    }
    if (jobs.isEmpty) return l10n.activityJobsEmpty;
    return l10n.activityJobsCount(jobs.length);
  }
}

class _ExecutableJobsHeader extends StatelessWidget {
  const _ExecutableJobsHeader({required this.countLabel});

  final String countLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Wrap(
      key: const Key('activity-executable-jobs-toolbar'),
      spacing: spacing.sm,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          l10n.activityExecutableJobsTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        AppBadge(
          key: const Key('activity-executable-jobs-count'),
          label: countLabel,
          size: AppBadgeSize.compact,
          tone: AppBadgeTone.neutral,
        ),
      ],
    );
  }
}

class _JobSectionHeader extends StatelessWidget {
  const _JobSectionHeader({
    super.key,
    required this.title,
    required this.countLabel,
  });

  final String title;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: title,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
          ),
        ),
        SizedBox(width: spacing.md),
        Text(
          countLabel,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    );
  }
}
