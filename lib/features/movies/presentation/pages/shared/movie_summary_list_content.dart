import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

typedef MovieSummaryListBodyBuilder =
    Widget Function(
      BuildContext context,
      ScrollController scrollController,
      Widget sliver,
      Future<void> Function()? onRefresh,
    );

typedef MovieSummaryListHeaderBuilder =
    Widget Function(BuildContext context, MovieSummaryListHeaderArgs args);

class MovieSummaryListHeaderArgs {
  const MovieSummaryListHeaderArgs({
    required this.filterState,
    required this.onApply,
    required this.total,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieFilterState> onApply;
  final int total;
}

/// Riverpod 版影片列表共用渲染壳。
///
/// 影片库缓存页先使用这条 `movies` scope；标签页完成自身选择状态迁移后也会
/// 收敛到同一组件。滚动控制器仍归 View 所有，数据、筛选、订阅和广播补丁全部由
/// [movieSummaryProvider] 承担。
class MovieSummaryListContent extends ConsumerStatefulWidget {
  const MovieSummaryListContent({
    super.key,
    required this.scope,
    required this.surfaceColor,
    required this.contentKey,
    required this.totalKey,
    required this.sectionSpacing,
    required this.onMovieTap,
    required this.bodyBuilder,
    this.emptyMessage,
    this.enableRefresh = false,
    this.registerPageRefresh = false,
    this.onRefreshFailure,
    this.headerBuilder,
    this.useMobileSelectionLayout = false,
  });

  final MovieSummaryScope scope;
  final Color surfaceColor;
  final Key contentKey;
  final Key totalKey;
  final double sectionSpacing;
  final void Function(BuildContext context, String movieNumber) onMovieTap;
  final MovieSummaryListBodyBuilder bodyBuilder;
  final String? emptyMessage;
  final bool enableRefresh;
  final bool registerPageRefresh;
  final void Function(BuildContext context)? onRefreshFailure;
  final MovieSummaryListHeaderBuilder? headerBuilder;
  final bool useMobileSelectionLayout;

  @override
  ConsumerState<MovieSummaryListContent> createState() =>
      _MovieSummaryListContentState();
}

class _MovieSummaryListContentState
    extends ConsumerState<MovieSummaryListContent>
    with
        MultiSelectStateMixin<MovieSummaryListContent, String>,
        MovieBatchSelectionMixin<MovieSummaryListContent> {
  late final ScrollController _scrollController;

  @override
  String get batchKeyPrefix => 'movie-list';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor => ref
      .read(movieSummaryProvider(widget.scope).notifier)
      .batchToggleSubscription;

  @override
  MovieBlacklistBatchExecutor get batchBlacklistExecutor =>
      ref.read(movieSummaryProvider(widget.scope).notifier).blacklistMovies;

  @override
  List<String> get batchSelectableNumbers =>
      ref
          .read(movieSummaryProvider(widget.scope))
          .value
          ?.paged
          .items
          .map((movie) => movie.movieNumber)
          .toList(growable: false) ??
      const <String>[];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) {
      return;
    }
    final summary = ref.read(movieSummaryProvider(widget.scope)).value;
    final position = _scrollController.position;
    if (summary == null ||
        summary.paged.loadMoreErrorMessage != null ||
        position.pixels < position.maxScrollExtent - 300) {
      return;
    }
    unawaited(ref.read(movieSummaryProvider(widget.scope).notifier).loadMore());
  }

  void _applyFilter(MovieFilterState nextState) {
    final current =
        ref.read(movieSummaryProvider(widget.scope)).value?.filter.movie ??
        MovieFilterState.initial;
    if (nextState.matches(current)) {
      return;
    }
    if (selectionMode) {
      exitSelection();
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    unawaited(
      ref
          .read(movieSummaryProvider(widget.scope).notifier)
          .applyMovieFilter(nextState),
    );
  }

  void _resetFilters() => _applyFilter(MovieFilterState.initial);

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(movieSummaryProvider(widget.scope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  Future<void> _handleRefresh() async {
    final error = await ref
        .read(movieSummaryProvider(widget.scope).notifier)
        .refresh();
    if (error == null || !mounted) {
      return;
    }
    final onRefreshFailure = widget.onRefreshFailure;
    if (onRefreshFailure != null) {
      onRefreshFailure(context);
    } else {
      showToast('刷新失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(movieSummaryProvider(widget.scope));
    final summary = moviesAsync.value;
    final paged = summary?.paged;
    final filter = summary?.filter.movie ?? MovieFilterState.initial;
    final items = paged?.items ?? const [];
    final isInitialLoading = moviesAsync.isLoading && summary == null;
    final initialErrorMessage = moviesAsync.hasError && summary == null
        ? widget.scope.initialLoadErrorText
        : null;
    final showFooter =
        items.isNotEmpty &&
        (paged!.isLoadingMore || paged.loadMoreErrorMessage != null);

    ref.listen(movieCollectionTypeEventsProvider, (_, next) {
      final change = next.value;
      if (change == null ||
          change.targetType != MovieCollectionType.collection ||
          filter.collectionType != MovieCollectionTypeFilter.single ||
          !selectionMode ||
          !selectedIds.contains(change.movieNumber)) {
        return;
      }
      setState(() => selectedIds.remove(change.movieNumber));
    });

    final headerBuilder = widget.headerBuilder;
    final Widget header;
    if (selectionMode) {
      header = widget.useMobileSelectionLayout
          ? buildMobileBatchSelectionHeader()
          : buildBatchSelectionToolbar();
    } else if (headerBuilder != null) {
      header = headerBuilder(
        context,
        MovieSummaryListHeaderArgs(
          filterState: filter,
          onApply: _applyFilter,
          total: paged?.total ?? 0,
        ),
      );
    } else {
      header = AppListHeader(
        filterButtonKey: const Key('movies-filter-trigger'),
        filterLabel: filter.triggerLabel,
        filterPanelKey: const Key('movies-filter-panel'),
        filterPanelBuilder: (_) => MovieFilterSectionGroup(
          filterState: filter,
          onChanged: _applyFilter,
        ),
        filterPanelFooter: AppFilterPanelFooter(
          isDefault: filter.isDefault,
          onReset: _resetFilters,
        ),
        informationSlots: [
          AppListHeaderInfo(
            key: widget.totalKey,
            label: '${paged?.total ?? 0} 部',
          ),
        ],
        actionSlots: [buildEnterSelectionButton()],
      );
    }

    final body = ColoredBox(
      color: widget.surfaceColor,
      child: AppFilterResultLoadingOverlay(
        isLoading: paged?.filterUpdate.isLoading ?? false,
        hasPreviousItems: items.isNotEmpty,
        child: widget.bodyBuilder(
          context,
          _scrollController,
          SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  key: widget.contentKey,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    AppFilterUpdateBar(
                      state:
                          paged?.filterUpdate ?? const FilterUpdateState.idle(),
                      hasPreviousItems: items.isNotEmpty,
                      onRetry: () => unawaited(
                        ref
                            .read(movieSummaryProvider(widget.scope).notifier)
                            .retryFilter(),
                      ),
                    ),
                    SizedBox(height: widget.sectionSpacing),
                  ],
                ),
              ),
              if (!(paged?.filterUpdate.hasFailed ?? false) || items.isNotEmpty)
                MovieSummarySliver(
                  items: items,
                  isLoading: isInitialLoading,
                  errorMessage: initialErrorMessage,
                  onMovieTap: (movie) =>
                      widget.onMovieTap(context, movie.movieNumber),
                  onMovieMenuRequest: (movie, globalPosition) {
                    unawaited(
                      showMovieCollectionFeatureActionMenu(
                        context: context,
                        movieNumber: movie.movieNumber,
                        globalPosition: globalPosition,
                        isSubscribed: movie.isSubscribed,
                        onBlacklisted: () => ref
                            .read(movieSummaryProvider(widget.scope).notifier)
                            .removeMovies(<String>[movie.movieNumber]),
                        onEnterSelection: widget.useMobileSelectionLayout
                            ? () {
                                enterSelection();
                                toggleSelect(movie.movieNumber);
                              }
                            : null,
                      ),
                    );
                  },
                  onMovieSubscriptionTap: (movie) =>
                      _toggleMovieSubscription(movie.movieNumber),
                  isMovieSubscriptionUpdating: (movie) =>
                      summary?.isSubscriptionUpdating(movie.movieNumber) ??
                      false,
                  emptyMessage:
                      widget.emptyMessage ??
                      (filter.isDefault ? '暂无影片，去搜索看看吧' : '当前筛选条件下暂无匹配影片'),
                  selectionMode: selectionMode,
                  isMovieSelected: (movie) => isSelected(movie.movieNumber),
                  onMovieSelectedChanged: (movie, _) =>
                      toggleSelect(movie.movieNumber),
                ),
              if (showFooter)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: context.appSpacing.md),
                    child: AppPagedLoadMoreFooter(
                      isLoading: paged.isLoadingMore,
                      errorMessage: paged.loadMoreErrorMessage,
                      onRetry: () => ref
                          .read(movieSummaryProvider(widget.scope).notifier)
                          .loadMore(),
                    ),
                  ),
                ),
            ],
          ),
          widget.enableRefresh ? _handleRefresh : null,
        ),
      ),
    );

    final content = widget.useMobileSelectionLayout
        ? Column(
            children: [
              Expanded(child: body),
              if (selectionMode) buildMobileBatchSelectionBottomBar(),
            ],
          )
        : body;
    return widget.registerPageRefresh
        ? AppPageRefreshScope(onRefresh: _handleRefresh, child: content)
        : content;
  }
}
