import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_overview_actions.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_overview_collections_section.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_scope.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_glass_list_header.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_overview_grid_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';

/// 桌面 PornBox 首页：合集横滑区 + 全部视频网格 + 桌面多选动作。
class DesktopVideoListPage extends ConsumerStatefulWidget {
  const DesktopVideoListPage({super.key});

  @override
  ConsumerState<DesktopVideoListPage> createState() =>
      _DesktopVideoListPageState();
}

class _DesktopVideoListPageState extends ConsumerState<DesktopVideoListPage>
    with
        MultiSelectStateMixin<DesktopVideoListPage, int>,
        VideoOverviewActionsMixin<DesktopVideoListPage> {
  static const _scope = VideoSummaryScope.desktop;

  @override
  VideoSummaryScope get overviewScope => _scope;

  @override
  bool get isMobile => false;

  @override
  String get overviewCacheKey => desktopVideosPageCacheKey();

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

    return AppPageRefreshScope(
      onRefresh: refreshOverview,
      child: AppFilterResultLoadingOverlay(
        protectedHeaderKey: listHeaderKey,
        scrollController: scrollController,
        isLoading: paged.filterUpdate.isLoading,
        hasPreviousItems: paged.items.isNotEmpty,
        child: AppPagedLoadMoreScope(
          canLoadMore: () => canAutoLoadMore,
          onLoadMore: loadMore,
          child: CustomScrollView(
            key: const PageStorageKey<String>('desktop:videos:list'),
            controller: scrollController,
            slivers: [
              AppPinnedSliverSection(
                key: const Key('videos-page-list'),
                headerKey: listHeaderKey,
                before: <Widget>[
                  SliverToBoxAdapter(
                    child: Column(
                      key: const Key('videos-page'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VideoOverviewCollectionsSection(
                          mobile: false,
                          onViewAll: viewAllCollections,
                          onCreate: createCollection,
                          onCollectionTap: (collection) =>
                              context.pushDesktopVideoCollectionDetail(
                                collectionId: collection.id,
                              ),
                        ),
                        SizedBox(height: context.appSpacing.lg),
                      ],
                    ),
                  ),
                ],
                header: VideoGlassListHeader(
                  filterState: filter,
                  total: paged.total,
                  filterUpdate: paged.filterUpdate,
                  hasPreviousFilterItems: paged.items.isNotEmpty,
                  onFilterChanged: applyFilter,
                  onRetryFilter: retryFilter,
                  onEnterSelection: !selectionMode && paged.items.isNotEmpty
                      ? enterSelection
                      : null,
                  selectionHeader: selectionMode
                      ? _buildSelectionHeader(context)
                      : null,
                  totalKey: const Key('videos-page-total'),
                ),
                headerBottomSpacing: context.appSpacing.lg,
                after: <Widget>[
                  if (!paged.filterUpdate.hasFailed || paged.items.isNotEmpty)
                    VideoOverviewGridSliver(
                      gridKey: const Key('video-summary-grid'),
                      videos: paged.items,
                      isLoading: paged.isInitialLoading,
                      placeholderCount: 18,
                      errorMessage: paged.initialError != null
                          ? l10n.errorVideoListLoadFailed
                          : null,
                      emptyMessage: l10n.videoEmptyList,
                      onVideoTap: (video) => selectionAwareTap(
                        video.id,
                        () => openActions(video),
                      )(),
                      onVideoPlay: (video) => unawaited(playVideo(video)),
                      onVideoThumbnails: (video) =>
                          context.pushDesktopVideoThumbnails(videoId: video.id),
                      onVideoAddToCollection: (video) =>
                          unawaited(addToCollection(video)),
                      onVideoDelete: (video) => unawaited(deleteVideo(video)),
                      selectionMode: selectionMode,
                      selectedIds: selectedIds,
                      onVideoToggleSelect: (video) => handleSelectTap(video.id),
                    ),
                  PagedLoadMoreFooterSliver(
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
    );
  }

  Widget _buildSelectionHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final videoIds = loadedVideos.map((video) => video.id);
    final allSelected = isAllSelected(videoIds);
    final hasSelection = selectedCount > 0;
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.videoCollectionAdd,
      BatchOperationType.videoDelete,
    ]);

    return AppGlassSelectionHeader(
      selectionLabel: l10n.videoSelectedCount(selectedCount),
      countKey: const Key('videos-selection-count-text'),
      selectAllLabel: allSelected
          ? l10n.videoDeselectAll
          : l10n.videoSelectAllCount(loadedVideos.length),
      selectAllKey: const Key('videos-select-all-button'),
      onToggleAll: loadedVideos.isEmpty
          ? null
          : () => toggleSelectAll(videoIds),
      actions: <AppGlassSelectionAction>[
        AppGlassSelectionAction(
          key: const Key('videos-batch-add-collection-button'),
          icon: Icons.playlist_add_rounded,
          label: l10n.videoAddToCollection,
          onTap: hasSelection && !submitting ? batchAddToCollection : null,
        ),
        AppGlassSelectionAction(
          key: const Key('videos-batch-delete-button'),
          icon: Icons.delete_outline_rounded,
          label: l10n.commonDelete,
          foregroundColor: hasSelection ? context.appTextPalette.error : null,
          onTap: hasSelection && !submitting ? batchDelete : null,
        ),
      ],
      exitKey: const Key('videos-exit-selection-button'),
      onExitSelection: exitSelection,
    );
  }
}
