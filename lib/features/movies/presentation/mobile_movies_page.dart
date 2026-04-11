import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/movie_list_page_state.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/movies/movie_filter_toolbar.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';

class MobileMoviesPage extends StatefulWidget {
  const MobileMoviesPage({super.key});

  @override
  State<MobileMoviesPage> createState() => _MobileMoviesPageState();
}

class _MobileMoviesPageState extends State<MobileMoviesPage> {
  late final MovieListPageStateEntry _pageState;
  late final bool _ownsPageState;

  PagedMovieSummaryController get _moviesController => _pageState.controller;
  MovieFilterState get _filterState => _pageState.filterState;

  @override
  void initState() {
    super.initState();
    final cache = maybeReadAppPageStateCache(context);
    if (cache == null) {
      _ownsPageState = true;
      _pageState = MovieListPageStateEntry(
        moviesApi: context.read<MoviesApi>(),
      );
      return;
    }

    _ownsPageState = false;
    _pageState = cache.obtain<MovieListPageStateEntry>(
      key: mobileMoviesPageStateKey(),
      create:
          () => MovieListPageStateEntry(moviesApi: context.read<MoviesApi>()),
    );
  }

  @override
  void dispose() {
    if (_ownsPageState) {
      _pageState.dispose();
    }
    super.dispose();
  }

  void _applyFilter(MovieFilterState nextState) {
    if (nextState.status == _filterState.status &&
        nextState.collectionType == _filterState.collectionType &&
        nextState.sortField == _filterState.sortField &&
        nextState.sortDirection == _filterState.sortDirection) {
      return;
    }
    setState(() {
      _pageState.filterState = nextState;
    });
    if (_moviesController.scrollController.hasClients) {
      _moviesController.scrollController.jumpTo(0);
    }
    unawaited(_moviesController.reload());
  }

  void _resetFilters() {
    _applyFilter(MovieFilterState.initial);
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await _moviesController.toggleSubscription(
      movieNumber: movieNumber,
    );
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: AppPullToRefresh(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _moviesController.scrollController,
          child: AnimatedBuilder(
            animation: _moviesController,
            builder: (context, _) {
              final showFooter =
                  _moviesController.items.isNotEmpty &&
                  (_moviesController.isLoadingMore ||
                      _moviesController.loadMoreErrorMessage != null);

              return Column(
                key: const Key('mobile-movies-page'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppFilterTotalHeader(
                    leading: MovieFilterToolbar(
                      filterState: _filterState,
                      onChanged: _applyFilter,
                      onReset: _resetFilters,
                    ),
                    totalText: '${_moviesController.total} 部',
                    totalKey: const Key('mobile-movies-page-total'),
                  ),
                  SizedBox(height: context.appSpacing.md),
                  MovieSummaryGrid(
                    items: _moviesController.items,
                    isLoading: _moviesController.isInitialLoading,
                    errorMessage: _moviesController.initialErrorMessage,
                    onMovieTap:
                        (movie) => MobileMovieDetailRouteData(
                          movieNumber: movie.movieNumber,
                        ).push(context),
                    onMovieMenuRequest: (movie, globalPosition) {
                      unawaited(
                        showMovieCollectionFeatureActionMenu(
                          context: context,
                          movieNumber: movie.movieNumber,
                          globalPosition: globalPosition,
                        ),
                      );
                    },
                    onMovieSubscriptionTap:
                        (movie) => _toggleMovieSubscription(movie.movieNumber),
                    isMovieSubscriptionUpdating:
                        (movie) => _moviesController.isSubscriptionUpdating(
                          movie.movieNumber,
                        ),
                    emptyMessage: '暂无影片数据',
                  ),
                  if (showFooter) ...[
                    SizedBox(height: context.appSpacing.md),
                    AppPagedLoadMoreFooter(
                      isLoading: _moviesController.isLoadingMore,
                      errorMessage: _moviesController.loadMoreErrorMessage,
                      onRetry: _moviesController.loadMore,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await _moviesController.refresh();
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }
}
