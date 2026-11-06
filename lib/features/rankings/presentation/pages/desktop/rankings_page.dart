import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/format/synced_at_label.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_provider.dart';
import 'package:sakuramedia/features/rankings/presentation/rankings_placeholders.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_scope.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/providers/stable_set_selection.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/rankings/ranking_sort_menu_button.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranked_movie_summary_grid.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranking_filter_sections.dart';

class DesktopRankingsPage extends ConsumerStatefulWidget {
  const DesktopRankingsPage({super.key});

  @override
  ConsumerState<DesktopRankingsPage> createState() =>
      _DesktopRankingsPageState();
}

class _DesktopRankingsPageState extends ConsumerState<DesktopRankingsPage>
    with
        MultiSelectStateMixin<DesktopRankingsPage, String>,
        MovieBatchSelectionMixin<DesktopRankingsPage> {
  static const _scope = RankingSummaryScope.desktop();

  late final RiverpodPageHandle _pageCacheHandle;
  late final ScrollController _scrollController;

  MovieCardHoverFeatureActions get _hoverFeatureActions =>
      movieCardHoverFeatureActions(context);

  @override
  String get batchKeyPrefix => 'desktop-rankings';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor =>
      ref.read(rankingSummaryProvider(_scope).notifier).batchToggleSubscription;

  @override
  List<String> get batchSelectableNumbers =>
      ref
          .read(rankingSummaryProvider(_scope))
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
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: desktopRankingsPageCacheKey(),
          resolveLinks: () {
            final link = ref
                .read(rankingSummaryProvider(_scope).notifier)
                .cacheLink;
            return link == null ? const [] : [link];
          },
        );
  }

  @override
  void dispose() {
    _pageCacheHandle.release();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(rankingSummaryProvider(_scope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  void _applyFilterChange(Future<void> Function() action) {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    unawaited(action());
  }

  /// 与移动榜单页共用同一条顶栏：筛选入口（当前榜单）+ 总数 / 更新时间信息槽。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
  Widget _buildHeader(
    BuildContext context,
    PagedViewSnapshot<RankedMovieListItemDto> paged,
    RankingFilterState filters,
    DateTime? syncedAt,
  ) {
    final l10n = AppLocalizations.of(context);
    // 与移动端同一套单值语义：只报「榜单」这一主维度。
    final boardLabel =
        filters.selectedBoard?.name ??
        filters.selectedSource?.name ??
        l10n.rankingAllBoards;
    final syncedAtLabel = formatSyncedAtLabel(
      syncedAt,
      l10n: AppLocalizations.of(context),
      withPrefix: false,
    );

    return AppGlassListHeader(
      leading: AppGlassFilterPopover(
        panelKey: const Key('rankings-filter-panel'),
        scrollable: true,
        showResetFooter: false,
        enabled: filters.sources.isNotEmpty,
        triggerKey: const Key('desktop-rankings-filter-trigger'),
        label: boardLabel,
        info: <Widget>[
          AppGlassHeaderText(
            key: const Key('desktop-rankings-page-total'),
            label: l10n.sharedMovieCount(paged.total),
          ),
          if (syncedAtLabel != null)
            AppGlassHeaderText(
              key: const Key('desktop-rankings-synced-at'),
              label: syncedAtLabel,
            ),
        ],
        panelBuilder: (context) => RankingFilterSectionGroup(
          sources: filters.sources,
          selectedSource: filters.selectedSource,
          boards: filters.boards,
          selectedBoard: filters.selectedBoard,
          selectedPeriod: filters.selectedPeriod,
          isBoardLoading: filters.isLoading,
          onSourceChanged: (value) => _applyFilterChange(
            () => ref
                .read(rankingSummaryProvider(_scope).notifier)
                .selectSource(value),
          ),
          onBoardChanged: (value) => _applyFilterChange(
            () => ref
                .read(rankingSummaryProvider(_scope).notifier)
                .selectBoard(value),
          ),
          onPeriodChanged: (value) => _applyFilterChange(
            () => ref
                .read(rankingSummaryProvider(_scope).notifier)
                .selectPeriod(value),
          ),
          interaction: filters.interaction,
          onInteractionChanged: (value) => _applyFilterChange(
            () => ref
                .read(rankingSummaryProvider(_scope).notifier)
                .selectInteraction(value),
          ),
        ),
      ),
      trailing: AppGlassHeaderGroup(
        children: <Widget>[
          RankingSortMenuButton(
            triggerKey: const Key('rankings-sort-trigger'),
            panelKey: const Key('rankings-sort-panel'),
            filterState: filters,
            glassGrouped: true,
            onSortChanged: (field, direction) => _applyFilterChange(
              () => ref
                  .read(rankingSummaryProvider(_scope).notifier)
                  .selectSort(field, direction),
            ),
          ),
          if (batchSelectableNumbers.isNotEmpty)
            AppGlassHeaderButton(
              key: Key('$batchKeyPrefix-enter-selection-button'),
              icon: Icons.check_circle_outline,
              label: l10n.baseSelect,
              onTap: enterSelection,
            ),
        ],
      ),
      filterUpdate: paged.filterUpdate,
      hasPreviousFilterItems: paged.items.isNotEmpty,
      onRetryFilter: () => unawaited(
        ref.read(rankingSummaryProvider(_scope).notifier).retryFilter(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paged = ref.watch(
      rankingSummaryProvider(
        _scope,
      ).select((async) => pagedViewSnapshot(async, (state) => state.paged)),
    );
    final filters =
        ref.watch(
          rankingSummaryProvider(
            _scope,
          ).select((async) => async.value?.filters),
        ) ??
        RankingFilterState.initial;
    final syncedAt = ref.watch(
      rankingSummaryProvider(
        _scope,
      ).select((async) => async.value?.paged.syncedAt),
    );
    final initialErrorMessage = ref.watch(
      rankingSummaryProvider(
        _scope,
      ).select((async) => async.value?.initialErrorMessage),
    );
    final subscriptionUpdating = ref.watch(
      rankingSummaryProvider(_scope).select(
        (async) => StableSetSelection<String>(
          async.value?.subscriptionUpdatingMovieNumbers ?? const <String>{},
        ),
      ),
    );
    final hasNoSources = filters.hasNoSources;

    return AppPageRefreshScope(
      onRefresh: () =>
          ref.read(rankingSummaryProvider(_scope).notifier).refresh(),
      child: AppFixedHeaderLayout(
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectionMode)
              buildGlassBatchSelectionToolbar()
            else
              _buildHeader(context, paged, filters, syncedAt),
            SizedBox(height: context.appSpacing.md),
            if (filters.errorMessage != null && paged.filterUpdate.isIdle) ...[
              AppInlineErrorBanner(
                message: filters.errorMessage!,
                onRetry: () => ref
                    .read(rankingSummaryProvider(_scope).notifier)
                    .reloadFiltersAndData(),
              ),
              SizedBox(height: context.appSpacing.md),
            ],
            SizedBox(height: context.appSpacing.sm),
          ],
        ),
        child: AppFilterResultLoadingOverlay(
          isLoading: paged.filterUpdate.isLoading,
          hasPreviousItems: paged.items.isNotEmpty,
          child: AppPagedLoadMoreScope(
            canLoadMore: () =>
                ref
                    .read(rankingSummaryProvider(_scope))
                    .value
                    ?.paged
                    .canAutoLoadMore ??
                false,
            onLoadMore: () =>
                ref.read(rankingSummaryProvider(_scope).notifier).loadMore(),
            child: CustomScrollView(
              key: const PageStorageKey<String>('desktop:rankings:list'),
              controller: _scrollController,
              slivers: [
                SliverMainAxisGroup(
                  key: const Key('desktop-rankings-page'),
                  slivers: [
                    if (hasNoSources &&
                        !(paged.filterUpdate.hasFailed && paged.items.isEmpty))
                      SliverToBoxAdapter(
                        child: AppEmptyState(message: l10n.rankingNoBoards),
                      )
                    else if (!paged.filterUpdate.hasFailed ||
                        paged.items.isNotEmpty)
                      AppSkeletonizer.sliver(
                        enabled:
                            (paged.isInitialLoading || filters.isLoading) &&
                            paged.items.isEmpty,
                        child: RankedMovieSummarySliver(
                          items:
                              (paged.isInitialLoading || filters.isLoading) &&
                                  paged.items.isEmpty
                              ? rankedMoviePlaceholders(count: 24)
                              : paged.items,
                          errorMessage: initialErrorMessage,
                          onMovieTap: (movie) => context.pushDesktopMovieDetail(
                            movieNumber: movie.movieNumber,
                            fallbackPath: desktopRankingsPath,
                          ),
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
                          emptyMessage: l10n.rankingEmptyData,
                          selectionMode: selectionMode,
                          isMovieSelected: (movie) =>
                              isSelected(movie.movieNumber),
                          onMovieSelectedChanged: (movie, _) =>
                              toggleSelect(movie.movieNumber),
                        ),
                      ),
                    // loadMore 页脚独立订阅：翻页 loading / 失败只重建页脚。
                    PagedLoadMoreFooterSliver(
                      watchFooter: (ref) => ref.watch(
                        rankingSummaryProvider(_scope).select(
                          (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
                        ),
                      ),
                      onLoadMore: (ref) => unawaited(
                        ref
                            .read(rankingSummaryProvider(_scope).notifier)
                            .loadMore(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
