import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/moment_collection_placeholders.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_overview_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/pick_moment_collection_dialog.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/moments/presentation/actions/moment_preview_flow.dart';
import 'package:sakuramedia/features/moments/presentation/moment_filter_sections.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/moments/presentation/moment_placeholders.dart';
import 'package:sakuramedia/features/moments/presentation/providers/moments_provider.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_hint_box.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_grid.dart';

/// 时刻列表共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异全部收在壳注入的参数与回调里：
/// - Key 三件套（keyPrefix / rootKey / previewDrawerKey）由壳传参、本层产出；
/// - 预览关闭后的导航（图搜、演员、视频/影片播放、影片详情）统一走
///   [showMomentPreviewFlow]，由 `isMobile` + `previewFallbackPath` 表达平台差异；
/// - 滚动容器（下拉刷新 vs 裸 CustomScrollView）与筛选面板容器（底部抽屉 vs 就地浮层）
///   由 `enablePullToRefresh` / `useMobileFilterDrawer` 两个壳参数表达。
class MomentsContent extends HookConsumerWidget {
  const MomentsContent({
    super.key,
    required this.keyPrefix,
    required this.rootKey,
    required this.previewFallbackPath,
    this.previewDrawerKey,
    this.enablePullToRefresh = false,
    this.useMobileFilterDrawer = false,
    this.enabled = true,
    this.onOpenCollections,
    this.onOpenCollectionDetail,
  });

  /// 网格/筛选 Key 前缀：桌面 `moments`，移动 `mobile-moments`。
  final String keyPrefix;

  /// 列表根 Key：桌面 `moments-page`，移动 `mobile-overview-moments-tab`。
  final Key rootKey;

  /// 预览关闭后的图搜 / 影片详情 / 演员详情 / 应用内播放器的兜底路径。
  final String previewFallbackPath;

  /// 预览弹层落底部抽屉时的 drawerKey（移动端）；桌面不传。
  final Key? previewDrawerKey;

  /// 下拉刷新容器开关：`true`（移动）→ `AppAdaptiveRefreshScrollView`，
  /// `false`（桌面）→ 裸 `CustomScrollView`。
  final bool enablePullToRefresh;

  /// 顶栏筛选入口点开什么：`true` 弹底部抽屉（移动端），`false` 就地展开浮层（桌面端）。
  final bool useMobileFilterDrawer;

  /// 所在 Tab 是否可见；隐藏的 keep-alive Tab 不应继续自动补页。
  final bool enabled;

  final VoidCallback? onOpenCollections;
  final ValueChanged<int>? onOpenCollectionDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.listen(momentCollectionMutationEventsProvider, (_, next) {
      if (next.value != null) {
        unawaited(
          ref.read(momentCollectionsOverviewProvider.notifier).refresh(),
        );
      }
    });
    final paged = ref.watch(
      momentsProvider.select(
        (async) => pagedViewSnapshot(async, (state) => state.paged),
      ),
    );
    final collectionsAsync = ref.watch(momentCollectionsOverviewProvider);
    // 筛选变化频率低，与分页快照分开订阅。
    // 首次加载尚无 state 时，从 notifier 读默认筛选。
    final filter =
        ref.watch(momentsProvider.select((async) => async.value?.filter)) ??
        ref.read(momentsProvider.notifier).filter;
    final selectionMode = useState(false);
    final selectedPointIds = useState<Set<int>>(<int>{});
    final selectedCount = selectedPointIds.value.length;
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.momentCollectionAdd,
      BatchOperationType.momentCollectionRemove,
      BatchOperationType.mediaPointDelete,
    ]);

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
    final scrollController = useScrollController();

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
              : Colors.transparent,
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
            submitting: submitting,
          ),
        ),
        _buildBody(
          context,
          ref,
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
        // loadMore 页脚独立订阅：翻页 loading / 失败只重建页脚。
        PagedLoadMoreFooterSliver(
          watchFooter: (ref) => ref.watch(
            momentsProvider.select(
              (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
            ),
          ),
          onLoadMore: (ref) =>
              unawaited(ref.read(momentsProvider.notifier).loadMore()),
        ),
      ],
    );

    final page = AppFilterResultLoadingOverlay(
      surfaceColor: useMobileFilterDrawer
          ? context.appColors.surfaceCard
          : context.appColors.surfacePage,
      protectedHeaderKey: listHeaderKey,
      scrollController: scrollController,
      isLoading: paged.filterUpdate.isLoading,
      hasPreviousItems: paged.items.isNotEmpty,
      child: AppPagedLoadMoreScope(
        enabled: enabled,
        canLoadMore: () =>
            ref.read(momentsProvider).value?.paged.canAutoLoadMore ?? false,
        onLoadMore: () => ref.read(momentsProvider.notifier).loadMore(),
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
    );
    final pageWithSelectionBar = useMobileFilterDrawer && selectionMode.value
        ? Column(
            children: [
              Expanded(child: page),
              AppSelectionBottomBar(
                actions: [
                  AppButton(
                    key: Key('$keyPrefix-batch-add-collection-button'),
                    label: l10n.momentAddToCollection,
                    variant: AppButtonVariant.secondary,
                    onPressed: selectedCount == 0 || submitting
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
                    label: l10n.commonDelete,
                    variant: AppButtonVariant.danger,
                    onPressed: selectedCount == 0 || submitting
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
      child: pageWithSelectionBar,
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
      showToast(
        AppLocalizations.of(context).momentErrorRefreshFailed,
        tone: AppToastTone.error,
      );
    }
  }

  Widget _buildCollectionsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<MomentCollectionDto>> collectionsAsync,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final collections = collectionsAsync.value ?? const <MomentCollectionDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (useMobileFilterDrawer) SizedBox(height: spacing.sm),
        Row(
          children: [
            Text(
              l10n.momentCollectionSectionTitle,
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
              label: l10n.momentNewAction,
              size: AppTextButtonSize.small,
              onPressed: () => _createCollection(context, ref),
            ),
            if (collections.isNotEmpty && onOpenCollections != null) ...[
              SizedBox(width: spacing.xs),
              AppTextButton(
                key: Key('$keyPrefix-view-all-collections-button'),
                label: l10n.momentViewAll,
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
      final l10n = AppLocalizations.of(context);
      return CollectionHintBox(
        message: apiErrorMessage(
          collectionsAsync.error!,
          fallback: l10n.momentErrorCollectionLoadFailed,
          l10n: l10n,
        ),
      );
    }
    final isLoading = collectionsAsync.isLoading && collections.isEmpty;
    final display = isLoading
        ? momentCollectionPlaceholders(count: 4)
        : collections;
    if (display.isEmpty) {
      return CollectionHintBox(
        message: AppLocalizations.of(context).momentCollectionEmptyHint,
      );
    }
    return AppSkeletonizer(
      enabled: isLoading,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          key: Key('$keyPrefix-collections-row'),
          scrollDirection: Axis.horizontal,
          itemCount: display.length,
          separatorBuilder: (context, index) => SizedBox(width: itemSpacing),
          itemBuilder: (context, index) {
            final collection = display[index];
            return SizedBox(
              width: itemWidth,
              // 卡片按内容自然高度渲染，避免被固定行高拉伸后在标题下方留白。
              child: Align(
                alignment: Alignment.topCenter,
                child: CollectionCard.moment(
                  collection: collection,
                  onTap: () => onOpenCollectionDetail?.call(collection.id),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _createCollection(BuildContext context, WidgetRef ref) async {
    final created = await showMomentCollectionEditor(context);
    if (!context.mounted || created == null) {
      return;
    }
    ref
        .read(momentCollectionsOverviewProvider.notifier)
        .insertCollection(created);
    showToast(
      AppLocalizations.of(context).momentCollectionCreatedFromMomentsToast,
      tone: AppToastTone.success,
    );
  }

  Widget _buildMomentsHeader(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
    GlobalKey listHeaderKey,
    PagedViewSnapshot<MomentListItem> paged,
    MomentsFilter filter, {
    required bool selectionMode,
    required int selectedCount,
    required Set<int> selectedPointIds,
    required VoidCallback onEnterSelection,
    required VoidCallback onExitSelection,
    required VoidCallback onToggleAll,
    required VoidCallback onBatchAddToCollection,
    required VoidCallback onBatchDelete,
    required bool submitting,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            submitting: submitting,
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
    required bool submitting,
  }) {
    final ids = items.map((item) => item.pointId).toSet();
    final allSelected = ids.isNotEmpty && ids.every(selectedPointIds.contains);
    final hasSelection = selectedCount > 0;
    final l10n = AppLocalizations.of(context);
    if (useMobileFilterDrawer) {
      return AppListHeader.selection(
        selectionLabel: l10n.momentSelectedCount(selectedCount),
        selectionExitButtonKey: Key('$keyPrefix-exit-selection-button'),
        onExitSelection: onExitSelection,
        actionSlots: [
          AppButton(
            key: Key('$keyPrefix-select-all-button'),
            label: allSelected ? l10n.momentDeselectAll : l10n.momentSelectAll,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.xSmall,
            isSelected: allSelected,
            onPressed: onToggleAll,
          ),
        ],
      );
    }
    return AppSelectionHeaderToolbar(
      countLabel: l10n.momentSelectedCount(selectedCount),
      selectAllLabel: allSelected
          ? l10n.momentDeselectAll
          : l10n.momentSelectAll,
      selectAllKey: Key('$keyPrefix-select-all-button'),
      onToggleAll: onToggleAll,
      actions: [
        AppButton(
          key: Key('$keyPrefix-selection-add-collection-button'),
          label: l10n.momentAddToCollection,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection && !submitting
              ? onBatchAddToCollection
              : null,
        ),
        AppButton(
          key: Key('$keyPrefix-selection-delete-button'),
          label: l10n.commonDelete,
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection && !submitting ? onBatchDelete : null,
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
    PagedViewSnapshot<MomentListItem> paged,
    MomentsFilter filter,
    VoidCallback onEnterSelection,
  ) {
    final l10n = AppLocalizations.of(context);
    return AppListHeader(
      filterButtonKey: Key('$keyPrefix-filter-trigger'),
      // 摘要只报「内容类型」这一主维度，排序有独立分节，不堆在入口上。
      filterLabel: filter.kindFilter.label(l10n),
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
          label: l10n.momentCountLabel(paged.total),
        ),
      ],
      actionSlots: paged.items.isEmpty
          ? const <Widget>[]
          : [
              AppTextButton(
                key: Key('$keyPrefix-enter-selection-button'),
                label: l10n.momentSelectAction,
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
    PagedViewSnapshot<MomentListItem> paged, {
    required bool selectionMode,
    required bool Function(MomentListItem item) isSelected,
    required ValueChanged<MomentListItem> onSelectedChanged,
    required ValueChanged<MomentListItem> onLongPress,
  }) {
    final isLoading = paged.isInitialLoading;
    final l10n = AppLocalizations.of(context);
    if (!isLoading && paged.initialError != null && paged.items.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(message: l10n.errorMomentListLoadFailed),
      );
    }
    if (!isLoading && paged.items.isEmpty && paged.filterUpdate.hasFailed) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (!isLoading && paged.items.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(message: l10n.momentEmptyList),
      );
    }
    // loading 用占位时刻渲染真实卡片，由 [AppSkeletonizer] 灰化。
    final items = isLoading ? momentListPlaceholders() : paged.items;
    return AppSkeletonizer.sliver(
      enabled: isLoading,
      child: MomentSliver(
        items: items,
        onItemTap: (item) => _openMomentPreview(context, ref, item),
        onItemPlay: (item) => unawaited(
          playMomentItem(
            context: context,
            item: item,
            fallbackPath: previewFallbackPath,
          ),
        ),
        onItemOpenMovie: (item) => openMomentSourceMovie(
          context: context,
          item: item,
          fallbackPath: previewFallbackPath,
        ),
        onItemAddToCollection: (item) =>
            unawaited(addMomentItemToCollection(context, item: item)),
        onItemDelete: (item) => unawaited(_deleteItem(context, ref, item)),
        selectionMode: selectionMode,
        isSelected: isSelected,
        onSelectedChanged: onSelectedChanged,
        onLongPress: useMobileFilterDrawer && !selectionMode
            ? onLongPress
            : null,
      ),
    );
  }

  /// 卡片悬停「删除」：删除时刻标记本体（确认后硬删并刷新列表）。
  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    MomentListItem item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.momentDeleteTitle,
      message: l10n.momentDeleteMarkerConfirmMessage(
        item.localizedDisplayLabel(l10n),
      ),
      confirmLabel: l10n.commonDelete,
      danger: true,
      dialogKey: Key('$keyPrefix-delete-dialog'),
      confirmKey: Key('$keyPrefix-delete-confirm-button'),
    );
    if (!context.mounted || !confirmed) {
      return;
    }
    try {
      await ref.read(mediaApiProvider).deleteMediaPoint(pointId: item.pointId);
      if (!context.mounted) {
        return;
      }
      unawaited(_refreshAfterPointDelete(ref));
      showToast(l10n.momentDeletedToast, tone: AppToastTone.success);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.momentErrorDeleteFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> _openMomentPreview(
    BuildContext context,
    WidgetRef ref,
    MomentListItem item,
  ) {
    return showMomentPreviewFlow(
      context: context,
      item: item,
      fallbackPath: previewFallbackPath,
      drawerKey: previewDrawerKey,
      onPointRemoved: () => unawaited(_refreshAfterPointDelete(ref)),
    );
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
    final target = await showPickMomentCollectionDialog(context);
    if (!context.mounted || target == null) return;
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.momentCollectionAdd,
      targetCollectionId: target.id,
      ids: selected.map((item) => item.pointId).toList(growable: false),
    );
    if (!context.mounted) return;
    if (submitted) onFinished();
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.momentDeleteTitle,
      message: l10n.momentBatchDeleteMarkerConfirmMessage(selected.length),
      confirmLabel: l10n.commonDelete,
      danger: true,
      dialogKey: Key('$keyPrefix-batch-delete-dialog'),
      confirmKey: Key('$keyPrefix-batch-delete-confirm-button'),
    );
    if (!context.mounted || !confirmed) return;
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.mediaPointDelete,
      ids: selected.map((item) => item.pointId).toList(growable: false),
    );
    if (!context.mounted) return;
    if (submitted) onFinished();
  }

  Future<void> _refreshAfterPointDelete(WidgetRef ref) async {
    await ref.read(momentsProvider.notifier).reload();
    await ref.read(momentCollectionsOverviewProvider.notifier).refresh();
  }
}
