import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_overview_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/add_to_moment_collection_dialog.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/pick_moment_collection_dialog.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/moments/presentation/moment_filter_sections.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/moments/presentation/providers/moments_provider.dart';
import 'package:sakuramedia/features/moments/presentation/providers/moments_state.dart';
import 'package:sakuramedia/features/shared/presentation/hooks/paged_scroll_hook.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/operations/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_cover_card.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_grid.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_image.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_preview_launcher.dart';

/// 时刻列表共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异全部收在壳注入的参数与回调里：
/// - Key 三件套（keyPrefix / rootKey / previewDrawerKey）由壳传参、本层产出；
/// - 图搜、演员、视频播放、影片播放、影片详情等导航分支收为壳注入的回调组；
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
    this.onOpenActorDetail,
    this.onOpenCollections,
    this.onOpenCollectionDetail,
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

  final void Function(BuildContext context, int actorId)? onOpenActorDetail;

  final VoidCallback? onOpenCollections;
  final ValueChanged<int>? onOpenCollectionDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(momentCollectionMutationEventsProvider, (_, next) {
      if (next.value != null) {
        unawaited(
          ref.read(momentCollectionsOverviewProvider.notifier).refresh(),
        );
      }
    });
    final async = ref.watch(momentsProvider);
    final collectionsAsync = ref.watch(momentCollectionsOverviewProvider);
    final state = async.value;
    final paged = state?.paged ?? const PagedListState<MomentListItem>();
    // 首次加载尚无 state 时，从 notifier 读默认筛选。
    final filter = state?.filter ?? ref.read(momentsProvider.notifier).filter;
    final selectionMode = useState(false);
    final selectedPointIds = useState<Set<int>>(<int>{});
    final selectedCount = selectedPointIds.value.length;

    void exitSelection() {
      selectionMode.value = false;
      selectedPointIds.value = <int>{};
    }

    void enterSelection([MomentListItem? item]) {
      selectionMode.value = true;
      if (item == null) return;
      final next = <int>{...selectedPointIds.value, item.pointId};
      selectedPointIds.value = next;
    }

    void toggleSelection(MomentListItem item) {
      final next = <int>{...selectedPointIds.value};
      if (!next.add(item.pointId)) {
        next.remove(item.pointId);
      }
      selectedPointIds.value = next;
    }

    void toggleSelectAll(Iterable<MomentListItem> items) {
      final currentItems = items.toList(growable: false);
      final ids = currentItems.map((item) => item.pointId).toSet();
      final allSelected =
          ids.isNotEmpty && ids.every(selectedPointIds.value.contains);
      final next = <int>{...selectedPointIds.value};
      if (allSelected) {
        next.removeWhere(ids.contains);
      } else {
        next.addAll(ids);
      }
      selectedPointIds.value = next;
    }

    useEffect(() {
      if (selectionMode.value || selectedPointIds.value.isNotEmpty) {
        exitSelection();
      }
      return null;
    }, [filter.sortOrder, filter.kindFilter]);

    final listHeaderKey = useMemoized(() => GlobalKey());
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
          child: _buildCollectionsSection(context, ref, collectionsAsync),
        ),
        AppPinnedListHeader(
          key: listHeaderKey,
          color: useMobileFilterDrawer
              ? context.appColors.surfaceCard
              : context.appColors.surfaceElevated,
          child: _buildMomentsHeader(
            context,
            ref,
            scrollController,
            listHeaderKey,
            paged,
            filter,
            selectionMode: selectionMode.value,
            selectedCount: selectedCount,
            selectedPointIds: selectedPointIds.value,
            onEnterSelection: () => enterSelection(),
            onExitSelection: exitSelection,
            onToggleAll: () => toggleSelectAll(paged.items),
            onBatchAddToCollection: () => unawaited(
              _batchAddToCollection(
                context,
                ref,
                paged.items,
                selectedPointIds.value,
                exitSelection,
              ),
            ),
            onBatchDelete: () => unawaited(
              _batchDelete(
                context,
                ref,
                paged.items,
                selectedPointIds.value,
                exitSelection,
              ),
            ),
          ),
        ),
        _buildBody(
          context,
          ref,
          async,
          paged,
          selectionMode: selectionMode.value,
          isSelected: (item) => selectedPointIds.value.contains(item.pointId),
          onSelectedChanged: toggleSelection,
          onLongPress: (item) {
            if (!selectionMode.value) {
              enterSelection(item);
            }
          },
        ),
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

    final page = AppFilterResultLoadingOverlay(
      protectedHeaderKey: listHeaderKey,
      scrollController: scrollController,
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
    );
    final pageWithSelectionBar = useMobileFilterDrawer && selectionMode.value
        ? Column(
            children: [
              Expanded(child: page),
              AppSelectionBottomBar(
                actions: [
                  AppButton(
                    key: Key('$keyPrefix-batch-add-collection-button'),
                    label: '加入合集',
                    variant: AppButtonVariant.secondary,
                    onPressed: selectedCount == 0
                        ? null
                        : () => unawaited(
                            _batchAddToCollection(
                              context,
                              ref,
                              paged.items,
                              selectedPointIds.value,
                              exitSelection,
                            ),
                          ),
                  ),
                  AppButton(
                    key: Key('$keyPrefix-batch-delete-button'),
                    label: '删除',
                    variant: AppButtonVariant.danger,
                    onPressed: selectedCount == 0
                        ? null
                        : () => unawaited(
                            _batchDelete(
                              context,
                              ref,
                              paged.items,
                              selectedPointIds.value,
                              exitSelection,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          )
        : page;

    return AppPageRefreshScope(
      onRefresh: () => _handleRefresh(context, ref),
      child: ColoredBox(
        color: useMobileFilterDrawer
            ? context.appColors.surfaceCard
            : context.appColors.surfaceElevated,
        child: pageWithSelectionBar,
      ),
    );
  }

  Future<void> _handleRefresh(BuildContext context, WidgetRef ref) async {
    final momentsRefresh = ref.read(momentsProvider.notifier).refresh();
    final collectionsRefresh = ref
        .read(momentCollectionsOverviewProvider.notifier)
        .refresh();
    final errorMessage = await momentsRefresh;
    await collectionsRefresh;
    if (errorMessage != null && context.mounted) {
      showToast('刷新失败');
    }
  }

  Widget _buildCollectionsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<MomentCollectionDto>> collectionsAsync,
  ) {
    final spacing = context.appSpacing;
    final collections = collectionsAsync.value ?? const <MomentCollectionDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (useMobileFilterDrawer) SizedBox(height: spacing.sm),
        Row(
          children: [
            Text(
              '时刻合集',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            const Spacer(),
            AppTextButton(
              key: Key('$keyPrefix-create-collection-button'),
              label: '新建',
              size: AppTextButtonSize.small,
              onPressed: () => _createCollection(context, ref),
            ),
            if (collections.isNotEmpty && onOpenCollections != null) ...[
              SizedBox(width: spacing.xs),
              AppTextButton(
                key: Key('$keyPrefix-view-all-collections-button'),
                label: '查看全部',
                size: AppTextButtonSize.small,
                onPressed: onOpenCollections,
              ),
            ],
          ],
        ),
        SizedBox(height: spacing.sm),
        _buildCollectionsRow(context, collectionsAsync, collections),
        SizedBox(height: spacing.lg),
      ],
    );
  }

  Widget _buildCollectionsRow(
    BuildContext context,
    AsyncValue<List<MomentCollectionDto>> collectionsAsync,
    List<MomentCollectionDto> collections,
  ) {
    final isMobile = useMobileFilterDrawer;
    final spacing = context.appSpacing;
    final height = isMobile ? 148.0 : 172.0;
    final itemWidth = isMobile ? 168.0 : 210.0;
    final itemSpacing = isMobile ? spacing.sm : spacing.md;
    if (collectionsAsync.hasError && collections.isEmpty) {
      return _MomentCollectionsHintBox(
        message: apiErrorMessage(
          collectionsAsync.error!,
          fallback: '合集暂时无法加载，请稍后重试',
        ),
      );
    }
    if (collectionsAsync.isLoading && collections.isEmpty) {
      return CollectionCardSkeletonRow(
        key: Key('$keyPrefix-collections-skeleton-row'),
        height: height,
        itemWidth: itemWidth,
        itemSpacing: itemSpacing,
      );
    }
    if (collections.isEmpty) {
      return const _MomentCollectionsHintBox(
        message: '还没有合集，点「新建」把喜欢的时刻攒成一个合集吧',
      );
    }
    return SizedBox(
      height: height,
      child: ListView.separated(
        key: Key('$keyPrefix-collections-row'),
        scrollDirection: Axis.horizontal,
        itemCount: collections.length,
        separatorBuilder: (context, index) => SizedBox(width: itemSpacing),
        itemBuilder: (context, index) {
          final collection = collections[index];
          return SizedBox(
            width: itemWidth,
            child: CollectionCoverCard(
              tapKey: Key('moment-collection-card-${collection.id}'),
              title: collection.name,
              count: collection.pointCount,
              coverUrl: collection.coverImage?.bestAvailableUrl,
              placeholderIcon: Icons.bookmarks_outlined,
              onTap: () => onOpenCollectionDetail?.call(collection.id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createCollection(BuildContext context, WidgetRef ref) async {
    final created = await showMomentCollectionEditor(
      context,
      presentation: useMobileFilterDrawer
          ? MomentCollectionEditPresentation.bottomDrawer
          : MomentCollectionEditPresentation.dialog,
    );
    if (!context.mounted || created == null) {
      return;
    }
    ref
        .read(momentCollectionsOverviewProvider.notifier)
        .insertCollection(created);
    showToast('已创建时刻合集');
  }

  Widget _buildMomentsHeader(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
    GlobalKey listHeaderKey,
    PagedListState<MomentListItem> paged,
    MomentsFilter filter, {
    required bool selectionMode,
    required int selectedCount,
    required Set<int> selectedPointIds,
    required VoidCallback onEnterSelection,
    required VoidCallback onExitSelection,
    required VoidCallback onToggleAll,
    required VoidCallback onBatchAddToCollection,
    required VoidCallback onBatchDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: context.appSpacing.sm),
          child: Row(
            children: [
              Text(
                '全部时刻',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        if (selectionMode)
          _buildSelectionHeader(
            context,
            paged.items,
            selectedCount: selectedCount,
            selectedPointIds: selectedPointIds,
            onToggleAll: onToggleAll,
            onBatchAddToCollection: onBatchAddToCollection,
            onBatchDelete: onBatchDelete,
            onExitSelection: onExitSelection,
          ),
        if (!selectionMode)
          _buildHeader(
            context,
            ref,
            scrollController,
            listHeaderKey,
            paged,
            filter,
            onEnterSelection,
          ),
      ],
    );
  }

  Widget _buildSelectionHeader(
    BuildContext context,
    List<MomentListItem> items, {
    required int selectedCount,
    required Set<int> selectedPointIds,
    required VoidCallback onToggleAll,
    required VoidCallback onBatchAddToCollection,
    required VoidCallback onBatchDelete,
    required VoidCallback onExitSelection,
  }) {
    final ids = items.map((item) => item.pointId).toSet();
    final allSelected = ids.isNotEmpty && ids.every(selectedPointIds.contains);
    final hasSelection = selectedCount > 0;
    if (useMobileFilterDrawer) {
      return AppListHeader.selection(
        selectionLabel: '已选 $selectedCount 个',
        selectionExitButtonKey: Key('$keyPrefix-exit-selection-button'),
        onExitSelection: onExitSelection,
        actionSlots: [
          AppButton(
            key: Key('$keyPrefix-select-all-button'),
            label: allSelected ? '取消全选' : '全选',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.xSmall,
            isSelected: allSelected,
            onPressed: onToggleAll,
          ),
        ],
      );
    }
    return AppSelectionHeaderToolbar(
      countLabel: '已选 $selectedCount 个',
      selectAllLabel: allSelected ? '取消全选' : '全选',
      selectAllKey: Key('$keyPrefix-select-all-button'),
      onToggleAll: onToggleAll,
      actions: [
        AppButton(
          key: Key('$keyPrefix-selection-add-collection-button'),
          label: '加入合集',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection ? onBatchAddToCollection : null,
        ),
        AppButton(
          key: Key('$keyPrefix-selection-delete-button'),
          label: '删除',
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection ? onBatchDelete : null,
        ),
      ],
      exitKey: Key('$keyPrefix-exit-selection-button'),
      onExit: onExitSelection,
    );
  }

  /// 桌面与移动共用同一条顶栏：筛选入口（当前内容类型）+ 总数信息槽。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
    GlobalKey listHeaderKey,
    PagedListState<MomentListItem> paged,
    MomentsFilter filter,
    VoidCallback onEnterSelection,
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
              _openFilterDrawer(
                context,
                ref,
                scrollController,
                listHeaderKey,
                filter,
              ),
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
                listHeaderKey,
                (current) => current.copyWith(kindFilter: next),
              ),
              onSortChanged: (next) => _applyFilter(
                ref,
                scrollController,
                listHeaderKey,
                (current) => current.copyWith(sortOrder: next),
              ),
            ),
      informationSlots: [
        AppListHeaderInfo(
          key: Key('$keyPrefix-page-total'),
          label: '${paged.total} 个时刻',
        ),
      ],
      actionSlots: paged.items.isEmpty
          ? const <Widget>[]
          : [
              AppTextButton(
                key: Key('$keyPrefix-enter-selection-button'),
                label: '选择',
                size: useMobileFilterDrawer
                    ? AppTextButtonSize.xSmall
                    : AppTextButtonSize.small,
                icon: Icon(
                  Icons.check_circle_outline,
                  size: useMobileFilterDrawer ? 14 : 16,
                ),
                onPressed: onEnterSelection,
              ),
            ],
    );
  }

  Future<void> _openFilterDrawer(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
    GlobalKey listHeaderKey,
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
        listHeaderKey,
        (current) => current.copyWith(kindFilter: next),
      ),
      onSortChanged: (next) => _applyFilter(
        ref,
        scrollController,
        listHeaderKey,
        (current) => current.copyWith(sortOrder: next),
      ),
    );
  }

  void _applyFilter(
    WidgetRef ref,
    ScrollController scrollController,
    GlobalKey listHeaderKey,
    MomentsFilter Function(MomentsFilter current) update,
  ) {
    final notifier = ref.read(momentsProvider.notifier);
    final next = update(notifier.filter);
    // 同值去重在这里做（applyFilterState 内部也会短路），避免同值时误 jumpTo(0)。
    if (next == notifier.filter) {
      return;
    }
    if (scrollController.hasClients) {
      AppPinnedListHeader.scrollToStart(listHeaderKey, scrollController);
    }
    unawaited(notifier.applyFilterState(next));
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<MomentsState> async,
    PagedListState<MomentListItem> paged, {
    required bool selectionMode,
    required bool Function(MomentListItem item) isSelected,
    required ValueChanged<MomentListItem> onSelectedChanged,
    required ValueChanged<MomentListItem> onLongPress,
  }) {
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
      selectionMode: selectionMode,
      isSelected: isSelected,
      onSelectedChanged: onSelectedChanged,
      onLongPress: useMobileFilterDrawer && !selectionMode ? onLongPress : null,
    );
  }

  Future<void> _openMomentPreview(
    BuildContext context,
    WidgetRef ref,
    MomentListItem item,
  ) async {
    int? selectedActorId;
    final action = await showMomentPreviewOverlay(
      context: context,
      item: item,
      presentation: MediaPreviewPresentation.auto,
      drawerKey: previewDrawerKey,
      onPointRemoved: () => unawaited(_refreshAfterPointDelete(ref)),
      closeOnPointRemoved: true,
      allowAddToCollection: true,
      useInlineNavigation: true,
      onActorSelected: (actorId) => selectedActorId = actorId,
    );
    if (!context.mounted) {
      return;
    }
    if (selectedActorId != null) {
      onOpenActorDetail?.call(context, selectedActorId!);
      return;
    }
    if (action == null) return;
    switch (action) {
      case MediaPreviewAction.searchSimilar:
        await _searchSimilarFromMoment(context, item);
      case MediaPreviewAction.play:
        _openPlayerForMoment(context, item);
      case MediaPreviewAction.openMovieDetail:
        _openMovieDetailForMoment(context, item);
      case MediaPreviewAction.addToCollection:
        await showAddToMomentCollectionDialog(
          context,
          pointId: item.pointId,
          useBottomDrawer: useMobileFilterDrawer,
        );
    }
  }

  Future<void> _batchAddToCollection(
    BuildContext context,
    WidgetRef ref,
    List<MomentListItem> items,
    Set<int> selectedPointIds,
    VoidCallback onFinished,
  ) async {
    final selected = items
        .where((item) => selectedPointIds.contains(item.pointId))
        .toList(growable: false);
    if (selected.isEmpty) return;
    final target = await showPickMomentCollectionDialog(
      context,
      presentation: useMobileFilterDrawer
          ? PickMomentCollectionPresentation.bottomDrawer
          : PickMomentCollectionPresentation.dialog,
    );
    if (!context.mounted || target == null) return;
    final result = await runBatchOperation<MomentListItem>(
      context,
      title: '正在加入「${target.name}」',
      items: selected,
      action: (item) => ref
          .read(momentCollectionsApiProvider)
          .addPoint(collectionId: target.id, pointId: item.pointId),
    );
    if (!context.mounted) return;
    if (result.succeeded.isNotEmpty) {
      ref
          .read(momentCollectionMutationEventsProvider.notifier)
          .reportChanged(target.id);
    }
    if (result.failed.isEmpty) {
      showToast('已加入合集 ${result.succeeded.length} 个时刻');
    } else {
      showToast(
        '加入合集完成：成功 ${result.succeeded.length} 个，失败 ${result.failed.length} 个',
      );
    }
    onFinished();
  }

  Future<void> _batchDelete(
    BuildContext context,
    WidgetRef ref,
    List<MomentListItem> items,
    Set<int> selectedPointIds,
    VoidCallback onFinished,
  ) async {
    final selected = items
        .where((item) => selectedPointIds.contains(item.pointId))
        .toList(growable: false);
    if (selected.isEmpty) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除时刻',
      message: '确认删除选中的 ${selected.length} 个时刻？只会删除时刻标记，不会删除原视频或媒体文件。',
      confirmLabel: '删除',
      danger: true,
      dialogKey: Key('$keyPrefix-batch-delete-dialog'),
      confirmKey: Key('$keyPrefix-batch-delete-confirm-button'),
    );
    if (!context.mounted || !confirmed) return;
    final result = await runBatchOperation<MomentListItem>(
      context,
      title: '正在删除时刻',
      items: selected,
      action: (item) => ref
          .read(mediaApiProvider)
          .deleteMediaPoint(mediaId: item.mediaId, pointId: item.pointId),
    );
    if (!context.mounted) return;
    onFinished();
    if (result.succeeded.isNotEmpty) {
      unawaited(_refreshAfterPointDelete(ref));
    }
    if (result.failed.isEmpty) {
      showToast('已删除 ${result.succeeded.length} 个时刻');
    } else {
      showToast(
        '删除时刻完成：成功 ${result.succeeded.length} 个，失败 ${result.failed.length} 个',
      );
    }
  }

  Future<void> _refreshAfterPointDelete(WidgetRef ref) async {
    await ref.read(momentsProvider.notifier).reload();
    await ref.read(momentCollectionsOverviewProvider.notifier).refresh();
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

class _MomentCollectionsHintBox extends StatelessWidget {
  const _MomentCollectionsHintBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Text(
        message,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }
}
