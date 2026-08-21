import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sakuramedia/core/format/synced_at_label.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_list_item_dto.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_period.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/hot_review_filter_sections.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/providers/hot_reviews_provider.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/providers/hot_reviews_state.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/widgets/hot_review_card.dart';
import 'package:sakuramedia/features/shared/presentation/hooks/paged_scroll_hook.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

typedef HotReviewMovieOpenHandler =
    void Function(BuildContext context, HotReviewListItemDto item);

/// 热评共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 7 个配置参数（列数 / 刷新 / 抽屉 / 导航）由壳传入，两端差异收在壳；页内 iOS
/// `defaultTargetPlatform` 下拉刷新分支（`RefreshIndicator` vs Cupertino sliver）
/// 原样保留在本层，有测试锁三态。
class HotReviewsContent extends HookConsumerWidget {
  const HotReviewsContent({
    super.key,
    this.onOpenMovieDetail,
    this.minColumns = 2,
    this.maxColumns = 4,
    this.targetCardWidth = 420,
    this.enablePullToRefresh = false,
    this.scrollPhysics,
    this.useMobileFilterDrawer = false,
  }) : assert(minColumns >= 1),
       assert(maxColumns >= minColumns),
       assert(targetCardWidth > 0);

  final HotReviewMovieOpenHandler? onOpenMovieDetail;
  final int minColumns;
  final int maxColumns;
  final double targetCardWidth;
  final bool enablePullToRefresh;
  final ScrollPhysics? scrollPhysics;

  /// 顶栏筛选入口点开什么：`true` 弹底部抽屉（移动端），`false` 就地展开浮层
  /// （桌面端）。两端按钮外观、面板内容、条件即时更新行为完全一致，只有容器不同。
  final bool useMobileFilterDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hotReviewsProvider);
    final state = async.value;
    final paged = state?.paged ?? const PagedListState<HotReviewListItemDto>();
    // 首次加载尚无 state 时，从 notifier 读默认周期。
    final period =
        state?.period ?? ref.read(hotReviewsProvider.notifier).period;
    final scrollController = usePagedLoadMoreScroll(
      onReachBottom: () {
        // 对齐旧基类：loadMore 失败存续期间滚动不自动重试。
        if (paged.loadMoreErrorMessage == null) {
          unawaited(ref.read(hotReviewsProvider.notifier).loadMore());
        }
      },
      triggerOffset: 300,
    );

    final showFooter =
        paged.isNotEmpty &&
        (paged.isLoadingMore || paged.loadMoreErrorMessage != null);
    final slivers = <Widget>[
      SliverMainAxisGroup(
        key: const Key('desktop-hot-reviews-page'),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, ref, scrollController, paged, period),
          ),
          SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
          _buildBodySliver(context, ref, async, paged),
          if (showFooter)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: context.appSpacing.md),
                child: AppPagedLoadMoreFooter(
                  isLoading: paged.isLoadingMore,
                  errorMessage: paged.loadMoreErrorMessage,
                  onRetry: () => unawaited(
                    ref.read(hotReviewsProvider.notifier).loadMore(),
                  ),
                ),
              ),
            ),
        ],
      ),
    ];
    final scrollView = CustomScrollView(
      key: const Key('desktop-hot-reviews-scroll-view'),
      physics: enablePullToRefresh
          ? scrollPhysics ?? const AlwaysScrollableScrollPhysics()
          : scrollPhysics,
      controller: scrollController,
      slivers: slivers,
    );

    return AppPageRefreshScope(
      onRefresh: () => _handleRefresh(context, ref),
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: _buildRefreshableBody(
          context,
          ref,
          scrollController,
          scrollView,
          slivers,
        ),
      ),
    );
  }

  Widget _buildRefreshableBody(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
    CustomScrollView scrollView,
    List<Widget> slivers,
  ) {
    if (!enablePullToRefresh) {
      return scrollView;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppAdaptiveRefreshScrollView(
        onRefresh: () => _handleRefresh(context, ref),
        controller: scrollController,
        physics: scrollPhysics ?? const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      );
    }

    return AppPullToRefresh(
      onRefresh: () => _handleRefresh(context, ref),
      child: scrollView,
    );
  }

  Future<void> _handleRefresh(BuildContext context, WidgetRef ref) async {
    final errorMessage = await ref.read(hotReviewsProvider.notifier).refresh();
    if (errorMessage != null && context.mounted) {
      showToast('刷新失败');
    }
  }

  Future<void> _applyPeriod(
    WidgetRef ref,
    ScrollController scrollController,
    HotReviewPeriod period,
  ) async {
    final notifier = ref.read(hotReviewsProvider.notifier);
    // 同值去重在这里做（applyFilterState 内部也会短路），避免同值时误 jumpTo(0)。
    if (notifier.period == period) {
      return;
    }
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    await notifier.applyFilterState(period);
  }

  /// 桌面与移动共用同一条顶栏：筛选入口（当前周期）+ 总数 / 抓取时间信息槽。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
    PagedListState<HotReviewListItemDto> paged,
    HotReviewPeriod period,
  ) {
    final syncedAtLabel = formatSyncedAtLabel(
      paged.syncedAt,
      withPrefix: false,
    );

    return AppListHeader(
      filterButtonKey: const Key('hot-reviews-filter-trigger'),
      filterIcon: Icons.date_range_rounded,
      filterLabel: period.label,
      filterPanelKey: const Key('hot-reviews-filter-panel'),
      filterPanelExtraWidth: 180,
      filterUpdate: paged.filterUpdate,
      hasPreviousFilterItems: paged.items.isNotEmpty,
      onRetryFilter: () =>
          unawaited(ref.read(hotReviewsProvider.notifier).retryFilter()),
      onFilterTap: useMobileFilterDrawer
          ? () => unawaited(
              _openFilterDrawer(context, ref, scrollController, period),
            )
          : null,
      filterPanelBuilder: useMobileFilterDrawer
          ? null
          : (_) => HotReviewFilterSectionGroup(
              period: period,
              onChanged: (next) =>
                  unawaited(_applyPeriod(ref, scrollController, next)),
            ),
      informationSlots: [
        AppListHeaderInfo(
          key: const Key('desktop-hot-reviews-page-total'),
          label: '${paged.total} 条',
        ),
        if (syncedAtLabel != null)
          AppListHeaderInfo(
            key: const Key('hot-reviews-synced-at'),
            label: syncedAtLabel,
            icon: Icons.schedule_rounded,
          ),
      ],
    );
  }

  Future<void> _openFilterDrawer(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
    HotReviewPeriod period,
  ) async {
    await showMobileHotReviewFilterDrawer(
      context,
      current: period,
      onChanged: (next) => unawaited(_applyPeriod(ref, scrollController, next)),
    );
  }

  Widget _buildBodySliver(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<HotReviewsState> async,
    PagedListState<HotReviewListItemDto> paged,
  ) {
    if (async.isLoading && async.value == null) {
      return HotReviewSliver(
        isLoading: true,
        items: <HotReviewListItemDto>[],
        minColumns: minColumns,
        maxColumns: maxColumns,
        targetCardWidth: targetCardWidth,
      );
    }

    if (async.hasError && paged.isEmpty) {
      return const SliverToBoxAdapter(
        child: AppEmptyState(message: '热评加载失败，请稍后重试'),
      );
    }

    if (paged.isEmpty && paged.filterUpdate.hasFailed) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (paged.isEmpty) {
      return const SliverToBoxAdapter(child: AppEmptyState(message: '暂无热评数据'));
    }

    return HotReviewSliver(
      isLoading: false,
      items: paged.items,
      onItemTap: (item) => _openMovieDetail(context, item),
      minColumns: minColumns,
      maxColumns: maxColumns,
      targetCardWidth: targetCardWidth,
    );
  }

  void _openMovieDetail(BuildContext context, HotReviewListItemDto item) {
    final movieNumber = item.movie.movieNumber.trim();
    if (movieNumber.isEmpty) {
      return;
    }
    final onOpenMovieDetail = this.onOpenMovieDetail;
    if (onOpenMovieDetail != null) {
      onOpenMovieDetail(context, item);
      return;
    }
    context.pushDesktopMovieDetail(
      movieNumber: movieNumber,
      fallbackPath: desktopHotReviewsPath,
    );
  }
}
