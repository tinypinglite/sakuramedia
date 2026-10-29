import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 可执行任务摘要卡：展示任务总数与任务明细入口。
class ActivityExecutableJobsCard extends StatelessWidget {
  const ActivityExecutableJobsCard({
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

    return AppContentCard(
      key: const Key('activity-executable-jobs-card'),
      title: l10n.activityExecutableJobsTitle,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBadge(label: _summaryLabel(l10n), tone: AppBadgeTone.neutral),
          SizedBox(width: context.appSpacing.sm),
          AppButton(
            key: const Key('activity-jobs-toggle'),
            label: l10n.activityViewJobs,
            icon: const Icon(Icons.list_alt_rounded),
            size: AppButtonSize.small,
            onPressed: onOpen,
          ),
        ],
      ),
      child: Text(
        l10n.activityExecutableJobsDescription,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ),
      ),
    );
  }

  String _summaryLabel(AppLocalizations l10n) {
    if (isLoading && jobs.isEmpty) return l10n.activityJobsLoading;
    if (errorMessage != null && jobs.isEmpty) {
      return l10n.activityJobsLoadFailed;
    }
    if (jobs.isEmpty) return l10n.activityJobsEmpty;
    return l10n.activityJobsCount(jobs.length);
  }
}
