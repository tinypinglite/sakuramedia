import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
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
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_actions_dialog.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/operations/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/domain/media/quick_play_dialog.dart';

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
  bool _railRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
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
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
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

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) {
      return;
    }
    final summary = ref.read(videoSummaryProvider(_scope)).value;
    final position = _scrollController.position;
    if (summary == null ||
        summary.paged.loadMoreErrorMessage != null ||
        position.pixels < position.maxScrollExtent - 300) {
      return;
    }
    unawaited(ref.read(videoSummaryProvider(_scope).notifier).loadMore());
  }

  void _applySort(VideoFilterState next) {
    final current =
        ref.read(videoSummaryProvider(_scope)).value?.filter ??
        VideoFilterState.initial;
    if (next.matches(current)) {
      return;
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
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
    final added = await showAddToVideoCollectionDialog(
      context,
      videoItemId: video.id,
    );
    if (!mounted) {
      return;
    }
    if (added == true) {
      // 合集成员/封面可能变化：广播信号，由页面监听统一刷新合集横滑区。
      ref
          .read(videoMutationEventsProvider.notifier)
          .reportCollectionMembershipChanged(videoId: video.id);
    }
  }

  /// 点视频卡：弹桌面版动作弹窗（对齐移动端 sheet）。用户在弹窗里选「播放」
  /// 再走原来的快速播放弹窗；「加入合集」/「删除」都是本页原有的入口。
  void _openActionsDialog(VideoItemListItemDto video) {
    showDesktopVideoActionsDialog(
      context,
      video: video,
      onPlay: () => showVideoQuickPlayDialog(
        context,
        videoId: video.id,
        title: video.preferredTitle,
      ),
      onAddToCollection: () => _addToCollection(video),
      onDelete: () => _deleteVideo(video),
      collections: video.collections,
      onCollectionTap: (ref) =>
          context.pushDesktopVideoCollectionDetail(collectionId: ref.id),
    );
  }

  Future<void> _deleteVideo(VideoItemListItemDto video) async {
    final title = video.preferredTitle.trim();
    final label = title.isEmpty ? '该视频' : '“$title”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除视频',
      message: '确认删除$label？该操作不可恢复。',
      danger: true,
      confirmLabel: '删除',
      confirmKey: const Key('video-delete-confirm-button'),
    );
    if (!mounted || !confirmed) {
      return;
    }
    try {
      await ref.read(videosApiProvider).deleteVideo(video.id);
      // 广播删除信号：列表 provider 精准移除，页面刷新合集横滑区。
      ref.read(videoMutationEventsProvider.notifier).reportDeleted(video.id);
      if (mounted) {
        showToast('已删除视频');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除失败，请重试'));
    }
  }

  List<VideoItemListItemDto> get _loadedVideos =>
      ref.read(videoSummaryProvider(_scope)).value?.paged.items ?? const [];

  List<VideoItemListItemDto> _selectedVideos() =>
      _loadedVideos.where((v) => isSelected(v.id)).toList(growable: false);

  void _showBatchToast(String verb, BatchRunResult<dynamic> result) {
    if (result.failed.isEmpty) {
      showToast('已$verb ${result.succeeded.length} 个视频');
    } else {
      showToast(
        '$verb完成：成功 ${result.succeeded.length} 个，失败 ${result.failed.length} 个',
      );
    }
  }

  Future<void> _batchDelete() async {
    final selected = _selectedVideos();
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除视频',
      message: '确认删除选中的 ${selected.length} 个视频？该操作不可恢复。',
      danger: true,
      confirmLabel: '删除',
      confirmKey: const Key('videos-batch-delete-confirm-button'),
    );
    if (!mounted || !confirmed) {
      return;
    }
    final api = ref.read(videosApiProvider);
    final result = await runBatchOperation<VideoItemListItemDto>(
      context,
      title: '正在删除视频',
      items: selected,
      action: (video) => api.deleteVideo(video.id),
    );
    if (!mounted) {
      return;
    }
    // 逐条广播删除信号（同步连发）：列表 provider 精准移除，
    // 页面监听用微任务合并成一次合集横滑区刷新。
    for (final video in result.succeeded) {
      ref.read(videoMutationEventsProvider.notifier).reportDeleted(video.id);
    }
    _showBatchToast('删除', result);
    exitSelection();
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
    final api = ref.read(videoCollectionsApiProvider);
    final result = await runBatchOperation<VideoItemListItemDto>(
      context,
      title: '正在加入「${target.name}」',
      items: selected,
      action: (video) =>
          api.addCollectionItem(collectionId: target.id, videoItemId: video.id),
    );
    if (!mounted) {
      return;
    }
    // 合集成员/封面变化：逐条广播，由页面监听合并刷新合集横滑区。
    for (final video in result.succeeded) {
      ref
          .read(videoMutationEventsProvider.notifier)
          .reportCollectionMembershipChanged(
            videoId: video.id,
            collectionId: target.id,
          );
    }
    _showBatchToast('加入合集', result);
    exitSelection();
  }

  Future<void> _handlePageRefresh() async {
    await Future.wait<void>([
      ref.read(videoSummaryProvider(_scope).notifier).refresh(),
      ref.read(videoCollectionsOverviewProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(videoSummaryProvider(_scope));
    final summary = videosAsync.value;
    final paged = summary?.paged;
    final filter = summary?.filter ?? VideoFilterState.initial;

    ref.listen(videoMutationEventsProvider, (_, next) {
      if (next.value != null) {
        _onMutation();
      }
    });

    return AppPageRefreshScope(
      onRefresh: _handlePageRefresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
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
              paged: paged ?? const PagedListState<VideoItemListItemDto>(),
              isInitialLoading: videosAsync.isLoading && summary == null,
              initialErrorMessage: videosAsync.hasError && summary == null
                  ? '视频列表加载失败，请稍后重试'
                  : null,
              filterState: filter,
              onFilterChanged: _applySort,
              onRetryFilter: () => unawaited(
                ref.read(videoSummaryProvider(_scope).notifier).retryFilter(),
              ),
              onLoadMore: () =>
                  ref.read(videoSummaryProvider(_scope).notifier).loadMore(),
              contentKey: const Key('videos-page-list'),
              totalKey: const Key('videos-page-total'),
              sectionSpacing: context.appSpacing.lg,
              onVideoTap: _openActionsDialog,
              selectionMode: selectionMode,
              selectedIds: selectedIds,
              onVideoToggleSelect: (video) => toggleSelect(video.id),
              selectionHeaderBuilder: _buildSelectionHeader,
              headerActionsBuilder: _buildInlineSelectionTrigger,
            ),
          ],
        ),
      ),
    );
  }

  /// 顶栏右侧的「选择」入口：仅在非选择模式且有数据时显示。
  Widget? _buildInlineSelectionTrigger(BuildContext context) {
    if (selectionMode || _loadedVideos.isEmpty) {
      return null;
    }
    return AppSelectionEntryButton(
      key: const Key('videos-enter-selection-button'),
      onPressed: enterSelection,
    );
  }

  /// 多选态下**原地改写整条顶栏**（与影片列表一致），不在筛选行下面另起一行。
  Widget? _buildSelectionHeader(BuildContext context) {
    final videoIds = _loadedVideos.map((v) => v.id);
    final allSelected = isAllSelected(videoIds);
    final hasSelection = selectedCount > 0;

    return AppSelectionHeaderToolbar(
      countLabel: '已选 $selectedCount 个',
      countKey: const Key('videos-selection-count-text'),
      selectAllLabel: allSelected ? '取消全选' : '全选(${_loadedVideos.length})',
      selectAllKey: const Key('videos-select-all-button'),
      onToggleAll: _loadedVideos.isEmpty
          ? null
          : () => toggleSelectAll(videoIds),
      actions: [
        AppButton(
          key: const Key('videos-batch-add-collection-button'),
          label: '加入合集',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection ? _batchAddToCollection : null,
        ),
        AppButton(
          key: const Key('videos-batch-delete-button'),
          label: '删除',
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection ? _batchDelete : null,
        ),
      ],
      exitKey: const Key('videos-exit-selection-button'),
      onExit: exitSelection,
    );
  }

  Widget _buildCollectionsSection(BuildContext context) {
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
                  '视频合集',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s16,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                const Spacer(),
                AppTextButton(
                  key: const Key('videos-create-collection-button'),
                  label: '新建',
                  size: AppTextButtonSize.small,
                  onPressed: _createCollection,
                ),
                if (collections.isNotEmpty) ...[
                  SizedBox(width: context.appSpacing.xs),
                  AppTextButton(
                    key: const Key('videos-view-all-collections-button'),
                    label: '查看全部',
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
    if (async.hasError && collections.isEmpty) {
      return _HintBox(
        message: apiErrorMessage(async.error!, fallback: '合集加载失败，请稍后重试'),
      );
    }
    if (async.isLoading && collections.isEmpty) {
      return CollectionCardSkeletonRow(
        key: const Key('videos-collections-skeleton-row'),
        height: 172,
        itemWidth: 210,
        itemSpacing: context.appSpacing.md,
      );
    }
    if (collections.isEmpty) {
      return const _HintBox(message: '还没有合集，点「新建」把视频攒成一个连播合集吧');
    }
    return SizedBox(
      height: 172,
      child: ListView.separated(
        key: const Key('videos-collections-row'),
        scrollDirection: Axis.horizontal,
        itemCount: collections.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: context.appSpacing.md),
        itemBuilder: (context, index) {
          final collection = collections[index];
          return SizedBox(
            width: 210,
            child: CollectionCard.video(
              collection: collection,
              onTap: () => context.pushDesktopVideoCollectionDetail(
                collectionId: collection.id,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.message});

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
