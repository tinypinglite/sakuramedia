import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/add_to_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/create_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/pick_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/collections/video_collections_overview_controller.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/video_list_content.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_list_page_state.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/notifiers/video_mutation_change_notifier.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/collections/collection_card.dart';
import 'package:sakuramedia/widgets/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/videos/video_quick_play_dialog.dart';

/// PornBox 主页：顶部「新建合集」，中部「视频合集」横滑区（参照切片页），
/// 下方「全部视频」网格。导入入口统一收口到「媒体导入」页。
/// 合集详情/连播作为子路由从本页跳转，不再独占侧栏菜单项。
class DesktopVideoListPage extends StatefulWidget {
  const DesktopVideoListPage({super.key});

  @override
  State<DesktopVideoListPage> createState() => _DesktopVideoListPageState();
}

class _DesktopVideoListPageState extends State<DesktopVideoListPage>
    with MultiSelectStateMixin<DesktopVideoListPage, int> {
  late final CachedPageStateHandle<VideoListPageStateEntry> _pageStateHandle;
  late final VideoCollectionsOverviewController _collectionsController;
  late final VideoMutationChangeNotifier _mutationNotifier;
  bool _railRefreshScheduled = false;

  VideoListPageStateEntry get _pageState => _pageStateHandle.value;

  @override
  void initState() {
    super.initState();
    _mutationNotifier = context.read<VideoMutationChangeNotifier>();
    _pageStateHandle = obtainCachedPageState<VideoListPageStateEntry>(
      context,
      key: desktopVideosPageStateKey(),
      create: () => VideoListPageStateEntry(
        videosApi: context.read<VideosApi>(),
        mutationNotifier: _mutationNotifier,
      ),
    );
    _collectionsController = VideoCollectionsOverviewController(
      collectionsApi: context.read<VideoCollectionsApi>(),
    )..load();
    _mutationNotifier.addListener(_onMutation);
  }

  @override
  void dispose() {
    _mutationNotifier.removeListener(_onMutation);
    _collectionsController.dispose();
    _pageStateHandle.dispose();
    super.dispose();
  }

  /// 删除 / 合集成员变化都可能改变合集横滑区的封面与计数；用微任务把一轮内的
  /// 多次信号（如批量操作）合并成一次刷新，避免 N 次请求。视频网格本身的删除
  /// 由缓存 entry 监听同一信号就地移除（见 [VideoListPageStateEntry]）。
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
      _collectionsController.refresh();
    });
  }

  void _applySort(VideoFilterState next) {
    if (next.matches(_pageState.filterState)) {
      return;
    }
    setState(() {
      _pageState.filterState = next;
    });
    _pageState.reloadVideos();
  }

  Future<void> _createCollection() async {
    final created = await showVideoCollectionDialog(context);
    if (created != null) {
      await _collectionsController.refresh();
    }
  }

  Future<void> _viewAllCollections() async {
    await context.pushDesktopVideoCollections();
    if (!mounted) {
      return;
    }
    // 全部合集页内可能重命名/删除合集，返回后刷新首页合集横滑区。
    await _collectionsController.refresh();
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
      _mutationNotifier.reportCollectionMembershipChanged(videoId: video.id);
    }
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
      await context.read<VideosApi>().deleteVideo(video.id);
      // 广播删除信号：缓存 entry 监听后从网格精准移除，页面监听后刷新合集横滑区。
      _mutationNotifier.reportDeleted(video.id);
      if (mounted) {
        showToast('已删除视频');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除失败，请重试'));
    }
  }

  List<VideoItemListItemDto> get _loadedVideos => _pageState.controller.items;

  List<VideoItemListItemDto> _selectedVideos() => _loadedVideos
      .where((v) => isSelected(v.id))
      .toList(growable: false);

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
    final api = context.read<VideosApi>();
    final result = await runBatchOperation<VideoItemListItemDto>(
      context,
      title: '正在删除视频',
      items: selected,
      action: (video) => api.deleteVideo(video.id),
    );
    if (!mounted) {
      return;
    }
    // 逐条广播删除信号（同步连发）：缓存 entry 监听后从网格精准移除，
    // 页面监听用微任务合并成一次合集横滑区刷新。
    for (final video in result.succeeded) {
      _mutationNotifier.reportDeleted(video.id);
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
    final api = context.read<VideoCollectionsApi>();
    final result = await runBatchOperation<VideoItemListItemDto>(
      context,
      title: '正在加入「${target.name}」',
      items: selected,
      action: (video) => api.addCollectionItem(
        collectionId: target.id,
        videoItemId: video.id,
      ),
    );
    if (!mounted) {
      return;
    }
    // 合集成员/封面变化：逐条广播，由页面监听合并刷新合集横滑区。
    for (final video in result.succeeded) {
      _mutationNotifier.reportCollectionMembershipChanged(
        videoId: video.id,
        collectionId: target.id,
      );
    }
    _showBatchToast('加入合集', result);
    exitSelection();
  }

  @override
  Widget build(BuildContext context) {
    final pageState = _pageState;

    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: pageState.controller.scrollController,
        child: Column(
          key: const Key('videos-page'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCollectionsSection(context),
            SizedBox(height: context.appSpacing.lg),
            VideoListContent(
              controller: pageState.controller,
              filterState: pageState.filterState,
              onFilterChanged: _applySort,
              contentKey: const Key('videos-page-list'),
              totalKey: const Key('videos-page-total'),
              sectionSpacing: context.appSpacing.lg,
              onVideoTap: (video) => showVideoQuickPlayDialog(
                context,
                videoId: video.id,
                title: video.preferredTitle,
              ),
              onVideoAddToCollection: _addToCollection,
              onVideoDelete: _deleteVideo,
              selectionMode: selectionMode,
              selectedIds: selectedIds,
              onVideoToggleSelect: (video) => toggleSelect(video.id),
              headerTrailingBuilder: _buildSelectionControls,
              headerInlineTrailingBuilder: _buildInlineSelectionTrigger,
            ),
          ],
        ),
      ),
    );
  }

  /// 总数行右侧的「选择」入口：仅在非选择模式且有数据时显示。
  Widget? _buildInlineSelectionTrigger(BuildContext context) {
    if (selectionMode || _loadedVideos.isEmpty) {
      return null;
    }
    return AppTextButton(
      key: const Key('videos-enter-selection-button'),
      label: '选择',
      size: AppTextButtonSize.small,
      icon: const Icon(Icons.check_circle_outline, size: 16),
      onPressed: enterSelection,
    );
  }

  /// 总数行下方的批量操作栏：仅选择模式下显示。
  Widget? _buildSelectionControls(BuildContext context) {
    if (!selectionMode) {
      return null;
    }

    final loaded = _loadedVideos;
    final videoIds = loaded.map((v) => v.id);
    final allSelected = isAllSelected(videoIds);
    final hasSelection = selectedCount > 0;
    final spacing = context.appSpacing;

    return Row(
      children: [
        Text(
          '已选 $selectedCount 个',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ),
        ),
        const Spacer(),
        AppTextButton(
          key: const Key('videos-select-all-button'),
          label: allSelected ? '取消全选' : '全选',
          size: AppTextButtonSize.small,
          onPressed: () => toggleSelectAll(videoIds),
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('videos-batch-add-collection-button'),
          label: '加入合集',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection ? _batchAddToCollection : null,
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('videos-batch-delete-button'),
          label: '删除',
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection ? _batchDelete : null,
        ),
        SizedBox(width: spacing.sm),
        AppTextButton(
          key: const Key('videos-exit-selection-button'),
          label: '取消',
          size: AppTextButtonSize.small,
          onPressed: exitSelection,
        ),
      ],
    );
  }

  Widget _buildCollectionsSection(BuildContext context) {
    return AnimatedBuilder(
      animation: _collectionsController,
      builder: (context, _) {
        final collections = _collectionsController.collections;
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
            _buildCollectionsRow(context, collections),
          ],
        );
      },
    );
  }

  Widget _buildCollectionsRow(
    BuildContext context,
    List<VideoCollectionDto> collections,
  ) {
    final error = _collectionsController.errorMessage;
    if (error != null) {
      return _HintBox(message: error);
    }
    if (_collectionsController.isLoading && collections.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
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
