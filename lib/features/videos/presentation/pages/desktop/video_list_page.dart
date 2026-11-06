import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/add_to_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/pick_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_list_content.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_scope.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/videos/presentation/actions/video_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_actions_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/video_display_title.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_hint_box.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';

/// PornBox 主页：顶部「新建合集」，中部「视频合集」横滑区（参照切片页），
/// 下方「全部视频」网格。导入入口统一收口到「媒体导入」页。
/// 合集详情/连播作为子路由从本页跳转，不再独占侧栏菜单项。
class DesktopVideoListPage extends ConsumerStatefulWidget {
  const DesktopVideoListPage({super.key});

  @override
  ConsumerState<DesktopVideoListPage> createState() =>
      _DesktopVideoListPageState();
}

class _DesktopVideoListPageState extends ConsumerState<DesktopVideoListPage>
    with MultiSelectStateMixin<DesktopVideoListPage, int> {
  static const _scope = VideoSummaryScope.desktop();

  late final RiverpodPageHandle _pageCacheHandle;
  late final ScrollController _scrollController;
  final _listHeaderKey = GlobalKey();
  bool _railRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: desktopVideosPageCacheKey(),
          resolveLinks: () {
            final link = ref
                .read(videoSummaryProvider(_scope).notifier)
                .cacheLink;
            return link == null ? const [] : [link];
          },
        );
  }

  @override
  void dispose() {
    _pageCacheHandle.release();
    _scrollController.dispose();
    super.dispose();
  }

  /// 删除 / 合集成员变化都可能改变合集横滑区的封面与计数；用微任务把一轮内的
  /// 多次信号（如批量操作）合并成一次刷新，避免 N 次请求。视频网格本身的删除
  /// 由列表 provider 监听同一信号就地移除。
  void _onMutation() {
    if (_railRefreshScheduled) {
      return;
    }
    _railRefreshScheduled = true;
    scheduleMicrotask(() {
      _railRefreshScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(ref.read(videoCollectionsOverviewProvider.notifier).refresh());
    });
  }

  void _applySort(VideoFilterState next) {
    final current =
        ref.read(videoSummaryProvider(_scope)).value?.filter ??
        VideoFilterState.initial;
    if (next.matches(current)) {
      return;
    }
    if (_scrollController.hasClients) {
      AppPinnedListHeader.scrollToStart(_listHeaderKey, _scrollController);
    }
    unawaited(
      ref.read(videoSummaryProvider(_scope).notifier).applyFilter(next),
    );
  }

  Future<void> _createCollection() async {
    final created = await showVideoCollectionDialog(context);
    if (created != null) {
      await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
    }
  }

  Future<void> _viewAllCollections() async {
    await context.pushDesktopVideoCollections();
    if (!mounted) {
      return;
    }
    // 全部合集页内可能重命名/删除合集，返回后刷新首页合集横滑区。
    await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
  }

  Future<void> _addToCollection(VideoItemListItemDto video) async {
    await showAddToVideoCollectionDialog(
      context,
      videoItemId: video.id,
      collectedRefs: video.collections,
    );
    if (!mounted) {
      return;
    }
    // 弹窗内可加入 / 移出（勾选切换），关闭后统一广播，由页面刷新合集横滑区与卡片角标。
    ref
        .read(videoMutationEventsProvider.notifier)
        .reportCollectionMembershipChanged(videoId: video.id);
  }

  /// 播放：外部播放器优先（能唤起时交给系统），否则进入应用内 PornBox 单视频播放页。
  /// 卡片悬停播放键与动作弹窗的「播放」共用这一入口。
  Future<void> _playVideo(VideoItemListItemDto video) async {
    if (await tryLaunchExternalVideoPlayback(
      context,
      videoId: video.id,
      title: video.displayTitle(AppLocalizations.of(context)),
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    context.pushDesktopVideoPlayer(videoId: video.id);
  }

  /// 点视频卡：弹桌面版动作弹窗（对齐移动端 sheet）。用户在弹窗里选「播放」
  /// 后进入 PornBox 单视频播放页；「加入合集」/「删除」都是本页原有的入口。
  void _openActionsDialog(VideoItemListItemDto video) {
    showDesktopVideoActionsDialog(
      context,
      video: video,
      onPlay: () => unawaited(_playVideo(video)),
      onThumbnails: () => context.pushDesktopVideoThumbnails(videoId: video.id),
      onAddToCollection: () => _addToCollection(video),
      onDelete: () => _deleteVideo(video),
      collections: video.collections,
      onCollectionTap: (ref) =>
          context.pushDesktopVideoCollectionDetail(collectionId: ref.id),
    );
  }

  Future<void> _deleteVideo(VideoItemListItemDto video) async {
    final l10n = AppLocalizations.of(context);
    final title = video.preferredTitle.trim();
    final label = title.isEmpty ? l10n.videoGenericVideo : '“$title”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.videoDeleteTitle,
      message: l10n.videoDeleteConfirmMessage(label),
      danger: true,
      confirmLabel: l10n.commonDelete,
      confirmKey: const Key('video-delete-confirm-button'),
      onConfirm: () => ref.read(videosApiProvider).deleteVideo(video.id),
      failureFallback: l10n.videoDeleteFailed,
    );
    if (!mounted || !confirmed) {
      return;
    }
    // 广播删除信号：列表 provider 精准移除，页面刷新合集横滑区。
    ref.read(videoMutationEventsProvider.notifier).reportDeleted(video.id);
    showToast(l10n.videoDeletedToast, tone: AppToastTone.success);
  }

  List<VideoItemListItemDto> get _loadedVideos =>
      ref.read(videoSummaryProvider(_scope)).value?.paged.items ?? const [];

  List<VideoItemListItemDto> _selectedVideos() =>
      _loadedVideos.where((v) => isSelected(v.id)).toList(growable: false);

  Future<void> _batchDelete() async {
    final selected = _selectedVideos();
    if (selected.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.videoDeleteTitle,
      message: l10n.videoBatchDeleteConfirmMessage(selected.length),
      danger: true,
      confirmLabel: l10n.commonDelete,
      confirmKey: const Key('videos-batch-delete-confirm-button'),
    );
    if (!mounted || !confirmed) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.videoDelete,
      ids: selected.map((video) => video.id).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> _batchAddToCollection() async {
    final selected = _selectedVideos();
    if (selected.isEmpty) {
      return;
    }
    final target = await showPickVideoCollectionDialog(context);
    if (!mounted || target == null) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.videoCollectionAdd,
      targetCollectionId: target.id,
      ids: selected.map((video) => video.id).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> _handlePageRefresh() async {
    await Future.wait<void>([
      ref.read(videoSummaryProvider(_scope).notifier).refresh(),
      ref.read(videoCollectionsOverviewProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // 分页快照不包含 loadMore 状态，翻页 loading/失败只重建独立页脚，
    // 不重建合集区、顶栏与网格。
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

    ref.listen(videoMutationEventsProvider, (_, next) {
      if (next.value != null) {
        _onMutation();
      }
    });

    return AppPageRefreshScope(
      onRefresh: _handlePageRefresh,
      child: AppFilterResultLoadingOverlay(
        protectedHeaderKey: _listHeaderKey,
        scrollController: _scrollController,
        isLoading: paged.filterUpdate.isLoading,
        hasPreviousItems: paged.items.isNotEmpty,
        child: AppPagedLoadMoreScope(
          canLoadMore: () =>
              ref
                  .read(videoSummaryProvider(_scope))
                  .value
                  ?.paged
                  .canAutoLoadMore ??
              false,
          onLoadMore: () =>
              ref.read(videoSummaryProvider(_scope).notifier).loadMore(),
          child: CustomScrollView(
            key: const PageStorageKey<String>('desktop:videos:list'),
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  key: const Key('videos-page'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCollectionsSection(context),
                    SizedBox(height: context.appSpacing.lg),
                  ],
                ),
              ),
              VideoListContent(
                headerKey: _listHeaderKey,
                paged: paged,
                videoProvider: videoSummaryProvider(_scope),
                initialErrorMessage: paged.initialError != null
                    ? l10n.errorVideoListLoadFailed
                    : null,
                filterState: filter,
                onFilterChanged: _applySort,
                onRetryFilter: () => unawaited(
                  ref.read(videoSummaryProvider(_scope).notifier).retryFilter(),
                ),
                contentKey: const Key('videos-page-list'),
                totalKey: const Key('videos-page-total'),
                sectionSpacing: context.appSpacing.lg,
                onVideoTap: _openActionsDialog,
                onVideoPlay: (video) => unawaited(_playVideo(video)),
                onVideoThumbnails: (video) =>
                    context.pushDesktopVideoThumbnails(videoId: video.id),
                onVideoAddToCollection: (video) =>
                    unawaited(_addToCollection(video)),
                onVideoDelete: (video) => unawaited(_deleteVideo(video)),
                selectionMode: selectionMode,
                selectedIds: selectedIds,
                onVideoToggleSelect: (video) => toggleSelect(video.id),
                selectionHeaderBuilder: _buildSelectionHeader,
                onEnterSelection: enterSelection,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 多选态下**原地改写整条顶栏**（与影片列表一致），不在筛选行下面另起一行。
  Widget? _buildSelectionHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final videoIds = _loadedVideos.map((v) => v.id);
    final allSelected = isAllSelected(videoIds);
    final hasSelection = selectedCount > 0;
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.videoCollectionAdd,
      BatchOperationType.videoDelete,
    ]);

    return AppSelectionHeaderToolbar(
      countLabel: l10n.videoSelectedCount(selectedCount),
      countKey: const Key('videos-selection-count-text'),
      selectAllLabel: allSelected
          ? l10n.videoDeselectAll
          : l10n.videoSelectAllCount(_loadedVideos.length),
      selectAllKey: const Key('videos-select-all-button'),
      onToggleAll: _loadedVideos.isEmpty
          ? null
          : () => toggleSelectAll(videoIds),
      actions: [
        AppButton(
          key: const Key('videos-batch-add-collection-button'),
          label: l10n.videoAddToCollection,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection && !submitting ? _batchAddToCollection : null,
        ),
        AppButton(
          key: const Key('videos-batch-delete-button'),
          label: l10n.commonDelete,
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection && !submitting ? _batchDelete : null,
        ),
      ],
      exitKey: const Key('videos-exit-selection-button'),
      onExit: exitSelection,
    );
  }

  Widget _buildCollectionsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(videoCollectionsOverviewProvider);
        final collections = async.value ?? const <VideoCollectionDto>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.videoCollectionsTitle,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                const Spacer(),
                AppTextButton(
                  key: const Key('videos-create-collection-button'),
                  label: l10n.videoNew,
                  size: AppTextButtonSize.small,
                  onPressed: _createCollection,
                ),
                if (collections.isNotEmpty) ...[
                  SizedBox(width: context.appSpacing.xs),
                  AppTextButton(
                    key: const Key('videos-view-all-collections-button'),
                    label: l10n.videoViewAll,
                    size: AppTextButtonSize.small,
                    onPressed: _viewAllCollections,
                  ),
                ],
              ],
            ),
            SizedBox(height: context.appSpacing.sm),
            _buildCollectionsRow(context, async, collections),
          ],
        );
      },
    );
  }

  Widget _buildCollectionsRow(
    BuildContext context,
    AsyncValue<List<VideoCollectionDto>> async,
    List<VideoCollectionDto> collections,
  ) {
    final l10n = AppLocalizations.of(context);
    if (async.hasError && collections.isEmpty) {
      return CollectionHintBox(
        message: apiErrorMessage(
          async.error!,
          fallback: l10n.videoCollectionsLoadFailed,
          l10n: l10n,
        ),
      );
    }
    final isLoading = async.isLoading && collections.isEmpty;
    final display = isLoading
        ? videoCollectionPlaceholders(count: 4)
        : collections;
    if (display.isEmpty) {
      return CollectionHintBox(message: l10n.videoCollectionsEmptyHint);
    }
    return AppSkeletonizer(
      enabled: isLoading,
      child: SizedBox(
        height: 172,
        child: ListView.separated(
          key: const Key('videos-collections-row'),
          scrollDirection: Axis.horizontal,
          itemCount: display.length,
          separatorBuilder: (context, index) =>
              SizedBox(width: context.appSpacing.md),
          itemBuilder: (context, index) {
            final collection = display[index];
            return SizedBox(
              width: 210,
              // 卡片按内容自然高度渲染，避免被固定行高拉伸后在标题下方留白。
              child: Align(
                alignment: Alignment.topCenter,
                child: CollectionCard.video(
                  collection: collection,
                  onTap: () => context.pushDesktopVideoCollectionDetail(
                    collectionId: collection.id,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
