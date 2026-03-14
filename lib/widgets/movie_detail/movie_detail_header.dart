import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MovieDetailHeader extends StatelessWidget {
  const MovieDetailHeader({
    super.key,
    required this.movieNumber,
    required this.title,
  });

  final String movieNumber;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final showTitle = title.isNotEmpty && title != movieNumber;

    return Padding(
      padding: EdgeInsets.only(bottom: context.appSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movieNumber,
                  key: const Key('movie-detail-number'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (showTitle) ...[
                  SizedBox(height: context.appSpacing.xs),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
