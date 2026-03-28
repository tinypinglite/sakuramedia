import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MovieDetailHeader extends StatelessWidget {
  const MovieDetailHeader({
    super.key,
    required this.movieNumber,
    required this.title,
    required this.summary,
    this.trailing,
    this.showTitle = true,
    this.showNumberRow = true,
    this.showSummary = true,
  });

  final String movieNumber;
  final String title;
  final String summary;
  final Widget? trailing;
  final bool showTitle;
  final bool showNumberRow;
  final bool showSummary;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resolvedTitle = title.trim();
    final resolvedMovieNumber = movieNumber.trim();
    final resolvedSummary = summary.trim();
    final shouldShowTitle =
        showTitle &&
        resolvedTitle.isNotEmpty &&
        resolvedTitle != resolvedMovieNumber;
    final shouldShowSummary = showSummary && resolvedSummary.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom:
            shouldShowSummary ? context.appSpacing.md : context.appSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shouldShowTitle)
            Text(
              resolvedTitle,
              key: const Key('movie-detail-title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (shouldShowTitle && (showNumberRow || shouldShowSummary))
            SizedBox(height: context.appSpacing.lg),
          if (showNumberRow)
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
          if (showNumberRow && shouldShowSummary)
            SizedBox(height: context.appSpacing.xs),
          if (shouldShowSummary)
            Text(
              resolvedSummary,
              key: const Key('movie-detail-summary'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
        ],
      ),
    );
  }
}
