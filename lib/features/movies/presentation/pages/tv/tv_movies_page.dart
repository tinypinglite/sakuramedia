import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_movie_summary_grid_page.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class TvMoviesPage extends StatelessWidget {
  const TvMoviesPage({super.key});

  static const _scope = MovieSummaryScope.movies(
    cacheKey: 'tv:movies:list',
    pageSize: 36,
  );

  @override
  Widget build(BuildContext context) {
    return TvMovieSummaryGridPage(
      scope: _scope,
      title: AppLocalizations.of(context).routeMoviesTitle,
      pageKey: const Key('tv-movies-page'),
    );
  }
}
