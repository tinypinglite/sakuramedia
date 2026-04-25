import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/series_movies_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';

class DesktopSeriesMoviesPage extends StatelessWidget {
  const DesktopSeriesMoviesPage({
    super.key,
    required this.seriesId,
    this.seriesName,
  });

  final int seriesId;
  final String? seriesName;

  @override
  Widget build(BuildContext context) {
    return SeriesMoviesContent(
      seriesId: seriesId,
      initialSeriesName: seriesName,
      surfaceColor: context.appColors.surfaceElevated,
      contentKey: const Key('desktop-series-movies-page'),
      totalKey: const Key('desktop-series-movies-total'),
      sectionSpacing: context.appSpacing.lg,
      onMovieTap:
          (context, movieNumber) => context.pushDesktopMovieDetail(
            movieNumber: movieNumber,
            fallbackPath: desktopMoviesPath,
          ),
      bodyBuilder:
          (context, scrollController, child, _) =>
              SingleChildScrollView(controller: scrollController, child: child),
    );
  }
}
