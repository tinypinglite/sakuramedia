import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_stat_row.dart';

class MovieDetailBottomInfoBar extends StatelessWidget {
  const MovieDetailBottomInfoBar({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<MovieDetailStatItem> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('movie-detail-fixed-info-bar'),
      color: context.appColors.surfaceCard,
      borderRadius: context.appRadius.xsBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.appRadius.xsBorder,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: context.appComponentTokens.movieDetailBottomBarMinHeight,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.appSpacing.sm,
            vertical: 0,
          ),
          decoration: BoxDecoration(
            borderRadius: context.appRadius.smBorder,
            border: Border.all(color: context.appColors.borderSubtle),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: MovieDetailStatRow(items: items),
          ),
        ),
      ),
    );
  }
}
