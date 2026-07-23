import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_clips_to_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/controllers/clip_collection_detail_controller.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/controllers/clip_mutation_change_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/operations/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_player_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_member_views.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_playback_mode.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';

/// 合集详情的切片排布方式：纵向列表（可拖序）或网格（侧重浏览）。
enum _ClipLayout { list, grid }

/// 切片合集详情页：有序切片列表，支持拖序、移除、添加切片、改名与播放。
class DesktopClipCollectionDetailPage extends StatefulWidget {
  const DesktopClipCollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  final int collectionId;

  @override
  State<DesktopClipCollectionDetailPage> createState() =>
      _DesktopClipCollectionDetailPageState();
}

class _DesktopClipCollectionDetailPageState
    extends State<DesktopClipCollectionDetailPage>
    with MultiSelectStateMixin<DesktopClipCollectionDetailPage, int> {
  late final ClipCollectionDetailController _controller;
  late final ClipMutationChangeNotifier _mutationNotifier;
  int? _hoveredClipId;
  _ClipLayout _layout = _ClipLayout.grid;

  @override
  void initState() {
    super.initState();
    _mutationNotifier = context.read<ClipMutationChangeNotifier>();
    _controller = ClipCollectionDetailController(
      collectionId: widget.collectionId,
      api: context.read<ClipCollectionsApi>(),
      clipsApi: context.read<ClipsApi>(),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          _layout == _ClipLayout.list ? _ClipLayout.grid : _ClipLayout.list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageRefreshScope(
      onRefresh: _controller.refresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.isLoading && _controller.collection == null) {
            return const Center(
              child: SizedBox(
                key: Key('clip-collection-detail-loading'),
                width: 40,
                height: 40,
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (_controller.errorMessage != null &&
              _controller.collection == null) {
            return AppEmptyState(message: _controller.errorMessage!);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              SizedBox(height: context.appSpacing.md),
              Expanded(child: _buildClips(context)),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final collection = _controller.collection;
    final count = collection?.clipCount ?? _controller.clips.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          collection?.name ?? '合集',
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
                      // 选择模式下隐藏「编辑合集」，避免与多选交互混淆。
                      if (!selectionMode) ...[
                        SizedBox(width: context.appSpacing.xs),
                        AppIconButton(
                          key: const Key('clip-collection-rename-button'),
                          tooltip: '编辑合集',
                          onPressed:
                              collection == null ? null : _editCollection,
                          icon: Icon(
                            Icons.edit_outlined,
                            size: context.appComponentTokens.iconSizeSm,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: context.appSpacing.xs),
                  Text(
                    '$count 个切片',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                ],
              ),
            ),
            // 选择模式下隐藏「选择 / 视图切换 / 添加切片 / 播放」，仅保留标题与下方选择栏。
            if (!selectionMode) ...[
              if (_controller.clips.isNotEmpty) ...[
                AppTextButton(
                  key: const Key('clip-collection-enter-selection-button'),
                  label: '选择',
                  size: AppTextButtonSize.small,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  onPressed: enterSelection,
                ),
                SizedBox(width: context.appSpacing.sm),
                AppIconButton(
                  key: const Key('clip-collection-layout-toggle'),
                  tooltip: _layout == _ClipLayout.list ? '网格视图' : '列表视图',
                  onPressed: _toggleLayout,
                  icon: Icon(
                    _layout == _ClipLayout.list
                        ? Icons.grid_view_rounded
                        : Icons.view_agenda_outlined,
                    size: context.appComponentTokens.iconSizeSm,
                  ),
                ),
                SizedBox(width: context.appSpacing.sm),
              ],
              AppTextButton(
                key: const Key('clip-collection-add-clips-button'),
                label: '添加切片',
                size: AppTextButtonSize.small,
                onPressed: _addClips,
              ),
              // 无切片时无可播放内容，直接隐藏播放按钮。
              if (_controller.clips.isNotEmpty) ...[
                SizedBox(width: context.appSpacing.sm),
                AppTextButton(
                  key: const Key('clip-collection-play-all-button'),
                  label: '播放',
                  size: AppTextButtonSize.small,
                  onPressed: () => _playFrom(0),
                ),
              ],
            ],
          ],
        ),
        if (selectionMode) ...[
          SizedBox(height: context.appSpacing.md),
          _buildSelectionBar(context),
        ],
      ],
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    final clipIds = _controller.clips.map((clip) => clip.clipId);
    final allSelected = isAllSelected(clipIds);
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
          key: const Key('clip-collection-select-all-button'),
          label: allSelected ? '取消全选' : '全选',
          size: AppTextButtonSize.small,
          onPressed: () => toggleSelectAll(clipIds),
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('clip-collection-batch-remove-button'),
          label: '从合集移除',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: hasSelection ? _batchRemove : null,
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('clip-collection-batch-delete-button'),
          label: '删除切片',
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: hasSelection ? _batchDelete : null,
        ),
        SizedBox(width: spacing.sm),
        AppTextButton(
          key: const Key('clip-collection-exit-selection-button'),
          label: '取消',
          size: AppTextButtonSize.small,
          onPressed: exitSelection,
        ),
      ],
    );
  }

  Widget _buildClips(BuildContext context) {
    if (_controller.clips.isEmpty) {
      return const AppEmptyState(message: '合集还没有切片，去「全部切片」里加入吧');
    }
    return _layout == _ClipLayout.grid
        ? _buildGrid(context)
        : _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final clips = _controller.clips;
    // 选择模式下禁用拖拽重排，退化为普通列表，避免与多选交互冲突。
    final canReorder = !selectionMode;

    CollectionMemberRow buildRow(int index) {
      final clip = clips[index];
      return CollectionMemberRow(
        index: index,
        coverUrl: clip.coverImage?.bestAvailableUrl,
        coverWidth: 120,
        coverAspectRatio: 16 / 9,
        title: clip.displayTitle,
        subtitle: clip.metaLine,
        isHovered: _hoveredClipId == clip.clipId,
        onTap: selectionMode
            ? () => toggleSelect(clip.clipId)
            : () => _playClipSingle(clip),
        menuKey: Key('clip-collection-menu-${clip.clipId}'),
        dragHandleKey: Key('clip-reorder-handle-${clip.clipId}'),
        onOpenSource: _openMovieCallback(clip),
        openSourceLabel: '影片',
        onRemove: () => _removeClip(clip),
        onDelete: () => _deleteClip(clip),
        deleteLabel: '删除切片',
        reorderable: canReorder,
        selectionMode: selectionMode,
        isSelected: isSelected(clip.clipId),
      );
    }

    // 选择模式下退化为普通列表（无拖拽手柄）。
    if (!canReorder) {
      return ListView.separated(
        key: const Key('clip-collection-detail-list'),
        itemCount: clips.length,
        separatorBuilder: (context, _) =>
            SizedBox(height: context.appSpacing.sm),
        itemBuilder: (context, index) => buildRow(index),
      );
    }

    return ReorderableListView.builder(
      key: const Key('clip-collection-detail-list'),
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
            child: buildRow(index),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context) {
    final clips = _controller.clips;
    final spacing = context.appSpacing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _resolveColumnCount(constraints.maxWidth, spacing.md);
        return GridView.builder(
          key: const Key('clip-collection-detail-grid'),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing.md,
            crossAxisSpacing: spacing.md,
            childAspectRatio: 16 / 9,
          ),
          itemCount: clips.length,
          itemBuilder: (context, index) {
            final clip = clips[index];
            final number =
                clip.movieNumber?.isNotEmpty == true
                    ? clip.movieNumber!
                    : '无番号';
            final duration = formatMediaTimecode(clip.durationSeconds);
            return CollectionMemberCard(
              key: ValueKey<int>(clip.clipId),
              coverUrl: clip.coverImage?.bestAvailableUrl,
              coverAspectRatio: 16 / 9,
              title: number,
              subtitle: duration,
              clipOverlay: true,
              onTap: selectionMode
                  ? () => toggleSelect(clip.clipId)
                  : () => _playClipSingle(clip),
              menuKey: Key('clip-collection-grid-menu-${clip.clipId}'),
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
      },
    );
  }

  int _resolveColumnCount(double width, double spacing) {
    final columns = ((width + spacing) / (280 + spacing)).floor();
    return math.max(2, math.min(4, columns));
  }

  Future<void> _playFrom(int index) async {
    // 进入连播前先询问形态（列表连播 / 合并播放）；外部点关闭返回 null → 放弃跳转。
    final mode = await showCollectionPlaybackModePicker(context: context);
    if (mode == null || !mounted) {
      return;
    }
    final handoff = context.read<CollectionPlaybackHandoff>();
    // 切片自带 streamUrl，把当前列表交给连播页直接用，免其二次全量拉取。
    handoff.offerClips(
      collectionId: widget.collectionId,
      clips: _controller.clips,
    );
    handoff.offerMode(key: 'clip:${widget.collectionId}', mode: mode);
    context.pushDesktopClipCollectionPlay(
      collectionId: widget.collectionId,
      startIndex: index,
    );
  }

  /// 点单条卡片：只播这一个切片（对齐桌面切片主页 `_playClip`），不进合集连播。
  /// 头部「播放」按钮仍走 [_playFrom] 走整张合集连播。
  void _playClipSingle(MediaClipDto clip) {
    showClipPlayerDialog(
      context,
      streamUrl: clip.streamUrl,
      title: clip.title,
    );
  }

  /// 切片有番号时返回跳转来源影片详情的回调，否则为 `null`（菜单项隐藏）。
  VoidCallback? _openMovieCallback(MediaClipDto clip) {
    final movieNumber = clip.movieNumber;
    if (movieNumber == null || movieNumber.isEmpty) {
      return null;
    }
    return () => context.pushDesktopMovieDetail(movieNumber: movieNumber);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final error = await _controller.reorder(oldIndex, newIndex);
    if (!mounted) {
      return;
    }
    if (error != null) {
      showToast(error);
      return;
    }
    // 重排可能换掉合集首图（封面取自首个切片）；广播给上层合集列表刷新封面。
    _mutationNotifier.reportCollectionMembershipChanged(
      collectionId: widget.collectionId,
    );
  }

  Future<void> _removeClip(MediaClipDto clip) async {
    final error = await _controller.removeClip(clip.clipId);
    if (!mounted) {
      return;
    }
    if (error == null) {
      // 合集封面 / 计数可能变化，广播给上层合集列表（首页横滑区、全部合集页）。
      _mutationNotifier.reportCollectionMembershipChanged(
        clipId: clip.clipId,
        collectionId: widget.collectionId,
      );
    }
    showToast(error ?? '已从合集移除');
  }

  /// 彻底删除切片本体（含文件，不可恢复，后端从所有合集级联移除）：先确认，再走
  /// 控制器乐观删除并广播 [ClipMutationChangeNotifier.reportDeleted]，让「全部切片」
  /// 网格精准移除、上层合集列表刷新封面 / 计数。与「移出合集」不同。
  Future<void> _deleteClip(MediaClipDto clip) async {
    final title = clip.displayTitle.trim();
    final label = title.isEmpty ? '该切片' : '“$title”';
    final ok = await showAppConfirmDialog(
      context,
      title: '删除切片',
      message: '确认删除$label？切片文件会被一并删除，该操作不可恢复。',
      danger: true,
      confirmLabel: '删除',
      confirmKey: const Key('clip-collection-delete-confirm-button'),
    );
    if (!mounted || !ok) {
      return;
    }
    final error = await _controller.deleteClip(clip.clipId);
    if (!mounted) {
      return;
    }
    if (error == null) {
      _mutationNotifier.reportDeleted(clip.clipId);
    }
    showToast(error ?? '已删除切片');
  }

  List<MediaClipDto> _selectedClips() => _controller.clips
      .where((clip) => isSelected(clip.clipId))
      .toList(growable: false);

  void _showBatchToast(String verb, BatchRunResult<dynamic> result) {
    if (result.failed.isEmpty) {
      showToast('已$verb ${result.succeeded.length} 个切片');
    } else {
      showToast(
        '$verb完成：成功 ${result.succeeded.length} 个，失败 ${result.failed.length} 个',
      );
    }
  }

  Future<bool> _confirmBatch(String title, String message) async {
    return showAppConfirmDialog(
      context,
      title: title,
      message: message,
      danger: true,
      confirmKey: const Key('clip-collection-batch-confirm-button'),
    );
  }

  Future<void> _batchRemove() async {
    final selected = _selectedClips();
    if (selected.isEmpty) {
      return;
    }
    final ok = await _confirmBatch(
      '从合集移除',
      '确认从合集移除选中的 ${selected.length} 个切片？切片本身不会被删除。',
    );
    if (!mounted || !ok) {
      return;
    }
    final result = await runBatchOperation<MediaClipDto>(
      context,
      title: '正在从合集移除',
      items: selected,
      action: (clip) async {
        final error = await _controller.removeClip(clip.clipId);
        if (error != null) {
          throw Exception(error);
        }
      },
    );
    if (!mounted) {
      return;
    }
    // 重新拉取合集与切片，校准本页头部计数与列表。
    await _controller.refresh();
    if (!mounted) {
      return;
    }
    // 合集封面 / 计数可能变化，广播给上层合集列表。
    for (final clip in result.succeeded) {
      _mutationNotifier.reportCollectionMembershipChanged(
        clipId: clip.clipId,
        collectionId: widget.collectionId,
      );
    }
    _showBatchToast('移除', result);
    exitSelection();
  }

  Future<void> _batchDelete() async {
    final selected = _selectedClips();
    if (selected.isEmpty) {
      return;
    }
    final ok = await _confirmBatch(
      '删除切片',
      '确认删除选中的 ${selected.length} 个切片？切片文件会被一并删除，该操作不可恢复。',
    );
    if (!mounted || !ok) {
      return;
    }
    final clipsApi = context.read<ClipsApi>();
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
    await _controller.refresh();
    if (!mounted) {
      return;
    }
    // 广播删除信号：「全部切片」网格精准移除 + 上层合集列表刷新。
    for (final clip in result.succeeded) {
      _mutationNotifier.reportDeleted(clip.clipId);
    }
    _showBatchToast('删除', result);
    exitSelection();
  }

  Future<void> _editCollection() async {
    final collection = _controller.collection;
    if (collection == null) {
      return;
    }
    final updated = await showEditClipCollectionDialog(
      context,
      collection: collection,
    );
    if (!mounted || updated == null) {
      return;
    }
    _controller.applyCollectionMeta(updated);
    // 合集名称变化，广播给上层合集列表刷新卡片标题。
    _mutationNotifier.reportCollectionMembershipChanged(
      collectionId: widget.collectionId,
    );
    showToast('已保存');
  }

  Future<void> _addClips() async {
    await showAddClipsToCollectionDialog(
      context,
      collectionId: widget.collectionId,
      memberClipIds: _controller.clips.map((clip) => clip.clipId).toSet(),
    );
    if (!mounted) {
      return;
    }
    // 选择器内可能增删了成员，回来统一刷新切片列表与计数。
    await _controller.refresh();
    if (!mounted) {
      return;
    }
    // 成员 / 封面 / 计数可能变化，广播给上层合集列表。
    _mutationNotifier.reportCollectionMembershipChanged(
      collectionId: widget.collectionId,
    );
  }
}
