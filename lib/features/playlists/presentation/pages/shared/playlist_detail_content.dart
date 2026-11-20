import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/providers/stable_set_selection.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_detail_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_mutation_events_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_editor_dialog.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/smart_playlist_editor.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_detail_action_menu.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_filter_drawer.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_filter_sections.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_sort_menu_button.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_banner_card.dart';
import 'package:sakuramedia/widgets/domain/tags/tag_filter_section.dart';

class PlaylistDetailContent extends ConsumerStatefulWidget {
  const PlaylistDetailContent({
    super.key,
    required this.playlistId,
    required this.surfaceColor,
    required this.onMovieTap,
    required this.fallbackPath,
    this.enablePullToRefresh = false,
  });

  final int playlistId;
  final Color surfaceColor;
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
  final ValueNotifier<bool> _tagSelectionActive = ValueNotifier<bool>(false);

  MovieSummaryScope? _scopeState;
  TagSelectionScope? _tagSelectionScopeState;
  PlaylistFilterState _savedFilterState = PlaylistFilterState.initial;
  List<int> _savedTagIds = const <int>[];
  TagMatchMode _savedTagMatch = TagMatchMode.or;

  MovieSummaryScope get _scope => _scopeState!;

  TagSelectionScope get _tagSelectionScope => _tagSelectionScopeState!;

  MovieCardHoverFeatureActions get _hoverFeatureActions =>
      movieCardHoverFeatureActions(context);

  PlaylistFilterState get _filterState =>
      ref.read(movieSummaryProvider(_scope)).value?.filter.playlist ??
      PlaylistFilterState.initial;

  @override
  String get batchKeyPrefix => 'playlist-detail';

  @override
  int? get batchExcludedPlaylistId => widget.playlistId;

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
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _tagSelectionActive.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureScopes(PlaylistDto playlist) {
    if (_scopeState != null) {
      return;
    }
    final smartFilter = playlist.smartFilter;
    _savedFilterState = PlaylistFilterState.fromSmartFilter(smartFilter);
    _savedTagIds = smartFilter?.tagIds ?? const <int>[];
    _savedTagMatch = TagMatchModeX.fromApiValue(smartFilter?.tagMatch ?? 'or');
    _scopeState = MovieSummaryScope.playlist(
      playlistId: widget.playlistId,
      initialPlaylistFilter: _savedFilterState,
      initialTagIds: _savedTagIds,
      initialTagMatch: _savedTagMatch,
    );
    _tagSelectionScopeState = TagSelectionScope.custom(
      instanceKey: 'playlist-detail:${widget.playlistId}',
      initialSelectedTagIds: _savedTagIds,
      initialMatchMode: _savedTagMatch,
      preload: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(playlistDetailProvider(widget.playlistId));
    if (detailAsync.isLoading && detailAsync.value == null) {
      return const PlaylistDetailLoadingContent();
    }

    if (detailAsync.hasError && detailAsync.value == null) {
      final l10n = AppLocalizations.of(context);
      return AppErrorState(
        title: l10n.playlistLoadFailed,
        message: playlistDetailErrorMessage(detailAsync.error!, l10n: l10n),
        retryKey: const Key('playlist-detail-error-retry'),
        onRetry: _retryInitialLoad,
      );
    }

    final playlist = detailAsync.value;
    if (playlist == null) {
      return const SizedBox.shrink();
    }
    _ensureScopes(playlist);

    final view = ref.watch(
      movieSummaryProvider(
        _scope,
      ).select((async) => pagedViewSnapshot(async, (state) => state.paged)),
    );
    final subscriptionUpdating = ref.watch(
      movieSummaryProvider(_scope).select(
        (async) => StableSetSelection<String>(
          async.value?.subscriptionUpdatingMovieNumbers ?? const <String>{},
        ),
      ),
    );
    final tagSelection = ref.watch(tagSelectionProvider(_tagSelectionScope));
    ref.listen(tagSelectionProvider(_tagSelectionScope), (previous, next) {
      if (previous == null) {
        return;
      }
      if (listEquals(previous.selectedTagIds, next.selectedTagIds) &&
          previous.matchMode == next.matchMode) {
        return;
      }
      _tagSelectionActive.value = !_tagsMatchSaved(next);
      _applyTagSelection(next);
    });

    return AppPageRefreshScope(
      onRefresh: _handleRefresh,
      child: Builder(
        builder: (context) {
          final canManage = playlist.isMutable || playlist.isDeletable;
          final slivers = <Widget>[
            AppPinnedSliverSection(
              headerKey: _listHeaderKey,
              before: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: context.appSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Stack(
                          children: [
                            PlaylistBannerCard(
                              key: Key('playlist-banner-card-${playlist.id}'),
                              title: playlist.name,
                              coverImageUrl:
                                  view.items.firstOrNull?.coverImage?.origin,
                              badgeLabel: playlist.isSmart
                                  ? AppLocalizations.of(
                                      context,
                                    ).playlistSmartBadge
                                  : null,
                            ),
                            if (canManage)
                              Positioned(
                                top: context.appSpacing.sm,
                                right: context.appSpacing.sm,
                                child: _PlaylistDetailMoreButton(
                                  onTap: (position) => unawaited(
                                    _openActionMenu(playlist, position),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (playlist.isSmart &&
                            playlist.smartFilter != null) ...[
                          SizedBox(height: context.appSpacing.sm),
                          _PlaylistSavedConditions(
                            summary: _smartFilterSummary(
                              playlist.smartFilter!,
                              AppLocalizations.of(context),
                            ),
                            onEdit: () => unawaited(_editPlaylist(playlist)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              header: selectionMode
                  ? (_isMobile
                        ? buildMobileBatchSelectionHeader()
                        : buildGlassBatchSelectionToolbar())
                  : _buildListHeader(context, playlist, view, tagSelection),
              headerBottomSpacing: _isMobile
                  ? context.appSpacing.md
                  : context.appSpacing.lg,
              after: <Widget>[
                if (!view.filterUpdate.hasFailed || view.items.isNotEmpty)
                  AppSkeletonizer.sliver(
                    enabled: view.isInitialLoading,
                    child: MovieSummarySliver(
                      items: view.isInitialLoading
                          ? movieListItemPlaceholders(count: 24)
                          : view.items,
                      errorMessage: view.initialError != null
                          ? _scope.errorText(AppLocalizations.of(context))
                          : null,
                      onMovieTap: (movie) => selectionAwareTap(
                        movie.movieNumber,
                        () => widget.onMovieTap(movie),
                      )(),
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
                          subscriptionUpdating.contains(movie.movieNumber),
                      emptyMessage:
                          !_hasTemporaryFilterChanges(
                            _filterState,
                            tagSelection,
                          )
                          ? AppLocalizations.of(context).playlistNoMovies
                          : AppLocalizations.of(
                              context,
                            ).playlistNoMatchingMovies,
                      selectionMode: selectionMode,
                      isMovieSelected: (movie) => isSelected(movie.movieNumber),
                      onMovieSelectedChanged: (movie, _) =>
                          handleSelectTap(movie.movieNumber),
                    ),
                  ),
                PagedLoadMoreFooterSliver(
                  topSpacing: PagedFooterSpacing.md,
                  watchFooter: (ref) => ref.watch(
                    movieSummaryProvider(_scope).select(
                      (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
                    ),
                  ),
                  onLoadMore: (ref) => unawaited(
                    ref.read(movieSummaryProvider(_scope).notifier).loadMore(),
                  ),
                ),
              ],
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
            // iOS 的刷新容器自带底部安全区留白（[AppAdaptiveRefreshScrollView]）。
            listContent = AppAdaptiveRefreshScrollView(
              onRefresh: _handleRefresh,
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: slivers,
            );
          } else {
            // Android 这条自己拼：下拉刷新壳不吃底部安全区，末尾要补留白。
            listContent = AppPullToRefresh(
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                slivers: [...slivers, ...bottomSafeAreaSliver(context)],
              ),
            );
          }

          final content = AppFilterResultLoadingOverlay(
            surfaceColor: widget.surfaceColor,
            protectedHeaderKey: _listHeaderKey,
            scrollController: _scrollController,
            isLoading: view.filterUpdate.isLoading,
            hasPreviousItems: view.items.isNotEmpty,
            child: AppPagedLoadMoreScope(
              canLoadMore: () =>
                  ref
                      .read(movieSummaryProvider(_scope))
                      .value
                      ?.paged
                      .canAutoLoadMore ??
                  false,
              onLoadMore: () =>
                  ref.read(movieSummaryProvider(_scope).notifier).loadMore(),
              child: listContent,
            ),
          );
          if (!_isMobile) {
            return content;
          }
          return Column(
            children: <Widget>[
              Expanded(child: content),
              if (selectionMode) buildMobileBatchSelectionBottomBar(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final l10n = AppLocalizations.of(context);
    try {
      await Future.wait<void>([
        ref.read(playlistDetailProvider(widget.playlistId).notifier).refresh(),
        ref.read(movieSummaryProvider(_scope).notifier).refresh(),
      ]);
    } catch (_) {
      if (mounted) {
        showToast(l10n.playlistRefreshFailed, tone: AppToastTone.error);
      }
    }
  }

  void _retryInitialLoad() {
    ref.invalidate(playlistDetailProvider(widget.playlistId));
    if (_scopeState != null) {
      ref.invalidate(movieSummaryProvider(_scope));
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
    final updated = playlist.isSmart
        ? await showSmartPlaylistEditor(context, playlist: playlist)
        : await showPlaylistEditor(
            context,
            playlist: playlist,
            presentation: _isMobile
                ? CollectionEditorPresentation.drawer
                : CollectionEditorPresentation.dialog,
          );
    if (!mounted || updated == null) {
      return;
    }
    ref
        .read(playlistDetailProvider(widget.playlistId).notifier)
        .applyUpdated(updated);
    ref.read(playlistMutationEventsProvider.notifier).reportUpdated(updated);
    if (playlist.isSmart) {
      final smartFilter = updated.smartFilter;
      _savedFilterState = PlaylistFilterState.fromSmartFilter(smartFilter);
      _savedTagIds = smartFilter?.tagIds ?? const <int>[];
      _savedTagMatch = TagMatchModeX.fromApiValue(
        smartFilter?.tagMatch ?? 'or',
      );
      _tagSelectionActive.value = false;
      final future = ref
          .read(movieSummaryProvider(_scope).notifier)
          .applyPlaylistViewFilter(
            _savedFilterState,
            tagIds: _savedTagIds,
            tagMatch: _savedTagMatch,
          );
      ref
          .read(tagSelectionProvider(_tagSelectionScope).notifier)
          .replaceSelection(_savedTagIds, matchMode: _savedTagMatch);
      unawaited(future);
    }
  }

  Future<void> _deletePlaylist(PlaylistDto playlist) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.playlistDeleteTitle,
      message: l10n.playlistDeleteMessage(playlist.name),
      danger: true,
      confirmLabel: l10n.commonDelete,
      dialogKey: const Key('playlist-detail-delete-confirm'),
      confirmKey: const Key('playlist-detail-delete-confirm-button'),
      failureFallback: l10n.playlistDeleteFailed,
      onConfirm: () =>
          ref.read(playlistsApiProvider).deletePlaylist(playlist.id),
    );
    if (!confirmed || !mounted) {
      return;
    }
    ref
        .read(playlistMutationEventsProvider.notifier)
        .reportDeleted(playlist.id);
    showToast(l10n.playlistDeletedToast, tone: AppToastTone.success);
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(widget.fallbackPath);
  }

  /// 列表顶栏：桌面使用 `AppGlassListHeader`，移动使用紧凑玻璃控制行。
  Widget _buildListHeader(
    BuildContext context,
    PlaylistDto playlist,
    PagedViewSnapshot<MovieListItemDto> view,
    TagSelectionState tagSelection,
  ) {
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final l10n = AppLocalizations.of(context);
    final filter = _filterState;
    final hasTempChanges = _hasTemporaryFilterChanges(filter, tagSelection);
    final total = view.isInitialLoading && view.total == 0
        ? playlist.movieCount
        : view.total;
    final countLabel = hasTempChanges
        ? l10n.playlistMovieCountTemporary(total, playlist.movieCount)
        : l10n.playlistMovieCount(total);
    final filterLabel = _playlistFilterLabel(filter, tagSelection, l10n);
    final savedSortLabel = playlistSortLabel(playlist.smartFilter?.sort, l10n);
    final defaultSortLabel = playlist.isSmart && savedSortLabel != null
        ? l10n.playlistSortSaved(savedSortLabel)
        : l10n.playlistSortDefault;
    final batchSelectButton = AppGlassHeaderButton(
      key: const Key('playlist-detail-enter-selection-button'),
      icon: Icons.check_circle_outline,
      label: l10n.baseSelect,
      enabled: batchSelectableNumbers.isNotEmpty,
      onTap: enterSelection,
    );
    if (isMobile) {
      return AppMobileListHeader(
        leading: AppMobileHeaderText(
          key: const Key('playlist-detail-total'),
          countLabel: countLabel,
        ),
        actions: <Widget>[
          AppGlassFilterIconButton(
            key: const Key('playlist-detail-filter-trigger'),
            summary: filterLabel,
            isActive: hasTempChanges,
            onPressed: () => unawaited(_openFilterDrawer()),
          ),
          PlaylistSortMenuButton(
            triggerKey: const Key('playlist-detail-sort-trigger'),
            panelKey: const Key('playlist-detail-sort-panel'),
            drawerKey: const Key('mobile-playlist-detail-sort-drawer'),
            keyPrefix: 'mobile-playlist',
            filterState: filter,
            onChanged: _applyFilter,
            defaultOptionLabel: defaultSortLabel,
            useDrawer: true,
            iconOnly: true,
          ),
          AppGlassIconButton(
            key: const Key('playlist-detail-enter-selection-button'),
            tooltip: l10n.baseSelect,
            icon: Icons.check_circle_outline,
            onPressed: batchSelectableNumbers.isEmpty ? null : enterSelection,
          ),
        ],
        filterUpdate: view.filterUpdate,
        hasPreviousFilterItems: view.items.isNotEmpty,
        onRetryFilter: () => unawaited(
          ref.read(movieSummaryProvider(_scope).notifier).retryFilter(),
        ),
      );
    }
    return AppGlassListHeader(
      leading: AppGlassFilterPopover(
        panelKey: const Key('playlist-detail-filter-panel'),
        scrollable: true,
        isDefault: !hasTempChanges,
        onReset: _resetFilters,
        resetKey: const Key('playlist-detail-filter-reset'),
        triggerKey: const Key('playlist-detail-filter-trigger'),
        label: filterLabel,
        tooltip: l10n.baseFilterTooltip,
        info: <Widget>[
          AppGlassHeaderText(
            key: const Key('playlist-detail-total'),
            label: countLabel,
          ),
        ],
        panelBuilder: (context) => PlaylistFilterSectionGroup(
          filterState: filter,
          onChanged: _applyFilter,
          tagSection: TagFilterSection(scope: _tagSelectionScope),
        ),
      ),
      trailing: AppGlassHeaderGroup(
        children: <Widget>[
          PlaylistSortMenuButton(
            triggerKey: const Key('playlist-detail-sort-trigger'),
            panelKey: const Key('playlist-detail-sort-panel'),
            filterState: filter,
            onChanged: _applyFilter,
            defaultOptionLabel: defaultSortLabel,
            glassGrouped: true,
            fieldControlKey: const Key('playlist-detail-sort-field'),
            directionControlKey: const Key('playlist-detail-sort-direction'),
          ),
          batchSelectButton,
        ],
      ),
      filterUpdate: view.filterUpdate,
      hasPreviousFilterItems: view.items.isNotEmpty,
      onRetryFilter: () => unawaited(
        ref.read(movieSummaryProvider(_scope).notifier).retryFilter(),
      ),
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
    final current = _filterState;
    final restored = _savedFilterState.copyWith(
      sortField: current.sortField,
      sortDirection: current.sortDirection,
    );
    _tagSelectionActive.value = false;
    final future = ref
        .read(movieSummaryProvider(_scope).notifier)
        .applyPlaylistViewFilter(
          restored,
          tagIds: _savedTagIds,
          tagMatch: _savedTagMatch,
        );
    ref
        .read(tagSelectionProvider(_tagSelectionScope).notifier)
        .replaceSelection(_savedTagIds, matchMode: _savedTagMatch);
    unawaited(future);
  }

  Future<void> _openFilterDrawer() async {
    final current = _filterState;
    final restored = _savedFilterState.copyWith(
      sortField: current.sortField,
      sortDirection: current.sortDirection,
    );
    await showMobilePlaylistFilterDrawer(
      context,
      current: current,
      initial: restored,
      onChanged: _applyFilter,
      tagSection: TagFilterSection(scope: _tagSelectionScope),
      extraActive: _tagSelectionActive,
      onReset: _resetFilters,
      isDefault: (value) =>
          value.matchesFilters(_savedFilterState) &&
          _tagsMatchSaved(ref.read(tagSelectionProvider(_tagSelectionScope))),
    );
  }

  bool _tagsMatchSaved(TagSelectionState selection) =>
      listEquals(selection.selectedTagIds, _savedTagIds) &&
      selection.matchMode == _savedTagMatch;

  bool _hasTemporaryFilterChanges(
    PlaylistFilterState filter,
    TagSelectionState tagSelection,
  ) =>
      !filter.matchesFilters(_savedFilterState) ||
      !_tagsMatchSaved(tagSelection);

  String _playlistFilterLabel(
    PlaylistFilterState filter,
    TagSelectionState tagSelection,
    AppLocalizations l10n,
  ) {
    final filterLabel = filter.triggerLabel(l10n);
    if (tagSelection.selectedTagIds.isEmpty) {
      return filterLabel;
    }
    final tagLabel = l10n.moviePageTagFilterCount(
      tagSelection.selectedTagIds.length,
    );
    if (!filter.hasActiveFilters) {
      return tagLabel;
    }
    return '$filterLabel · $tagLabel';
  }

  void _applyTagSelection(TagSelectionState selection) {
    final current = ref.read(movieSummaryProvider(_scope)).value?.filter;
    if (current != null &&
        listEquals(current.tagIds, selection.selectedTagIds) &&
        current.tagMatch == selection.matchMode) {
      return;
    }
    if (selectionMode) {
      exitSelection();
    }
    AppPinnedListHeader.scrollToStart(_listHeaderKey, _scrollController);
    final notifier = ref.read(movieSummaryProvider(_scope).notifier);
    if (selection.hasSelection) {
      unawaited(
        notifier.applyTagFilter(
          tagIds: selection.selectedTagIds,
          tagMatch: selection.matchMode,
        ),
      );
    } else {
      unawaited(notifier.clearTagFilter());
    }
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(movieSummaryProvider(_scope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }
}

String _smartFilterSummary(
  SmartPlaylistFilterDto filter,
  AppLocalizations l10n,
) {
  final parts = <String>[];
  final statusLabels = <String>[
    for (final value in filter.statuses)
      if (MovieStatusFilterX.fromApiValue(value) != MovieStatusFilter.all)
        MovieStatusFilterX.fromApiValue(value).labelWith(l10n),
  ];
  if (statusLabels.isNotEmpty) {
    parts.add(_multiLabel(statusLabels, l10n));
  }
  final watchLabels = <String>[
    for (final value in filter.watchStatuses)
      if (MovieWatchStatusFilterX.fromApiValue(value) !=
          MovieWatchStatusFilter.all)
        MovieWatchStatusFilterX.fromApiValue(value).labelWith(l10n),
  ];
  if (watchLabels.isNotEmpty) {
    parts.add(_multiLabel(watchLabels, l10n));
  }
  if (filter.years.isNotEmpty) {
    parts.add(movieFilterYearsLabel(filter.years.toSet(), l10n));
  }
  final resolutionLabels = filter.resolutions
      .map(PlaylistResolutionFilterX.fromApiValue)
      .whereType<PlaylistResolutionFilter>()
      .map((value) => value.label)
      .toList(growable: false);
  if (resolutionLabels.isNotEmpty) {
    parts.add(_multiLabel(resolutionLabels, l10n));
  }
  if (filter.tagIds.isNotEmpty) {
    parts.add(l10n.moviePageTagFilterCount(filter.tagIds.length));
  }
  if (filter.mediaTagIds.isNotEmpty) {
    parts.add(l10n.moviePageMediaTagCount(filter.mediaTagIds.length));
  }
  if (filter.actorIds.isNotEmpty) {
    parts.add(l10n.playlistSavedActorCount(filter.actorIds.length));
  }
  if (filter.actorAgeMin != null || filter.actorAgeMax != null) {
    parts.add(
      movieActorAgeRangeLabel(filter.actorAgeMin, filter.actorAgeMax, l10n),
    );
  }
  if (filter.heatMin != null || filter.heatMax != null) {
    parts.add(
      '${l10n.sharedInteractionHeat} '
      '${movieInteractionRangeLabel(MovieInteractionMetric.heat, filter.heatMin, filter.heatMax, l10n)}',
    );
  }
  final collectionType = MovieCollectionTypeFilterX.fromApiValue(
    filter.collectionType,
  );
  if (collectionType != MovieCollectionTypeFilter.all) {
    parts.add(collectionType.labelWith(l10n));
  }
  final numberSource = MovieNumberSourceFilterX.fromApiValue(
    filter.numberSource,
  );
  if (numberSource != MovieNumberSourceFilter.all) {
    parts.add(numberSource.labelWith(l10n));
  }
  return parts.isEmpty ? l10n.playlistFilterAll : parts.join(' · ');
}

String _multiLabel(List<String> labels, AppLocalizations l10n) {
  if (labels.length == 1) {
    return labels.single;
  }
  return l10n.playlistFilterSummary(labels.first, labels.length - 1);
}

class _PlaylistSavedConditions extends StatelessWidget {
  const _PlaylistSavedConditions({required this.summary, required this.onEdit});

  final String summary;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      key: const Key('playlist-detail-saved-conditions'),
      children: [
        Expanded(
          child: Text(
            '${l10n.playlistSavedConditions} · $summary',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
        ),
        AppTextButton(
          key: const Key('playlist-detail-edit-smart-conditions'),
          label: l10n.playlistEditSmartConditions,
          size: AppTextButtonSize.xSmall,
          onPressed: onEdit,
        ),
      ],
    );
  }
}

class PlaylistDetailLoadingContent extends StatelessWidget {
  const PlaylistDetailLoadingContent({super.key});

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
          ...bottomSafeAreaSliver(context),
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
        tooltip: AppLocalizations.of(context).playlistActionsTooltip,
        semanticLabel: AppLocalizations.of(context).playlistActionsTooltip,
        borderRadius: context.appRadius.pillBorder,
        backgroundColor: colors.mediaOverlayStrong,
        borderColor: colors.mediaOverlayBorder,
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
