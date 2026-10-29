import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';

class DownloadCandidateSelectionSummary extends StatelessWidget {
  const DownloadCandidateSelectionSummary({
    super.key,
    required this.evaluation,
    this.showManualHint = true,
  });

  final DownloadCandidateSelectionEvaluationDto evaluation;
  final bool showManualHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final preferredLabel = evaluation.matchedPreferredGroupLabel?.trim();
    final rank = evaluation.selectionRank;
    final outsideAttemptLimit =
        evaluation.eligible && !evaluation.withinAttemptLimit;
    final recommended =
        evaluation.eligible && rank != null && !outsideAttemptLimit;
    return Column(
      key: const Key('download-candidate-selection-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.xs,
          children: [
            if (recommended)
              AppBadge(
                label: l10n.downloadSelectionCandidateRecommended(rank),
                tone: AppBadgeTone.primary,
                size: AppBadgeSize.compact,
              )
            else
              AppBadge(
                label: outsideAttemptLimit && rank != null
                    ? l10n.downloadSelectionCandidateOutsideAttemptLimit(rank)
                    : evaluation.eligible
                    ? l10n.downloadSelectionCandidateEligible
                    : l10n.downloadSelectionCandidateFiltered,
                tone: evaluation.eligible && !outsideAttemptLimit
                    ? AppBadgeTone.primary
                    : AppBadgeTone.warning,
                size: AppBadgeSize.compact,
              ),
            if (preferredLabel != null && preferredLabel.isNotEmpty)
              AppBadge(
                label: l10n.downloadSelectionCandidatePreferred(preferredLabel),
                tone: AppBadgeTone.neutral,
                size: AppBadgeSize.compact,
              ),
          ],
        ),
        if (outsideAttemptLimit && showManualHint) ...[
          SizedBox(height: spacing.sm),
          Container(
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: context.appColors.warningSurface,
              borderRadius: context.appRadius.mdBorder,
            ),
            child: Text(
              l10n.downloadSelectionCandidateManualHint,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
        ],
        if (!evaluation.eligible && evaluation.rejectionReasons.isNotEmpty) ...[
          SizedBox(height: spacing.sm),
          Container(
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: context.appColors.warningSurface,
              borderRadius: context.appRadius.mdBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (
                  var index = 0;
                  index < evaluation.rejectionReasons.length;
                  index++
                ) ...[
                  if (index > 0) SizedBox(height: spacing.xs),
                  Text(
                    '· ${evaluation.rejectionReasons[index].message}',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.warning,
                    ),
                  ),
                ],
                if (showManualHint) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    l10n.downloadSelectionCandidateManualHint,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
