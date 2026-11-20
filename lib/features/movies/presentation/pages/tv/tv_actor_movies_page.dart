import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_movie_summary_grid_page.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class TvActorMoviesPage extends StatelessWidget {
  const TvActorMoviesPage({super.key, required this.actorId, this.actorName});

  final int actorId;
  final String? actorName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TvMovieSummaryGridPage(
      scope: MovieSummaryScope.actor(actorId: actorId, pageSize: 36),
      title: actorName?.trim().isNotEmpty ?? false
          ? actorName!.trim()
          : l10n.routeActorsTitle,
      pageKey: const Key('tv-actor-movies-page'),
    );
  }
}
