import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/activity/data/task_attention_dto.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_task_run_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';

/// 「需要关注」区：只展示后端标记为最新运行失败 / 完成带警告的任务。
///
/// 条目为空时整段隐藏（旧后端没有该接口时同样隐藏），不占用默认页面高度。
class ActivityAttentionSection extends StatelessWidget {
  const ActivityAttentionSection({
    super.key,
    required this.items,
    required this.onViewHistory,
  });

  final List<TaskAttentionDto> items;
  final void Function(TaskAttentionDto item) onViewHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const Key('activity-attention-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.report_problem_rounded,
              size: context.appComponentTokens.iconSizeMd,
              color: context.appTextPalette.warning,
            ),
            SizedBox(width: context.appSpacing.sm),
            Text(
              l10n.activityAttentionTitle,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(width: context.appSpacing.sm),
            AppBadge(
              label: l10n.activityAttentionCount(items.length),
              tone: AppBadgeTone.warning,
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.lg),
        for (var index = 0; index < items.length; index++) ...[
          _AttentionCard(item: items[index], onViewHistory: onViewHistory),
          if (index != items.length - 1)
            SizedBox(height: context.appSpacing.md),
        ],
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.item, required this.onViewHistory});

  final TaskAttentionDto item;
  final void Function(TaskAttentionDto item) onViewHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final latestRun = item.latestRun;
    final summary = latestRun?.displaySummary(l10n);
    final lastIssueAt = item.lastIssueAt ?? latestRun?.finishedAt;
    final lastIssueLabel = formatUpdatedAtLabel(lastIssueAt);

    return Container(
      key: Key('activity-attention-${item.taskKey}'),
      width: double.infinity,
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(
          color: context.appTextPalette.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.displayName,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ),
              if (latestRun != null) ...[
                SizedBox(width: spacing.md),
                AppBadge(
                  label: activityTaskStateLabel(latestRun.state, l10n),
                  tone: activityTaskStateTone(latestRun.state),
                ),
              ],
            ],
          ),
          if ((summary ?? '').trim().isNotEmpty) ...[
            SizedBox(height: spacing.sm),
            Text(
              summary!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ],
          SizedBox(height: spacing.md),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                label: l10n.activityAttentionFailedCount(item.failedCount7d),
                tone: AppBadgeTone.error,
              ),
              if (lastIssueLabel != null)
                Text(
                  l10n.activityLastIssueAt(lastIssueLabel),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppTextButton(
              key: Key('activity-attention-history-${item.taskKey}'),
              label: l10n.activityViewRunRecords,
              icon: const Icon(Icons.history_rounded),
              size: AppTextButtonSize.small,
              emphasis: AppTextButtonEmphasis.accent,
              onPressed: () => onViewHistory(item),
            ),
          ),
        ],
      ),
    );
  }
}
