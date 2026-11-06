import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/collection_playback_handoff_provider.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_detail_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_detail_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/features/videos/presentation/video_display_title.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/pick_video_collection_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_member_views.dart';
import 'package:sakuramedia/widgets/domain/videos/video_collection_sort_menu_button.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';
import 'package:skeletonizer/skeletonizer.dart';

typedef VideoCollectionPlaySingle =
    Future<void> Function(BuildContext context, int videoId, String title);

typedef VideoCollectionConfirm =
    Future<bool> Function(
      BuildContext context, {
      required String title,
      required String message,
      required String confirmLabel,
      required Key confirmKey,
      Key? drawerKey,
      Future<void> Function()? onConfirm,
    });

typedef VideoCollectionPlayAllBuilder =
    Widget Function(
      BuildContext context, {
      required bool enabled,
      required VoidCallback onPlayFrom,
    });

/// 单条成员动作的执行器（由共享 State 绑定后交给壳渲染动作弹窗/抽屉）。
class VideoCollectionMemberActions {
  const VideoCollectionMemberActions({
    required this.playSingle,
    required this.remove,
    required this.delete,
  });

  final VideoCollectionPlaySingle playSingle;
  final Future<void> Function(int videoId) remove;
  final Future<void> Function(int videoId) delete;
}

/// 视频合集详情共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异收在壳参数与钩子里：
/// - `surfaceColor` / `keyPrefix` / `useMobileSelectionLayout` /
///   `hoistTitleToSubpageShell` 表达渲染差异；
/// - `onMemberTap` / `playSingle` / `onOpenCollection` / `confirm` / `playAllBuilder`
///   收掉动作壳、确认弹层与主行动按钮的平台呈现；
/// - 批量动作 / 删除 / 连播 / 封面比例等逐字重复块全部下沉本层。
class VideoCollectionDetailContent extends ConsumerStatefulWidget {
  const VideoCollectionDetailContent({
    super.key,
    required this.collectionId,
    required this.surfaceColor,
    required this.keyPrefix,
    this.useMobileSelectionLayout = false,
    this.hoistTitleToSubpageShell = false,
    this.useMobileSortDrawer = false,
    this.playAllBuilder,
    this.onMemberTap,
    this.playSingle,
    this.onOpenCollection,
    this.confirm,
  });

  final int collectionId;
  final Color surfaceColor;
  final String keyPrefix;

  /// 移动端多选布局：多选态顶栏只留退出/计数/全选，批量动作走贴底
  /// `AppSelectionBottomBar`；桌面端批量动作内联在顶栏。语义对齐 `SeriesMoviesContent`。
  final bool useMobileSelectionLayout;

  /// 把合集名报给外层移动子页壳的返回栏（见 [AppMobileSubpageTitle]）；桌面端
  /// 保持 `false`——标题块留在页内（名称 + 简介 + 播放全部）。
  final bool hoistTitleToSubpageShell;

  /// 顶栏筛选入口容器：`true` 弹底部抽屉（移动端），`false` 就地展开浮层（桌面端）。
  final bool useMobileSortDrawer;

  final VideoCollectionPlayAllBuilder? playAllBuilder;

  /// 单条成员点击后的动作壳（桌面弹窗 / 移动抽屉），由壳实现。
  final void Function(
    BuildContext context,
    VideoCollectionItemDto item,
    VideoCollectionMemberActions actions,
  )?
  onMemberTap;

  /// 单集播放（桌面快播弹窗 / 移动全屏页），由壳实现。
  final VideoCollectionPlaySingle? playSingle;

  /// 「跳到其它合集」（桌面 push / 移动 push 路由），由壳实现。
  final void Function(BuildContext context, int collectionId)? onOpenCollection;

  /// 确认弹层（桌面 dialog / 移动 drawer），由壳实现；`drawerKey` 仅移动端使用。
  final VideoCollectionConfirm? confirm;

  @override
  ConsumerState<VideoCollectionDetailContent> createState() =>
      _VideoCollectionDetailContentState();
}

class _VideoCollectionDetailContentState
    extends ConsumerState<VideoCollectionDetailContent>
    with MultiSelectStateMixin<VideoCollectionDetailContent, int> {
  late final ScrollController _itemsScrollController;

  VideoCollectionDetailProvider get _providerRef =>
      videoCollectionDetailProvider(widget.collectionId);

  VideoMutationEvents get _mutationBroadcaster =>
      ref.read(videoMutationEventsProvider.notifier);

  bool get _isMobile => widget.useMobileSelectionLayout;

  @override
  void initState() {
    super.initState();
    _itemsScrollController = ScrollController();
  }

  @override
  void dispose() {
    _itemsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_providerRef);
    final state = async.value;
    final notifier = ref.read(_providerRef.notifier);
    if (widget.hoistTitleToSubpageShell) {
      _reportTitle(state);
    }
    final isLoading = async.isLoading && state == null;

    final content = Builder(
      builder: (context) {
        if (!isLoading && async.hasError && state == null) {
          return _buildError(context, async.error!);
        }
        if (!isLoading && state == null) {
          return const SizedBox.shrink();
        }
        // loading 用占位数据渲染同一份真实布局，由 [AppSkeletonizer] 灰化，
        // 骨架与数据到位后的首屏严格同形。
        final displayState = isLoading
            ? videoCollectionDetailPlaceholder()
            : state!;
        return AppSkeletonizer(
          enabled: isLoading,
          child: Column(
            key: Key('${widget.keyPrefix}-detail-page'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 移动端标题报到返回栏，页面内不再写第二遍大标题。
              if (!widget.hoistTitleToSubpageShell)
                _buildTitleBlock(context, displayState),
              // 空合集没什么可排序 / 可选择的，顶栏整条省掉。
              if (displayState.items.isNotEmpty ||
                  !displayState.filterUpdate.isIdle) ...[
                if (!widget.hoistTitleToSubpageShell)
                  SizedBox(height: context.appSpacing.md),
                if (selectionMode)
                  _buildSelectionHeader(context, displayState)
                else
                  _buildListHeader(context, displayState),
              ],
              SizedBox(
                height: _isMobile
                    ? context.appSpacing.md
                    : context.appSpacing.lg,
              ),
              Expanded(
                child: AppFilterResultLoadingOverlay(
                  surfaceColor: widget.surfaceColor,
                  isLoading: displayState.filterUpdate.isLoading,
                  hasPreviousItems: displayState.items.isNotEmpty,
                  child: _buildBody(context, displayState),
                ),
              ),
              if (_isMobile && selectionMode)
                _buildBatchBar(context, displayState),
            ],
          ),
        );
      },
    );

    if (_isMobile) {
      return content;
    }
    return AppPageRefreshScope(onRefresh: notifier.refresh, child: content);
  }

  // --------------------------------------------------------- 状态三态

  Widget _buildError(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context);
    final message = apiErrorMessage(
      error,
      fallback: l10n.videoCollectionsLoadFailed,
      l10n: l10n,
    );
    if (_isMobile) {
      return AppEmptyState(message: message);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.md),
        AppButton(
          label: l10n.commonRetry,
          variant: AppButtonVariant.secondary,
          onPressed: () => ref.read(_providerRef.notifier).refresh(),
        ),
      ],
    );
  }

  // --------------------------------------------------------- 标题块

  /// 标题块（仅桌面）：合集名 + 简介 + 「播放全部」主行动。
  /// 「选择 / 视图切换」在下面那条 [AppListHeader] 的操作槽里，成员数在它的信息槽里。
  Widget _buildTitleBlock(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    final collection = state.collection;
    final items = state.items;
    final description = collection.description.trim();
    final playAllBuilder = widget.playAllBuilder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                collection.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  // 与切片合集详情统一 s18——两个合集详情是姊妹页。
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
            // 多选态隐藏主行动，避免和批量操作混在一起误触。
            if (!selectionMode && playAllBuilder != null)
              // 主行动保留品牌底色会显得「加载中也可用」，用 shade 随骨架一起灰化。
              Skeleton.shade(
                child: playAllBuilder(
                  context,
                  enabled: items.isNotEmpty,
                  onPlayFrom: () => _playFrom(0),
                ),
              ),
          ],
        ),
        if (description.isNotEmpty) ...[
          SizedBox(height: context.appSpacing.sm),
          Text(
            description,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
      ],
    );
  }

  /// 把合集名报给外层返回栏。数据是异步来的，所以每次 build 后用
  /// post-frame 回调写——直接在 build 里改 notifier 会触发 build-during-build。
  void _reportTitle(VideoCollectionDetailState? state) {
    final name = state?.collection.name.trim() ?? '';
    if (name.isEmpty) {
      return;
    }
    final notifier = AppMobileSubpageTitle.read(context);
    if (notifier == null || notifier.value == name) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        notifier.value = name;
      }
    });
  }

  // --------------------------------------------------------- 顶栏

  /// 成员列表顶栏：与影片 / PornBox 列表页共用同一条 `AppListHeader`。
  /// 筛选入口收排序，信息槽放成员数，右侧操作槽放「播放全部（移动）/ 选择 / 视图切换」。
  Widget _buildListHeader(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    final count = state.collection.itemCount == 0
        ? state.items.length
        : state.collection.itemCount;
    final playAllBuilder = widget.playAllBuilder;
    final l10n = AppLocalizations.of(context);
    return AppListHeader(
      filterUpdate: state.filterUpdate,
      hasPreviousFilterItems: state.items.isNotEmpty,
      onRetryFilter: () =>
          unawaited(ref.read(_providerRef.notifier).retrySort()),
      informationSlots: [
        AppListHeaderInfo(
          key: Key('${widget.keyPrefix}-total'),
          label: l10n.videoCollectionVideoCount(count),
        ),
      ],
      actionSlots: [
        VideoCollectionSortMenuButton(
          triggerKey: Key('${widget.keyPrefix}-sort-trigger'),
          panelKey: Key('${widget.keyPrefix}-sort-panel'),
          drawerKey: const Key('mobile-video-collection-sort-drawer'),
          keyPrefix: widget.keyPrefix,
          sort: state.sort,
          onChanged: _applySort,
          useDrawer: widget.useMobileSortDrawer,
        ),
        // 移动端「播放」入口在顶栏；桌面端在标题块。
        if (_isMobile && playAllBuilder != null)
          playAllBuilder(
            context,
            enabled: state.items.isNotEmpty,
            onPlayFrom: () => _playFrom(0),
          ),
        if (_isMobile)
          AppTextButton(
            key: Key('${widget.keyPrefix}-enter-selection-button'),
            label: l10n.videoSelect,
            size: AppTextButtonSize.xSmall,
            icon: const Icon(Icons.check_circle_outline, size: 14),
            onPressed: enterSelection,
          )
        else
          AppSelectionEntryButton(
            key: Key('${widget.keyPrefix}-enter-selection-button'),
            onPressed: enterSelection,
          ),
      ],
    );
  }

  void _applySort({required VideoSortField? field, SortDirection? direction}) {
    if (_itemsScrollController.hasClients) {
      _itemsScrollController.jumpTo(0);
    }
    ref
        .read(_providerRef.notifier)
        .applySort(field: field, direction: direction);
  }

  /// 多选态顶栏：桌面原地改写整条顶栏（批量动作内联），移动端只留退出/计数/全选、
  /// 批量动作走贴底 [_buildBatchBar]。
  Widget _buildSelectionHeader(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    final videoIds = state.items.map((it) => it.video.id);
    final allSelected = isAllSelected(videoIds);
    final hasSelection = selectedCount > 0;
    final l10n = AppLocalizations.of(context);
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.videoCollectionAdd,
      BatchOperationType.videoCollectionRemove,
      BatchOperationType.videoDelete,
    ]);
    if (_isMobile) {
      return AppListHeader.selection(
        selectionLabel: l10n.videoSelectedCount(selectedCount),
        selectionExitButtonKey: Key(
          '${widget.keyPrefix}-exit-selection-button',
        ),
        onExitSelection: exitSelection,
        actionSlots: [
          AppButton(
            key: Key('${widget.keyPrefix}-select-all-button'),
            label: allSelected ? l10n.videoDeselectAll : l10n.videoSelectAll,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.xSmall,
            isSelected: allSelected,
            onPressed: () => toggleSelectAll(videoIds),
          ),
        ],
      );
    }
    return AppSelectionHeaderToolbar(
      countLabel: l10n.videoSelectedCount(selectedCount),
      selectAllLabel: allSelected ? l10n.videoDeselectAll : l10n.videoSelectAll,
      selectAllKey: Key('${widget.keyPrefix}-select-all-button'),
      onToggleAll: () => toggleSelectAll(videoIds),
      actions: [
        AppButton(
          key: Key('${widget.keyPrefix}-batch-add-collection-button'),
          label: l10n.videoAddToCollection,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection && !submitting
              ? () => _batchAddToOtherCollection(state)
              : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-remove-button'),
          label: l10n.videoRemoveFromCollectionTitle,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection && !submitting
              ? () => _batchRemove(state)
              : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-delete-button'),
          label: l10n.videoDeleteTitle,
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection && !submitting
              ? () => _batchDelete(state)
              : null,
        ),
      ],
      exitKey: Key('${widget.keyPrefix}-exit-selection-button'),
      onExit: exitSelection,
    );
  }

  Widget _buildBatchBar(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    final hasSelection = selectedCount > 0;
    final l10n = AppLocalizations.of(context);
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.videoCollectionAdd,
      BatchOperationType.videoCollectionRemove,
      BatchOperationType.videoDelete,
    ]);
    return AppSelectionBottomBar(
      key: Key('${widget.keyPrefix}-batch-bottom-bar'),
      actions: [
        AppButton(
          key: Key('${widget.keyPrefix}-batch-add-collection-button'),
          label: l10n.videoAddToCollection,
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection && !submitting
              ? () => _batchAddToOtherCollection(state)
              : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-remove-button'),
          label: l10n.videoRemove,
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection && !submitting
              ? () => _batchRemove(state)
              : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-delete-button'),
          label: l10n.commonDelete,
          variant: AppButtonVariant.danger,
          onPressed: hasSelection && !submitting
              ? () => _batchDelete(state)
              : null,
        ),
      ],
    );
  }

  // --------------------------------------------------------- body

  Widget _buildBody(BuildContext context, VideoCollectionDetailState state) {
    if (state.items.isEmpty && state.filterUpdate.hasFailed) {
      return const SizedBox.shrink();
    }
    if (state.items.isEmpty) {
      return AppEmptyState(
        message: AppLocalizations.of(context).videoCollectionEmptyHint,
      );
    }
    return _buildGrid(context, state);
  }

  Widget _buildGrid(BuildContext context, VideoCollectionDetailState state) {
    final items = state.items;
    final spacing = context.appSpacing.md;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = resolveAppCardGridColumnCount(
          context,
          width: constraints.maxWidth,
          spacing: spacing,
          orientation: AppCardGridOrientation.mixed,
        );
        return MasonryGridView.count(
          controller: _itemsScrollController,
          key: Key('${widget.keyPrefix}-detail-grid'),
          // 横向缩进由 shell 提供，此处只补底部留白（仅移动）：区块留白之外
          // 还要补回外壳不再吞掉的底部安全区。
          padding: _isMobile
              ? EdgeInsets.only(
                  bottom:
                      context.appSpacing.lg +
                      MediaQuery.paddingOf(context).bottom,
                )
              : null,
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final aspect = _resolveCoverAspect(
              item.video.coverWidth,
              item.video.coverHeight,
            );
            final playSingle = widget.playSingle;
            return AspectRatio(
              aspectRatio: aspect,
              child: CollectionMemberCard(
                key: ValueKey<int>(item.video.id),
                onLongPress: _isMobile && !selectionMode
                    ? () {
                        enterSelection();
                        toggleSelect(item.video.id);
                      }
                    : null,
                coverUrl: item.video.coverImage?.origin,
                // expandToParent 模式下 coverAspectRatio 仅在 cover placeholder 时
                // 影响占位比例；瀑布流 tile 已按真实比例分配高度，传 16:9 兜底即可。
                coverAspectRatio: 16 / 9,
                title: item.video.displayTitle(AppLocalizations.of(context)),
                // 副信息只在桌面悬停面板渲染；移动端无 hover，收起态不铺文字。
                subtitle: _formatReleaseDate(item.video.releaseDate),
                onTap: selectionMode
                    ? () => toggleSelect(item.video.id)
                    : () => _openMemberActions(context, item),
                menuKey: Key('${widget.keyPrefix}-grid-menu-${item.video.id}'),
                onPlay: _isMobile || playSingle == null
                    ? null
                    : () => playSingle(
                        context,
                        item.video.id,
                        item.video.displayTitle(AppLocalizations.of(context)),
                      ),
                playButtonKey: Key(
                  '${widget.keyPrefix}-grid-play-${item.video.id}',
                ),
                onThumbnails: _isMobile ? null : () => _openThumbnails(item),
                thumbnailsButtonKey: Key(
                  '${widget.keyPrefix}-grid-thumbnails-${item.video.id}',
                ),
                onAddToCollection: _isMobile
                    ? null
                    : () => _addToOtherCollection(item),
                addToCollectionButtonKey: Key(
                  '${widget.keyPrefix}-grid-add-collection-${item.video.id}',
                ),
                onRemove: _isMobile ? null : () => _removeVideo(item.video.id),
                removeButtonKey: Key(
                  '${widget.keyPrefix}-grid-remove-${item.video.id}',
                ),
                onDelete: _isMobile ? null : () => _deleteVideo(item.video.id),
                deleteButtonKey: Key(
                  '${widget.keyPrefix}-grid-delete-${item.video.id}',
                ),
                expandToParent: true,
                selectionMode: selectionMode,
                isSelected: isSelected(item.video.id),
              ),
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------------- 单条动作

  void _openMemberActions(BuildContext context, VideoCollectionItemDto item) {
    final handler = widget.onMemberTap;
    if (handler == null) {
      return;
    }
    handler(
      context,
      item,
      VideoCollectionMemberActions(
        playSingle: widget.playSingle ?? (_, __, ___) async {},
        remove: _removeVideo,
        delete: _deleteVideo,
      ),
    );
  }

  Future<void> _removeVideo(int videoId) async {
    final error = await ref.read(_providerRef.notifier).removeVideo(videoId);
    if (!mounted) {
      return;
    }
    if (error == null) {
      // 合集封面/计数可能变化，广播给列表页的合集横滑区。
      _mutationBroadcaster.reportCollectionMembershipChanged(
        videoId: videoId,
        collectionId: widget.collectionId,
      );
    }
    showToast(
      error ?? AppLocalizations.of(context).videoRemovedFromCollection,
      tone: error == null ? AppToastTone.success : AppToastTone.error,
    );
  }

  /// 彻底删除视频本体（含文件，不可恢复）：先确认，再走 notifier 乐观删除并广播
  /// [VideoMutationEvents.reportDeleted]，让列表页网格精准移除、合集横滑区刷新。
  Future<void> _deleteVideo(int videoId) async {
    final l10n = AppLocalizations.of(context);
    final items =
        ref.read(_providerRef).value?.items ?? const <VideoCollectionItemDto>[];
    var title = '';
    for (final item in items) {
      if (item.video.id == videoId) {
        title = item.video.preferredTitle.trim();
        break;
      }
    }
    final label = title.isEmpty ? l10n.videoGenericVideo : '“$title”';
    final notifier = ref.read(_providerRef.notifier);
    final confirmed = await _confirm(
      title: l10n.videoDeleteTitle,
      message: l10n.videoDeleteConfirmMessage(label),
      confirmLabel: l10n.commonDelete,
      confirmKey: Key('${widget.keyPrefix}-delete-confirm-button'),
      drawerKey: _isMobile ? Key('${widget.keyPrefix}-delete-drawer') : null,
      onConfirm: () => notifier.deleteVideo(videoId),
    );
    if (!mounted || !confirmed) {
      return;
    }
    _mutationBroadcaster.reportDeleted(videoId);
    showToast(l10n.videoDeletedToast, tone: AppToastTone.success);
  }

  /// 跳转到该视频的缩略图页（桌面悬停动作）。
  void _openThumbnails(VideoCollectionItemDto item) {
    context.pushDesktopVideoThumbnails(videoId: item.video.id);
  }

  /// 单卡「加入合集」：把该视频加入其它合集（排除当前合集），成功后广播刷新
  /// 目标合集的封面 / 计数。
  Future<void> _addToOtherCollection(VideoCollectionItemDto item) async {
    final l10n = AppLocalizations.of(context);
    final target = await showPickVideoCollectionDialog(
      context,
      presentation: _isMobile
          ? PickVideoCollectionPresentation.bottomDrawer
          : PickVideoCollectionPresentation.dialog,
      excludedCollectionId: widget.collectionId,
    );
    if (!mounted || target == null) {
      return;
    }
    try {
      await ref
          .read(videoCollectionsApiProvider)
          .addVideoToCollection(
            collectionId: target.id,
            videoItemId: item.video.id,
          );
      if (!mounted) {
        return;
      }
      _mutationBroadcaster.reportCollectionMembershipChanged(
        videoId: item.video.id,
        collectionId: target.id,
      );
      showToast(
        l10n.videoAddedToCollection(target.name),
        tone: AppToastTone.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.videoAddToCollectionFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Key confirmKey,
    Key? drawerKey,
    Future<void> Function()? onConfirm,
  }) async {
    final handler = widget.confirm;
    if (handler == null) {
      return false;
    }
    return handler(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      confirmKey: confirmKey,
      drawerKey: drawerKey,
      onConfirm: onConfirm,
    );
  }

  Future<void> _playFrom(int index) async {
    final state = ref.read(_providerRef).value;
    if (state == null) {
      return;
    }
    final handoff = ref.read(collectionPlaybackHandoffProvider);
    final sort = state.sort.apiValue;
    // 把当前已排序、带播放地址的成员交给连播页直接用，免其二次全量拉取。
    handoff.offerVideoItems(
      collectionId: widget.collectionId,
      sort: sort,
      items: state.items,
    );
    if (_isMobile) {
      MobileVideoCollectionPlayRouteData(
        collectionId: widget.collectionId,
        startIndex: index,
        // 移动端详情页按手动顺序展示（sort 为 null），连播顺序与之一致。
        sort: sort,
      ).push(context);
      return;
    }
    context.pushDesktopVideoCollectionPlay(
      collectionId: widget.collectionId,
      startIndex: index,
      sort: sort,
    );
  }

  // --------------------------------------------------------- 选择 / 批量

  List<VideoCollectionItemDto> _selectedItems(
    VideoCollectionDetailState state,
  ) => state.items
      .where((it) => isSelected(it.video.id))
      .toList(growable: false);

  Future<void> _batchAddToOtherCollection(
    VideoCollectionDetailState state,
  ) async {
    final selected = _selectedItems(state);
    if (selected.isEmpty) {
      return;
    }
    final target = await showPickVideoCollectionDialog(
      context,
      presentation: _isMobile
          ? PickVideoCollectionPresentation.bottomDrawer
          : PickVideoCollectionPresentation.dialog,
      excludedCollectionId: widget.collectionId,
    );
    if (!mounted || target == null) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.videoCollectionAdd,
      targetCollectionId: target.id,
      ids: selected.map((item) => item.video.id).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> _batchRemove(VideoCollectionDetailState state) async {
    final selected = _selectedItems(state);
    if (selected.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.videoRemoveFromCollectionTitle,
      message: l10n.videoBatchRemoveConfirmMessage(selected.length),
      confirmLabel: _isMobile ? l10n.videoRemove : l10n.videoConfirm,
      confirmKey: _batchConfirmKey('remove'),
      drawerKey: _isMobile
          ? Key('${widget.keyPrefix}-batch-remove-drawer')
          : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.videoCollectionRemove,
      targetCollectionId: widget.collectionId,
      ids: selected.map((item) => item.video.id).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> _batchDelete(VideoCollectionDetailState state) async {
    final selected = _selectedItems(state);
    if (selected.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.videoDeleteTitle,
      message: l10n.videoBatchDeleteConfirmMessage(selected.length),
      confirmLabel: _isMobile ? l10n.commonDelete : l10n.videoConfirm,
      confirmKey: _batchConfirmKey('delete'),
      drawerKey: _isMobile
          ? Key('${widget.keyPrefix}-batch-delete-drawer')
          : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.videoDelete,
      ids: selected.map((item) => item.video.id).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  /// 批量确认按钮 Key：桌面两端共用 `$keyPrefix-batch-confirm-button`，
  /// 移动端按操作区分（remove / delete）。
  Key _batchConfirmKey(String op) {
    if (_isMobile) {
      return Key('${widget.keyPrefix}-batch-$op-confirm-button');
    }
    return Key('${widget.keyPrefix}-batch-confirm-button');
  }
}

double _resolveCoverAspect(int? width, int? height) {
  if (width != null && height != null && width > 0 && height > 0) {
    return width / height;
  }
  return 16 / 9;
}

/// 发布日期文案；为空返回 `null`（不展示该行）。
String? _formatReleaseDate(DateTime? value) {
  if (value == null) {
    return null;
  }
  return DateFormat('yyyy-MM-dd').format(value.toLocal());
}
