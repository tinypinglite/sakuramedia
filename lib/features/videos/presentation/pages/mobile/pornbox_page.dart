import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
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
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_actions_sheet.dart';
import 'package:sakuramedia/features/videos/presentation/actions/video_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_sort_drawer.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/pick_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_scope.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/operations/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_hint_box.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_summary_card.dart';

/// 移动端 PornBox 主页（底部导航第 5 个 tab）：上方「视频合集」横滑区 + 下方「全部视频」
/// 网格。数据层与桌面 `DesktopVideoListPage` 完全一致（复用缓存页状态 + 合集控制器 +
/// mutation 广播），仅布局改为移动端竖屏网格 + 底部抽屉形态的编辑交互；长按视频卡进入
/// 多选模式，支持批量加入合集 / 删除。
class MobilePornboxPage extends ConsumerStatefulWidget {
  const MobilePornboxPage({super.key});

  @override
  ConsumerState<MobilePornboxPage> createState() => _MobilePornboxPageState();
}

class _MobilePornboxPageState extends ConsumerState<MobilePornboxPage>
    with MultiSelectStateMixin<MobilePornboxPage, int> {
  static const _scope = VideoSummaryScope.mobile();

  late final RiverpodPageHandle _pageCacheHandle;
  late final ScrollController _scrollController;
  final _listHeaderKey = GlobalKey();
  bool _railRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: mobilePornboxPageCacheKey(),
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

  /// 删除 / 合集成员变化都可能改变合集横滑区封面与计数；用微任务合并一轮内多次信号成
  /// 一次刷新。视频网格本身的删除由列表 provider 做就地移除。
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

  Future<void> _refresh() async {
    await Future.wait<void>(<Future<void>>[
      ref.read(videoSummaryProvider(_scope).notifier).refresh(),
      ref.read(videoCollectionsOverviewProvider.notifier).refresh(),
    ]);
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

  List<VideoItemListItemDto> get _loadedVideos =>
      ref.read(videoSummaryProvider(_scope)).value?.paged.items ?? const [];

  List<VideoItemListItemDto> _selectedVideos() =>
      _loadedVideos.where((v) => isSelected(v.id)).toList(growable: false);

  // --------------------------------------------------------- 单条动作

  void _openSheet(VideoItemListItemDto video) {
    showMobileVideoActionsSheet(
      context,
      video: video,
      onPlay: () => _playVideo(video),
      onThumbnails: () =>
          MobileVideoThumbnailRouteData(videoId: video.id).push<void>(context),
      onAddToCollection: () => _addToCollection(video),
      onDelete: () => _deleteVideo(video),
      collections: video.collections,
      onCollectionTap: (ref) => MobileVideoCollectionDetailRouteData(
        collectionId: ref.id,
      ).push(context),
    );
  }

  Future<void> _playVideo(VideoItemListItemDto video) async {
    if (await tryLaunchExternalVideoPlayback(
      context,
      videoId: video.id,
      title: video.preferredTitle,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    await MobileVideoPlayerRouteData(videoId: video.id).push<void>(context);
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
      ref
          .read(videoMutationEventsProvider.notifier)
          .reportCollectionMembershipChanged(videoId: video.id);
    }
  }

  Future<void> _deleteVideo(VideoItemListItemDto video) async {
    final title = video.preferredTitle.trim();
    final label = title.isEmpty ? '该视频' : '“$title”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除视频',
      message: '确认删除$label？该操作不可恢复。',
      confirmLabel: '删除',
      danger: true,
      dialogKey: const Key('mobile-video-delete-drawer'),
      confirmKey: const Key('mobile-video-delete-confirm-button'),
      onConfirm: () => ref.read(videosApiProvider).deleteVideo(video.id),
      failureFallback: '删除失败，请重试',
    );
    if (!mounted || !confirmed) {
      return;
    }
    ref.read(videoMutationEventsProvider.notifier).reportDeleted(video.id);
    showToast('已删除视频');
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
      dialogKey: const Key('mobile-videos-batch-delete-drawer'),
      confirmKey: const Key('mobile-videos-batch-delete-confirm-button'),
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
    for (final video in result.succeeded) {
      ref.read(videoMutationEventsProvider.notifier).reportDeleted(video.id);
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
    await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
    if (mounted) {
      showToast('已创建合集');
    }
  }

  Future<void> _viewAllCollections() async {
    await const MobileVideoCollectionsRouteData().push<void>(context);
    if (!mounted) {
      return;
    }
    await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
  }

  // --------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(videoSummaryProvider(_scope));
    final summary = videosAsync.value;
    final paged =
        summary?.paged ?? const PagedListState<VideoItemListItemDto>();
    final filter = summary?.filter ?? VideoFilterState.initial;

    ref.listen(videoMutationEventsProvider, (_, next) {
      if (next.value != null) {
        _onMutation();
      }
    });

    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppFilterResultLoadingOverlay(
              protectedHeaderKey: _listHeaderKey,
              scrollController: _scrollController,
              isLoading: paged.filterUpdate.isLoading,
              hasPreviousItems: paged.items.isNotEmpty,
              child: AppAdaptiveRefreshScrollView(
                key: const PageStorageKey<String>('mobile:pornbox:list'),
                controller: _scrollController,
                onRefresh: _refresh,
                slivers: <Widget>[
                  if (!selectionMode)
                    SliverToBoxAdapter(
                      child: _buildCollectionsSection(context),
                    ),
                  AppPinnedListHeader(
                    key: _listHeaderKey,
                    color: context.appColors.surfaceCard,
                    child: _buildVideosHeader(
                      context,
                      paged: paged,
                      videos: paged.items,
                      filter: filter,
                      total: paged.total,
                    ),
                  ),
                  _buildVideosSliver(
                    context,
                    paged: paged,
                    isInitialLoading: videosAsync.isLoading && summary == null,
                    initialErrorMessage: videosAsync.hasError && summary == null
                        ? '视频列表加载失败，请稍后重试'
                        : null,
                  ),
                  SliverToBoxAdapter(child: _buildFooter(context, paged)),
                ],
              ),
            ),
          ),
          if (selectionMode) _buildBatchBar(context),
        ],
      ),
    );
  }

  // --------------------------------------------------------- 合集区

  Widget _buildCollectionsSection(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(videoCollectionsOverviewProvider);
        final collections = async.value ?? const <VideoCollectionDto>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 与 _buildVideosHeader 的 AppListHeader 对齐：top: xs + 固定
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
                        key: const Key(
                          'mobile-pornbox-view-all-collections-button',
                        ),
                        label: '查看全部',
                        size: AppTextButtonSize.xSmall,
                        onPressed: _viewAllCollections,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: spacing.md),
              child: _buildCollectionsRow(context, async, collections),
            ),
            SizedBox(height: spacing.sm),
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
    final spacing = context.appSpacing;
    if (async.hasError && collections.isEmpty) {
      return CollectionHintBox(
        message: apiErrorMessage(async.error!, fallback: '合集加载失败，请稍后重试'),
      );
    }
    final isLoading = async.isLoading && collections.isEmpty;
    final display = isLoading
        ? videoCollectionPlaceholders(count: 4)
        : collections;
    if (display.isEmpty) {
      return const CollectionHintBox(message: '还没有合集，点「新建」把视频攒成一个连播合集吧');
    }
    return AppSkeletonizer(
      enabled: isLoading,
      child: SizedBox(
        // CollectionCoverCard 内容下限：16:9 封面 + sm padding + s14 标题 + 边框 ≈ 105，
        // 故 height 不能低于 ~110。保持 116（原值），只收紧宽度 132 → 116 已减少占用。
        height: 116,
        child: ListView.separated(
          key: const Key('mobile-pornbox-collections-row'),
          scrollDirection: Axis.horizontal,
          // 横滑首尾内缩由 shell body padding 统一提供，此处不叠加额外 horizontal。
          itemCount: display.length,
          separatorBuilder: (context, index) => SizedBox(width: spacing.sm),
          itemBuilder: (context, index) {
            final collection = display[index];
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
      ),
    );
  }

  // --------------------------------------------------------- 视频区

  Widget _buildVideosHeader(
    BuildContext context, {
    required PagedListState<VideoItemListItemDto> paged,
    required List<VideoItemListItemDto> videos,
    required VideoFilterState filter,
    required int total,
  }) {
    if (selectionMode) {
      final videoIds = videos.map((video) => video.id);
      final allSelected = isAllSelected(videoIds);
      return AppListHeader.selection(
        selectionLabel: '已选 $selectedCount 个',
        selectionExitButtonKey: const Key(
          'mobile-pornbox-exit-selection-button',
        ),
        onExitSelection: exitSelection,
        actionSlots: [
          AppButton(
            key: const Key('mobile-pornbox-select-all-button'),
            label: allSelected ? '取消全选' : '全选(${videos.length})',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.xSmall,
            isSelected: allSelected,
            onPressed: videos.isEmpty ? null : () => toggleSelectAll(videoIds),
          ),
        ],
      );
    }

    return AppListHeader(
      filterButtonKey: const Key('mobile-pornbox-filter-button'),
      filterTooltip: '排序筛选',
      filterLabel: filter.sortField.label,
      onFilterTap: _openSortDrawer,
      filterUpdate: paged.filterUpdate,
      hasPreviousFilterItems: videos.isNotEmpty,
      onRetryFilter: () => unawaited(
        ref.read(videoSummaryProvider(_scope).notifier).retryFilter(),
      ),
      informationSlots: [
        AppListHeaderInfo(
          key: const Key('mobile-pornbox-total'),
          label: '$total 个',
        ),
      ],
    );
  }

  Future<void> _openSortDrawer() async {
    await showMobileVideoSortDrawer(
      context,
      current:
          ref.read(videoSummaryProvider(_scope)).value?.filter ??
          VideoFilterState.initial,
      onChanged: _applySort,
    );
  }

  Widget _buildVideosSliver(
    BuildContext context, {
    required PagedListState<VideoItemListItemDto> paged,
    required bool isInitialLoading,
    required String? initialErrorMessage,
  }) {
    if (paged.filterUpdate.hasFailed && paged.items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final isLoading = isInitialLoading && paged.items.isEmpty;
    if (!isLoading && initialErrorMessage != null && paged.items.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: AppEmptyState(message: initialErrorMessage),
        ),
      );
    }
    final videos = isLoading ? videoSummaryPlaceholders() : paged.items;
    if (videos.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(height: 200, child: AppEmptyState(message: '暂无视频数据')),
      );
    }
    // 网格横向缩进由 shell 提供；用 Sliver 瀑布流直接消费外层 CustomScrollView，
    // 自带懒构建（按视口构建 tile），避免 SliverToBoxAdapter+Stack 一次性 build N 张卡。
    return AppSkeletonizer.sliver(
      enabled: isLoading,
      child: AppAdaptiveCardSliver<VideoItemListItemDto>(
        gridKey: const Key('mobile-pornbox-grid'),
        items: videos,
        layout: AppAdaptiveCardGridLayout.masonry,
        tileAspect: (index) => _resolveCoverAspect(
          videos[index].coverWidth,
          videos[index].coverHeight,
        ),
        itemBuilder: (context, video, index) {
          // Builder 是为了拿到**这一张卡自己**的 RenderBox，长按浮层要盖住它。
          return Builder(
            builder: (cardContext) => GestureDetector(
              onLongPressStart: selectionMode
                  ? null
                  : (details) => _openCardMenu(
                      cardContext,
                      video,
                      details.globalPosition,
                    ),
              child: VideoSummaryCard(
                video: video,
                onTap: selectionMode ? null : () => _openSheet(video),
                selectionMode: selectionMode,
                isSelected: isSelected(video.id),
                onSelectedChanged: (_) => toggleSelect(video.id),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 长按视频卡：弹操作菜单。目前只有「选择」——多选入口从此挂在长按菜单里，
  /// 顶栏不再常驻「选择」按钮；其余动作仍走整卡点击的 [_openSheet]。
  Future<void> _openCardMenu(
    BuildContext cardContext,
    VideoItemListItemDto video,
    Offset globalPosition,
  ) async {
    final selected = await showAppActionMenu<bool>(
      context: cardContext,
      globalPosition: globalPosition,
      drawerKey: const Key('mobile-pornbox-card-menu'),
      items: const <AppMenuItem<bool>>[
        AppMenuItem(
          key: Key('mobile-pornbox-card-menu-select-item'),
          value: true,
          label: '选择',
          icon: Icons.check_circle_outline,
        ),
      ],
    );
    if (selected != true || !mounted) {
      return;
    }
    enterSelection();
    toggleSelect(video.id);
  }

  double _resolveCoverAspect(int? width, int? height) {
    if (width != null && height != null && width > 0 && height > 0) {
      return width / height;
    }
    return 16 / 9;
  }

  Widget _buildFooter(
    BuildContext context,
    PagedListState<VideoItemListItemDto> paged,
  ) {
    final showFooter =
        paged.items.isNotEmpty &&
        (paged.isLoadingMore || paged.loadMoreErrorMessage != null);
    if (!showFooter) {
      return SizedBox(height: context.appSpacing.lg);
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
      child: AppPagedLoadMoreFooter(
        isLoading: paged.isLoadingMore,
        errorMessage: paged.loadMoreErrorMessage,
        onRetry: () =>
            ref.read(videoSummaryProvider(_scope).notifier).loadMore(),
      ),
    );
  }

  // --------------------------------------------------------- 选择模式

  Widget _buildBatchBar(BuildContext context) {
    final hasSelection = selectedCount > 0;
    return AppSelectionBottomBar(
      key: const Key('mobile-pornbox-batch-bottom-bar'),
      actions: [
        AppButton(
          key: const Key('mobile-pornbox-batch-add-collection-button'),
          label: '加入合集',
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection ? _batchAddToCollection : null,
        ),
        AppButton(
          key: const Key('mobile-pornbox-batch-delete-button'),
          label: '删除',
          variant: AppButtonVariant.danger,
          onPressed: hasSelection ? _batchDelete : null,
        ),
      ],
    );
  }
}
