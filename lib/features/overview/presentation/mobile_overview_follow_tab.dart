import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movies/mobile_follow_movie_card.dart';

class MobileOverviewFollowTab extends StatefulWidget {
  const MobileOverviewFollowTab({super.key});

  @override
  State<MobileOverviewFollowTab> createState() =>
      _MobileOverviewFollowTabState();
}

class _MobileOverviewFollowTabState extends State<MobileOverviewFollowTab> {
  static const int _detailConcurrentLimit = 1;
  static const int _detailStillImageLimit = 8;

  late final PagedMovieSummaryController _moviesController;
  late final MovieCollectionTypeChangeNotifier _collectionChangeNotifier;
  late final MovieSubscriptionChangeNotifier _subscriptionChangeNotifier;
  final Map<String, _FollowMovieDetailState> _movieDetailStates =
      <String, _FollowMovieDetailState>{};
  final Queue<String> _detailQueue = Queue<String>();
  final Set<String> _queuedMovieNumbers = <String>{};
  int _activeDetailRequests = 0;

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
      pageSize: 20,
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
      _movieDetailStates.remove(change.movieNumber);
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

  void _ensureMovieDetailLoaded(String movieNumber) {
    if (_movieDetailStates.containsKey(movieNumber)) {
      return;
    }
    _movieDetailStates[movieNumber] = const _FollowMovieDetailState.loading();
    if (mounted) {
      setState(() {});
    }
    if (_activeDetailRequests < _detailConcurrentLimit) {
      unawaited(_loadMovieDetail(movieNumber));
      return;
    }
    if (_queuedMovieNumbers.add(movieNumber)) {
      _detailQueue.add(movieNumber);
    }
  }

  Future<void> _loadMovieDetail(String movieNumber) async {
    _activeDetailRequests += 1;
    try {
      final detail = await context.read<MoviesApi>().getMovieDetail(
        movieNumber: movieNumber,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _movieDetailStates[movieNumber] = _FollowMovieDetailState.success(
          detail: detail,
          stillImageLimit: _detailStillImageLimit,
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _movieDetailStates[movieNumber] = const _FollowMovieDetailState.error();
      });
    } finally {
      _activeDetailRequests -= 1;
      _drainDetailQueue();
    }
  }

  void _drainDetailQueue() {
    if (!mounted) {
      _detailQueue.clear();
      _queuedMovieNumbers.clear();
      return;
    }
    while (_activeDetailRequests < _detailConcurrentLimit &&
        _detailQueue.isNotEmpty) {
      final movieNumber = _detailQueue.removeFirst();
      _queuedMovieNumbers.remove(movieNumber);
      unawaited(_loadMovieDetail(movieNumber));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: AppAdaptiveRefreshScrollView(
        onRefresh: _handleRefresh,
        controller: _moviesController.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          AnimatedBuilder(
            animation: _moviesController,
            builder: (context, _) => _buildContentSliver(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSliver(BuildContext context) {
    if (_moviesController.isInitialLoading && _moviesController.items.isEmpty) {
      return const SliverToBoxAdapter(child: _FollowTabLoadingState());
    }

    if (_moviesController.initialErrorMessage != null &&
        _moviesController.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppEmptyState(
                    message: _moviesController.initialErrorMessage!,
                  ),
                  SizedBox(height: context.appSpacing.xs),
                  TextButton(
                    onPressed: _moviesController.reload,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_moviesController.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            const Center(child: AppEmptyState(message: '暂无关注影片')),
          ],
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.only(
        top: context.appSpacing.sm,
        bottom: context.appSpacing.md,
      ),
      sliver: SliverList(
        key: const Key('mobile-overview-follow-list'),
        delegate: SliverChildListDelegate(_buildFollowListChildren(context)),
      ),
    );
  }

  List<Widget> _buildFollowListChildren(BuildContext context) {
    final children = <Widget>[];
    final showFooter =
        _moviesController.isLoadingMore ||
        _moviesController.loadMoreErrorMessage != null;

    for (var index = 0; index < _moviesController.items.length; index += 1) {
      if (index > 0) {
        children.add(SizedBox(height: context.appSpacing.sm));
      }

      final movie = _moviesController.items[index];
      final detailState = _movieDetailStates[movie.movieNumber];
      children.add(
        MobileFollowMovieCard(
          movie: movie,
          onTap:
              () => MobileMovieDetailRouteData(
                movieNumber: movie.movieNumber,
              ).push(context),
          onSubscriptionTap: () => _toggleMovieSubscription(movie.movieNumber),
          isSubscriptionUpdating: _moviesController.isSubscriptionUpdating(
            movie.movieNumber,
          ),
          isDetailLoading:
              detailState == null ||
              detailState.status == _FollowMovieDetailStatus.loading,
          detailStillImageUrls: detailState?.stillImageUrls ?? const [],
          detailSummary: detailState?.summary,
          detailThinCoverUrl: detailState?.thinCoverUrl,
          onVisible: () => _ensureMovieDetailLoaded(movie.movieNumber),
        ),
      );
    }

    if (showFooter) {
      children.add(SizedBox(height: context.appSpacing.sm));
      children.add(
        AppPagedLoadMoreFooter(
          isLoading: _moviesController.isLoadingMore,
          errorMessage: _moviesController.loadMoreErrorMessage,
          onRetry: _moviesController.loadMore,
        ),
      );
    }

    return children;
  }

  Future<void> _handleRefresh() async {
    try {
      _movieDetailStates.clear();
      _detailQueue.clear();
      _queuedMovieNumbers.clear();
      _activeDetailRequests = 0;
      await _moviesController.refresh();
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }
}

enum _FollowMovieDetailStatus { loading, success, error }

class _FollowMovieDetailState {
  const _FollowMovieDetailState._({
    required this.status,
    required this.summary,
    required this.thinCoverUrl,
    required this.stillImageUrls,
  });

  const _FollowMovieDetailState.loading()
    : this._(
        status: _FollowMovieDetailStatus.loading,
        summary: null,
        thinCoverUrl: null,
        stillImageUrls: const <String>[],
      );

  const _FollowMovieDetailState.error()
    : this._(
        status: _FollowMovieDetailStatus.error,
        summary: null,
        thinCoverUrl: null,
        stillImageUrls: const <String>[],
      );

  factory _FollowMovieDetailState.success({
    required MovieDetailDto detail,
    required int stillImageLimit,
  }) {
    final stillImageUrls = detail.plotImages
        .map((image) => image.bestAvailableUrl.trim())
        .where((url) => url.isNotEmpty)
        .take(stillImageLimit)
        .toList(growable: false);
    final summary =
        detail.summary.trim().isEmpty ? detail.title : detail.summary;
    final thinCoverUrl =
        detail.thinCoverImage?.bestAvailableUrl.trim().isNotEmpty ?? false
            ? detail.thinCoverImage!.bestAvailableUrl.trim()
            : detail.coverImage?.bestAvailableUrl.trim();
    return _FollowMovieDetailState._(
      status: _FollowMovieDetailStatus.success,
      summary: summary,
      thinCoverUrl: thinCoverUrl,
      stillImageUrls: stillImageUrls,
    );
  }

  final _FollowMovieDetailStatus status;
  final String? summary;
  final String? thinCoverUrl;
  final List<String> stillImageUrls;
}

class _FollowTabLoadingState extends StatelessWidget {
  const _FollowTabLoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(
        top: context.appSpacing.sm,
        bottom: context.appSpacing.md,
      ),
      child: Column(
        children: List<Widget>.generate(4, (index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == 3 ? 0 : context.appSpacing.sm,
            ),
            child: Container(
              key: Key('mobile-overview-follow-skeleton-$index'),
              height: 216,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: context.appRadius.mdBorder,
              ),
            ),
          );
        }),
      ),
    );
  }
}
