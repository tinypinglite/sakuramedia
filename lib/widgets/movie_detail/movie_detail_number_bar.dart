import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MovieDetailNumberBar extends StatelessWidget {
  const MovieDetailNumberBar({
    super.key,
    required this.movieNumber,
    required this.summary,
    required this.wantWatchCount,
    required this.watchedCount,
    required this.score,
    required this.commentCount,
    required this.heat,
    required this.scoreNumber,
    this.trailing,
  });

  final String movieNumber;
  final String summary;
  final int wantWatchCount;
  final int watchedCount;
  final double score;
  final int commentCount;
  final int heat;
  final int scoreNumber;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final resolvedMovieNumber = movieNumber.trim();
    final resolvedSummary = summary.trim();
    final shouldShowSummary = resolvedSummary.isNotEmpty;
    final scoreLabel = _formatScore(score);

    return Padding(
      padding: EdgeInsets.only(
        bottom: context.appComponentTokens.movieDetailSectionGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                resolvedMovieNumber,
                key: const Key('movie-detail-number'),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: context.appSpacing.md),
                trailing!,
              ],
            ],
          ),
          SizedBox(height: context.appSpacing.xs),
          Wrap(
            key: const Key('movie-detail-interaction-row'),
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '想看人数 $wantWatchCount',
                key: const Key('movie-detail-interaction-want-watch-text'),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
              Text(
                '看过人数 $watchedCount',
                key: const Key('movie-detail-interaction-watched-text'),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
              Row(
                key: const Key('movie-detail-interaction-score-item'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_outline_rounded,
                    size: context.appComponentTokens.iconSizeXs,
                    color: context.appColors.movieDetailScoreIcon,
                  ),
                  SizedBox(width: context.appSpacing.xs),
                  Text(
                    scoreLabel,
                    key: const Key('movie-detail-interaction-score-text'),
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
              Row(
                key: const Key('movie-detail-interaction-comment-item'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: context.appComponentTokens.iconSizeXs,
                    color: context.appColors.movieDetailCommentCountIcon,
                  ),
                  SizedBox(width: context.appSpacing.xs),
                  Text(
                    '$commentCount',
                    key: const Key('movie-detail-interaction-comment-text'),
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
              Row(
                key: const Key('movie-detail-interaction-heat-item'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: context.appComponentTokens.iconSizeXs,
                    color: context.appColors.movieDetailHeatIcon,
                  ),
                  SizedBox(width: context.appSpacing.xs),
                  Text(
                    '$heat',
                    key: const Key('movie-detail-interaction-heat-text'),
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
              Text(
                '评分人数 $scoreNumber',
                key: const Key('movie-detail-interaction-score-number-text'),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
          ),
          if (shouldShowSummary) ...[
            SizedBox(height: context.appSpacing.xs),
            Text(
              resolvedSummary,
              key: const Key('movie-detail-summary'),
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
    );
  }
}

String _formatScore(double score) {
  final fixed = score.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
