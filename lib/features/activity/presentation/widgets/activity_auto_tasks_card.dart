import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 自动任务摘要卡：只统计配置了定时表达式的任务，提示需要关注的数量。
///
/// 明细（自动 / 手动、来源、异常筛选）在弹层里；默认页面不铺全部任务定义。
class ActivityAutoTasksCard extends StatelessWidget {
  const ActivityAutoTasksCard({
    super.key,
    required this.jobs,
    required this.isLoading,
    this.errorMessage,
    required this.onOpen,
  });

  final List<JobMetadataDto> jobs;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final autoJobs = jobs
        .where((job) => job.isScheduled)
        .toList(growable: false);
    final attentionCount = autoJobs.where((job) => job.needsAttention).length;

    return AppContentCard(
      key: const Key('activity-auto-tasks-card'),
      title: l10n.activityAutoTasksTitle,
      // 标题栏只放主行动；数量角标放正文，窄屏不会被标题挤压。
      headerTrailing: AppButton(
        key: const Key('activity-jobs-toggle'),
        label: l10n.activityViewJobs,
        icon: const Icon(Icons.list_alt_rounded),
        size: AppButtonSize.small,
        onPressed: onOpen,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                label: _summaryLabel(l10n, autoJobs.length),
                tone: AppBadgeTone.neutral,
              ),
              if (attentionCount > 0)
                AppBadge(
                  key: const Key('activity-auto-tasks-attention-badge'),
                  label: l10n.activityAutoTasksNeedAttention(attentionCount),
                  tone: AppBadgeTone.warning,
                ),
            ],
          ),
          SizedBox(height: context.appSpacing.sm),
          Text(
            l10n.activityAutoTasksDescription,
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

  String _summaryLabel(AppLocalizations l10n, int autoJobCount) {
    if (isLoading && jobs.isEmpty) return l10n.activityJobsLoading;
    if (errorMessage != null && jobs.isEmpty) {
      return l10n.activityJobsLoadFailed;
    }
    if (jobs.isEmpty) return l10n.activityJobsEmpty;
    return l10n.activityAutoTasksCount(autoJobCount);
  }
}
