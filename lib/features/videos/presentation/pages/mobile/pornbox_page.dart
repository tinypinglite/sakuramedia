import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_overview_actions.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_overview_collections_section.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_scope.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_overview_grid_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/interaction/app_context_menu_trigger.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/domain/videos/video_sort_menu_button.dart';

/// 移动端 PornBox 首页：大标题 + 合集横滑区 + 吸顶视频网格。
class MobilePornboxPage extends ConsumerStatefulWidget {
  const MobilePornboxPage({super.key});

  @override
  ConsumerState<MobilePornboxPage> createState() => _MobilePornboxPageState();
}

class _MobilePornboxPageState extends ConsumerState<MobilePornboxPage>
    with
        MultiSelectStateMixin<MobilePornboxPage, int>,
        VideoOverviewActionsMixin<MobilePornboxPage> {
  static const _scope = VideoSummaryScope.mobile;

  @override
  VideoSummaryScope get overviewScope => _scope;

  @override
  bool get isMobile => true;

  @override
  String get overviewCacheKey => mobilePornboxPageCacheKey();

  @override
  Widget build(BuildContext context) {
    listenForMutations();
    final paged = ref.watch(
      videoSummaryProvider(_scope).select(
        (asyncState) => pagedViewSnapshot(asyncState, (state) => state.paged),
      ),
    );
    final filter = ref.watch(
      videoSummaryProvider(_scope).select(
        (asyncState) => asyncState.value?.filter ?? VideoFilterState.initial,
      ),
    );
    final l10n = AppLocalizations.of(context);
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;

    return Column(
      children: [
        Expanded(
          child: AppFilterResultLoadingOverlay(
            surfaceColor: highContrast
                ? context.appColors.surfacePage
                : context.appColors.surfaceCard.withValues(alpha: 0.9),
            protectedHeaderKey: listHeaderKey,
            scrollController: scrollController,
            isLoading: paged.filterUpdate.isLoading,
            hasPreviousItems: paged.items.isNotEmpty,
            child: AppPagedLoadMoreScope(
              canLoadMore: () => canAutoLoadMore,
              onLoadMore: loadMore,
              child: AppAdaptiveRefreshScrollView(
                key: const PageStorageKey<String>('mobile:pornbox:list'),
                controller: scrollController,
                onRefresh: refreshOverview,
                slivers: <Widget>[
                  AppPinnedSliverSection(
                    headerKey: listHeaderKey,
                    before: <Widget>[
                      SliverToBoxAdapter(
                        child: AppMobilePageTitle(
                          key: const Key('mobile-pornbox-large-title'),
                          title: l10n.routeVideosTitle,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: VideoOverviewCollectionsSection(
                          mobile: true,
                          onViewAll: viewAllCollections,
                          onCollectionTap: (collection) =>
                              MobileVideoCollectionDetailRouteData(
                                collectionId: collection.id,
                              ).push(context),
                        ),
                      ),
                    ],
                    header: _buildHeader(context, paged, filter),
                    headerBottomSpacing: context.appSpacing.md,
                    after: <Widget>[
                      if (!paged.filterUpdate.hasFailed ||
                          paged.items.isNotEmpty)
                        VideoOverviewGridSliver(
                          gridKey: const Key('mobile-pornbox-grid'),
                          videos: paged.items,
                          isLoading: paged.isInitialLoading,
                          errorMessage: paged.initialError != null
                              ? l10n.errorVideoListLoadFailed
                              : null,
                          emptyMessage: l10n.videoEmptyList,
                          onVideoTap: (video) => selectionAwareTap(
                            video.id,
                            () => openActions(video),
                          )(),
                          selectionMode: selectionMode,
                          selectedIds: selectedIds,
                          onVideoToggleSelect: (video) =>
                              handleSelectTap(video.id),
                          wrapCard: selectionMode
                              ? null
                              : (cardContext, video, card) =>
                                    AppContextMenuTrigger(
                                      onRequestMenu: (position) => openCardMenu(
                                        cardContext,
                                        video,
                                        position,
                                      ),
                                      child: card,
                                    ),
                        ),
                      PagedLoadMoreFooterSliver(
                        hiddenSpacing: PagedFooterSpacing.lg,
                        watchFooter: (ref) => ref.watch(
                          videoSummaryProvider(_scope).select(
                            (state) =>
                                pagedLoadMoreFooterSnapshot(state.value?.paged),
                          ),
                        ),
                        onLoadMore: (ref) => unawaited(
                          ref
                              .read(videoSummaryProvider(_scope).notifier)
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
        if (selectionMode) _buildBatchBar(context),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    PagedViewSnapshot<VideoItemListItemDto> paged,
    VideoFilterState filter,
  ) {
    final videos = paged.items;
    if (selectionMode) {
      final l10n = AppLocalizations.of(context);
      final videoIds = videos.map((video) => video.id);
      final allSelected = isAllSelected(videoIds);
      return AppMobileSelectionHeader(
        selectionLabel: l10n.videoSelectedCount(selectedCount),
        countKey: const Key('mobile-pornbox-selection-count'),
        exitKey: const Key('mobile-pornbox-exit-selection-button'),
        onExitSelection: exitSelection,
        selectAllKey: const Key('mobile-pornbox-select-all-button'),
        selectAllTooltip: allSelected
            ? l10n.videoDeselectAll
            : l10n.videoSelectAllCount(videos.length),
        onToggleAll: videos.isEmpty ? null : () => toggleSelectAll(videoIds),
      );
    }

    final l10n = AppLocalizations.of(context);
    return AppMobileListHeader(
      leading: AppMobileHeaderText(
        key: const Key('mobile-pornbox-total'),
        title: l10n.videoAllVideosTitle,
        countLabel: l10n.videoTotalCount(paged.total),
      ),
      actions: <Widget>[
        AppGlassFilterIconButton(
          key: const Key('mobile-pornbox-filter-button'),
          summary: filter.triggerLabel(l10n),
          isActive: filter.hasActiveFilters,
          onPressed: openFilterDrawer,
        ),
        VideoSortMenuButton(
          triggerKey: const Key('mobile-pornbox-sort-trigger'),
          drawerKey: const Key('mobile-pornbox-sort-drawer'),
          keyPrefix: 'mobile-pornbox',
          filterState: filter,
          onChanged: applyFilter,
          useDrawer: true,
          iconOnly: true,
        ),
        AppGlassIconButton(
          key: const Key('mobile-pornbox-create-collection-button'),
          tooltip: l10n.videoNewCollection,
          icon: Icons.add_rounded,
          onPressed: createCollection,
        ),
      ],
      filterUpdate: paged.filterUpdate,
      hasPreviousFilterItems: videos.isNotEmpty,
      onRetryFilter: retryFilter,
    );
  }

  Widget _buildBatchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasSelection = selectedCount > 0;
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.videoCollectionAdd,
      BatchOperationType.videoDelete,
    ]);
    return AppSelectionBottomBar(
      key: const Key('mobile-pornbox-batch-bottom-bar'),
      actions: [
        AppButton(
          key: const Key('mobile-pornbox-batch-add-collection-button'),
          label: l10n.videoAddToCollection,
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection && !submitting ? batchAddToCollection : null,
        ),
        AppButton(
          key: const Key('mobile-pornbox-batch-delete-button'),
          label: l10n.commonDelete,
          variant: AppButtonVariant.danger,
          onPressed: hasSelection && !submitting ? batchDelete : null,
        ),
      ],
    );
  }
}
