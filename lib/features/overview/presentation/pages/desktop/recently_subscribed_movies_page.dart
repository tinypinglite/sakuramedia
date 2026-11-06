import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';

/// 「最近订阅」全量列表页：概览页分区的「更多」落点，按订阅时间倒序分页加载。
class DesktopRecentlySubscribedMoviesPage extends StatelessWidget {
  const DesktopRecentlySubscribedMoviesPage({super.key});

  static const _scope = MovieSummaryScope.recentlySubscribed();

  @override
  Widget build(BuildContext context) {
    return MovieSummaryListContent(
      scope: _scope,
      surfaceColor: context.appColors.surfaceElevated,
      contentKey: const Key('desktop-recently-subscribed-movies-page'),
      sectionSpacing: context.appSpacing.lg,
      registerPageRefresh: true,
      emptyMessage: AppLocalizations.of(context).overviewNoSubscribedMovies,
      showHeader: false,
      onMovieTap: (context, movieNumber) => DesktopRoutes.movieDetail(
        movieNumber: movieNumber,
        fallbackPath: desktopRecentlySubscribedMoviesPath,
      ).push(context),
      bodyBuilder: (context, scrollController, sliver, _) =>
          CustomScrollView(controller: scrollController, slivers: [sliver]),
    );
  }
}
