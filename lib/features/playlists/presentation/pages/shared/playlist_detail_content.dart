import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_detail_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_mutation_events_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/edit_playlist_dialog.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_detail_action_menu.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_filter_drawer.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_filter_sections.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_banner_card.dart';

class PlaylistDetailContent extends ConsumerStatefulWidget {
  const PlaylistDetailContent({
    super.key,
    required this.playlistId,
    required this.onMovieTap,
    required this.fallbackPath,
    this.enablePullToRefresh = false,
  });

  final int playlistId;
  final ValueChanged<MovieListItemDto> onMovieTap;

  /// 深链进入时没有可 pop 的上一页，删除成功后回到该列表页。
  final String fallbackPath;
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
  final _listHeaderKey = GlobalKey();

  MovieSummaryScope get _scope =>
      MovieSummaryScope.playlist(playlistId: widget.playlistId);

  MovieCardHoverFeatureActions get _hoverFeatureActions =>
      movieCardHoverFeatureActions(context);

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
          final canManage = playlist.isMutable || playlist.isDeletable;
          final footer = _buildLoadMoreFooter(context, movies);
          final slivers = <Widget>[
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  PlaylistBannerCard(
                    key: Key('playlist-banner-card-${playlist.id}'),
                    title: playlist.name,
                    coverImageUrl: paged
                        ?.items
                        .firstOrNull
                        ?.coverImage
                        ?.bestAvailableUrl,
                  ),
                  if (canManage)
                    Positioned(
                      top: context.appSpacing.sm,
                      right: context.appSpacing.sm,
                      child: _PlaylistDetailMoreButton(
                        onTap: (position) =>
                            unawaited(_openActionMenu(playlist, position)),
                      ),
                    ),
                ],
              ),
            ),
            AppPinnedListHeader(
              key: _listHeaderKey,
              color: context.appColors.surfaceElevated,
              child: Padding(
                padding: EdgeInsets.only(bottom: context.appSpacing.sm),
                child: selectionMode
                    ? buildBatchSelectionToolbar()
                    : _buildListHeader(context, playlist.movieCount, paged),
              ),
            ),
            if (!(paged?.filterUpdate.hasFailed ?? false) ||
                (paged?.items.isNotEmpty ?? false))
              AppSkeletonizer.sliver(
                enabled: moviesAsync.isLoading && movies == null,
                child: MovieSummarySliver(
                  items: moviesAsync.isLoading && movies == null
                      ? movieListItemPlaceholders(count: 24)
                      : paged?.items ?? const [],
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
                  onMovieToggleCollectionType:
                      _hoverFeatureActions.toggleCollectionType,
                  onMovieBlacklist: _hoverFeatureActions.blacklist,
                  isMovieSubscriptionUpdating: (movie) =>
                      movies?.isSubscriptionUpdating(movie.movieNumber) ??
                      false,
                  emptyMessage: _filterState.isDefault
                      ? '暂无影片数据'
                      : '当前筛选条件下暂无匹配影片',
                  selectionMode: selectionMode,
                  isMovieSelected: (movie) => isSelected(movie.movieNumber),
                  onMovieSelectedChanged: (movie, _) =>
                      toggleSelect(movie.movieNumber),
                ),
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
            protectedHeaderKey: _listHeaderKey,
            scrollController: _scrollController,
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
      ]);
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }

  bool get _isMobile => AppPlatformScope.maybeOf(context) == AppPlatform.mobile;

  Future<void> _openActionMenu(PlaylistDto playlist, Offset position) async {
    final action = await showPlaylistDetailActionMenu(
      context: context,
      playlist: playlist,
      presentation: _isMobile
          ? AppMenuPresentation.bottomDrawer
          : AppMenuPresentation.popup,
      position: position,
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case PlaylistDetailActionType.edit:
        await _editPlaylist(playlist);
      case PlaylistDetailActionType.delete:
        await _deletePlaylist(playlist);
    }
  }

  Future<void> _editPlaylist(PlaylistDto playlist) async {
    final updated = await showEditPlaylistDialog(
      context,
      playlist: playlist,
      presentation: _isMobile
          ? EditPlaylistDialogPresentation.bottomDrawer
          : EditPlaylistDialogPresentation.dialog,
    );
    if (!mounted || updated == null) {
      return;
    }
    ref
        .read(playlistDetailProvider(widget.playlistId).notifier)
        .applyUpdated(updated);
    ref.read(playlistMutationEventsProvider.notifier).reportUpdated(updated);
  }

  Future<void> _deletePlaylist(PlaylistDto playlist) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除播放列表',
      message: '确认删除播放列表“${playlist.name}”？该操作不可恢复。',
      danger: true,
      confirmLabel: '删除',
      dialogKey: const Key('playlist-detail-delete-confirm'),
      confirmKey: const Key('playlist-detail-delete-confirm-button'),
      failureFallback: '删除播放列表失败',
      onConfirm: () =>
          ref.read(playlistsApiProvider).deletePlaylist(playlist.id),
    );
    if (!confirmed || !mounted) {
      return;
    }
    ref
        .read(playlistMutationEventsProvider.notifier)
        .reportDeleted(playlist.id);
    showToast('播放列表已删除');
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(widget.fallbackPath);
  }

  /// 列表顶栏：与影片 / 女优列表共用同一条 `AppListHeader`。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
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
          : (_) => PlaylistFilterSectionGroup(
              filterState: _filterState,
              onChanged: _applyFilter,
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
    AppPinnedListHeader.scrollToStart(_listHeaderKey, _scrollController);
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
    await showMobilePlaylistFilterDrawer(
      context,
      current: _filterState,
      onChanged: _applyFilter,
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
    // loading 用占位影片渲染真实网格，由 [AppSkeletonizer] 统一灰化。
    return AppSkeletonizer(
      enabled: true,
      child: CustomScrollView(
        key: const Key('playlist-detail-loading'),
        slivers: [
          SliverToBoxAdapter(
            child: PlaylistBannerCard(
              title: BoneMock.words(2),
              coverImageUrl: null,
            ),
          ),
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
          MovieSummarySliver(
            items: movieListItemPlaceholders(count: 12),
            onMovieTap: _ignoreMovieTap,
          ),
        ],
      ),
    );
  }
}

void _ignoreMovieTap(MovieListItemDto _) {}

/// 横幅右上角常显「···」：桌面点击弹锚点菜单，移动端弹底部操作表。
class _PlaylistDetailMoreButton extends StatelessWidget {
  const _PlaylistDetailMoreButton({required this.onTap});

  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Builder(
      builder: (buttonContext) => AppIconButton(
        key: const Key('playlist-detail-more-actions-button'),
        size: AppIconButtonSize.mini,
        tooltip: '播放列表操作',
        semanticLabel: '播放列表操作',
        borderRadius: context.appRadius.pillBorder,
        backgroundColor: colors.mediaOverlayStrong,
        borderColor: colors.borderSubtle.withValues(alpha: 0.42),
        iconColor: context.appTextPalette.onMedia,
        icon: const Icon(Icons.more_horiz_rounded),
        onPressed: () {
          final box = buttonContext.findRenderObject()! as RenderBox;
          onTap(box.localToGlobal(Offset(box.size.width, box.size.height)));
        },
      ),
    );
  }
}
