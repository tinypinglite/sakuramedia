import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collection_detail_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collection_detail_state.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/pick_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/collection_playback_handoff_provider.dart';
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
import 'package:sakuramedia/widgets/domain/clips/clip_cover_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_member_views.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_playback_mode.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

/// 合集详情的切片排布方式：纵向列表（可拖序）或网格（侧重浏览）。
enum ClipCollectionDetailLayout { list, grid }

typedef ClipPlaySingle = Future<void> Function(
  BuildContext context,
  MediaClipDto clip,
);

typedef ClipConfirm = Future<bool> Function(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Key confirmKey,
  Key? drawerKey,
});

typedef ClipPlayAllBuilder = Widget Function(
  BuildContext context, {
  required bool enabled,
  required VoidCallback onPlayFrom,
});

/// 单条切片动作的执行器（由共享 State 绑定后交给壳渲染动作抽屉 / 直接播放）。
class ClipCollectionMemberActions {
  const ClipCollectionMemberActions({
    required this.playSingle,
    required this.remove,
    required this.delete,
  });

  final ClipPlaySingle playSingle;
  final Future<void> Function(MediaClipDto clip) remove;
  final Future<void> Function(MediaClipDto clip) delete;
}

/// 切片合集详情共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异收在壳参数与钩子里：`surfaceColor` / `keyPrefix` / `enableReorder` /
/// `defaultLayout` / `useMobileSelectionLayout` / `hoistTitleToSubpageShell`,
///以及动作抽屉（`onMemberTap`）、单集播放（`playSingle`）、来源影片（`onOpenMovie`）、
/// 确认弹层（`confirm`）、播放全部（`playAllBuilder`）、改名 / 添加切片（`onEditCollection` /
/// `onAddClips`）。批量动作 / 删除 / 连播交接 / 列数推导等逐字重复块全部下沉本层。
/// **桌面切片合集没有「加入其它合集」批量动作**（移动独有），本层按
/// `useMobileSelectionLayout` 门控、不改变两端行为。
class ClipCollectionDetailContent extends ConsumerStatefulWidget {
  const ClipCollectionDetailContent({
    super.key,
    required this.collectionId,
    required this.surfaceColor,
    required this.keyPrefix,
    this.useMobileSelectionLayout = false,
    this.hoistTitleToSubpageShell = false,
    this.enableReorder = false,
    this.defaultLayout = ClipCollectionDetailLayout.grid,
    this.loadingBuilder,
    this.playAllBuilder,
    this.onMemberTap,
    this.playSingle,
    this.onOpenMovie,
    this.confirm,
    this.onEditCollection,
    this.onAddClips,
  });

  final int collectionId;
  final Color surfaceColor;
  final String keyPrefix;

  /// 移动端多选布局：多选态顶栏只留退出/计数/全选，批量动作走贴底
  /// `AppSelectionBottomBar`；桌面端批量动作内联在顶栏。
  final bool useMobileSelectionLayout;

  /// 把合集名报给外层移动子页壳的返回栏；桌面端 `false`——标题块留在页内。
  final bool hoistTitleToSubpageShell;

  /// 允许列表拖拽重排（桌面端 true；移动端不支持拖序）。
  final bool enableReorder;

  /// 默认成员排布：两端默认都是 grid。
  final ClipCollectionDetailLayout defaultLayout;

  final Widget Function(BuildContext context)? loadingBuilder;
  final ClipPlayAllBuilder? playAllBuilder;

  /// 单条切片点击后的动作（桌面直接播放 / 移动动作抽屉），由壳实现。
  final void Function(
    BuildContext context,
    MediaClipDto clip,
    ClipCollectionMemberActions actions,
  )?
  onMemberTap;

  /// 单集播放（桌面 `showClipPlayerDialog` / 移动全屏页），由壳实现。
  final ClipPlaySingle? playSingle;

  /// 「来源影片」（桌面 push / 移动 push 路由），由壳实现。
  final void Function(BuildContext context, MediaClipDto clip)? onOpenMovie;

  /// 确认弹层（桌面 `showAppConfirmDialog` / 移动 `showMobileClipConfirmDrawer`），
  /// 由壳实现；`drawerKey` 仅移动端使用。
  final ClipConfirm? confirm;

  /// 改名 / 编辑合集（桌面对话框 / 移动底部抽屉），由壳实现；返回更新后的合集。
  final Future<ClipCollectionDto?> Function(
    BuildContext context,
    ClipCollectionDto collection,
  )?
  onEditCollection;

  /// 添加切片（桌面对话框 / 移动底部抽屉），由壳实现；返回后 content 统一刷新广播。
  final Future<void> Function(BuildContext context, Set<int> memberClipIds)?
  onAddClips;

  @override
  ConsumerState<ClipCollectionDetailContent> createState() =>
      _ClipCollectionDetailContentState();
}

class _ClipCollectionDetailContentState
    extends ConsumerState<ClipCollectionDetailContent>
    with MultiSelectStateMixin<ClipCollectionDetailContent, int> {
  int? _hoveredClipId;
  late ClipCollectionDetailLayout _layout;

  ClipCollectionDetailProvider get _providerRef =>
      clipCollectionDetailProvider(widget.collectionId);

  ClipMutationEvents get _mutationBroadcaster =>
      ref.read(clipMutationEventsProvider.notifier);

  bool get _isMobile => widget.useMobileSelectionLayout;

  String get _reorderHandleKeyPrefix =>
      _isMobile ? 'mobile-clip-reorder-handle' : 'clip-reorder-handle';

  @override
  void initState() {
    super.initState();
    _layout = widget.defaultLayout;
  }

  void _setHovered(int? clipId) {
    if (_hoveredClipId == clipId) {
      return;
    }
    setState(() => _hoveredClipId = clipId);
  }

  void _toggleLayout() {
    setState(() {
      _layout =
          _layout == ClipCollectionDetailLayout.list
              ? ClipCollectionDetailLayout.grid
              : ClipCollectionDetailLayout.list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_providerRef);
    final state = async.value;
    if (widget.hoistTitleToSubpageShell) {
      _reportTitleToShell(state?.collection);
    }

    final content = Builder(
      builder: (context) {
        if (async.isLoading && state == null) {
          return (
            widget.loadingBuilder ??
            (_) => const Center(child: CircularProgressIndicator())
          )(context);
        }
        if (async.hasError && state == null) {
          return AppEmptyState(
            message: apiErrorMessage(
              async.error!,
              fallback: '合集详情暂时无法加载，请稍后重试',
            ),
          );
        }
        if (state == null) {
          return const SizedBox.shrink();
        }
        return Column(
          key: Key('${widget.keyPrefix}-detail-page-body'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 移动端标题报到返回栏，页面内不再写第二遍大标题。
            if (!widget.hoistTitleToSubpageShell)
              _buildTitleBlock(context, state),
            if (!widget.hoistTitleToSubpageShell)
              SizedBox(height: context.appSpacing.md),
            if (selectionMode)
              _buildSelectionHeader(context, state)
            else
              _buildListHeader(context, state),
            SizedBox(height: context.appSpacing.md),
            Expanded(child: _buildClips(context, state)),
            if (_isMobile && selectionMode) _buildBatchBar(context, state),
          ],
        );
      },
    );

    if (_isMobile) {
      return ColoredBox(color: widget.surfaceColor, child: content);
    }
    return AppPageRefreshScope(
      onRefresh: ref.read(_providerRef.notifier).refresh,
      child: ColoredBox(color: widget.surfaceColor, child: content),
    );
  }

  // --------------------------------------------------------- 标题块

  /// 标题块（仅桌面）：合集名 + 「编辑合集」+ 「播放全部」主行动。
  Widget _buildTitleBlock(
    BuildContext context,
    ClipCollectionDetailState state,
  ) {
    final collection = state.collection;
    final playAllBuilder = widget.playAllBuilder;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 标题区整体 Expanded 吃掉剩余空间，主行动才会真的贴右。
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  collection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s18,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              // 多选态隐藏「编辑合集」，避免和批量操作混在一起误触。
              if (!selectionMode) ...[
                SizedBox(width: context.appSpacing.xs),
                AppIconButton(
                  key: Key('${widget.keyPrefix}-rename-button'),
                  tooltip: '编辑合集',
                  onPressed: () => _editCollection(context),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: context.appComponentTokens.iconSizeSm,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!selectionMode && playAllBuilder != null)
          playAllBuilder(
            context,
            enabled: state.clips.isNotEmpty,
            onPlayFrom: () => _playFrom(0),
          ),
      ],
    );
  }

  /// 把合集名报给外层返回栏。数据是异步来的，所以用 post-frame 回调写。
  void _reportTitleToShell(ClipCollectionDto? collection) {
    final name = collection?.name.trim() ?? '';
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

  /// 成员列表顶栏：与其它列表页共用同一条 `AppListHeader`。
  /// **本页没有筛选维度**——切片合集是手动顺序，不接筛选入口。
  Widget _buildListHeader(
    BuildContext context,
    ClipCollectionDetailState state,
  ) {
    final count = state.collection.clipCount;
    final hasClips = state.clips.isNotEmpty;
    final playAllBuilder = widget.playAllBuilder;
    return AppListHeader(
      informationSlots: [
        AppListHeaderInfo(
          key: Key('${widget.keyPrefix}-total'),
          label: '$count 个切片',
        ),
      ],
      actionSlots: [
        if (hasClips && _isMobile && playAllBuilder != null)
          playAllBuilder(
            context,
            enabled: true,
            onPlayFrom: () => _playFrom(0),
          ),
        if (_isMobile)
          AppTextButton(
            key: Key('${widget.keyPrefix}-add-clips-button'),
            label: '添加',
            size: AppTextButtonSize.xSmall,
            onPressed: () => _addClips(context),
          )
        else
          AppTextButton(
            key: Key('${widget.keyPrefix}-add-clips-button'),
            label: '添加切片',
            size: AppTextButtonSize.small,
            onPressed: () => _addClips(context),
          ),
        if (hasClips)
          if (_isMobile)
            AppIconButton(
              key: Key('${widget.keyPrefix}-layout-toggle'),
              tooltip: _layout == ClipCollectionDetailLayout.list ? '网格视图' : '列表视图',
              onPressed: _toggleLayout,
              icon: Icon(
                _layout == ClipCollectionDetailLayout.list
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_outlined,
                size: context.appComponentTokens.iconSizeSm,
              ),
            )
          else ...[
            AppSelectionEntryButton(
              key: Key('${widget.keyPrefix}-enter-selection-button'),
              onPressed: enterSelection,
            ),
            AppIconButton(
              key: Key('${widget.keyPrefix}-layout-toggle'),
              tooltip: _layout == ClipCollectionDetailLayout.list ? '网格视图' : '列表视图',
              onPressed: _toggleLayout,
              icon: Icon(
                _layout == ClipCollectionDetailLayout.list
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_outlined,
                size: context.appComponentTokens.iconSizeSm,
              ),
            ),
          ],
        if (_isMobile)
          AppIconButton(
            key: Key('${widget.keyPrefix}-rename-button'),
            tooltip: '编辑合集',
            onPressed: () => _editCollection(context),
            icon: Icon(
              Icons.edit_outlined,
              size: context.appComponentTokens.iconSizeSm,
            ),
          ),
      ],
    );
  }

  /// 多选态顶栏：桌面原地改写整条顶栏（批量动作内联），移动端只留退出/计数/全选、
  /// 批量动作走贴底 [_buildBatchBar]。
  Widget _buildSelectionHeader(
    BuildContext context,
    ClipCollectionDetailState state,
  ) {
    final clipIds = state.clips.map((clip) => clip.clipId);
    final allSelected = isAllSelected(clipIds);
    final hasSelection = selectedCount > 0;
    if (_isMobile) {
      return AppListHeader.selection(
        selectionLabel: '已选 $selectedCount 个',
        selectionExitButtonKey: Key('${widget.keyPrefix}-exit-selection-button'),
        onExitSelection: exitSelection,
        actionSlots: [
          AppButton(
            key: Key('${widget.keyPrefix}-select-all-button'),
            label: allSelected ? '取消全选' : '全选',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.xSmall,
            isSelected: allSelected,
            onPressed: () => toggleSelectAll(clipIds),
          ),
        ],
      );
    }
    return AppSelectionHeaderToolbar(
      countLabel: '已选 $selectedCount 个',
      selectAllLabel: allSelected ? '取消全选' : '全选',
      selectAllKey: Key('${widget.keyPrefix}-select-all-button'),
      onToggleAll: () => toggleSelectAll(clipIds),
      actions: [
        AppButton(
          key: Key('${widget.keyPrefix}-batch-remove-button'),
          label: '从合集移除',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection ? () => _batchRemove(state) : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-delete-button'),
          label: '删除切片',
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
    ClipCollectionDetailState state,
  ) {
    final hasSelection = selectedCount > 0;
    return AppSelectionBottomBar(
      key: Key('${widget.keyPrefix}-batch-bottom-bar'),
      actions: [
        AppButton(
          key: Key('${widget.keyPrefix}-batch-add-collection-button'),
          label: '加入合集',
          variant: AppButtonVariant.secondary,
          onPressed:
              hasSelection ? () => _batchAddToOtherCollection(state) : null,
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

  Widget _buildClips(BuildContext context, ClipCollectionDetailState state) {
    if (state.clips.isEmpty) {
      return AppEmptyState(
        message: _isMobile ? '合集还没有切片，点右上角「添加」加入吧' : '合集还没有切片，去「全部切片」里加入吧',
      );
    }
    return _layout == ClipCollectionDetailLayout.grid
        ? _buildGrid(context, state)
        : _buildList(context, state);
  }

  Widget _buildList(BuildContext context, ClipCollectionDetailState state) {
    final clips = state.clips;
    // 选择模式下禁用拖拽重排，退化为普通列表，避免与多选交互冲突（仅桌面）。
    final canReorder = widget.enableReorder && !selectionMode;

    CollectionMemberRow buildRow(int index, {required bool isHovered}) {
      final clip = clips[index];
      return CollectionMemberRow(
        key: ValueKey<int>(clip.clipId),
        index: index,
        coverUrl: clip.coverImage?.bestAvailableUrl,
        coverWidth: 120,
        coverAspectRatio: 16 / 9,
        title: clip.displayTitle,
        subtitle: clip.metaLine,
        isHovered: _isMobile ? false : isHovered,
        onTap:
            selectionMode
                ? () => toggleSelect(clip.clipId)
                : () => _openMemberActions(context, clip),
        menuKey: Key('${widget.keyPrefix}-menu-${clip.clipId}'),
        dragHandleKey: Key('$_reorderHandleKeyPrefix-${clip.clipId}'),
        onOpenSource: _isMobile ? null : _openMovieCallback(clip),
        openSourceLabel: '影片',
        onRemove: _isMobile ? null : () => _removeClip(clip),
        onDelete: _isMobile ? null : () => _deleteClip(clip),
        deleteLabel: '删除切片',
        reorderable: _isMobile ? false : canReorder,
        selectionMode: selectionMode,
        isSelected: isSelected(clip.clipId),
      );
    }

    if (_isMobile) {
      return ListView.separated(
        key: Key('${widget.keyPrefix}-detail-list'),
        // 横向缩进由 shell 提供，此处只补底部留白。
        padding: EdgeInsets.only(bottom: context.appSpacing.lg),
        itemCount: clips.length,
        separatorBuilder: (context, index) => SizedBox(height: context.appSpacing.sm),
        itemBuilder: (context, index) {
          final clip = clips[index];
          return GestureDetector(
            onLongPress:
                selectionMode
                    ? null
                    : () {
                      enterSelection();
                      toggleSelect(clip.clipId);
                    },
            child: buildRow(index, isHovered: false),
          );
        },
      );
    }

    // 选择模式下退化为普通列表（无拖拽手柄）。
    if (!canReorder) {
      return ListView.separated(
        key: Key('${widget.keyPrefix}-detail-list'),
        itemCount: clips.length,
        separatorBuilder:
            (context, _) => SizedBox(height: context.appSpacing.sm),
        itemBuilder: (context, index) => buildRow(index, isHovered: false),
      );
    }

    return ReorderableListView.builder(
      key: Key('${widget.keyPrefix}-detail-list'),
      buildDefaultDragHandles: false,
      itemCount: clips.length,
      onReorder: _onReorder,
      // 默认 proxyDecorator 会给拖动项叠加带阴影的 Material（主题色偏粉），
      // 这里换成无阴影透明包装，去掉拖动时的粉色投影。
      proxyDecorator:
          (child, index, animation) =>
              Material(type: MaterialType.transparency, child: child),
      itemBuilder: (context, index) {
        final clip = clips[index];
        return Padding(
          key: ValueKey<int>(clip.clipId),
          padding: EdgeInsets.only(bottom: context.appSpacing.sm),
          child: MouseRegion(
            onEnter: (_) => _setHovered(clip.clipId),
            onExit: (_) {
              if (_hoveredClipId == clip.clipId) {
                _setHovered(null);
              }
            },
            child: buildRow(index, isHovered: _hoveredClipId == clip.clipId),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, ClipCollectionDetailState state) {
    final clips = state.clips;
    final spacing = context.appSpacing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _resolveColumnCount(constraints.maxWidth, spacing.md);
        final grid = GridView.builder(
          key: Key('${widget.keyPrefix}-detail-grid'),
          padding: _isMobile
              ? EdgeInsets.only(bottom: spacing.lg)
              : EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing.md,
            crossAxisSpacing: spacing.md,
            childAspectRatio: 16 / 9,
          ),
          itemCount: clips.length,
          itemBuilder: (context, index) {
            final clip = clips[index];
            if (_isMobile) {
              return GestureDetector(
                onLongPress:
                    selectionMode
                        ? null
                        : () {
                          enterSelection();
                          toggleSelect(clip.clipId);
                        },
                child: ClipCoverCard(
                  key: ValueKey<int>(clip.clipId),
                  clip: clip,
                  selectionMode: selectionMode,
                  isSelected: isSelected(clip.clipId),
                  onSelectedChanged: (_) => toggleSelect(clip.clipId),
                  onTap: () => _openMemberActions(context, clip),
                ),
              );
            }
            final number =
                clip.movieNumber?.isNotEmpty == true ? clip.movieNumber! : '无番号';
            final duration = formatMediaTimecode(clip.durationSeconds);
            return CollectionMemberCard(
              key: ValueKey<int>(clip.clipId),
              coverUrl: clip.coverImage?.bestAvailableUrl,
              coverAspectRatio: 16 / 9,
              title: number,
              subtitle: duration,
              clipOverlay: true,
              onTap:
                  selectionMode
                      ? () => toggleSelect(clip.clipId)
                      : () => _openMemberActions(context, clip),
              menuKey: Key('${widget.keyPrefix}-grid-menu-${clip.clipId}'),
              onOpenSource: _openMovieCallback(clip),
              openSourceLabel: '影片',
              onRemove: () => _removeClip(clip),
              onDelete: () => _deleteClip(clip),
              deleteLabel: '删除切片',
              selectionMode: selectionMode,
              isSelected: isSelected(clip.clipId),
            );
          },
        );
        return grid;
      },
    );
  }

  int _resolveColumnCount(double width, double spacing) {
    final columns = ((width + spacing) / (280 + spacing)).floor();
    return math.max(2, math.min(4, columns));
  }

  // --------------------------------------------------------- 单条动作

  void _openMemberActions(BuildContext context, MediaClipDto clip) {
    final handler = widget.onMemberTap;
    if (handler == null) {
      return;
    }
    handler(
      context,
      clip,
      ClipCollectionMemberActions(
        playSingle: widget.playSingle ?? (_, __) async {},
        remove: _removeClip,
        delete: _deleteClip,
      ),
    );
  }

  VoidCallback? _openMovieCallback(MediaClipDto clip) {
    final movieNumber = clip.movieNumber;
    if (movieNumber == null || movieNumber.isEmpty) {
      return null;
    }
    final onOpenMovie = widget.onOpenMovie;
    if (onOpenMovie == null) {
      return null;
    }
    return () => onOpenMovie(context, clip);
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
    // 切片自带 streamUrl，把当前列表交给连播页直接用，免其二次全量拉取。
    handoff.offerClips(
      collectionId: widget.collectionId,
      clips: state.clips,
    );
    handoff.offerMode(key: 'clip:${widget.collectionId}', mode: mode);
    if (_isMobile) {
      MobileClipCollectionPlayRouteData(
        collectionId: widget.collectionId,
        startIndex: index,
      ).push(context);
      return;
    }
    context.pushDesktopClipCollectionPlay(
      collectionId: widget.collectionId,
      startIndex: index,
    );
  }

  Future<void> _removeClip(MediaClipDto clip) async {
    final error = await ref
        .read(_providerRef.notifier)
        .removeClip(clip.clipId);
    if (!mounted) {
      return;
    }
    if (error == null) {
      // 合集封面 / 计数可能变化，广播给上层合集列表（首页横滑区、全部合集页）。
      _mutationBroadcaster.reportCollectionMembershipChanged(
        clipId: clip.clipId,
        collectionId: widget.collectionId,
      );
    }
    showToast(error ?? '已从合集移除');
  }

  /// 彻底删除切片本体（含文件，不可恢复，后端从所有合集级联移除）：先确认，再走
  /// notifier 乐观删除并广播 [ClipMutationEvents.reportDeleted]。与「移出合集」不同。
  Future<void> _deleteClip(MediaClipDto clip) async {
    final title = clip.displayTitle.trim();
    final label = title.isEmpty ? '该切片' : '“$title”';
    final confirmed = await _confirm(
      title: '删除切片',
      message: '确认删除$label？切片文件会被一并删除，该操作不可恢复。',
      confirmLabel: '删除',
      confirmKey: Key('${widget.keyPrefix}-delete-confirm-button'),
      drawerKey: _isMobile ? Key('${widget.keyPrefix}-delete-drawer') : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final error = await ref
        .read(_providerRef.notifier)
        .deleteClip(clip.clipId);
    if (!mounted) {
      return;
    }
    if (error == null) {
      _mutationBroadcaster.reportDeleted(clip.clipId);
    }
    showToast(error ?? '已删除切片');
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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final error = await ref
        .read(_providerRef.notifier)
        .reorder(oldIndex, newIndex);
    if (!mounted) {
      return;
    }
    if (error != null) {
      showToast(error);
      return;
    }
    // 重排可能换掉合集首图（封面取自首个切片）；广播给上层合集列表刷新封面。
    _mutationBroadcaster.reportCollectionMembershipChanged(
      collectionId: widget.collectionId,
    );
  }

  Future<void> _editCollection(BuildContext context) async {
    final collection = ref.read(_providerRef).value?.collection;
    if (collection == null) {
      return;
    }
    final onEditCollection = widget.onEditCollection;
    if (onEditCollection == null) {
      return;
    }
    final updated = await onEditCollection(context, collection);
    if (!mounted || updated == null) {
      return;
    }
    ref.read(_providerRef.notifier).applyCollectionMeta(updated);
    // 合集名称变化，广播给上层合集列表刷新卡片标题。
    _mutationBroadcaster.reportCollectionMembershipChanged(
      collectionId: widget.collectionId,
    );
    showToast('已保存');
  }

  Future<void> _addClips(BuildContext context) async {
    final currentClips =
        ref.read(_providerRef).value?.clips ?? const <MediaClipDto>[];
    final onAddClips = widget.onAddClips;
    if (onAddClips == null) {
      return;
    }
    await onAddClips(
      context,
      currentClips.map((clip) => clip.clipId).toSet(),
    );
    if (!mounted) {
      return;
    }
    // 选择器内可能增删了成员，回来统一刷新切片列表与计数。
    await ref.read(_providerRef.notifier).refresh();
    if (!mounted) {
      return;
    }
    // 成员 / 封面 / 计数可能变化，广播给上层合集列表。
    _mutationBroadcaster.reportCollectionMembershipChanged(
      collectionId: widget.collectionId,
    );
  }

  // --------------------------------------------------------- 选择 / 批量

  List<MediaClipDto> _selectedClips(ClipCollectionDetailState state) =>
      state.clips.where((c) => isSelected(c.clipId)).toList(growable: false);

  void _showBatchToast(String verb, BatchRunResult<dynamic> result) {
    if (result.failed.isEmpty) {
      showToast('已$verb ${result.succeeded.length} 个切片');
    } else {
      showToast(
        '$verb完成：成功 ${result.succeeded.length} 个，失败 ${result.failed.length} 个',
      );
    }
  }

  /// 「加入其它合集」批量动作是**移动端独有**（桌面切片合集没有此入口），
  /// 按 `useMobileSelectionLayout` 门控展示；行为两端保持原样。
  Future<void> _batchAddToOtherCollection(
    ClipCollectionDetailState state,
  ) async {
    final selected = _selectedClips(state);
    if (selected.isEmpty) {
      return;
    }
    final ClipCollectionDto? target = await showPickClipCollectionDialog(
      context,
      presentation: PickClipCollectionPresentation.bottomDrawer,
      excludedCollectionId: widget.collectionId,
    );
    if (!mounted || target == null) {
      return;
    }
    final api = ref.read(clipCollectionsApiProvider);
    final result = await runBatchOperation<MediaClipDto>(
      context,
      title: '正在加入「${target.name}」',
      items: selected,
      action:
          (clip) => api.addClipToCollection(
            collectionId: target.id,
            clipId: clip.clipId,
          ),
    );
    if (!mounted) {
      return;
    }
    final broadcaster = _mutationBroadcaster;
    for (final clip in result.succeeded) {
      broadcaster.reportCollectionMembershipChanged(
        clipId: clip.clipId,
        collectionId: target.id,
      );
    }
    _showBatchToast('加入合集', result);
    exitSelection();
  }

  Future<void> _batchRemove(ClipCollectionDetailState state) async {
    final selected = _selectedClips(state);
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await _confirm(
      title: '从合集移除',
      message: '确认从合集移除选中的 ${selected.length} 个切片？切片本身不会被删除。',
      confirmLabel: _isMobile ? '移除' : '确认',
      confirmKey: _batchConfirmKey('remove'),
      drawerKey: _isMobile ? Key('${widget.keyPrefix}-batch-remove-drawer') : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final notifier = ref.read(_providerRef.notifier);
    final result = await runBatchOperation<MediaClipDto>(
      context,
      title: '正在从合集移除',
      items: selected,
      action: (clip) async {
        final error = await notifier.removeClip(clip.clipId);
        if (error != null) {
          throw Exception(error);
        }
      },
    );
    if (!mounted) {
      return;
    }
    // 重新拉取合集与切片，校准本页头部计数与列表。
    await notifier.refresh();
    if (!mounted) {
      return;
    }
    // 合集封面 / 计数可能变化，广播给上层合集列表。
    final broadcaster = _mutationBroadcaster;
    for (final clip in result.succeeded) {
      broadcaster.reportCollectionMembershipChanged(
        clipId: clip.clipId,
        collectionId: widget.collectionId,
      );
    }
    _showBatchToast('移除', result);
    exitSelection();
  }

  Future<void> _batchDelete(ClipCollectionDetailState state) async {
    final selected = _selectedClips(state);
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await _confirm(
      title: '删除切片',
      message: '确认删除选中的 ${selected.length} 个切片？切片文件会被一并删除，该操作不可恢复。',
      confirmLabel: _isMobile ? '删除' : '确认',
      confirmKey: _batchConfirmKey('delete'),
      drawerKey: _isMobile ? Key('${widget.keyPrefix}-batch-delete-drawer') : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final clipsApi = ref.read(clipsApiProvider);
    final result = await runBatchOperation<MediaClipDto>(
      context,
      title: '正在删除切片',
      items: selected,
      action: (clip) => clipsApi.deleteClip(clipId: clip.clipId),
    );
    if (!mounted) {
      return;
    }
    // 重新拉取合集与切片，校准本页头部计数与列表。
    await ref.read(_providerRef.notifier).refresh();
    if (!mounted) {
      return;
    }
    // 广播删除信号：「全部切片」网格精准移除 + 上层合集列表刷新。
    final broadcaster = _mutationBroadcaster;
    for (final clip in result.succeeded) {
      broadcaster.reportDeleted(clip.clipId);
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
