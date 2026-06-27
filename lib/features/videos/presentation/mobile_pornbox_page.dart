import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clips/presentation/mobile_clip_confirm_drawer.dart';
import 'package:sakuramedia/features/videos/data/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/add_to_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/create_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/mobile_video_actions_sheet.dart';
import 'package:sakuramedia/features/videos/presentation/mobile_video_player_page.dart';
import 'package:sakuramedia/features/videos/presentation/mobile_video_sort_drawer.dart';
import 'package:sakuramedia/features/videos/presentation/pick_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/video_collections_overview_controller.dart';
import 'package:sakuramedia/features/videos/presentation/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/video_list_page_state.dart';
import 'package:sakuramedia/features/videos/presentation/video_mutation_change_notifier.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/collections/collection_card.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/navigation/app_mobile_tab_header.dart';
import 'package:sakuramedia/widgets/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/videos/video_summary_card.dart';

/// 移动端 PornBox 主页（底部导航第 5 个 tab）：上方「视频合集」横滑区 + 下方「全部视频」
/// 网格。数据层与桌面 `DesktopVideoListPage` 完全一致（复用缓存页状态 + 合集控制器 +
/// mutation 广播），仅布局改为移动端竖屏网格 + 底部抽屉形态的编辑交互；长按视频卡进入
/// 多选模式，支持批量加入合集 / 删除。
class MobilePornboxPage extends StatefulWidget {
  const MobilePornboxPage({super.key});

  @override
  State<MobilePornboxPage> createState() => _MobilePornboxPageState();
}

class _MobilePornboxPageState extends State<MobilePornboxPage>
    with MultiSelectStateMixin<MobilePornboxPage, int> {
  late final CachedPageStateHandle<VideoListPageStateEntry> _pageStateHandle;
  late final VideoCollectionsOverviewController _collectionsController;
  late final VideoMutationChangeNotifier _mutationNotifier;
  bool _railRefreshScheduled = false;

  VideoListPageStateEntry get _pageState => _pageStateHandle.value;

  Listenable get _pageListenable => Listenable.merge(<Listenable>[
    _pageState.controller,
    _collectionsController,
  ]);

  @override
  void initState() {
    super.initState();
    _mutationNotifier = context.read<VideoMutationChangeNotifier>();
    _pageStateHandle = obtainCachedPageState<VideoListPageStateEntry>(
      context,
      key: mobilePornboxPageStateKey(),
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

  /// 删除 / 合集成员变化都可能改变合集横滑区封面与计数；用微任务合并一轮内多次信号成
  /// 一次刷新。视频网格本身的删除由缓存 entry 监听同一信号就地移除（见 [VideoListPageStateEntry]）。
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

  Future<void> _refresh() async {
    await Future.wait<void>(<Future<void>>[
      _pageState.controller.refresh(),
      _collectionsController.refresh(),
    ]);
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

  List<VideoItemListItemDto> get _loadedVideos => _pageState.controller.items;

  List<VideoItemListItemDto> _selectedVideos() =>
      _loadedVideos.where((v) => isSelected(v.id)).toList(growable: false);

  // --------------------------------------------------------- 单条动作

  void _openSheet(VideoItemListItemDto video) {
    showMobileVideoActionsSheet(
      context,
      video: video,
      onPlay: () => _playVideo(video),
      onAddToCollection: () => _addToCollection(video),
      onDelete: () => _deleteVideo(video),
    );
  }

  void _playVideo(VideoItemListItemDto video) {
    // 用根 Navigator 推全屏页，覆盖底部导航。
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => MobileVideoPlayerPage(
          videoId: video.id,
          title: video.preferredTitle,
        ),
      ),
    );
  }

  Future<void> _addToCollection(VideoItemListItemDto video) async {
    final added = await showAddToVideoCollectionDialog(
      context,
      videoItemId: video.id,
      presentation: AddToVideoCollectionPresentation.bottomDrawer,
    );
    if (!mounted) {
      return;
    }
    if (added == true) {
      _mutationNotifier.reportCollectionMembershipChanged(videoId: video.id);
    }
  }

  Future<void> _deleteVideo(VideoItemListItemDto video) async {
    final title = video.preferredTitle.trim();
    final label = title.isEmpty ? '该视频' : '“$title”';
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '删除视频',
      message: '确认删除$label？该操作不可恢复。',
      confirmLabel: '删除',
      drawerKey: const Key('mobile-video-delete-drawer'),
      confirmButtonKey: const Key('mobile-video-delete-confirm-button'),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    try {
      await context.read<VideosApi>().deleteVideo(video.id);
      _mutationNotifier.reportDeleted(video.id);
      if (mounted) {
        showToast('已删除视频');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除失败，请重试'));
    }
  }

  // --------------------------------------------------------- 批量动作

  void _showBatchToast(String verb, BatchRunResult<dynamic> result) {
    if (result.failed.isEmpty) {
      showToast('已$verb ${result.succeeded.length} 个视频');
    } else {
      showToast(
        '$verb完成：成功 ${result.succeeded.length} 个，失败 ${result.failed.length} 个',
      );
    }
  }

  Future<void> _batchAddToCollection() async {
    final selected = _selectedVideos();
    if (selected.isEmpty) {
      return;
    }
    final target = await showPickVideoCollectionDialog(
      context,
      presentation: PickVideoCollectionPresentation.bottomDrawer,
    );
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
    for (final video in result.succeeded) {
      _mutationNotifier.reportCollectionMembershipChanged(
        videoId: video.id,
        collectionId: target.id,
      );
    }
    _showBatchToast('加入合集', result);
    exitSelection();
  }

  Future<void> _batchDelete() async {
    final selected = _selectedVideos();
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '删除视频',
      message: '确认删除选中的 ${selected.length} 个视频？该操作不可恢复。',
      confirmLabel: '删除',
      drawerKey: const Key('mobile-videos-batch-delete-drawer'),
      confirmButtonKey: const Key('mobile-videos-batch-delete-confirm-button'),
    );
    if (!mounted || confirmed != true) {
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
    for (final video in result.succeeded) {
      _mutationNotifier.reportDeleted(video.id);
    }
    _showBatchToast('删除', result);
    exitSelection();
  }

  // --------------------------------------------------------- 合集动作

  Future<void> _createCollection() async {
    final created = await showVideoCollectionDialog(
      context,
      presentation: VideoCollectionEditPresentation.bottomDrawer,
    );
    if (!mounted || created == null) {
      return;
    }
    await _collectionsController.refresh();
    if (mounted) {
      showToast('已创建合集');
    }
  }

  Future<void> _viewAllCollections() async {
    await const MobileVideoCollectionsRouteData().push<void>(context);
    if (!mounted) {
      return;
    }
    await _collectionsController.refresh();
  }

  // --------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: AnimatedBuilder(
        animation: _pageListenable,
        builder: (context, _) {
          return Column(
            children: [
              if (selectionMode) _buildSelectionBar(context),
              Expanded(
                child: AppAdaptiveRefreshScrollView(
                  key: const Key('mobile-pornbox-scroll'),
                  controller: _pageState.controller.scrollController,
                  onRefresh: _refresh,
                  slivers: <Widget>[
                    if (!selectionMode)
                      SliverToBoxAdapter(child: _buildCollectionsSection(context)),
                    SliverToBoxAdapter(child: _buildVideosHeader(context)),
                    _buildVideosSliver(context),
                    SliverToBoxAdapter(child: _buildFooter(context)),
                  ],
                ),
              ),
              if (selectionMode) _buildBatchBar(context),
            ],
          );
        },
      ),
    );
  }

  // --------------------------------------------------------- 合集区

  Widget _buildCollectionsSection(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    final collections = _collectionsController.collections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 与 _buildVideosHeader 的 AppMobileTabHeader 对齐：top: xs + 固定
        // mobileTopTabHeight 容器，标题行垂直居中。
        Padding(
          padding: EdgeInsets.only(top: spacing.xs),
          child: SizedBox(
            height: componentTokens.mobileTopTabHeight,
            child: Row(
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
                AppIconButton(
                  key: const Key('mobile-pornbox-create-collection-button'),
                  tooltip: '新建合集',
                  onPressed: _createCollection,
                  icon: const Icon(Icons.add_rounded),
                ),
                if (collections.isNotEmpty) ...[
                  SizedBox(width: spacing.xs),
                  AppTextButton(
                    key: const Key('mobile-pornbox-view-all-collections-button'),
                    label: '查看全部',
                    size: AppTextButtonSize.xSmall,
                    onPressed: _viewAllCollections,
                  ),
                ],
                if (_loadedVideos.isNotEmpty) ...[
                  SizedBox(width: spacing.xs),
                  AppTextButton(
                    key: const Key('mobile-pornbox-enter-selection-button'),
                    label: '选择',
                    size: AppTextButtonSize.xSmall,
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    onPressed: enterSelection,
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: spacing.md),
          child: _buildCollectionsRow(context, collections),
        ),
        SizedBox(height: spacing.sm),
      ],
    );
  }

  Widget _buildCollectionsRow(
    BuildContext context,
    List<VideoCollectionDto> collections,
  ) {
    final spacing = context.appSpacing;
    if (_collectionsController.errorMessage != null) {
      return _HintBox(message: _collectionsController.errorMessage!);
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
      // CollectionCoverCard 内容下限：16:9 封面 + sm padding + s14 标题 + 边框 ≈ 105，
      // 故 height 不能低于 ~110。保持 116（原值），只收紧宽度 132 → 116 已减少占用。
      height: 116,
      child: ListView.separated(
        key: const Key('mobile-pornbox-collections-row'),
        scrollDirection: Axis.horizontal,
        // 横滑首尾内缩由 shell body padding 统一提供，此处不叠加额外 horizontal。
        itemCount: collections.length,
        separatorBuilder: (context, index) => SizedBox(width: spacing.sm),
        itemBuilder: (context, index) {
          final collection = collections[index];
          return SizedBox(
            width: 116, // L2 收紧：132 → 116
            child: CollectionCard.video(
              key: Key('mobile-video-collection-card-${collection.id}'),
              collection: collection,
              onTap: () => MobileVideoCollectionDetailRouteData(
                collectionId: collection.id,
              ).push(context),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------- 视频区

  Widget _buildVideosHeader(BuildContext context) {
    final filter = _pageState.filterState;
    return AppMobileTabHeader(
      chips: [
        AppMobileTabChip(
          key: const Key('mobile-pornbox-sort-chip'),
          label: filter.sortField.label,
          isSelected: false,
          trailingIcon: Icons.expand_more,
          onTap: _openSortDrawer,
        ),
      ],
    );
  }

  Future<void> _openSortDrawer() async {
    final result = await showMobileVideoSortDrawer(
      context,
      current: _pageState.filterState,
    );
    if (!mounted || result == null) {
      return;
    }
    _applySort(result);
  }

  Widget _buildVideosSliver(BuildContext context) {
    final controller = _pageState.controller;
    if (controller.isInitialLoading && controller.items.isEmpty) {
      return const SliverToBoxAdapter(
        child: AppMobileSkeletonList(
          key: Key('mobile-pornbox-loading'),
        ),
      );
    }
    if (controller.initialErrorMessage != null && controller.items.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: AppEmptyState(message: controller.initialErrorMessage!),
        ),
      );
    }
    final videos = controller.items;
    if (videos.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: AppEmptyState(message: '暂无视频数据'),
        ),
      );
    }
    final spacing = context.appSpacing.md;
    // 网格横向缩进由 shell 提供；用 SliverMasonryGrid 直接消费外层 CustomScrollView，
    // 自带懒构建（按视口构建 tile），避免 SliverToBoxAdapter+Stack 一次性 build N 张卡。
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final rawColumns = ((width + spacing) / (180 + spacing)).floor();
        final columns = rawColumns < 2 ? 2 : (rawColumns > 6 ? 6 : rawColumns);
        return SliverMasonryGrid.count(
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childCount: videos.length,
          itemBuilder: (context, i) {
            final video = videos[i];
            final aspect = _resolveCoverAspect(
              video.coverWidth,
              video.coverHeight,
            );
            return AspectRatio(
              aspectRatio: aspect,
              child: GestureDetector(
                onLongPress: selectionMode
                    ? null
                    : () {
                        enterSelection();
                        toggleSelect(video.id);
                      },
                child: VideoSummaryCard(
                  video: video,
                  onTap:
                      selectionMode ? null : () => _openSheet(video),
                  selectionMode: selectionMode,
                  isSelected: isSelected(video.id),
                  onSelectedChanged: (_) => toggleSelect(video.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _resolveCoverAspect(int? width, int? height) {
    if (width != null && height != null && width > 0 && height > 0) {
      return width / height;
    }
    return 16 / 9;
  }

  Widget _buildFooter(BuildContext context) {
    final controller = _pageState.controller;
    final showFooter = controller.items.isNotEmpty &&
        (controller.isLoadingMore || controller.loadMoreErrorMessage != null);
    if (!showFooter) {
      return SizedBox(height: context.appSpacing.lg);
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
      child: AppPagedLoadMoreFooter(
        isLoading: controller.isLoadingMore,
        errorMessage: controller.loadMoreErrorMessage,
        onRetry: controller.loadMore,
      ),
    );
  }

  // --------------------------------------------------------- 选择模式

  Widget _buildSelectionBar(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final videoIds = _loadedVideos.map((v) => v.id);
    final allSelected = isAllSelected(videoIds);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          AppTextButton(
            key: const Key('mobile-pornbox-exit-selection-button'),
            label: '取消',
            size: AppTextButtonSize.small,
            onPressed: exitSelection,
          ),
          SizedBox(width: spacing.sm),
          Text(
            '已选 $selectedCount 个',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.medium,
              tone: AppTextTone.primary,
            ),
          ),
          const Spacer(),
          AppTextButton(
            key: const Key('mobile-pornbox-select-all-button'),
            label: allSelected ? '取消全选' : '全选',
            size: AppTextButtonSize.small,
            isSelected: allSelected,
            onPressed: () => toggleSelectAll(videoIds),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchBar(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final hasSelection = selectedCount > 0;
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('mobile-pornbox-batch-add-collection-button'),
                label: '加入合集',
                variant: AppButtonVariant.secondary,
                onPressed: hasSelection ? _batchAddToCollection : null,
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                key: const Key('mobile-pornbox-batch-delete-button'),
                label: '删除',
                variant: AppButtonVariant.danger,
                onPressed: hasSelection ? _batchDelete : null,
              ),
            ),
          ],
        ),
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
      margin: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
      padding: EdgeInsets.all(context.appSpacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
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
