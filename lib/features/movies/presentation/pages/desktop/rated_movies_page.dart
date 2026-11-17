import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/rated_movies_header.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';

/// 「我的评分」页：标准影片网格，默认按总分倒序，可按单个维度排序。
class DesktopRatedMoviesPage extends ConsumerWidget {
  const DesktopRatedMoviesPage({super.key});

  static const _scope = MovieSummaryScope.ratedList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MovieSummaryListContent(
      scope: _scope,
      surfaceColor: context.appColors.surfaceElevated,
      contentKey: const Key('desktop-rated-movies-page'),
      sectionSpacing: context.appSpacing.lg,
      registerPageRefresh: true,
      emptyMessage: AppLocalizations.of(context).moviePageEmptyNotRated,
      headerBuilder: (context, args) =>
          RatedMoviesHeader(args: args, isMobile: false),
      trailingLabelForMovie: (movie) =>
          ratedTotalLabel(movie, l10n: AppLocalizations.of(context)),
      onMovieTap: (context, movieNumber) => DesktopRoutes.movieDetail(
        movieNumber: movieNumber,
        fallbackPath: desktopRatingsPath,
      ).push(context),
      bodyBuilder: (context, scrollController, sliver, _) => CustomScrollView(
        key: const PageStorageKey<String>('desktop:rated:list'),
        controller: scrollController,
        slivers: [sliver],
      ),
    );
  }
}
