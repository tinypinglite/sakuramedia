import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_stat_row.dart';

enum MovieDetailBottomInfoBarVariant { desktopCard, mobileFullWidth }

class MovieDetailBottomInfoBar extends StatelessWidget {
  const MovieDetailBottomInfoBar({
    super.key,
    required this.items,
    required this.onTap,
    this.variant = MovieDetailBottomInfoBarVariant.desktopCard,
  });

  final List<MovieDetailStatItem> items;
  final VoidCallback onTap;
  final MovieDetailBottomInfoBarVariant variant;

  @override
  Widget build(BuildContext context) {
    final borderRadius =
        variant == MovieDetailBottomInfoBarVariant.desktopCard
            ? context.appRadius.xsBorder
            : BorderRadius.zero;
    final decoration =
        variant == MovieDetailBottomInfoBarVariant.desktopCard
            ? BoxDecoration(
              borderRadius: context.appRadius.smBorder,
              border: Border.all(color: context.appColors.borderSubtle),
            )
            : BoxDecoration(
              border: Border(
                top: BorderSide(color: context.appColors.borderSubtle),
              ),
            );

    return Material(
      key: const Key('movie-detail-fixed-info-bar'),
      color: context.appColors.surfaceCard,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: context.appComponentTokens.movieDetailBottomBarMinHeight,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.appSpacing.sm,
            vertical: 0,
          ),
          decoration: decoration,
          child: Align(
            alignment: Alignment.centerLeft,
            child: MovieDetailStatRow(items: items),
          ),
        ),
      ),
    );
  }
}
