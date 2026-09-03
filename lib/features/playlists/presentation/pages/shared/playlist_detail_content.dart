import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_detail_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_resolution_options_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_filter_drawer.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_filter_sections.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_banner_card.dart';

class PlaylistDetailContent extends ConsumerStatefulWidget {
  const PlaylistDetailContent({
    super.key,
    required this.playlistId,
    required this.onMovieTap,
    this.enablePullToRefresh = false,
  });

  final int playlistId;
  final ValueChanged<MovieListItemDto> onMovieTap;
  final bool enablePullToRefresh;

  @override
  ConsumerState<PlaylistDetailContent> createState() =>
      _PlaylistDetailContentState();
}

class _PlaylistDetailContentState extends ConsumerState<PlaylistDetailContent>
    with
        MultiSelectStateMixin<PlaylistDetailContent, String>,
        MovieBatchSelectionMixin<PlaylistDetailContent> {
  late final ScrollController _scrollController;

  MovieSummaryScope get _scope =>
      MovieSummaryScope.playlist(playlistId: widget.playlistId);

  PlaylistFilterState get _filterState =>
      ref.read(movieSummaryProvider(_scope)).value?.filter.playlist ??
      PlaylistFilterState.initial;

  @override
  String get batchKeyPrefix => 'playlist-detail';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor =>
      ref.read(movieSummaryProvider(_scope).notifier).batchToggleSubscription;

  @override
  List<String> get batchSelectableNumbers =>
      ref
          .read(movieSummaryProvider(_scope))
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
    final position = _scrollController.position;
    final summary = ref.read(movieSummaryProvider(_scope)).value;
    if (summary == null ||
        summary.paged.loadMoreErrorMessage != null ||
        position.pixels < position.maxScrollExtent - 300) {
      return;
    }
    unawaited(ref.read(movieSummaryProvider(_scope).notifier).loadMore());
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(playlistDetailProvider(widget.playlistId));
    final moviesAsync = ref.watch(movieSummaryProvider(_scope));
    final movies = moviesAsync.value;
    final paged = movies?.paged;

    return AppPageRefreshScope(
      onRefresh: _handleRefresh,
      child: Builder(
        builder: (context) {
          if (detailAsync.isLoading && detailAsync.value == null) {
            return const _PlaylistDetailLoadingContent();
          }

          if (detailAsync.hasError && detailAsync.value == null) {
            return AppEmptyState(
              message: playlistDetailErrorMessage(detailAsync.error!),
            );
          }

          final playlist = detailAsync.value;
          if (playlist == null) {
            return const SizedBox.shrink();
          }
          final footer = _buildLoadMoreFooter(context, movies);
          final slivers = <Widget>[
            SliverToBoxAdapter(
              child: PlaylistBannerCard(
                key: Key('playlist-banner-card-${playlist.id}'),
                title: playlist.name,
                coverImageUrl:
                    paged?.items.firstOrNull?.coverImage?.bestAvailableUrl,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: context.appSpacing.sm),
                child: selectionMode
                    ? buildBatchSelectionToolbar()
                    : _buildListHeader(context, playlist.movieCount, paged),
              ),
            ),
            if (!(paged?.filterUpdate.hasFailed ?? false) ||
                (paged?.items.isNotEmpty ?? false))
              MovieSummarySliver(
                items: paged?.items ?? const [],
                isLoading: moviesAsync.isLoading && movies == null,
                errorMessage: moviesAsync.hasError && movies == null
                    ? _scope.initialLoadErrorText
                    : null,
                onMovieTap: widget.onMovieTap,
                onMovieMenuRequest: (movie, globalPosition) =>
                    requestMovieCollectionMenu(
                      context,
                      movie.movieNumber,
                      globalPosition,
                      isSubscribed: movie.isSubscribed,
                    ),
                onMovieSubscriptionTap: (movie) =>
                    _toggleMovieSubscription(movie.movieNumber),
                isMovieSubscriptionUpdating: (movie) =>
                    movies?.isSubscriptionUpdating(movie.movieNumber) ?? false,
                emptyMessage: _filterState.isDefault
                    ? '暂无影片数据'
                    : '当前筛选条件下暂无匹配影片',
                selectionMode: selectionMode,
                isMovieSelected: (movie) => isSelected(movie.movieNumber),
                onMovieSelectedChanged: (movie, _) =>
                    toggleSelect(movie.movieNumber),
              ),
            if (footer != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: context.appSpacing.md),
                  child: footer,
                ),
              ),
          ];
          final scrollView = CustomScrollView(
            physics: widget.enablePullToRefresh
                ? const AlwaysScrollableScrollPhysics()
                : null,
            controller: _scrollController,
            slivers: slivers,
          );

          final Widget listContent;
          if (!widget.enablePullToRefresh) {
            listContent = scrollView;
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            listContent = AppAdaptiveRefreshScrollView(
              onRefresh: _handleRefresh,
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: slivers,
            );
          } else {
            listContent = AppPullToRefresh(
              onRefresh: _handleRefresh,
              child: scrollView,
            );
          }

          return AppFilterResultLoadingOverlay(
            isLoading: paged?.filterUpdate.isLoading ?? false,
            hasPreviousItems: paged?.items.isNotEmpty ?? false,
            child: listContent,
          );
        },
      ),
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await Future.wait<void>([
        ref.read(playlistDetailProvider(widget.playlistId).notifier).refresh(),
        ref.read(movieSummaryProvider(_scope).notifier).refresh(),
        ref
            .read(playlistResolutionOptionsProvider(widget.playlistId).notifier)
            .refresh(),
      ]);
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }

  /// 列表顶栏：与影片 / 女优列表共用同一条 `AppListHeader`。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
  ///
  /// 分辨率状态通过 [playlistResolutionOptionsProvider] 暴露（惰性加载，面板首次
  /// 打开才拉取），widgets 层通过纯值 [PlaylistResolutionOptionsState] 传入，
  /// 桌面/移动都实时跟随 provider 更新；抽屉里的重试按钮也能正确刷新。
  Widget _buildListHeader(
    BuildContext context,
    int totalMovies,
    PagedListState<MovieListItemDto>? paged,
  ) {
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    return AppListHeader(
      filterButtonKey: const Key('playlist-detail-filter-trigger'),
      filterLabel: _filterState.triggerLabel,
      filterPanelKey: const Key('playlist-detail-filter-panel'),
      filterUpdate: paged?.filterUpdate ?? const FilterUpdateState.idle(),
      hasPreviousFilterItems: paged?.items.isNotEmpty ?? false,
      onRetryFilter: () => unawaited(
        ref.read(movieSummaryProvider(_scope).notifier).retryFilter(),
      ),
      onFilterTap: isMobile ? () => unawaited(_openFilterDrawer()) : null,
      filterPanelBuilder: isMobile
          ? null
          : (_) => Consumer(
              builder: (context, ref, _) {
                final resolutionState = ref.watch(
                  playlistResolutionOptionsProvider(widget.playlistId),
                );
                return PlaylistFilterSectionGroup(
                  filterState: _filterState,
                  onChanged: _applyFilter,
                  resolutionState: resolutionState,
                  onResolutionRetry: () => unawaited(
                    ref
                        .read(
                          playlistResolutionOptionsProvider(
                            widget.playlistId,
                          ).notifier,
                        )
                        .retry(),
                  ),
                );
              },
            ),
      onFilterPanelOpened: isMobile
          ? null
          : () => unawaited(
              ref
                  .read(
                    playlistResolutionOptionsProvider(
                      widget.playlistId,
                    ).notifier,
                  )
                  .ensureLoaded(),
            ),
      filterPanelFooter: AppFilterPanelFooter(
        isDefault: _filterState.isDefault,
        onReset: _resetFilters,
      ),
      informationSlots: [
        AppListHeaderInfo(
          key: const Key('playlist-detail-total'),
          label: '$totalMovies 部影片',
        ),
      ],
      actionSlots: [buildEnterSelectionButton()],
    );
  }

  void _applyFilter(PlaylistFilterState nextState) {
    if (nextState.matches(_filterState)) {
      return;
    }
    // 切筛选跨结果集，选中态失去意义。
    if (selectionMode) {
      exitSelection();
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    unawaited(
      ref
          .read(movieSummaryProvider(_scope).notifier)
          .applyPlaylistFilter(nextState),
    );
  }

  void _resetFilters() {
    _applyFilter(PlaylistFilterState.initial);
  }

  Future<void> _openFilterDrawer() async {
    // 分辨率状态由 provider 惰性加载，抽屉打开时若还没加载过就触发一次。
    // 抽屉内部通过 resolutionStateBuilder 回调实时读 provider 快照——移动抽屉
    // 是 modal route 且 build 是同步的，每次 build 都会调 builder 拿最新状态。
    unawaited(
      ref
          .read(playlistResolutionOptionsProvider(widget.playlistId).notifier)
          .ensureLoaded(),
    );
    await showMobilePlaylistFilterDrawer(
      context,
      current: _filterState,
      onChanged: _applyFilter,
      resolutionStateBuilder: (_) =>
          ref.read(playlistResolutionOptionsProvider(widget.playlistId)),
      onResolutionRetry: () => unawaited(
        ref
            .read(playlistResolutionOptionsProvider(widget.playlistId).notifier)
            .retry(),
      ),
    );
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(movieSummaryProvider(_scope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  Widget? _buildLoadMoreFooter(
    BuildContext context, [
    MovieSummaryState? summary,
  ]) {
    final paged =
        summary?.paged ?? ref.read(movieSummaryProvider(_scope)).value?.paged;
    if (paged == null || paged.items.isEmpty) {
      return null;
    }

    if (paged.isLoadingMore) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
          child: const AppInlineSpinner(),
        ),
      );
    }

    if (paged.loadMoreErrorMessage == null) {
      return null;
    }

    return Center(
      child: TextButton(
        onPressed: () =>
            ref.read(movieSummaryProvider(_scope).notifier).loadMore(),
        child: Text(paged.loadMoreErrorMessage!),
      ),
    );
  }
}

class _PlaylistDetailLoadingContent extends StatelessWidget {
  const _PlaylistDetailLoadingContent();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return CustomScrollView(
      key: const Key('playlist-detail-loading'),
      slivers: [
        const SliverToBoxAdapter(child: PlaylistBannerCardSkeleton()),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: spacing.sm),
            child: Row(
              children: [
                const AppSkeletonBlock(width: 96, height: 14),
                const Spacer(),
                AppSkeletonBlock(
                  width: 76,
                  height: context.appComponentTokens.buttonHeightXs,
                  radius: context.appRadius.pillBorder,
                ),
              ],
            ),
          ),
        ),
        const MovieSummarySliver(
          items: <MovieListItemDto>[],
          isLoading: true,
          placeholderCount: 12,
          onMovieTap: _ignoreMovieTap,
        ),
      ],
    );
  }
}

void _ignoreMovieTap(MovieListItemDto _) {}
