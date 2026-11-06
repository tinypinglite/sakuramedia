import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/series_movies_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';
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
      contentKey: const Key('desktop-series-movies-page'),
      totalKey: const Key('desktop-series-movies-total'),
      sectionSpacing: context.appSpacing.lg,
      onMovieTap: (context, movieNumber) => DesktopRoutes.movieDetail(
        movieNumber: movieNumber,
        fallbackPath: desktopMoviesPath,
      ).push(context),
      bodyBuilder: (context, scrollController, sliver, _) =>
          CustomScrollView(controller: scrollController, slivers: [sliver]),
    );
  }
}
