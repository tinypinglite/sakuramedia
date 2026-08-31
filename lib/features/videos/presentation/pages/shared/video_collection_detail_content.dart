import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/shared/presentation/providers/collection_playback_handoff_provider.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_detail_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_detail_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/pick_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/video_collection_filter_sections.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/operations/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_member_views.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_playback_mode.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

/// 合集详情的成员排布方式：纵向列表（可拖序）或网格（侧重浏览）。
enum CollectionDetailLayout { list, grid }

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
  final Future<void> Function(int itemId) remove;
  final Future<void> Function(int itemId) delete;
}

/// 视频合集详情共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异收在壳参数与钩子里：
/// - `surfaceColor` / `keyPrefix` / `enableReorder` / `defaultLayout` /
///   `useMobileSelectionLayout` / `hoistTitleToSubpageShell` 表达渲染差异；
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
    this.useMobileFilterDrawer = false,
    this.enableReorder = false,
    this.defaultLayout = CollectionDetailLayout.list,
    this.loadingBuilder,
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
  final bool useMobileFilterDrawer;

  /// 允许列表拖拽重排（桌面端 true；移动端不支持拖序）。
  final bool enableReorder;

  /// 默认成员排布：桌面 list，移动 grid。
  final CollectionDetailLayout defaultLayout;

  final Widget Function(BuildContext context)? loadingBuilder;
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

  /// 确认弹层（桌面 `showAppConfirmDialog` / 移动 `showMobileClipConfirmDrawer`），
  /// 由壳实现；`drawerKey` 仅移动端使用。
  final VideoCollectionConfirm? confirm;

  @override
  ConsumerState<VideoCollectionDetailContent> createState() =>
      _VideoCollectionDetailContentState();
}

class _VideoCollectionDetailContentState
    extends ConsumerState<VideoCollectionDetailContent>
    with MultiSelectStateMixin<VideoCollectionDetailContent, int> {
  int? _hoveredItemId;
  late CollectionDetailLayout _layout;
  late final ScrollController _itemsScrollController;

  VideoCollectionDetailProvider get _providerRef =>
      videoCollectionDetailProvider(widget.collectionId);

  VideoMutationEvents get _mutationBroadcaster =>
      ref.read(videoMutationEventsProvider.notifier);

  bool get _isMobile => widget.useMobileSelectionLayout;

  String get _reorderHandleKeyPrefix =>
      _isMobile ? 'mobile-video-reorder-handle' : 'video-reorder-handle';

  @override
  void initState() {
    super.initState();
    _layout = widget.defaultLayout;
    _itemsScrollController = ScrollController();
  }

  @override
  void dispose() {
    _itemsScrollController.dispose();
    super.dispose();
  }

  void _setHovered(int? itemId) {
    if (_hoveredItemId == itemId) {
      return;
    }
    setState(() => _hoveredItemId = itemId);
  }

  void _toggleLayout() {
    setState(() {
      _layout = _layout == CollectionDetailLayout.list
          ? CollectionDetailLayout.grid
          : CollectionDetailLayout.list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_providerRef);
    final state = async.value;
    final notifier = ref.read(_providerRef.notifier);
    if (widget.hoistTitleToSubpageShell) {
      _reportTitle(state);
    }

    final content = Builder(
      builder: (context) {
        if (async.isLoading && state == null) {
          return (widget.loadingBuilder ??
              (_) => const Center(child: CircularProgressIndicator()))(context);
        }
        if (async.hasError && state == null) {
          return _buildError(context, async.error!);
        }
        if (state == null) {
          return const SizedBox.shrink();
        }
        return Column(
          key: Key('${widget.keyPrefix}-detail-page'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 移动端标题报到返回栏，页面内不再写第二遍大标题。
            if (!widget.hoistTitleToSubpageShell)
              _buildTitleBlock(context, state),
            // 空合集没什么可排序 / 可选择的，顶栏整条省掉。
            if (state.items.isNotEmpty || !state.filterUpdate.isIdle) ...[
              if (!widget.hoistTitleToSubpageShell)
                SizedBox(height: context.appSpacing.md),
              if (selectionMode)
                _buildSelectionHeader(context, state)
              else
                _buildListHeader(context, state),
            ],
            SizedBox(
              height: _isMobile ? context.appSpacing.md : context.appSpacing.lg,
            ),
            Expanded(child: _buildBody(context, state)),
            if (_isMobile && selectionMode) _buildBatchBar(context, state),
          ],
        );
      },
    );

    if (_isMobile) {
      return ColoredBox(color: widget.surfaceColor, child: content);
    }
    return AppPageRefreshScope(
      onRefresh: notifier.refresh,
      child: ColoredBox(color: widget.surfaceColor, child: content),
    );
  }

  // --------------------------------------------------------- 状态三态

  Widget _buildError(BuildContext context, Object error) {
    final message = apiErrorMessage(error, fallback: '合集加载失败，请稍后重试');
    if (_isMobile) {
      return AppEmptyState(message: message);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.md),
        AppButton(
          label: '重试',
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
              playAllBuilder(
                context,
                enabled: items.isNotEmpty,
                onPlayFrom: () => _playFrom(0),
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
    return AppListHeader(
      filterButtonKey: Key('${widget.keyPrefix}-sort-trigger'),
      filterIcon: Icons.swap_vert_rounded,
      filterLabel: videoCollectionSortLabel(state.sort.field),
      filterTooltip: _isMobile ? '排序' : null,
      filterPanelKey: Key('${widget.keyPrefix}-sort-panel'),
      filterUpdate: state.filterUpdate,
      hasPreviousFilterItems: state.items.isNotEmpty,
      onRetryFilter: () =>
          unawaited(ref.read(_providerRef.notifier).retrySort()),
      filterPanelExtraWidth: 180,
      onFilterTap: widget.useMobileFilterDrawer
          ? () => unawaited(_openSortDrawer(state))
          : null,
      filterPanelBuilder: widget.useMobileFilterDrawer
          ? null
          : (_) => VideoCollectionFilterSectionGroup(
              sortField: state.sort.field,
              sortDirection: state.sort.direction,
              onChanged: _applySort,
            ),
      informationSlots: [
        AppListHeaderInfo(
          key: Key('${widget.keyPrefix}-total'),
          label: '$count 个视频',
        ),
      ],
      actionSlots: [
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
            label: '选择',
            size: AppTextButtonSize.xSmall,
            icon: const Icon(Icons.check_circle_outline, size: 14),
            onPressed: enterSelection,
          )
        else
          AppSelectionEntryButton(
            key: Key('${widget.keyPrefix}-enter-selection-button'),
            onPressed: enterSelection,
          ),
        AppIconButton(
          key: Key('${widget.keyPrefix}-layout-toggle'),
          tooltip: _layout == CollectionDetailLayout.list ? '网格视图' : '列表视图',
          onPressed: _toggleLayout,
          icon: Icon(
            _layout == CollectionDetailLayout.list
                ? Icons.grid_view_rounded
                : Icons.view_agenda_outlined,
            size: context.appComponentTokens.iconSizeSm,
          ),
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

  Future<void> _openSortDrawer(VideoCollectionDetailState state) async {
    await showMobileVideoCollectionFilterDrawer(
      context,
      sortField: state.sort.field,
      sortDirection: state.sort.direction,
      onChanged: _applySort,
    );
  }

  /// 多选态顶栏：桌面原地改写整条顶栏（批量动作内联），移动端只留退出/计数/全选、
  /// 批量动作走贴底 [_buildBatchBar]。
  Widget _buildSelectionHeader(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    final itemIds = state.items.map((it) => it.itemId);
    final allSelected = isAllSelected(itemIds);
    final hasSelection = selectedCount > 0;
    if (_isMobile) {
      return AppListHeader.selection(
        selectionLabel: '已选 $selectedCount 个',
        selectionExitButtonKey: Key(
          '${widget.keyPrefix}-exit-selection-button',
        ),
        onExitSelection: exitSelection,
        actionSlots: [
          AppButton(
            key: Key('${widget.keyPrefix}-select-all-button'),
            label: allSelected ? '取消全选' : '全选',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.xSmall,
            isSelected: allSelected,
            onPressed: () => toggleSelectAll(itemIds),
          ),
        ],
      );
    }
    return AppSelectionHeaderToolbar(
      countLabel: '已选 $selectedCount 个',
      selectAllLabel: allSelected ? '取消全选' : '全选',
      selectAllKey: Key('${widget.keyPrefix}-select-all-button'),
      onToggleAll: () => toggleSelectAll(itemIds),
      actions: [
        AppButton(
          key: Key('${widget.keyPrefix}-batch-add-collection-button'),
          label: '加入合集',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection
              ? () => _batchAddToOtherCollection(state)
              : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-remove-button'),
          label: '从合集移除',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection ? () => _batchRemove(state) : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-delete-button'),
          label: '删除视频',
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection ? () => _batchDelete(state) : null,
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
    return AppSelectionBottomBar(
      key: Key('${widget.keyPrefix}-batch-bottom-bar'),
      actions: [
        AppButton(
          key: Key('${widget.keyPrefix}-batch-add-collection-button'),
          label: '加入合集',
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection
              ? () => _batchAddToOtherCollection(state)
              : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-remove-button'),
          label: '移除',
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection ? () => _batchRemove(state) : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-delete-button'),
          label: '删除',
          variant: AppButtonVariant.danger,
          onPressed: hasSelection ? () => _batchDelete(state) : null,
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
      return const AppEmptyState(message: '合集还没有视频，去视频列表用「加入合集」添加吧');
    }
    return _layout == CollectionDetailLayout.grid
        ? _buildGrid(context, state)
        : _buildList(context, state);
  }

  Widget _buildList(BuildContext context, VideoCollectionDetailState state) {
    final items = state.items;
    // 仅手动顺序且非选择模式下允许拖拽重排（仅桌面）：其它排序下拖拽会与排序冲突。
    final canReorder =
        widget.enableReorder && !selectionMode && state.sort.isManual;

    CollectionMemberRow buildRow(int index, {required bool isHovered}) {
      final item = items[index];
      return CollectionMemberRow(
        key: ValueKey<int>(item.itemId),
        index: index,
        coverUrl: item.video.coverImage?.bestAvailableUrl,
        coverWidth: _isMobile ? 64 : 56,
        coverAspectRatio: context.appComponentTokens.movieCardAspectRatio,
        coverFit: _isMobile ? BoxFit.contain : BoxFit.cover,
        title: item.video.preferredTitle,
        subtitle: _isMobile
            ? _subtitleFor(item.video)
            : _formatReleaseDate(item.video.releaseDate),
        isHovered: _isMobile ? false : isHovered,
        onTap: selectionMode
            ? () => toggleSelect(item.itemId)
            : () => _openMemberActions(context, item),
        menuKey: Key('${widget.keyPrefix}-menu-${item.itemId}'),
        dragHandleKey: Key('$_reorderHandleKeyPrefix-${item.itemId}'),
        onRemove: _isMobile ? null : () => _removeItem(item.itemId),
        onDelete: _isMobile ? null : () => _deleteVideo(item.itemId),
        placeholderIcon: Icons.video_library_outlined,
        titleMaxLines: 2,
        reorderable: _isMobile ? false : canReorder,
        selectionMode: selectionMode,
        isSelected: isSelected(item.itemId),
      );
    }

    if (_isMobile) {
      return ListView.separated(
        controller: _itemsScrollController,
        key: Key('${widget.keyPrefix}-detail-list'),
        // 横向缩进由 shell 提供，此处只补底部留白。
        padding: EdgeInsets.only(bottom: context.appSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (context, _) =>
            SizedBox(height: context.appSpacing.sm),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onLongPress: selectionMode
                ? null
                : () {
                    enterSelection();
                    toggleSelect(item.itemId);
                  },
            child: buildRow(index, isHovered: false),
          );
        },
      );
    }

    // 选择模式或非手动排序下禁用拖拽重排，退化为普通列表。
    if (!canReorder) {
      return ListView.separated(
        controller: _itemsScrollController,
        key: Key('${widget.keyPrefix}-detail-list'),
        itemCount: items.length,
        separatorBuilder: (context, _) =>
            SizedBox(height: context.appSpacing.sm),
        itemBuilder: (context, index) => buildRow(index, isHovered: false),
      );
    }

    return ReorderableListView.builder(
      scrollController: _itemsScrollController,
      key: Key('${widget.keyPrefix}-detail-list'),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) =>
          ref.read(_providerRef.notifier).reorder(oldIndex, newIndex),
      // 默认 proxyDecorator 会给拖动项叠加带阴影的 Material，这里换成无阴影透明包装。
      proxyDecorator: (child, index, animation) =>
          Material(type: MaterialType.transparency, child: child),
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          key: ValueKey<int>(item.itemId),
          padding: EdgeInsets.only(bottom: context.appSpacing.sm),
          child: MouseRegion(
            onEnter: (_) => _setHovered(item.itemId),
            onExit: (_) {
              if (_hoveredItemId == item.itemId) {
                _setHovered(null);
              }
            },
            child: buildRow(index, isHovered: _hoveredItemId == item.itemId),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, VideoCollectionDetailState state) {
    final items = state.items;
    final spacing = context.appSpacing.md;
    final columnCap = _isMobile ? 6 : 8;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 列数按目标宽 180 自动算，与原 maxCrossAxisExtent 一致。
        final rawColumns = ((width + spacing) / (180 + spacing)).floor();
        final columns = rawColumns < 2
            ? 2
            : (rawColumns > columnCap ? columnCap : rawColumns);
        return MasonryGridView.count(
          controller: _itemsScrollController,
          key: Key('${widget.keyPrefix}-detail-grid'),
          // 横向缩进由 shell 提供，此处只补底部留白（仅移动）。
          padding: _isMobile
              ? EdgeInsets.only(bottom: context.appSpacing.lg)
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
            return AspectRatio(
              aspectRatio: aspect,
              child: GestureDetector(
                onLongPress: _isMobile && !selectionMode
                    ? () {
                        enterSelection();
                        toggleSelect(item.itemId);
                      }
                    : null,
                child: CollectionMemberCard(
                  key: ValueKey<int>(item.itemId),
                  coverUrl: item.video.coverImage?.bestAvailableUrl,
                  // expandToParent 模式下 coverAspectRatio 仅在 cover placeholder 时
                  // 影响占位比例；瀑布流 tile 已按真实比例分配高度，传 16:9 兜底即可。
                  coverAspectRatio: 16 / 9,
                  title: item.video.preferredTitle,
                  subtitle: _isMobile
                      ? _subtitleFor(item.video)
                      : _formatReleaseDate(item.video.releaseDate),
                  onTap: selectionMode
                      ? () => toggleSelect(item.itemId)
                      : () => _openMemberActions(context, item),
                  menuKey: Key('${widget.keyPrefix}-grid-menu-${item.itemId}'),
                  onRemove: _isMobile ? null : () => _removeItem(item.itemId),
                  onDelete: _isMobile ? null : () => _deleteVideo(item.itemId),
                  placeholderIcon: Icons.video_library_outlined,
                  titleMaxLines: 2,
                  overlayCaption: true,
                  expandToParent: true,
                  selectionMode: selectionMode,
                  isSelected: isSelected(item.itemId),
                ),
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
        remove: _removeItem,
        delete: _deleteVideo,
      ),
    );
  }

  Future<void> _removeItem(int itemId) async {
    final items =
        ref.read(_providerRef).value?.items ?? const <VideoCollectionItemDto>[];
    int? videoId;
    for (final item in items) {
      if (item.itemId == itemId) {
        videoId = item.video.id;
        break;
      }
    }
    final error = await ref.read(_providerRef.notifier).removeItem(itemId);
    if (!mounted) {
      return;
    }
    if (error == null && videoId != null) {
      // 合集封面/计数可能变化，广播给列表页的合集横滑区。
      _mutationBroadcaster.reportCollectionMembershipChanged(
        videoId: videoId,
        collectionId: widget.collectionId,
      );
    }
    showToast(error ?? '已从合集移除');
  }

  /// 彻底删除视频本体（含文件，不可恢复）：先确认，再走 notifier 乐观删除并广播
  /// [VideoMutationEvents.reportDeleted]，让列表页网格精准移除、合集横滑区刷新。
  Future<void> _deleteVideo(int itemId) async {
    final items =
        ref.read(_providerRef).value?.items ?? const <VideoCollectionItemDto>[];
    int? videoId;
    var title = '';
    for (final item in items) {
      if (item.itemId == itemId) {
        videoId = item.video.id;
        title = item.video.preferredTitle.trim();
        break;
      }
    }
    if (videoId == null) {
      return;
    }
    final label = title.isEmpty ? '该视频' : '“$title”';
    final confirmed = await _confirm(
      title: '删除视频',
      message: '确认删除$label？该操作不可恢复。',
      confirmLabel: '删除',
      confirmKey: Key('${widget.keyPrefix}-delete-confirm-button'),
      drawerKey: _isMobile ? Key('${widget.keyPrefix}-delete-drawer') : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final error = await ref
        .read(_providerRef.notifier)
        .deleteVideo(itemId, videoId);
    if (!mounted) {
      return;
    }
    if (error == null) {
      _mutationBroadcaster.reportDeleted(videoId);
    }
    showToast(error ?? '已删除视频');
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Key confirmKey,
    Key? drawerKey,
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
    );
  }

  Future<void> _playFrom(int index) async {
    final state = ref.read(_providerRef).value;
    if (state == null) {
      return;
    }
    // 进入连播前先询问形态（列表连播 / 合并播放）；外部点关闭返回 null → 放弃跳转。
    final mode = await showCollectionPlaybackModePicker(
      context: context,
      useBottomDrawer: _isMobile,
    );
    if (mode == null || !mounted) {
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
    // key 与连播页 takeMode 处保持一致：合集 + 排序，避免同合集换排序后串。
    handoff.offerMode(
      key: 'video:${widget.collectionId}:${sort ?? ''}',
      mode: mode,
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
  ) => state.items.where((it) => isSelected(it.itemId)).toList(growable: false);

  void _showBatchToast(String verb, BatchRunResult<dynamic> result) {
    if (result.failed.isEmpty) {
      showToast('已$verb ${result.succeeded.length} 个视频');
    } else {
      showToast(
        '$verb完成：成功 ${result.succeeded.length} 个，失败 ${result.failed.length} 个',
      );
    }
  }

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
    final api = ref.read(videoCollectionsApiProvider);
    final result = await runBatchOperation<VideoCollectionItemDto>(
      context,
      title: '正在加入「${target.name}」',
      items: selected,
      action: (item) => api.addCollectionItem(
        collectionId: target.id,
        videoItemId: item.video.id,
      ),
    );
    if (!mounted) {
      return;
    }
    // 合集封面/计数变化：逐条广播给列表页的合集横滑区。
    final broadcaster = _mutationBroadcaster;
    for (final item in result.succeeded) {
      broadcaster.reportCollectionMembershipChanged(
        videoId: item.video.id,
        collectionId: target.id,
      );
    }
    _showBatchToast('加入合集', result);
    exitSelection();
  }

  Future<void> _batchRemove(VideoCollectionDetailState state) async {
    final selected = _selectedItems(state);
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await _confirm(
      title: '从合集移除',
      message: '确认从合集移除选中的 ${selected.length} 个视频？视频本身不会被删除。',
      confirmLabel: _isMobile ? '移除' : '确认',
      confirmKey: _batchConfirmKey('remove'),
      drawerKey: _isMobile
          ? Key('${widget.keyPrefix}-batch-remove-drawer')
          : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final notifier = ref.read(_providerRef.notifier);
    final result = await runBatchOperation<VideoCollectionItemDto>(
      context,
      title: '正在从合集移除',
      items: selected,
      action: (item) async {
        final error = await notifier.removeItem(item.itemId);
        if (error != null) {
          throw Exception(error);
        }
      },
    );
    if (!mounted) {
      return;
    }
    // 重新拉取合集与成员，校准本页头部计数（collection.itemCount）与列表。
    await notifier.refresh();
    if (!mounted) {
      return;
    }
    // 广播给列表页的合集横滑区（封面/计数变化）。
    final broadcaster = _mutationBroadcaster;
    for (final item in result.succeeded) {
      broadcaster.reportCollectionMembershipChanged(
        videoId: item.video.id,
        collectionId: widget.collectionId,
      );
    }
    _showBatchToast('移除', result);
    exitSelection();
  }

  Future<void> _batchDelete(VideoCollectionDetailState state) async {
    final selected = _selectedItems(state);
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await _confirm(
      title: '删除视频',
      message: '确认删除选中的 ${selected.length} 个视频？该操作不可恢复。',
      confirmLabel: _isMobile ? '删除' : '确认',
      confirmKey: _batchConfirmKey('delete'),
      drawerKey: _isMobile
          ? Key('${widget.keyPrefix}-batch-delete-drawer')
          : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final videosApi = ref.read(videosApiProvider);
    final result = await runBatchOperation<VideoCollectionItemDto>(
      context,
      title: '正在删除视频',
      items: selected,
      action: (item) => videosApi.deleteVideo(item.video.id),
    );
    if (!mounted) {
      return;
    }
    // 重新拉取合集与成员，校准本页头部计数与列表。
    await ref.read(_providerRef.notifier).refresh();
    if (!mounted) {
      return;
    }
    // 广播删除信号：列表页网格精准移除 + 合集横滑区刷新。
    final broadcaster = _mutationBroadcaster;
    for (final item in result.succeeded) {
      broadcaster.reportDeleted(item.video.id);
    }
    _showBatchToast('删除', result);
    exitSelection();
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

/// 移动端副标题：时长。
String? _subtitleFor(VideoItemListItemDto video) {
  if (video.durationSeconds <= 0) {
    return null;
  }
  return formatMediaTimecode(video.durationSeconds);
}
