import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MovieDetailTitle extends StatelessWidget {
  const MovieDetailTitle({
    super.key,
    required this.title,
    required this.movieNumber,
  });

  final String title;
  final String movieNumber;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title.trim();
    final resolvedMovieNumber = movieNumber.trim();
    final shouldShow =
        resolvedTitle.isNotEmpty && resolvedTitle != resolvedMovieNumber;

    if (!shouldShow) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: context.appSpacing.lg),
      child: Text(
        resolvedTitle,
        key: const Key('movie-detail-title'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.appColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
