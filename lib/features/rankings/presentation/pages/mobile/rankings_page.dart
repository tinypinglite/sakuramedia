import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/format/synced_at_label.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/mobile/ranking_filter_drawer.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_provider.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_scope.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
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
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
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

  @override
  Widget build(BuildContext context) {
    final summary =
        ref.watch(rankingSummaryProvider(_scope)).value ??
        RankingSummaryState.initial;
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppFilterResultLoadingOverlay(
              isLoading: summary.paged.filterUpdate.isLoading,
              hasPreviousItems: summary.paged.items.isNotEmpty,
              child: _buildScrollView(context, summary),
            ),
          ),
          // 多选态的批量动作贴底常驻，与影片列表 / PornBox 一致。
          if (selectionMode) buildMobileBatchSelectionBottomBar(),
        ],
      ),
    );
  }

  Widget _buildScrollView(BuildContext context, RankingSummaryState summary) {
    final showFooter =
        summary.paged.items.isNotEmpty &&
        (summary.paged.isLoadingMore ||
            summary.paged.loadMoreErrorMessage != null);
    final hasNoSources = summary.filters.hasNoSources;
    return AppAdaptiveRefreshScrollView(
      key: const PageStorageKey<String>('mobile:rankings:list'),
      onRefresh: _handleRefresh,
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverMainAxisGroup(
          key: const Key('mobile-rankings-page'),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (selectionMode)
                    buildMobileBatchSelectionHeader()
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
                ],
              ),
            ),
            if (hasNoSources &&
                !(summary.paged.filterUpdate.hasFailed &&
                    summary.paged.items.isEmpty))
              const SliverToBoxAdapter(child: AppEmptyState(message: '暂无可用排行榜'))
            else if (!summary.paged.filterUpdate.hasFailed ||
                summary.paged.items.isNotEmpty)
              RankedMovieSummarySliver(
                items: summary.paged.items,
                isLoading: summary.filters.isLoading
                    ? summary.paged.items.isEmpty
                    : summary.isListLoading,
                errorMessage: summary.initialErrorMessage,
                onMovieTap: (movie) => context.pushMobileMovieDetail(
                  movieNumber: movie.movieNumber,
                ),
                onMovieMenuRequest: (movie, globalPosition) =>
                    requestMovieCollectionMenu(
                      context,
                      movie.movieNumber,
                      globalPosition,
                      isSubscribed: movie.isSubscribed,
                      onEnterSelection: () {
                        enterSelection();
                        toggleSelect(movie.movieNumber);
                      },
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
    );
  }

  Future<void> _handleRefresh() async {
    final error = await ref
        .read(rankingSummaryProvider(_scope).notifier)
        .refresh();
    if (error != null && mounted) {
      showToast('刷新失败');
    }
  }

  Widget _buildHeader(BuildContext context, RankingSummaryState summary) {
    final source = summary.filters.selectedSource;
    final board = summary.filters.selectedBoard;
    // 与桌面榜单页同一套单值语义：只报「榜单」这一主维度。
    final boardLabel = board?.name ?? source?.name ?? '全部榜单';
    final syncedAtLabel = formatSyncedAtLabel(
      summary.paged.syncedAt,
      withPrefix: false,
    );

    return AppListHeader(
      filterButtonKey: const Key('mobile-rankings-filter-button'),
      filterTooltip: '筛选',
      filterIcon: Icons.leaderboard_outlined,
      filterLabel: boardLabel,
      filterEnabled: summary.filters.sources.isNotEmpty,
      filterUpdate: summary.paged.filterUpdate,
      hasPreviousFilterItems: summary.paged.items.isNotEmpty,
      onRetryFilter: () => unawaited(
        ref.read(rankingSummaryProvider(_scope).notifier).retryFilter(),
      ),
      onFilterTap: () => _openFilterDrawer(initialAnchor: null),
      informationSlots: [
        AppListHeaderInfo(
          key: const Key('mobile-rankings-page-total'),
          label: '${summary.paged.total} 部',
        ),
        if (syncedAtLabel != null)
          AppListHeaderInfo(
            key: const Key('mobile-rankings-synced-at'),
            label: syncedAtLabel,
            icon: Icons.schedule_rounded,
          ),
      ],
    );
  }

  Future<void> _openFilterDrawer({RankingFilterAnchor? initialAnchor}) async {
    await showMobileRankingFilterDrawer(
      context,
      scope: _scope,
      initialAnchor: initialAnchor,
      onFilterChanged: _scrollToTop,
    );
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
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
