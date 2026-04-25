import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';

typedef SeriesMoviesBodyBuilder =
    Widget Function(
      BuildContext context,
      ScrollController scrollController,
      Widget child,
      Future<void> Function()? onRefresh,
    );

class SeriesMoviesContent extends StatefulWidget {
  const SeriesMoviesContent({
    super.key,
    required this.seriesId,
    required this.surfaceColor,
    required this.contentKey,
    required this.totalKey,
    required this.sectionSpacing,
    required this.onMovieTap,
    required this.bodyBuilder,
    this.initialSeriesName,
    this.enableRefresh = false,
    this.onRefreshFailure,
  });

  final int seriesId;
  final String? initialSeriesName;
  final Color surfaceColor;
  final Key contentKey;
  final Key totalKey;
  final double sectionSpacing;
  final void Function(BuildContext context, String movieNumber) onMovieTap;
  final SeriesMoviesBodyBuilder bodyBuilder;
  final bool enableRefresh;
  final void Function(BuildContext context)? onRefreshFailure;

  @override
  State<SeriesMoviesContent> createState() => _SeriesMoviesContentState();
}

class _SeriesMoviesContentState extends State<SeriesMoviesContent> {
  late final PagedMovieSummaryController _controller;
  late final MovieSubscriptionChangeNotifier _subscriptionChangeNotifier;
  late final String? _initialSeriesName;

  @override
  void initState() {
    super.initState();
    _initialSeriesName = _normalizeSeriesName(widget.initialSeriesName);
    _subscriptionChangeNotifier =
        context.read<MovieSubscriptionChangeNotifier>();
    _subscriptionChangeNotifier.addListener(_onMovieSubscriptionChanged);
    _controller = PagedMovieSummaryController(
      fetchPage:
          (page, pageSize) => context.read<MoviesApi>().getMoviesBySeries(
            seriesId: widget.seriesId,
            page: page,
            pageSize: pageSize,
          ),
      subscribeMovie: context.read<MoviesApi>().subscribeMovie,
      unsubscribeMovie: context.read<MoviesApi>().unsubscribeMovie,
      onSubscriptionChanged: _reportSubscriptionChange,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
      initialLoadErrorText: '系列影片加载失败，请稍后重试',
      loadMoreErrorText: '加载更多失败，请点击重试',
    );
    _controller.attachScrollListener();
    _controller.initialize();
  }

  @override
  void dispose() {
    _subscriptionChangeNotifier.removeListener(_onMovieSubscriptionChanged);
    _controller.dispose();
    super.dispose();
  }

  String get _displaySeriesName {
    final initialSeriesName = _initialSeriesName;
    if (initialSeriesName != null) {
      return initialSeriesName;
    }
    for (final movie in _controller.items) {
      final seriesName = movie.seriesName.trim();
      if (seriesName.isNotEmpty) {
        return seriesName;
      }
    }
    return '系列 #${widget.seriesId}';
  }

  void _onMovieSubscriptionChanged() {
    final change = _subscriptionChangeNotifier.lastChange;
    if (change == null) {
      return;
    }
    _controller.applySubscriptionChange(
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
    final result = await _controller.toggleSubscription(
      movieNumber: movieNumber,
    );
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  Future<void> _handleRefresh() async {
    try {
      await _controller.refresh();
    } catch (_) {
      if (!mounted) {
        return;
      }
      final onRefreshFailure = widget.onRefreshFailure;
      if (onRefreshFailure != null) {
        onRefreshFailure(context);
      } else {
        showToast('刷新失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.surfaceColor,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final showFooter =
              _controller.items.isNotEmpty &&
              (_controller.isLoadingMore ||
                  _controller.loadMoreErrorMessage != null);
          return widget.bodyBuilder(
            context,
            _controller.scrollController,
            Column(
              key: widget.contentKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SeriesMoviesHeader(
                  seriesName: _displaySeriesName,
                  total: _controller.total,
                  totalKey: widget.totalKey,
                ),
                SizedBox(height: widget.sectionSpacing),
                _buildMoviesArea(context),
                if (showFooter) ...[
                  SizedBox(height: context.appSpacing.md),
                  AppPagedLoadMoreFooter(
                    isLoading: _controller.isLoadingMore,
                    errorMessage: _controller.loadMoreErrorMessage,
                    onRetry: _controller.loadMore,
                  ),
                ],
              ],
            ),
            widget.enableRefresh ? _handleRefresh : null,
          );
        },
      ),
    );
  }

  Widget _buildMoviesArea(BuildContext context) {
    if (_controller.initialErrorMessage != null &&
        !_controller.isInitialLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppEmptyState(message: _controller.initialErrorMessage!),
          SizedBox(height: context.appSpacing.md),
          Center(
            child: TextButton(
              onPressed: _controller.reload,
              child: const Text('重试'),
            ),
          ),
        ],
      );
    }

    return MovieSummaryGrid(
      items: _controller.items,
      isLoading: _controller.isInitialLoading,
      onMovieTap: (movie) => widget.onMovieTap(context, movie.movieNumber),
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
          (movie) => _controller.isSubscriptionUpdating(movie.movieNumber),
      emptyMessage: '该系列暂无影片',
    );
  }

  String? _normalizeSeriesName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class _SeriesMoviesHeader extends StatelessWidget {
  const _SeriesMoviesHeader({
    required this.seriesName,
    required this.total,
    required this.totalKey,
  });

  final String seriesName;
  final int total;
  final Key totalKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Container(
      key: const Key('series-movies-header-card'),
      width: double.infinity,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.smBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Row(
        children: [
         
          Expanded(
            child: Text(
              seriesName,
              key: const Key('series-movies-title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.medium,
                tone: AppTextTone.primary,
              ),
            ),
          ),
          SizedBox(width: spacing.md),
          Text(
            '共 $total 部',
            key: totalKey,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.medium,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
