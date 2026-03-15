import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
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
  static const int _detailConcurrentLimit = 3;

  late final PagedMovieSummaryController _moviesController;
  final Map<String, _FollowMovieDetailState> _movieDetailStates =
      <String, _FollowMovieDetailState>{};
  final Queue<String> _detailQueue = Queue<String>();
  final Set<String> _queuedMovieNumbers = <String>{};
  int _activeDetailRequests = 0;

  @override
  void initState() {
    super.initState();
    _moviesController = PagedMovieSummaryController(
      fetchPage:
          (page, pageSize) => context
              .read<MoviesApi>()
              .getSubscribedActorsLatestMovies(page: page, pageSize: pageSize),
      subscribeMovie: context.read<MoviesApi>().subscribeMovie,
      unsubscribeMovie: context.read<MoviesApi>().unsubscribeMovie,
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
    _moviesController.dispose();
    super.dispose();
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
      child: AnimatedBuilder(
        animation: _moviesController,
        builder: (context, _) {
          if (_moviesController.isInitialLoading &&
              _moviesController.items.isEmpty) {
            return const _FollowTabLoadingState();
          }

          if (_moviesController.initialErrorMessage != null &&
              _moviesController.items.isEmpty) {
            return Center(
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
            );
          }

          if (_moviesController.items.isEmpty) {
            return const Center(child: AppEmptyState(message: '暂无关注影片'));
          }

          final showFooter =
              _moviesController.isLoadingMore ||
              _moviesController.loadMoreErrorMessage != null;
          return ListView.separated(
            key: const Key('mobile-overview-follow-list'),
            controller: _moviesController.scrollController,
            padding: EdgeInsets.only(
              top: context.appSpacing.sm,
              bottom: context.appSpacing.md,
            ),
            itemCount: _moviesController.items.length + (showFooter ? 1 : 0),
            separatorBuilder:
                (_, __) => SizedBox(height: context.appSpacing.sm),
            itemBuilder: (context, index) {
              if (index >= _moviesController.items.length) {
                return AppPagedLoadMoreFooter(
                  isLoading: _moviesController.isLoadingMore,
                  errorMessage: _moviesController.loadMoreErrorMessage,
                  onRetry: _moviesController.loadMore,
                );
              }

              final movie = _moviesController.items[index];
              final detailState = _movieDetailStates[movie.movieNumber];
              return MobileFollowMovieCard(
                movie: movie,
                onTap:
                    () => context.push(
                      buildMobileMovieDetailRoutePath(movie.movieNumber),
                      extra: mobileOverviewPath,
                    ),
                onSubscriptionTap:
                    () => _toggleMovieSubscription(movie.movieNumber),
                isSubscriptionUpdating: _moviesController
                    .isSubscriptionUpdating(movie.movieNumber),
                isDetailLoading:
                    detailState == null ||
                    detailState.status == _FollowMovieDetailStatus.loading,
                detailStillImageUrls: detailState?.stillImageUrls ?? const [],
                detailSummary: detailState?.summary,
                detailThinCoverUrl: detailState?.thinCoverUrl,
                onVisible: () => _ensureMovieDetailLoaded(movie.movieNumber),
              );
            },
          );
        },
      ),
    );
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

  factory _FollowMovieDetailState.success({required MovieDetailDto detail}) {
    final stillImageUrls = detail.plotImages
        .map((image) => image.bestAvailableUrl.trim())
        .where((url) => url.isNotEmpty)
        .take(24)
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
    return ListView.separated(
      padding: EdgeInsets.only(
        top: context.appSpacing.sm,
        bottom: context.appSpacing.md,
      ),
      itemCount: 4,
      separatorBuilder: (_, __) => SizedBox(height: context.appSpacing.sm),
      itemBuilder:
          (_, index) => Container(
            key: Key('mobile-overview-follow-skeleton-$index'),
            height: 216,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: context.appRadius.mdBorder,
            ),
          ),
    );
  }
}
