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
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/use_multi_selection.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';
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
    final selection = useMultiSelection<int>();
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.momentCollectionAdd,
      BatchOperationType.momentCollectionRemove,
      BatchOperationType.mediaPointDelete,
    ]);

    void batchAddToCollection() =>
        unawaited(_batchAddToCollection(context, ref, paged.items, selection));
    void batchDelete() =>
        unawaited(_batchDelete(context, ref, paged.items, selection));

    useEffect(() {
      if (selection.selectionMode || selection.selectedCount > 0) {
        selection.exit();
      }
      return null;
    }, [filter.sortOrder, filter.kindFilter]);

    final listHeaderKey = useMemoized(() => GlobalKey());
    final scrollController = useScrollController();

    final sliver = AppPinnedSliverSection(
      key: rootKey,
      headerKey: listHeaderKey,
      before: [
        SliverToBoxAdapter(
          child: _buildCollectionsSection(context, ref, collectionsAsync),
        ),
      ],
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selection.selectionMode)
            _buildSelectionHeader(
              context,
              paged.items,
              selection: selection,
              onBatchAddToCollection: batchAddToCollection,
              onBatchDelete: batchDelete,
              submitting: submitting,
            )
          else
            _buildHeader(
              context,
              ref,
              scrollController,
              listHeaderKey,
              paged,
              filter,
              () => selection.enter(),
            ),
        ],
      ),
      headerBottomSpacing: useMobileFilterDrawer
          ? context.appSpacing.md
          : context.appSpacing.lg,
      after: [
        _buildBody(
          context,
          ref,
          paged,
          selection: selection,
          onLongPress: (item) {
            if (!selection.selectionMode) {
              selection.enter(item.pointId);
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
    final pageWithSelectionBar =
        useMobileFilterDrawer && selection.selectionMode
        ? Column(
            children: [
              Expanded(child: page),
              AppSelectionBottomBar(
                actions: [
                  AppButton(
                    key: Key('$keyPrefix-batch-add-collection-button'),
                    label: l10n.momentAddToCollection,
                    variant: AppButtonVariant.secondary,
                    onPressed: selection.selectedCount == 0 || submitting
                        ? null
                        : batchAddToCollection,
                  ),
                  AppButton(
                    key: Key('$keyPrefix-batch-delete-button'),
                    label: l10n.commonDelete,
                    variant: AppButtonVariant.danger,
                    onPressed: selection.selectedCount == 0 || submitting
                        ? null
                        : batchDelete,
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

  Widget _buildSelectionHeader(
    BuildContext context,
    List<MomentListItem> items, {
    required MultiSelection<int> selection,
    required VoidCallback onBatchAddToCollection,
    required VoidCallback onBatchDelete,
    required bool submitting,
  }) {
    final ids = items.map((item) => item.pointId);
    final allSelected = selection.isAllSelected(ids);
    final hasSelection = selection.selectedCount > 0;
    final l10n = AppLocalizations.of(context);
    if (useMobileFilterDrawer) {
      return AppMobileSelectionHeader(
        selectionLabel: l10n.momentSelectedCount(selection.selectedCount),
        exitKey: Key('$keyPrefix-exit-selection-button'),
        onExitSelection: selection.exit,
        selectAllKey: Key('$keyPrefix-select-all-button'),
        selectAllTooltip: allSelected
            ? l10n.momentDeselectAll
            : l10n.momentSelectAll,
        onToggleAll: () => selection.toggleAll(ids),
      );
    }
    return AppGlassSelectionHeader(
      selectionLabel: l10n.momentSelectedCount(selection.selectedCount),
      selectAllLabel: allSelected
          ? l10n.momentDeselectAll
          : l10n.momentSelectAll,
      selectAllKey: Key('$keyPrefix-select-all-button'),
      onToggleAll: () => selection.toggleAll(ids),
      onExitSelection: selection.exit,
      exitKey: Key('$keyPrefix-exit-selection-button'),
      actions: <AppGlassSelectionAction>[
        AppGlassSelectionAction(
          key: Key('$keyPrefix-selection-add-collection-button'),
          label: l10n.momentAddToCollection,
          icon: Icons.playlist_add_rounded,
          onTap: hasSelection && !submitting ? onBatchAddToCollection : null,
        ),
        AppGlassSelectionAction(
          key: Key('$keyPrefix-selection-delete-button'),
          label: l10n.commonDelete,
          icon: Icons.delete_outline_rounded,
          foregroundColor: context.appTextPalette.error,
          onTap: hasSelection && !submitting ? onBatchDelete : null,
        ),
      ],
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
    if (!useMobileFilterDrawer) {
      return _buildGlassHeader(
        context,
        ref,
        scrollController,
        listHeaderKey,
        paged,
        filter,
        onEnterSelection,
      );
    }
    return AppMobileListHeader(
      leading: AppMobileHeaderText(
        key: Key('$keyPrefix-page-total'),
        countLabel: l10n.momentCountLabel(paged.total),
      ),
      actions: <Widget>[
        AppGlassFilterIconButton(
          key: Key('$keyPrefix-filter-trigger'),
          summary:
              '${filter.kindFilter.label(l10n)} · '
              '${filter.sortOrder.label(l10n)}',
          isActive:
              filter.kindFilter != MomentsFilter.initial.kindFilter ||
              filter.sortOrder != MomentsFilter.initial.sortOrder,
          onPressed: () => unawaited(
            _openFilterDrawer(
              context,
              ref,
              scrollController,
              listHeaderKey,
              filter,
            ),
          ),
        ),
        if (paged.items.isNotEmpty)
          AppGlassIconButton(
            key: Key('$keyPrefix-enter-selection-button'),
            tooltip: l10n.momentSelectAction,
            icon: Icons.check_circle_outline,
            onPressed: onEnterSelection,
          ),
      ],
      filterUpdate: paged.filterUpdate,
      hasPreviousFilterItems: paged.items.isNotEmpty,
      onRetryFilter: () =>
          unawaited(ref.read(momentsProvider.notifier).retryFilter()),
    );
  }

  Widget _buildGlassHeader(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
    GlobalKey listHeaderKey,
    PagedViewSnapshot<MomentListItem> paged,
    MomentsFilter filter,
    VoidCallback onEnterSelection,
  ) {
    final l10n = AppLocalizations.of(context);
    void applyKind(MomentKindFilter next) => _applyFilter(
      ref,
      scrollController,
      listHeaderKey,
      (current) => current.copyWith(kindFilter: next),
    );
    void applySort(MomentSortOrder next) => _applyFilter(
      ref,
      scrollController,
      listHeaderKey,
      (current) => current.copyWith(sortOrder: next),
    );

    return AppGlassListHeader(
      leading: AppGlassFilterPopover(
        panelKey: Key('$keyPrefix-filter-panel'),
        showResetFooter: false,
        triggerKey: Key('$keyPrefix-filter-trigger'),
        label: filter.kindFilter.label(l10n),
        tooltip: l10n.baseFilterTooltip,
        info: <Widget>[
          AppGlassHeaderText(
            key: Key('$keyPrefix-page-total'),
            label: l10n.momentCountLabel(paged.total),
          ),
        ],
        panelBuilder: (context) => AppFilterChoiceSection<MomentKindFilter>(
          title: l10n.momentFilterKindTitle,
          controlKey: Key('$keyPrefix-filter-kind'),
          items: <AppSegmentedItem<MomentKindFilter>>[
            for (final kind in MomentKindFilter.values)
              AppSegmentedItem(value: kind, label: kind.label(l10n)),
          ],
          selected: filter.kindFilter,
          onChanged: applyKind,
        ),
      ),
      trailing: AppGlassPopover(
        panelKey: Key('$keyPrefix-sort-panel'),
        triggerBuilder: (context, toggle) => AppGlassHeaderGroup(
          children: <Widget>[
            AppGlassHeaderButton(
              key: Key('$keyPrefix-sort-trigger'),
              icon: Icons.swap_vert_rounded,
              label: filter.sortOrder.label(l10n),
              trailingIcon: Icons.expand_more_rounded,
              tooltip: l10n.baseSortTooltip,
              onTap: toggle,
            ),
            if (paged.items.isNotEmpty)
              AppGlassHeaderButton(
                key: Key('$keyPrefix-enter-selection-button'),
                icon: Icons.check_circle_outline,
                label: l10n.momentSelectAction,
                onTap: onEnterSelection,
              ),
          ],
        ),
        contentBuilder: (context, close) =>
            AppFilterChoiceSection<MomentSortOrder>(
              title: l10n.momentFilterSortTitle,
              controlKey: Key('$keyPrefix-sort-order'),
              items: <AppSegmentedItem<MomentSortOrder>>[
                for (final order in MomentSortOrder.values)
                  AppSegmentedItem(value: order, label: order.label(l10n)),
              ],
              selected: filter.sortOrder,
              onChanged: applySort,
            ),
      ),
      filterUpdate: paged.filterUpdate,
      hasPreviousFilterItems: paged.items.isNotEmpty,
      onRetryFilter: () =>
          unawaited(ref.read(momentsProvider.notifier).retryFilter()),
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
    required MultiSelection<int> selection,
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
        selectionMode: selection.selectionMode,
        isSelected: (item) => selection.isSelected(item.pointId),
        onSelectedChanged: (item) => selection.toggle(item.pointId),
        onLongPress: useMobileFilterDrawer && !selection.selectionMode
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
    MultiSelection<int> selection,
  ) async {
    final selected = items
        .where((item) => selection.isSelected(item.pointId))
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
    if (submitted) selection.exit();
  }

  Future<void> _batchDelete(
    BuildContext context,
    WidgetRef ref,
    List<MomentListItem> items,
    MultiSelection<int> selection,
  ) async {
    final selected = items
        .where((item) => selection.isSelected(item.pointId))
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
    if (submitted) selection.exit();
  }

  Future<void> _refreshAfterPointDelete(WidgetRef ref) async {
    await ref.read(momentsProvider.notifier).reload();
    await ref.read(momentCollectionsOverviewProvider.notifier).refresh();
  }
}
