import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/movie_list_page_state.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';

class MobileMoviesPage extends StatefulWidget {
  const MobileMoviesPage({super.key});

  @override
  State<MobileMoviesPage> createState() => _MobileMoviesPageState();
}

class _MobileMoviesPageState extends State<MobileMoviesPage> {
  late final CachedPageStateHandle<MovieListPageStateEntry> _pageStateHandle;

  MovieListPageStateEntry get _pageState => _pageStateHandle.value;

  @override
  void initState() {
    super.initState();
    _pageStateHandle = obtainCachedPageState<MovieListPageStateEntry>(
      context,
      key: mobileMoviesPageStateKey(),
      create:
          () => MovieListPageStateEntry(moviesApi: context.read<MoviesApi>()),
    );
  }

  @override
  void dispose() {
    _pageStateHandle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MovieListContent(
      pageState: _pageState,
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('mobile-movies-page'),
      totalKey: const Key('mobile-movies-page-total'),
      sectionSpacing: context.appSpacing.md,
      onMovieTap:
          (context, movieNumber) => MobileMovieDetailRouteData(
            movieNumber: movieNumber,
          ).push(context),
      bodyBuilder:
          (context, scrollController, child, onRefresh) => AppPullToRefresh(
            onRefresh: onRefresh!,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: scrollController,
              child: child,
            ),
          ),
      enableRefresh: true,
      onRefreshFailure: (_) => showToast('刷新失败'),
    );
  }
}
