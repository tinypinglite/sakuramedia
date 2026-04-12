import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/data/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';

class DesktopFollowPage extends StatefulWidget {
  const DesktopFollowPage({super.key});

  @override
  State<DesktopFollowPage> createState() => _DesktopFollowPageState();
}

class _DesktopFollowPageState extends State<DesktopFollowPage> {
  late final PagedMovieSummaryController _moviesController;
  late final MovieCollectionTypeChangeNotifier _collectionChangeNotifier;

  @override
  void initState() {
    super.initState();
    _collectionChangeNotifier =
        context.read<MovieCollectionTypeChangeNotifier>();
    _collectionChangeNotifier.addListener(_onCollectionTypeChanged);

    _moviesController = PagedMovieSummaryController(
      fetchPage:
          (page, pageSize) => context
              .read<MoviesApi>()
              .getSubscribedActorsLatestMovies(page: page, pageSize: pageSize),
      subscribeMovie: context.read<MoviesApi>().subscribeMovie,
      unsubscribeMovie: context.read<MoviesApi>().unsubscribeMovie,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
      initialLoadErrorText: '关注影片加载失败，请稍后重试',
      loadMoreErrorText: '加载更多失败，请点击重试',
    );
    _moviesController.attachScrollListener();
    _moviesController.initialize();
  }

  @override
  void dispose() {
    _collectionChangeNotifier.removeListener(_onCollectionTypeChanged);
    _moviesController.dispose();
    super.dispose();
  }

  void _onCollectionTypeChanged() {
    final change = _collectionChangeNotifier.lastChange;
    if (change == null) {
      return;
    }
    if (change.targetType == MovieCollectionType.collection) {
      _moviesController.removeItem(change.movieNumber);
    }
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
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _moviesController.scrollController,
        child: AnimatedBuilder(
          animation: _moviesController,
          builder: (context, _) {
            final showFooter =
                _moviesController.items.isNotEmpty &&
                (_moviesController.isLoadingMore ||
                    _moviesController.loadMoreErrorMessage != null);
            return Column(
              key: const Key('desktop-follow-page'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFilterTotalHeader(
                  leading: Text(
                    '女优上新',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  totalText: '${_moviesController.total} 部',
                  totalKey: const Key('desktop-follow-page-total'),
                ),
                SizedBox(height: context.appSpacing.lg),
                MovieSummaryGrid(
                  items: _moviesController.items,
                  isLoading: _moviesController.isInitialLoading,
                  errorMessage: _moviesController.initialErrorMessage,
                  onMovieTap:
                      (movie) => context.pushDesktopMovieDetail(
                        movieNumber: movie.movieNumber,
                        fallbackPath: desktopFollowPath,
                      ),
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
                  emptyMessage: '暂无关注影片',
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
    );
  }
}
