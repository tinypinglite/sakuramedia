import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

class DesktopFollowPage extends StatefulWidget {
  const DesktopFollowPage({super.key});

  @override
  State<DesktopFollowPage> createState() => _DesktopFollowPageState();
}

class _DesktopFollowPageState extends State<DesktopFollowPage> {
  late final PagedMovieSummaryController _moviesController;
  late final MovieCollectionTypeChangeNotifier _collectionChangeNotifier;
  late final MovieSubscriptionChangeNotifier _subscriptionChangeNotifier;

  @override
  void initState() {
    super.initState();
    _collectionChangeNotifier =
        context.read<MovieCollectionTypeChangeNotifier>();
    _collectionChangeNotifier.addListener(_onCollectionTypeChanged);
    _subscriptionChangeNotifier =
        context.read<MovieSubscriptionChangeNotifier>();
    _subscriptionChangeNotifier.addListener(_onMovieSubscriptionChanged);

    _moviesController = PagedMovieSummaryController(
      fetchPage:
          (page, pageSize) => context
              .read<MoviesApi>()
              .getSubscribedActorsLatestMovies(page: page, pageSize: pageSize),
      subscribeMovie: context.read<MoviesApi>().subscribeMovie,
      unsubscribeMovie: context.read<MoviesApi>().unsubscribeMovie,
      onSubscriptionChanged: _reportSubscriptionChange,
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
    _subscriptionChangeNotifier.removeListener(_onMovieSubscriptionChanged);
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

  void _onMovieSubscriptionChanged() {
    final change = _subscriptionChangeNotifier.lastChange;
    if (change == null) {
      return;
    }
    _moviesController.applySubscriptionChange(
      movieNumber: change.movieNumber,
      isSubscribed: change.isSubscribed,
    );
  }

  void _reportSubscriptionChange({
    required String movieNumber,
    required bool isSubscribed,
  }) {
    _subscriptionChangeNotifier.reportChange(
      movieNumber: movieNumber,
      isSubscribed: isSubscribed,
    );
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
    return AppPageRefreshScope(
      onRefresh: _moviesController.refresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: CustomScrollView(
          controller: _moviesController.scrollController,
          slivers: [
            AnimatedBuilder(
            animation: _moviesController,
            builder: (context, _) {
              final showFooter =
                  _moviesController.items.isNotEmpty &&
                  (_moviesController.isLoadingMore ||
                      _moviesController.loadMoreErrorMessage != null);
              return SliverMainAxisGroup(
                key: const Key('desktop-follow-page'),
                slivers: [
                  SliverToBoxAdapter(
                    child: AppFilterTotalHeader(
                      leading: Text(
                        '女优上新',
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s18,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                      ),
                      totalText: '${_moviesController.total} 部',
                      totalKey: const Key('desktop-follow-page-total'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: context.appSpacing.lg),
                  ),
                  MovieSummarySliver(
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
                          isSubscribed: movie.isSubscribed,
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
                  if (showFooter)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: context.appSpacing.md),
                        child: AppPagedLoadMoreFooter(
                          isLoading: _moviesController.isLoadingMore,
                          errorMessage: _moviesController.loadMoreErrorMessage,
                          onRetry: _moviesController.loadMore,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          ],
        ),
      ),
    );
  }
}
