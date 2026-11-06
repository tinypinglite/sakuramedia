import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/format/synced_at_label.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_sort.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_provider.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_scope.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_state.dart';
import 'package:sakuramedia/features/rankings/presentation/rankings_placeholders.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranked_movie_summary_grid.dart';
import 'package:sakuramedia/features/shared/data/movie_interaction_filter.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/providers/stable_set_selection.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';

/// 榜单页一次 build 需要的 provider 切片。
typedef RankingsPageView = ({
  PagedViewSnapshot<RankedMovieListItemDto> paged,
  RankingFilterState filters,
  DateTime? syncedAt,
  String? initialErrorMessage,
  StableSetSelection<String> subscriptionUpdating,
});

/// 两端顶栏统一的「当前榜单」摘要：只报榜单这一主维度。
String rankingBoardLabel(RankingFilterState filters, AppLocalizations l10n) =>
    filters.selectedBoard?.name ??
    filters.selectedSource?.name ??
    l10n.rankingAllBoards;

String? rankingSyncedAtLabel(DateTime? syncedAt, AppLocalizations l10n) =>
    formatSyncedAtLabel(syncedAt, l10n: l10n, withPrefix: false);

/// 桌面与移动榜单共享的 scope、缓存、分页、刷新、筛选、批量选择与订阅行为。
///
/// 页面只保留各自的 header 和滚动容器；平台差异收敛在 [isMobileRankings]
/// 这一个维度上。
mixin RankingsPageBehaviorMixin<W extends ConsumerStatefulWidget>
    on
        ConsumerState<W>,
        MultiSelectStateMixin<W, String>,
        MovieBatchSelectionMixin<W> {
  late final ScrollController rankingsScrollController;
  final GlobalKey rankingsHeaderKey = GlobalKey();
  RiverpodPageHandle? _pageCacheHandle;

  RankingSummaryScope get rankingScope;

  bool get isMobileRankings =>
      rankingScope == const RankingSummaryScope.mobile();

  MovieCardHoverFeatureActions get _rankingHoverFeatureActions =>
      movieCardHoverFeatureActions(context);

  RankingSummary get _ranking =>
      ref.read(rankingSummaryProvider(rankingScope).notifier);

  @override
  String get batchKeyPrefix =>
      isMobileRankings ? 'mobile-rankings' : 'desktop-rankings';

  @override
  MovieBatchToggleExecutor get batchSubscriptionExecutor =>
      _ranking.batchToggleSubscription;

  @override
  List<String> get batchSelectableNumbers =>
      ref
          .read(rankingSummaryProvider(rankingScope))
          .value
          ?.paged
          .items
          .map((movie) => movie.movieNumber)
          .toList(growable: false) ??
      const <String>[];

  @override
  void initState() {
    super.initState();
    rankingsScrollController = ScrollController();
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: rankingScope.cacheKey,
          resolveLinks: () {
            final link = _ranking.cacheLink;
            return link == null ? const [] : [link];
          },
        );
  }

  @override
  void dispose() {
    _pageCacheHandle?.release();
    rankingsScrollController.dispose();
    super.dispose();
  }

  RankingsPageView watchRankingsPage() {
    return ref.watch(
      rankingSummaryProvider(rankingScope).select(
        (async) => (
          paged: pagedViewSnapshot(async, (state) => state.paged),
          filters: async.value?.filters ?? RankingFilterState.initial,
          syncedAt: async.value?.paged.syncedAt,
          initialErrorMessage: async.value?.initialErrorMessage,
          subscriptionUpdating: StableSetSelection<String>(
            async.value?.subscriptionUpdatingMovieNumbers ?? const <String>{},
          ),
        ),
      ),
    );
  }

  bool get canAutoLoadMoreRankings =>
      ref
          .read(rankingSummaryProvider(rankingScope))
          .value
          ?.paged
          .canAutoLoadMore ??
      false;

  Future<void> refreshRankings() => _ranking.refresh();

  Future<void> loadMoreRankings() => _ranking.loadMore();

  Future<void> reloadRankings() => _ranking.reloadFiltersAndData();

  void retryRankingFilter() => unawaited(_ranking.retryFilter());

  Future<void> toggleRankingSubscription(String movieNumber) async {
    final result = await _ranking.toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  void selectRankingSource(RankingSourceDto value) =>
      _applyRankingFilterChange(() => _ranking.selectSource(value));

  void selectRankingBoard(RankingBoardDto value) =>
      _applyRankingFilterChange(() => _ranking.selectBoard(value));

  void selectRankingPeriod(String value) =>
      _applyRankingFilterChange(() => _ranking.selectPeriod(value));

  void selectRankingInteraction(MovieInteractionFilter value) =>
      _applyRankingFilterChange(() => _ranking.selectInteraction(value));

  void selectRankingSort(RankingSortField? field, SortDirection direction) =>
      _applyRankingFilterChange(() => _ranking.selectSort(field, direction));

  void _applyRankingFilterChange(Future<void> Function() action) {
    scrollRankingsToStart();
    unawaited(action());
  }

  void scrollRankingsToStart() {
    if (isMobileRankings) {
      AppPinnedListHeader.scrollToStart(
        rankingsHeaderKey,
        rankingsScrollController,
      );
      return;
    }
    if (!rankingsScrollController.hasClients) {
      return;
    }
    rankingsScrollController.jumpTo(
      rankingsScrollController.position.minScrollExtent,
    );
  }

  /// 筛选元数据刷新失败时的内联重试条；两端容器与间距不同，只共享内容。
  Widget? buildRankingFilterErrorBanner(RankingsPageView view) {
    final filters = view.filters;
    if (filters.errorMessage == null || !view.paged.filterUpdate.isIdle) {
      return null;
    }
    return AppInlineErrorBanner(
      message: filters.errorMessage!,
      onRetry: reloadRankings,
    );
  }

  /// 结果区 sliver：无榜单空态、骨架网格或真实网格，以及独立的翻页页脚。
  List<Widget> buildRankingListSlivers(RankingsPageView view) {
    final l10n = AppLocalizations.of(context);
    final paged = view.paged;
    final items = paged.items;
    final loading =
        (paged.isInitialLoading || view.filters.isLoading) && items.isEmpty;
    return <Widget>[
      if (view.filters.hasNoSources &&
          !(paged.filterUpdate.hasFailed && items.isEmpty))
        SliverToBoxAdapter(child: AppEmptyState(message: l10n.rankingNoBoards))
      else if (!paged.filterUpdate.hasFailed || items.isNotEmpty)
        AppSkeletonizer.sliver(
          enabled: loading,
          child: RankedMovieSummarySliver(
            items: loading ? rankedMoviePlaceholders(count: 24) : items,
            errorMessage: view.initialErrorMessage,
            onErrorRetry: () => unawaited(reloadRankings()),
            onMovieTap: (movie) => selectionAwareTap(
              movie.movieNumber,
              () => _openRankingMovie(movie),
            )(),
            onMovieLongPress: isMobileRankings
                ? (movie) => selectionLongPressHandler(movie.movieNumber).call()
                : null,
            onMovieMenuRequest: (movie, globalPosition) =>
                requestMovieCollectionMenu(
                  context,
                  movie.movieNumber,
                  globalPosition,
                  isSubscribed: movie.isSubscribed,
                  onEnterSelection: isMobileRankings
                      ? () => enterSelection(initial: movie.movieNumber)
                      : null,
                ),
            onMovieSubscriptionTap: (movie) =>
                toggleRankingSubscription(movie.movieNumber),
            onMovieToggleCollectionType:
                _rankingHoverFeatureActions.toggleCollectionType,
            onMovieBlacklist: _rankingHoverFeatureActions.blacklist,
            isMovieSubscriptionUpdating: (movie) =>
                view.subscriptionUpdating.contains(movie.movieNumber),
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
            rankingScope,
          ).select((state) => pagedLoadMoreFooterSnapshot(state.value?.paged)),
        ),
        onLoadMore: (ref) => unawaited(loadMoreRankings()),
      ),
    ];
  }

  void _openRankingMovie(RankedMovieListItemDto movie) {
    if (isMobileRankings) {
      MobileRoutes.movieDetail(movieNumber: movie.movieNumber).push(context);
      return;
    }
    DesktopRoutes.movieDetail(
      movieNumber: movie.movieNumber,
      fallbackPath: desktopRankingsPath,
    ).push(context);
  }
}
