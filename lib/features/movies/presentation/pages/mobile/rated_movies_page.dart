import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/rated_movies_header.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';

/// 移动端「我的评分」页：与桌面共用同一 scope 和排序抽屉。
class MobileRatedMoviesPage extends ConsumerWidget {
  const MobileRatedMoviesPage({super.key});

  static const _scope = MovieSummaryScope.ratedList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MovieSummaryListContent(
      scope: _scope,
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('mobile-rated-movies-page'),
      sectionSpacing: context.appSpacing.md,
      emptyMessage: AppLocalizations.of(context).moviePageEmptyNotRated,
      headerBuilder: (context, args) =>
          RatedMoviesHeader(args: args, isMobile: true),
      trailingLabelForMovie: (movie) =>
          ratedTotalLabel(movie, l10n: AppLocalizations.of(context)),
      onMovieTap: (context, movieNumber) =>
          MobileRoutes.movieDetail(movieNumber: movieNumber).push(context),
      bodyBuilder: (context, scrollController, sliver, onRefresh) =>
          AppAdaptiveRefreshScrollView(
            key: const PageStorageKey<String>('mobile:rated:list'),
            onRefresh: onRefresh!,
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[sliver],
          ),
      enableRefresh: true,
      onRefreshFailure: (context) => showToast(
        AppLocalizations.of(context).moviePageRefreshFailed,
        tone: AppToastTone.error,
      ),
    );
  }
}
