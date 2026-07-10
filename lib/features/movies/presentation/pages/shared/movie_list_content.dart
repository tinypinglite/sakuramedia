import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_list_filterable_page_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_toolbar.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

typedef MovieListBodyBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
  Widget child,
  Future<void> Function()? onRefresh,
);

typedef MovieListHeaderBuilder = Widget Function(
  BuildContext context,
  MovieListHeaderArgs args,
);

class MovieListHeaderArgs {
  const MovieListHeaderArgs({
    required this.filterState,
    required this.onApply,
    required this.onReset,
    required this.total,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieFilterState> onApply;
  final VoidCallback onReset;
  final int total;
}

class MovieListContent extends StatefulWidget {
  const MovieListContent({
    super.key,
    required this.pageState,
    required this.surfaceColor,
    required this.contentKey,
    required this.totalKey,
    required this.sectionSpacing,
    required this.onMovieTap,
    required this.bodyBuilder,
    this.emptyMessage,
    this.enableRefresh = false,
    this.onRefreshFailure,
    this.headerBuilder,
  });

  final MovieListFilterablePageState pageState;
  final Color surfaceColor;
  final Key contentKey;
  final Key totalKey;
  final double sectionSpacing;
  final void Function(BuildContext context, String movieNumber) onMovieTap;
  final MovieListBodyBuilder bodyBuilder;

  /// 为空时的提示文案；不传时按当前筛选状态自动决定：
  /// 未筛选(默认态)提示去搜索,已应用筛选则提示当前筛选下无匹配。
  final String? emptyMessage;
  final bool enableRefresh;
  final void Function(BuildContext context)? onRefreshFailure;

  /// 可选 header builder：传入则替代默认 `AppFilterTotalHeader + MovieFilterToolbar`。
  /// 移动 tab 主页用它注入 `AppMobileTabHeader` + 底抽屉范式。
  final MovieListHeaderBuilder? headerBuilder;

  @override
  State<MovieListContent> createState() => _MovieListContentState();
}

class _MovieListContentState extends State<MovieListContent> {
  late final MovieCollectionTypeChangeNotifier _collectionChangeNotifier;

  @override
  void initState() {
    super.initState();
    _collectionChangeNotifier =
        context.read<MovieCollectionTypeChangeNotifier>();
    _collectionChangeNotifier.addListener(_onCollectionTypeChanged);
  }

  @override
  void dispose() {
    _collectionChangeNotifier.removeListener(_onCollectionTypeChanged);
    super.dispose();
  }

  void _onCollectionTypeChanged() {
    final change = _collectionChangeNotifier.lastChange;
    if (change == null) {
      return;
    }
    final filterState = widget.pageState.filterState;
    if (change.targetType == MovieCollectionType.collection &&
        filterState.collectionType == MovieCollectionTypeFilter.single) {
      widget.pageState.controller.removeItem(change.movieNumber);
    }
  }

  void _applyFilter(MovieFilterState nextState) {
    final filterState = widget.pageState.filterState;
    if (nextState.matches(filterState)) {
      return;
    }
    setState(() {
      widget.pageState.filterState = nextState;
    });
    final controller = widget.pageState.controller;
    if (controller.scrollController.hasClients) {
      controller.scrollController.jumpTo(0);
    }
    unawaited(controller.reload());
  }

  void _resetFilters() {
    _applyFilter(MovieFilterState.initial);
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await widget.pageState.controller.toggleSubscription(
      movieNumber: movieNumber,
    );
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  Future<void> _handleRefresh() async {
    try {
      await widget.pageState.controller.refresh();
    } catch (_) {
      if (mounted) {
        final onRefreshFailure = widget.onRefreshFailure;
        if (onRefreshFailure != null) {
          onRefreshFailure(context);
        } else {
          showToast('刷新失败');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.pageState.controller;
    return ColoredBox(
      color: widget.surfaceColor,
      child: widget.bodyBuilder(
        context,
        controller.scrollController,
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final showFooter = controller.items.isNotEmpty &&
                (controller.isLoadingMore ||
                    controller.loadMoreErrorMessage != null);
            final headerBuilder = widget.headerBuilder;
            final header = headerBuilder != null
                ? headerBuilder(
                    context,
                    MovieListHeaderArgs(
                      filterState: widget.pageState.filterState,
                      onApply: _applyFilter,
                      onReset: _resetFilters,
                      total: controller.total,
                    ),
                  )
                : AppFilterTotalHeader(
                    leading: MovieFilterToolbar(
                      filterState: widget.pageState.filterState,
                      onChanged: _applyFilter,
                      onReset: _resetFilters,
                    ),
                    totalText: '${controller.total} 部',
                    totalKey: widget.totalKey,
                  );
            return Column(
              key: widget.contentKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                SizedBox(height: widget.sectionSpacing),
                MovieSummaryGrid(
                  items: controller.items,
                  isLoading: controller.isInitialLoading,
                  errorMessage: controller.initialErrorMessage,
                  onMovieTap: (movie) =>
                      widget.onMovieTap(context, movie.movieNumber),
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
                  onMovieSubscriptionTap: (movie) =>
                      _toggleMovieSubscription(movie.movieNumber),
                  isMovieSubscriptionUpdating: (movie) =>
                      controller.isSubscriptionUpdating(movie.movieNumber),
                  emptyMessage: widget.emptyMessage ??
                      (widget.pageState.filterState.isDefault
                          ? '暂无影片，去搜索看看吧'
                          : '当前筛选条件下暂无匹配影片'),
                ),
                if (showFooter) ...[
                  SizedBox(height: context.appSpacing.md),
                  AppPagedLoadMoreFooter(
                    isLoading: controller.isLoadingMore,
                    errorMessage: controller.loadMoreErrorMessage,
                    onRetry: controller.loadMore,
                  ),
                ],
              ],
            );
          },
        ),
        widget.enableRefresh ? _handleRefresh : null,
      ),
    );
  }
}
