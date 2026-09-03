import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sakuramedia/features/moments/presentation/moment_filter_sections.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/moments/presentation/providers/moments_provider.dart';
import 'package:sakuramedia/features/moments/presentation/providers/moments_state.dart';
import 'package:sakuramedia/features/shared/presentation/hooks/paged_scroll_hook.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_grid.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_image.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_preview_launcher.dart';

/// 时刻列表共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异全部收在壳注入的参数与回调里：
/// - Key 三件套（keyPrefix / rootKey / previewDrawerKey）由壳传参、本层产出；
/// - 图搜 / 视频播放 / 影片播放 / 影片详情四个导航分支收为壳注入的回调组；
/// - 预览弹层统一走 [MediaPreviewPresentation.auto]（读 `AppPlatformScope` 分派）；
/// - 滚动容器（下拉刷新 vs 裸 CustomScrollView）与筛选面板容器（底部抽屉 vs 就地浮层）
///   由 `enablePullToRefresh` / `useMobileFilterDrawer` 两个壳参数表达。
class MomentsContent extends HookConsumerWidget {
  const MomentsContent({
    super.key,
    required this.keyPrefix,
    required this.rootKey,
    this.previewDrawerKey,
    this.enablePullToRefresh = false,
    this.useMobileFilterDrawer = false,
    this.onSearchSimilar,
    this.onOpenVideo,
    this.onOpenPlayer,
    this.onOpenMovieDetail,
  });

  /// 网格/筛选 Key 前缀：桌面 `moments`，移动 `mobile-moments`。
  final String keyPrefix;

  /// 列表根 Key：桌面 `moments-page`，移动 `mobile-overview-moments-tab`。
  final Key rootKey;

  /// 预览弹层落底部抽屉时的 drawerKey（移动端）；桌面不传。
  final Key? previewDrawerKey;

  /// 下拉刷新容器开关：`true`（移动）→ `AppAdaptiveRefreshScrollView`，
  /// `false`（桌面）→ 裸 `CustomScrollView`。
  final bool enablePullToRefresh;

  /// 顶栏筛选入口点开什么：`true` 弹底部抽屉（移动端），`false` 就地展开浮层（桌面端）。
  final bool useMobileFilterDrawer;

  /// 图搜导航回调（壳注入：桌面走 launcher / 移动走 draft store 中转）。
  final Future<void> Function(BuildContext context, MomentListItem item)?
  onSearchSimilar;

  /// 视频时刻播放回调（壳注入：桌面快播弹窗 / 移动 push 全屏页）。
  final void Function(BuildContext context, MomentListItem item)? onOpenVideo;

  /// 影片时刻播放回调（壳注入：桌面 push 播放器 / 移动 launchMoviePlayback）。
  final void Function(BuildContext context, MomentListItem item)? onOpenPlayer;

  /// 影片详情导航回调（壳注入：桌面 push 详情 / 移动 push 移动详情）。
  final void Function(BuildContext context, MomentListItem item)?
  onOpenMovieDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(momentsProvider);
    final state = async.value;
    final paged = state?.paged ?? const PagedListState<MomentListItem>();
    // 首次加载尚无 state 时，从 notifier 读默认筛选。
    final filter = state?.filter ?? ref.read(momentsProvider.notifier).filter;
    final scrollController = usePagedLoadMoreScroll(
      onReachBottom: () {
        // 对齐旧基类：loadMore 失败存续期间滚动不自动重试。
        if (paged.loadMoreErrorMessage == null) {
          unawaited(ref.read(momentsProvider.notifier).loadMore());
        }
      },
      triggerOffset: 300,
    );

    final showFooter =
        paged.isNotEmpty &&
        (paged.isLoadingMore || paged.loadMoreErrorMessage != null);
    final sliver = SliverMainAxisGroup(
      key: rootKey,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: context.appSpacing.sm),
              _buildHeader(context, ref, scrollController, paged, filter),
              SizedBox(height: context.appSpacing.md),
            ],
          ),
        ),
        _buildBody(context, ref, async, paged),
        if (showFooter)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: context.appSpacing.md),
              child: AppPagedLoadMoreFooter(
                isLoading: paged.isLoadingMore,
                errorMessage: paged.loadMoreErrorMessage,
                onRetry: () =>
                    unawaited(ref.read(momentsProvider.notifier).loadMore()),
              ),
            ),
          ),
      ],
    );

    return AppPageRefreshScope(
      onRefresh: () => _handleRefresh(context, ref),
      child: ColoredBox(
        color: context.appColors.surfaceCard,
        child: AppFilterResultLoadingOverlay(
          isLoading: paged.filterUpdate.isLoading,
          hasPreviousItems: paged.items.isNotEmpty,
          child: enablePullToRefresh
              ? AppAdaptiveRefreshScrollView(
                  onRefresh: () => _handleRefresh(context, ref),
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[sliver],
                )
              : CustomScrollView(
                  controller: scrollController,
                  slivers: <Widget>[sliver],
                ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh(BuildContext context, WidgetRef ref) async {
    final errorMessage = await ref.read(momentsProvider.notifier).refresh();
    if (errorMessage != null && context.mounted) {
      showToast('刷新失败');
    }
  }

  /// 桌面与移动共用同一条顶栏：筛选入口（当前内容类型）+ 总数信息槽。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
    PagedListState<MomentListItem> paged,
    MomentsFilter filter,
  ) {
    return AppListHeader(
      filterButtonKey: Key('$keyPrefix-filter-trigger'),
      // 摘要只报「内容类型」这一主维度，排序有独立分节，不堆在入口上。
      filterLabel: filter.kindFilter.label,
      filterPanelKey: Key('$keyPrefix-filter-panel'),
      filterPanelExtraWidth: 180,
      filterUpdate: paged.filterUpdate,
      hasPreviousFilterItems: paged.items.isNotEmpty,
      onRetryFilter: () =>
          unawaited(ref.read(momentsProvider.notifier).retryFilter()),
      onFilterTap: useMobileFilterDrawer
          ? () => unawaited(
              _openFilterDrawer(context, ref, scrollController, filter),
            )
          : null,
      filterPanelBuilder: useMobileFilterDrawer
          ? null
          : (_) => MomentFilterSectionGroup(
              kindFilter: filter.kindFilter,
              sortOrder: filter.sortOrder,
              keyPrefix: keyPrefix,
              onKindChanged: (next) => _applyFilter(
                ref,
                scrollController,
                (current) => current.copyWith(kindFilter: next),
              ),
              onSortChanged: (next) => _applyFilter(
                ref,
                scrollController,
                (current) => current.copyWith(sortOrder: next),
              ),
            ),
      informationSlots: [
        AppListHeaderInfo(
          key: Key('$keyPrefix-page-total'),
          label: '${paged.total} 个时刻',
        ),
      ],
    );
  }

  Future<void> _openFilterDrawer(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
    MomentsFilter filter,
  ) async {
    await showMobileMomentFilterDrawer(
      context,
      kindFilter: filter.kindFilter,
      sortOrder: filter.sortOrder,
      keyPrefix: keyPrefix,
      onKindChanged: (next) => _applyFilter(
        ref,
        scrollController,
        (current) => current.copyWith(kindFilter: next),
      ),
      onSortChanged: (next) => _applyFilter(
        ref,
        scrollController,
        (current) => current.copyWith(sortOrder: next),
      ),
    );
  }

  void _applyFilter(
    WidgetRef ref,
    ScrollController scrollController,
    MomentsFilter Function(MomentsFilter current) update,
  ) {
    final notifier = ref.read(momentsProvider.notifier);
    final next = update(notifier.filter);
    // 同值去重在这里做（applyFilterState 内部也会短路），避免同值时误 jumpTo(0)。
    if (next == notifier.filter) {
      return;
    }
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    unawaited(notifier.applyFilterState(next));
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<MomentsState> async,
    PagedListState<MomentListItem> paged,
  ) {
    if (async.isLoading && async.value == null) {
      return const SliverToBoxAdapter(child: AppMobileSkeletonList());
    }
    if (async.hasError && paged.isEmpty) {
      return const SliverToBoxAdapter(
        child: AppEmptyState(message: '时刻列表加载失败，请稍后重试'),
      );
    }
    if (paged.isEmpty && paged.filterUpdate.hasFailed) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (paged.isEmpty) {
      return const SliverToBoxAdapter(child: AppEmptyState(message: '暂无时刻数据'));
    }
    return MomentSliver(
      items: paged.items,
      onItemTap: (item) => _openMomentPreview(context, ref, item),
    );
  }

  Future<void> _openMomentPreview(
    BuildContext context,
    WidgetRef ref,
    MomentListItem item,
  ) async {
    final action = await showMomentPreviewOverlay(
      context: context,
      item: item,
      presentation: MediaPreviewPresentation.auto,
      drawerKey: previewDrawerKey,
      onPointRemoved: () =>
          unawaited(ref.read(momentsProvider.notifier).reload()),
      closeOnPointRemoved: true,
    );
    if (!context.mounted || action == null) {
      return;
    }
    switch (action) {
      case MediaPreviewAction.searchSimilar:
        await _searchSimilarFromMoment(context, item);
      case MediaPreviewAction.play:
        _openPlayerForMoment(context, item);
      case MediaPreviewAction.openMovieDetail:
        _openMovieDetailForMoment(context, item);
    }
  }

  Future<void> _searchSimilarFromMoment(
    BuildContext context,
    MomentListItem item,
  ) async {
    final imageUrl = resolveMomentImageUrl(item);
    if (imageUrl.isEmpty) {
      return;
    }
    final handler = onSearchSimilar;
    if (handler == null) {
      return;
    }
    try {
      await handler(context, item);
    } catch (_) {
      if (context.mounted) {
        showToast('读取结果图片失败，请稍后重试');
      }
    }
  }

  void _openPlayerForMoment(BuildContext context, MomentListItem item) {
    if (item.isVideo) {
      onOpenVideo?.call(context, item);
      return;
    }
    onOpenPlayer?.call(context, item);
  }

  void _openMovieDetailForMoment(BuildContext context, MomentListItem item) {
    if (item.isVideo) {
      return;
    }
    onOpenMovieDetail?.call(context, item);
  }
}
