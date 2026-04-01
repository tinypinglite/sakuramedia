import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MovieDetailNumberBar extends StatelessWidget {
  const MovieDetailNumberBar({
    super.key,
    required this.movieNumber,
    required this.summary,
    this.trailing,
  });

  final String movieNumber;
  final String summary;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final resolvedMovieNumber = movieNumber.trim();
    final resolvedSummary = summary.trim();
    final shouldShowSummary = resolvedSummary.isNotEmpty;

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
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (trailing != null) ...[
                SizedBox(width: context.appSpacing.md),
                trailing!,
              ],
            ],
          ),
          if (shouldShowSummary) ...[
            SizedBox(height: context.appSpacing.xs),
            Text(
              resolvedSummary,
              key: const Key('movie-detail-summary'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
