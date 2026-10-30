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
import 'package:sakuramedia/widgets/base/interaction/app_context_menu_trigger.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/add_to_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_actions_sheet.dart';
import 'package:sakuramedia/features/videos/presentation/actions/video_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_filter_drawer.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/pick_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_scope.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/features/videos/presentation/video_display_title.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_hint_box.dart';
import 'package:sakuramedia/widgets/domain/videos/video_sort_menu_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_summary_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

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
    _scrollController = ScrollController();
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
    _scrollController.dispose();
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

  void _applyFilter(VideoFilterState next) {
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
      title: video.displayTitle(AppLocalizations.of(context)),
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    await MobileVideoPlayerRouteData(videoId: video.id).push<void>(context);
  }

  Future<void> _addToCollection(VideoItemListItemDto video) async {
    await showAddToVideoCollectionDialog(
      context,
      videoItemId: video.id,
      collectedRefs: video.collections,
      presentation: AddToVideoCollectionPresentation.bottomDrawer,
    );
    if (!mounted) {
      return;
    }
    // 弹窗内可加入 / 移出（勾选切换），关闭后统一广播刷新合集横滑区与卡片角标。
    ref
        .read(videoMutationEventsProvider.notifier)
        .reportCollectionMembershipChanged(videoId: video.id);
  }

  Future<void> _deleteVideo(VideoItemListItemDto video) async {
    final l10n = AppLocalizations.of(context);
    final title = video.preferredTitle.trim();
    final label = title.isEmpty ? l10n.videoGenericVideo : '“$title”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.videoDeleteTitle,
      message: l10n.videoDeleteConfirmMessage(label),
      confirmLabel: l10n.commonDelete,
      danger: true,
      dialogKey: const Key('mobile-video-delete-drawer'),
      confirmKey: const Key('mobile-video-delete-confirm-button'),
      onConfirm: () => ref.read(videosApiProvider).deleteVideo(video.id),
      failureFallback: l10n.videoDeleteFailed,
    );
    if (!mounted || !confirmed) {
      return;
    }
    ref.read(videoMutationEventsProvider.notifier).reportDeleted(video.id);
    showToast(l10n.videoDeletedToast);
  }

  // --------------------------------------------------------- 批量动作

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
      dialogKey: const Key('mobile-videos-batch-delete-drawer'),
      confirmKey: const Key('mobile-videos-batch-delete-confirm-button'),
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
      showToast(AppLocalizations.of(context).videoCollectionCreated);
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

    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppFilterResultLoadingOverlay(
              surfaceColor: context.appColors.surfaceCard,
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
                child: AppAdaptiveRefreshScrollView(
                  key: const PageStorageKey<String>('mobile:pornbox:list'),
                  controller: _scrollController,
                  onRefresh: _refresh,
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _buildCollectionsSection(context),
                    ),
                    AppPinnedListHeader(
                      key: _listHeaderKey,
                      color: context.appColors.surfaceCard,
                      child: _buildVideosHeader(
                        context,
                        paged: paged,
                        filter: filter,
                      ),
                    ),
                    _buildVideosSliver(
                      context,
                      paged: paged,
                      initialErrorMessage: paged.initialError != null
                          ? l10n.errorVideoListLoadFailed
                          : null,
                    ),
                    // loadMore 页脚独立订阅：翻页 loading / 失败只重建页脚。
                    // 隐藏时保留 lg 底部边距（原语义）。
                    PagedLoadMoreFooterSliver(
                      hiddenSpacing: PagedFooterSpacing.lg,
                      watchFooter: (ref) => ref.watch(
                        videoSummaryProvider(_scope).select(
                          (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
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
    final l10n = AppLocalizations.of(context);
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
                      l10n.videoCollectionsTitle,
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
                      tooltip: l10n.videoNewCollection,
                      onPressed: _createCollection,
                      icon: const Icon(Icons.add_rounded),
                    ),
                    if (collections.isNotEmpty) ...[
                      SizedBox(width: spacing.xs),
                      AppTextButton(
                        key: const Key(
                          'mobile-pornbox-view-all-collections-button',
                        ),
                        label: l10n.videoViewAll,
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
              // 卡片按内容自然高度渲染，避免被固定行高拉伸后在标题下方留白。
              child: Align(
                alignment: Alignment.topCenter,
                child: CollectionCard.video(
                  key: Key('mobile-video-collection-card-${collection.id}'),
                  collection: collection,
                  onTap: () => MobileVideoCollectionDetailRouteData(
                    collectionId: collection.id,
                  ).push(context),
                ),
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
    required PagedViewSnapshot<VideoItemListItemDto> paged,
    required VideoFilterState filter,
  }) {
    final videos = paged.items;
    if (selectionMode) {
      final l10n = AppLocalizations.of(context);
      final videoIds = videos.map((video) => video.id);
      final allSelected = isAllSelected(videoIds);
      return AppListHeader.selection(
        selectionLabel: l10n.videoSelectedCount(selectedCount),
        selectionExitButtonKey: const Key(
          'mobile-pornbox-exit-selection-button',
        ),
        onExitSelection: exitSelection,
        actionSlots: [
          AppButton(
            key: const Key('mobile-pornbox-select-all-button'),
            label: allSelected
                ? l10n.videoDeselectAll
                : l10n.videoSelectAllCount(videos.length),
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.xSmall,
            isSelected: allSelected,
            onPressed: videos.isEmpty ? null : () => toggleSelectAll(videoIds),
          ),
        ],
      );
    }

    final l10n = AppLocalizations.of(context);
    return AppListHeader(
      filterButtonKey: const Key('mobile-pornbox-filter-button'),
      filterTooltip: l10n.videoFilter,
      filterLabel: filter.triggerLabel(l10n),
      onFilterTap: _openFilterDrawer,
      filterUpdate: paged.filterUpdate,
      hasPreviousFilterItems: videos.isNotEmpty,
      onRetryFilter: () => unawaited(
        ref.read(videoSummaryProvider(_scope).notifier).retryFilter(),
      ),
      informationSlots: [
        AppListHeaderInfo(
          key: const Key('mobile-pornbox-total'),
          label: l10n.videoTotalCount(paged.total),
        ),
      ],
      actionSlots: [
        VideoSortMenuButton(
          triggerKey: const Key('mobile-pornbox-sort-trigger'),
          drawerKey: const Key('mobile-pornbox-sort-drawer'),
          keyPrefix: 'mobile-pornbox',
          filterState: filter,
          onChanged: _applyFilter,
          useDrawer: true,
        ),
      ],
    );
  }

  Future<void> _openFilterDrawer() async {
    await showMobileVideoFilterDrawer(
      context,
      current:
          ref.read(videoSummaryProvider(_scope)).value?.filter ??
          VideoFilterState.initial,
      onChanged: _applyFilter,
    );
  }

  Widget _buildVideosSliver(
    BuildContext context, {
    required PagedViewSnapshot<VideoItemListItemDto> paged,
    required String? initialErrorMessage,
  }) {
    if (paged.filterUpdate.hasFailed && paged.items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final isLoading = paged.isInitialLoading && paged.items.isEmpty;
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
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: AppEmptyState(
            message: AppLocalizations.of(context).videoEmptyList,
          ),
        ),
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
            builder: (cardContext) {
              final card = VideoSummaryCard(
                video: video,
                onTap: selectionMode ? null : () => _openSheet(video),
                selectionMode: selectionMode,
                isSelected: isSelected(video.id),
                onSelectedChanged: (_) => toggleSelect(video.id),
              );
              if (selectionMode) {
                return card;
              }
              return AppContextMenuTrigger(
                onRequestMenu: (position) =>
                    _openCardMenu(cardContext, video, position),
                child: card,
              );
            },
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
      items: <AppMenuItem<bool>>[
        AppMenuItem(
          key: Key('mobile-pornbox-card-menu-select-item'),
          value: true,
          label: AppLocalizations.of(cardContext).videoSelect,
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

  // --------------------------------------------------------- 选择模式

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
          onPressed: hasSelection && !submitting ? _batchAddToCollection : null,
        ),
        AppButton(
          key: const Key('mobile-pornbox-batch-delete-button'),
          label: l10n.commonDelete,
          variant: AppButtonVariant.danger,
          onPressed: hasSelection && !submitting ? _batchDelete : null,
        ),
      ],
    );
  }
}
