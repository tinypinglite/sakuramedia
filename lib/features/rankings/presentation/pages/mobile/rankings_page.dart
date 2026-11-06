import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/format/synced_at_label.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/mobile/ranking_filter_drawer.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_provider.dart';
import 'package:sakuramedia/features/rankings/presentation/rankings_placeholders.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_scope.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_state.dart';
import 'package:sakuramedia/features/shared/data/movie_interaction_filter.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/providers/stable_set_selection.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/rankings/ranking_sort_menu_button.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranked_movie_summary_grid.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranking_filter_sections.dart';

class MobileRankingsPage extends ConsumerStatefulWidget {
  const MobileRankingsPage({super.key});

  @override
  ConsumerState<MobileRankingsPage> createState() => _MobileRankingsPageState();
}

class _MobileRankingsPageState extends ConsumerState<MobileRankingsPage>
    with
        MultiSelectStateMixin<MobileRankingsPage, String>,
        MovieBatchSelectionMixin<MobileRankingsPage> {
  static const _scope = RankingSummaryScope.mobile();

  late final RiverpodPageHandle _pageCacheHandle;
  late final ScrollController _scrollController;
  final _listHeaderKey = GlobalKey();

  MovieCardHoverFeatureActions get _hoverFeatureActions =>
      movieCardHoverFeatureActions(context);

  @override
  String get batchKeyPrefix => 'mobile-rankings';

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
          key: mobileRankingsPageCacheKey(),
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

  @override
  Widget build(BuildContext context) {
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
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    return Column(
      children: [
        Expanded(
          child: AppFilterResultLoadingOverlay(
            surfaceColor: highContrast
                ? context.appColors.surfacePage
                : context.appColors.surfaceCard.withValues(alpha: 0.9),
            protectedHeaderKey: _listHeaderKey,
            scrollController: _scrollController,
            isLoading: paged.filterUpdate.isLoading,
            hasPreviousItems: paged.items.isNotEmpty,
            child: _buildScrollView(
              context,
              paged,
              filters,
              syncedAt,
              initialErrorMessage,
              subscriptionUpdating,
            ),
          ),
        ),
        // 多选态的批量动作贴底常驻，与影片列表 / PornBox 一致。
        if (selectionMode) buildMobileBatchSelectionBottomBar(),
      ],
    );
  }

  Widget _buildScrollView(
    BuildContext context,
    PagedViewSnapshot<RankedMovieListItemDto> paged,
    RankingFilterState filters,
    DateTime? syncedAt,
    String? initialErrorMessage,
    StableSetSelection<String> subscriptionUpdating,
  ) {
    final l10n = AppLocalizations.of(context);
    final hasNoSources = filters.hasNoSources;
    return AppPagedLoadMoreScope(
      canLoadMore: () =>
          ref
              .read(rankingSummaryProvider(_scope))
              .value
              ?.paged
              .canAutoLoadMore ??
          false,
      onLoadMore: () =>
          ref.read(rankingSummaryProvider(_scope).notifier).loadMore(),
      child: AppAdaptiveRefreshScrollView(
        key: const PageStorageKey<String>('mobile:rankings:list'),
        onRefresh: _handleRefresh,
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          AppPinnedSliverSection(
            key: const Key('mobile-rankings-page'),
            headerKey: _listHeaderKey,
            before: <Widget>[
              SliverToBoxAdapter(
                child: AppMobilePageTitle(
                  key: const Key('mobile-rankings-large-title'),
                  title: AppLocalizations.of(context).routeRankingsBoardTitle,
                ),
              ),
            ],
            header: selectionMode
                ? buildMobileBatchSelectionHeader()
                : _buildHeader(context, paged, filters, syncedAt),
            headerBottomSpacing: context.appSpacing.md,
            after: <Widget>[
              if (filters.errorMessage != null && paged.filterUpdate.isIdle)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: context.appSpacing.md),
                    child: AppInlineErrorBanner(
                      message: filters.errorMessage!,
                      onRetry: () => ref
                          .read(rankingSummaryProvider(_scope).notifier)
                          .reloadFiltersAndData(),
                    ),
                  ),
                ),
              if (hasNoSources &&
                  !(paged.filterUpdate.hasFailed && paged.items.isEmpty))
                SliverToBoxAdapter(
                  child: AppEmptyState(message: l10n.rankingNoBoards),
                )
              else if (!paged.filterUpdate.hasFailed || paged.items.isNotEmpty)
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
                    onMovieTap: (movie) => selectionAwareTap(
                      movie.movieNumber,
                      () => MobileRoutes.movieDetail(
                        movieNumber: movie.movieNumber,
                      ).push(context),
                    )(),
                    onMovieMenuRequest: (movie, globalPosition) =>
                        requestMovieCollectionMenu(
                          context,
                          movie.movieNumber,
                          globalPosition,
                          isSubscribed: movie.isSubscribed,
                          onEnterSelection: () =>
                              enterSelection(initial: movie.movieNumber),
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
                    isMovieSelected: (movie) => isSelected(movie.movieNumber),
                    onMovieSelectedChanged: (movie, _) =>
                        handleSelectTap(movie.movieNumber),
                  ),
                ),
              // loadMore 页脚独立订阅：翻页 loading / 失败只重建页脚。
              PagedLoadMoreFooterSliver(
                watchFooter: (ref) => ref.watch(
                  rankingSummaryProvider(
                    _scope,
                  ).select((s) => pagedLoadMoreFooterSnapshot(s.value?.paged)),
                ),
                onLoadMore: (ref) => unawaited(
                  ref.read(rankingSummaryProvider(_scope).notifier).loadMore(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final error = await ref
        .read(rankingSummaryProvider(_scope).notifier)
        .refresh();
    if (error != null && mounted) {
      showToast(
        AppLocalizations.of(context).sharedRefreshFailed,
        tone: AppToastTone.error,
      );
    }
  }

  Widget _buildHeader(
    BuildContext context,
    PagedViewSnapshot<RankedMovieListItemDto> paged,
    RankingFilterState filters,
    DateTime? syncedAt,
  ) {
    final l10n = AppLocalizations.of(context);
    final source = filters.selectedSource;
    final board = filters.selectedBoard;
    // 与桌面榜单页同一套单值语义：只报「榜单」这一主维度。
    final boardLabel = board?.name ?? source?.name ?? l10n.rankingAllBoards;
    final syncedAtLabel = formatSyncedAtLabel(
      syncedAt,
      l10n: AppLocalizations.of(context),
      withPrefix: false,
    );

    final filterActive =
        filters.selectedSource != null ||
        filters.selectedBoard != null ||
        filters.selectedPeriod != null ||
        filters.interaction != MovieInteractionFilter.initial;
    return AppMobileListHeader(
      leading: AppMobileHeaderText(
        key: const Key('mobile-rankings-page-total'),
        title: l10n.rankingListMoviesTitle,
        countLabel: l10n.sharedMovieCount(paged.total),
        secondaryLabel: syncedAtLabel,
        secondaryKey: const Key('mobile-rankings-synced-at'),
      ),
      actions: <Widget>[
        AppGlassFilterIconButton(
          key: const Key('mobile-rankings-filter-button'),
          summary: boardLabel,
          isActive: filterActive,
          onPressed: filters.sources.isEmpty
              ? null
              : () => _openFilterDrawer(initialAnchor: null),
        ),
        RankingSortMenuButton(
          triggerKey: const Key('mobile-rankings-sort-trigger'),
          drawerKey: const Key('mobile-rankings-sort-drawer'),
          keyPrefix: 'mobile-rankings',
          filterState: filters,
          useDrawer: true,
          iconOnly: true,
          onSortChanged: (field, direction) {
            _scrollToHeader();
            unawaited(
              ref
                  .read(rankingSummaryProvider(_scope).notifier)
                  .selectSort(field, direction),
            );
          },
        ),
      ],
      filterUpdate: paged.filterUpdate,
      hasPreviousFilterItems: paged.items.isNotEmpty,
      onRetryFilter: () => unawaited(
        ref.read(rankingSummaryProvider(_scope).notifier).retryFilter(),
      ),
    );
  }

  Future<void> _openFilterDrawer({RankingFilterAnchor? initialAnchor}) async {
    await showMobileRankingFilterDrawer(
      context,
      scope: _scope,
      initialAnchor: initialAnchor,
      onFilterChanged: _scrollToHeader,
    );
  }

  void _scrollToHeader() {
    AppPinnedListHeader.scrollToStart(_listHeaderKey, _scrollController);
  }
}
