import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/format/synced_at_label.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_provider.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_scope.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
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
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
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
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) {
      return;
    }
    final summary = ref.read(rankingSummaryProvider(_scope)).value;
    final position = _scrollController.position;
    if (summary == null ||
        summary.paged.loadMoreErrorMessage != null ||
        position.pixels < position.maxScrollExtent - 300) {
      return;
    }
    unawaited(ref.read(rankingSummaryProvider(_scope).notifier).loadMore());
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(rankingSummaryProvider(_scope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  void _applyFilterChange(Future<void> Function() action) {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    unawaited(action());
  }

  /// 与移动榜单页共用同一条顶栏：筛选入口（当前榜单）+ 总数 / 更新时间信息槽。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
  Widget _buildHeader(BuildContext context, RankingSummaryState summary) {
    // 与移动端同一套单值语义：只报「榜单」这一主维度。
    final boardLabel =
        summary.filters.selectedBoard?.name ??
        summary.filters.selectedSource?.name ??
        '全部榜单';
    final syncedAtLabel = formatSyncedAtLabel(
      summary.paged.syncedAt,
      withPrefix: false,
    );

    return AppListHeader(
      filterButtonKey: const Key('desktop-rankings-filter-trigger'),
      filterIcon: Icons.leaderboard_outlined,
      filterLabel: boardLabel,
      filterEnabled: summary.filters.sources.isNotEmpty,
      filterUpdate: summary.paged.filterUpdate,
      hasPreviousFilterItems: summary.paged.items.isNotEmpty,
      onRetryFilter: () => unawaited(
        ref.read(rankingSummaryProvider(_scope).notifier).retryFilter(),
      ),
      filterPanelKey: const Key('rankings-filter-panel'),
      filterPanelExtraWidth: 520,
      filterPanelBuilder: (_) => RankingFilterSectionGroup(
        sources: summary.filters.sources,
        selectedSource: summary.filters.selectedSource,
        boards: summary.filters.boards,
        selectedBoard: summary.filters.selectedBoard,
        selectedPeriod: summary.filters.selectedPeriod,
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
        selectedSortField: summary.filters.selectedSortField,
        selectedSortDirection: summary.filters.selectedSortDirection,
        onSortChanged: (field, dir) => _applyFilterChange(
          () => ref
              .read(rankingSummaryProvider(_scope).notifier)
              .selectSort(field, dir),
        ),
      ),
      informationSlots: [
        AppListHeaderInfo(
          key: const Key('desktop-rankings-page-total'),
          label: '${summary.paged.total} 部',
        ),
        if (syncedAtLabel != null)
          AppListHeaderInfo(
            key: const Key('desktop-rankings-synced-at'),
            label: syncedAtLabel,
            icon: Icons.schedule_rounded,
          ),
      ],
      actionSlots: [buildEnterSelectionButton()],
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary =
        ref.watch(rankingSummaryProvider(_scope)).value ??
        RankingSummaryState.initial;
    final showFooter =
        summary.paged.items.isNotEmpty &&
        (summary.paged.isLoadingMore ||
            summary.paged.loadMoreErrorMessage != null);
    final hasNoSources = summary.filters.hasNoSources;

    return AppPageRefreshScope(
      onRefresh: () =>
          ref.read(rankingSummaryProvider(_scope).notifier).refresh(),
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: AppFilterResultLoadingOverlay(
          isLoading: summary.paged.filterUpdate.isLoading,
          hasPreviousItems: summary.paged.items.isNotEmpty,
          child: CustomScrollView(
            key: const PageStorageKey<String>('desktop:rankings:list'),
            controller: _scrollController,
            slivers: [
              SliverMainAxisGroup(
                key: const Key('desktop-rankings-page'),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectionMode)
                          buildBatchSelectionToolbar()
                        else
                          _buildHeader(context, summary),
                        SizedBox(height: context.appSpacing.md),
                        if (summary.filters.errorMessage != null &&
                            summary.paged.filterUpdate.isIdle) ...[
                          _FilterErrorBanner(
                            message: summary.filters.errorMessage!,
                            onRetry: () => ref
                                .read(rankingSummaryProvider(_scope).notifier)
                                .reloadFiltersAndData(),
                          ),
                          SizedBox(height: context.appSpacing.md),
                        ],
                        SizedBox(height: context.appSpacing.sm),
                      ],
                    ),
                  ),
                  if (hasNoSources &&
                      !(summary.paged.filterUpdate.hasFailed &&
                          summary.paged.items.isEmpty))
                    const SliverToBoxAdapter(
                      child: AppEmptyState(message: '暂无可用排行榜'),
                    )
                  else if (!summary.paged.filterUpdate.hasFailed ||
                      summary.paged.items.isNotEmpty)
                    RankedMovieSummarySliver(
                      items: summary.paged.items,
                      isLoading: summary.filters.isLoading
                          ? summary.paged.items.isEmpty
                          : summary.isListLoading,
                      errorMessage: summary.initialErrorMessage,
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
                      isMovieSubscriptionUpdating: (movie) =>
                          summary.isSubscriptionUpdating(movie.movieNumber),
                      emptyMessage: '暂无榜单数据',
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
                          isLoading: summary.paged.isLoadingMore,
                          errorMessage: summary.paged.loadMoreErrorMessage,
                          onRetry: () => ref
                              .read(rankingSummaryProvider(_scope).notifier)
                              .loadMore(),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterErrorBanner extends StatelessWidget {
  const _FilterErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.appSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: context.appComponentTokens.iconSizeXl,
              color: context.appTextPalette.secondary,
            ),
            SizedBox(width: context.appSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
            SizedBox(width: context.appSpacing.sm),
            AppButton(
              label: '重试',
              size: AppButtonSize.xSmall,
              variant: AppButtonVariant.secondary,
              onPressed: () => unawaited(onRetry()),
            ),
          ],
        ),
      ),
    );
  }
}
