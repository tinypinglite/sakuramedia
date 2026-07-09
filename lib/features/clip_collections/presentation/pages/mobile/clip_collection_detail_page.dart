import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_clips_to_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/controllers/clip_collection_detail_controller.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/pick_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/controllers/clip_mutation_change_notifier.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_actions_sheet.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_confirm_drawer.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_player_page.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/widgets/media_player/collection_playback_mode.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/operations/batch/batch_progress_dialog.dart';
import 'package:sakuramedia/widgets/clips/clip_cover_card.dart';
import 'package:sakuramedia/widgets/collections/collection_member_views.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';

/// 合集详情的切片排布方式：纵向列表或网格（侧重浏览）。
enum _ClipLayout { list, grid }

/// 移动端切片合集详情页：有序切片列表 / 网格 + 添加切片 / 改名 / 移除 / 连播。
///
/// 列表复用桌面端同款行物料 [CollectionMemberRow]（关闭悬停与拖序）；网格用仿「时刻」
/// 版式的封面卡 [ClipCoverCard]（底部一条：左番号、右时长），与「全部切片」网格同款。
/// 交互对齐桌面：列表/网格切换、底部抽屉添加切片。点击切片走动作抽屉。
///
/// 长按切片进入多选模式：上方「选择栏」（取消 / 已选 N 个 / 全选），下方「批量栏」
/// （加入合集 / 移除 / 删除），与移动 PornBox / 视频合集详情页对齐。
class MobileClipCollectionDetailPage extends StatefulWidget {
  const MobileClipCollectionDetailPage({super.key, required this.collectionId});

  final int collectionId;

  @override
  State<MobileClipCollectionDetailPage> createState() =>
      _MobileClipCollectionDetailPageState();
}

class _MobileClipCollectionDetailPageState
    extends State<MobileClipCollectionDetailPage>
    with MultiSelectStateMixin<MobileClipCollectionDetailPage, int> {
  late final ClipCollectionDetailController _controller;
  late final ClipMutationChangeNotifier _mutationNotifier;
  _ClipLayout _layout = _ClipLayout.grid;

  void _toggleLayout() {
    setState(() {
      _layout =
          _layout == _ClipLayout.list ? _ClipLayout.grid : _ClipLayout.list;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.collection == null) {
            return const AppMobileSkeletonList(
              key: Key('mobile-clip-collection-detail-loading'),
            );
          }
          if (_controller.errorMessage != null &&
              _controller.collection == null) {
            return AppEmptyState(message: _controller.errorMessage!);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode)
                _buildSelectionBar(context)
              else
                _buildHeader(context),
              SizedBox(height: context.appSpacing.md),
              Expanded(child: _buildClips(context)),
              if (selectionMode) _buildBatchBar(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final spacing = context.appSpacing;
    final collection = _controller.collection;
    final count = collection?.clipCount ?? _controller.clips.length;
    final hasClips = _controller.clips.isNotEmpty;
    return Padding(
      // 横向缩进由 AppMobileSubpageShell 的 8px body padding 统一提供。
      padding: EdgeInsets.only(top: spacing.md),
      // 操作按钮（视图切换 / 选择 / 添加 / 播放）共四个，挤不进一行，故拆两行:
      // 第一行只放合集元信息（名称 + 编辑 + 切片数），第二行放操作按钮组。
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
              SizedBox(width: spacing.xs),
              AppIconButton(
                key: const Key('mobile-clip-collection-rename-button'),
                tooltip: '编辑合集',
                onPressed: collection == null ? null : _editCollection,
                icon: Icon(
                  Icons.edit_outlined,
                  size: context.appComponentTokens.iconSizeSm,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            '$count 个切片',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              // 视图切换在左侧，剩余按钮组靠右。
              if (hasClips)
                AppIconButton(
                  key: const Key('mobile-clip-collection-layout-toggle'),
                  tooltip: _layout == _ClipLayout.list ? '网格视图' : '列表视图',
                  onPressed: _toggleLayout,
                  icon: Icon(
                    _layout == _ClipLayout.list
                        ? Icons.grid_view_rounded
                        : Icons.view_agenda_outlined,
                    size: context.appComponentTokens.iconSizeSm,
                  ),
                ),
              const Spacer(),
              if (hasClips) ...[
                AppTextButton(
                  key: const Key(
                    'mobile-clip-collection-enter-selection-button',
                  ),
                  label: '选择',
                  size: AppTextButtonSize.small,
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  onPressed: enterSelection,
                ),
                SizedBox(width: spacing.xs),
              ],
              AppTextButton(
                key: const Key('mobile-clip-collection-add-clips-button'),
                label: '添加',
                size: AppTextButtonSize.small,
                onPressed: _addClips,
              ),
              if (hasClips) ...[
                SizedBox(width: spacing.xs),
                AppTextButton(
                  key: const Key('mobile-clip-collection-play-all-button'),
                  label: '播放',
                  size: AppTextButtonSize.small,
                  onPressed: () => _playFrom(0),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClips(BuildContext context) {
    if (_controller.clips.isEmpty) {
      return const AppEmptyState(message: '合集还没有切片，点右上角「添加」加入吧');
    }
    return _layout == _ClipLayout.grid
        ? _buildGrid(context)
        : _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final spacing = context.appSpacing;
    final clips = _controller.clips;
    return ListView.separated(
      key: const Key('mobile-clip-collection-detail-list'),
      // 横向缩进由 shell 提供，此处只补底部留白。
      padding: EdgeInsets.only(bottom: spacing.lg),
      itemCount: clips.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final clip = clips[index];
        return GestureDetector(
          onLongPress: selectionMode
              ? null
              : () {
                  enterSelection();
                  toggleSelect(clip.clipId);
                },
          child: CollectionMemberRow(
            key: ValueKey<int>(clip.clipId),
            index: index,
            coverUrl: clip.coverImage?.bestAvailableUrl,
            coverWidth: 120,
            coverAspectRatio: 16 / 9,
            title: clip.displayTitle,
            subtitle: clip.metaLine,
            // 移动端无悬停、不支持拖序，关闭手柄与 hover 显隐逻辑。
            isHovered: false,
            reorderable: false,
            selectionMode: selectionMode,
            isSelected: isSelected(clip.clipId),
            onTap: selectionMode
                ? () => toggleSelect(clip.clipId)
                : () => _openClipSheet(index, clip),
            menuKey: Key('mobile-clip-collection-menu-${clip.clipId}'),
            dragHandleKey: Key('mobile-clip-reorder-handle-${clip.clipId}'),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context) {
    final spacing = context.appSpacing;
    final clips = _controller.clips;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _resolveColumnCount(constraints.maxWidth, spacing.md);
        return GridView.builder(
          key: const Key('mobile-clip-collection-detail-grid'),
          // 横向缩进由 shell 提供，此处只补底部留白。
          padding: EdgeInsets.only(bottom: spacing.lg),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing.md,
            crossAxisSpacing: spacing.md,
            childAspectRatio: 16 / 9,
          ),
          itemCount: clips.length,
          itemBuilder: (context, index) {
            final clip = clips[index];
            return GestureDetector(
              onLongPress: selectionMode
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
                onTap: () => _openClipSheet(index, clip),
              ),
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

  void _openClipSheet(int index, MediaClipDto clip) {
    showMobileClipActionsSheet(
      context,
      clip: clip,
      onPlay: () => _playClipSingle(clip),
      onOpenMovie: _openMovieCallback(clip),
      onRemoveFromCollection: () => _removeClip(clip),
      onDelete: () => _deleteClip(clip),
    );
  }

  Future<void> _playFrom(int index) async {
    // 进入连播前先询问形态（列表连播 / 合并播放）；外部关闭返回 null → 放弃跳转。
    // 移动壳传 useBottomDrawer 走底部抽屉范式，对齐其它图片菜单两端。
    final mode = await showCollectionPlaybackModePicker(
      context: context,
      useBottomDrawer: true,
    );
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
    MobileClipCollectionPlayRouteData(
      collectionId: widget.collectionId,
      startIndex: index,
    ).push(context);
  }

  /// 动作抽屉「播放」：只播这一条切片（对齐移动切片主页 `_playClip`），不进合集连播。
  /// 头部「播放」按钮仍走 [_playFrom] 走整张合集连播。
  void _playClipSingle(MediaClipDto clip) {
    // 用根 Navigator 推全屏页，覆盖底部导航；切片自带 streamUrl 直接传入。
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => MobileClipPlayerPage(
          streamUrl: clip.streamUrl,
          title: clip.title,
        ),
      ),
    );
  }

  VoidCallback? _openMovieCallback(MediaClipDto clip) {
    final movieNumber = clip.movieNumber;
    if (movieNumber == null || movieNumber.isEmpty) {
      return null;
    }
    return () =>
        MobileMovieDetailRouteData(movieNumber: movieNumber).push(context);
  }

  Future<void> _editCollection() async {
    final collection = _controller.collection;
    if (collection == null) {
      return;
    }
    final updated = await showEditClipCollectionDialog(
      context,
      collection: collection,
      presentation: ClipCollectionEditPresentation.bottomDrawer,
    );
    if (!mounted || updated == null) {
      return;
    }
    _controller.applyCollectionMeta(updated);
    _mutationNotifier.reportCollectionMembershipChanged(
      collectionId: widget.collectionId,
    );
    showToast('已保存');
  }

  Future<void> _removeClip(MediaClipDto clip) async {
    final error = await _controller.removeClip(clip.clipId);
    if (!mounted) {
      return;
    }
    if (error == null) {
      _mutationNotifier.reportCollectionMembershipChanged(
        clipId: clip.clipId,
        collectionId: widget.collectionId,
      );
    }
    showToast(error ?? '已从合集移除');
  }

  /// 彻底删除切片本体（含文件，不可恢复）：先弹底部确认抽屉，再走控制器乐观删除并广播
  /// [ClipMutationChangeNotifier.reportDeleted]，与「全部切片」页的删除一致。
  Future<void> _deleteClip(MediaClipDto clip) async {
    final title = clip.displayTitle.trim();
    final label = title.isEmpty ? '该切片' : '“$title”';
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '删除切片',
      message: '确认删除$label？切片文件会被一并删除，该操作不可恢复。',
      confirmLabel: '删除',
      drawerKey: const Key('mobile-clip-collection-delete-drawer'),
      confirmButtonKey: const Key(
        'mobile-clip-collection-delete-confirm-button',
      ),
    );
    if (!mounted || confirmed != true) {
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

  Future<void> _addClips() async {
    await showAddClipsToCollectionDialog(
      context,
      collectionId: widget.collectionId,
      memberClipIds: _controller.clips.map((clip) => clip.clipId).toSet(),
      presentation: ClipCollectionEditPresentation.bottomDrawer,
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

  // --------------------------------------------------------- 选择 / 批量

  List<MediaClipDto> _selectedClips() => _controller.clips
      .where((c) => isSelected(c.clipId))
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

  Future<void> _batchAddToOtherCollection() async {
    final selected = _selectedClips();
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
    final api = context.read<ClipCollectionsApi>();
    final result = await runBatchOperation<MediaClipDto>(
      context,
      title: '正在加入「${target.name}」',
      items: selected,
      action: (clip) => api.addClipToCollection(
        collectionId: target.id,
        clipId: clip.clipId,
      ),
    );
    if (!mounted) {
      return;
    }
    for (final clip in result.succeeded) {
      _mutationNotifier.reportCollectionMembershipChanged(
        clipId: clip.clipId,
        collectionId: target.id,
      );
    }
    _showBatchToast('加入合集', result);
    exitSelection();
  }

  Future<void> _batchRemove() async {
    final selected = _selectedClips();
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '从合集移除',
      message: '确认从合集移除选中的 ${selected.length} 个切片？切片本身不会被删除。',
      confirmLabel: '移除',
      drawerKey: const Key('mobile-clip-collection-batch-remove-drawer'),
      confirmButtonKey: const Key(
        'mobile-clip-collection-batch-remove-confirm-button',
      ),
    );
    if (!mounted || confirmed != true) {
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
    await _controller.refresh();
    if (!mounted) {
      return;
    }
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
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '删除切片',
      message: '确认删除选中的 ${selected.length} 个切片？切片文件会被一并删除，该操作不可恢复。',
      confirmLabel: '删除',
      drawerKey: const Key('mobile-clip-collection-batch-delete-drawer'),
      confirmButtonKey: const Key(
        'mobile-clip-collection-batch-delete-confirm-button',
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    final api = context.read<ClipsApi>();
    final result = await runBatchOperation<MediaClipDto>(
      context,
      title: '正在删除切片',
      items: selected,
      action: (clip) => api.deleteClip(clipId: clip.clipId),
    );
    if (!mounted) {
      return;
    }
    await _controller.refresh();
    if (!mounted) {
      return;
    }
    for (final clip in result.succeeded) {
      _mutationNotifier.reportDeleted(clip.clipId);
    }
    _showBatchToast('删除', result);
    exitSelection();
  }

  Widget _buildSelectionBar(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final clipIds = _controller.clips.map((c) => c.clipId);
    final allSelected = isAllSelected(clipIds);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          AppTextButton(
            key: const Key(
              'mobile-clip-collection-exit-selection-button',
            ),
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
            key: const Key('mobile-clip-collection-select-all-button'),
            label: allSelected ? '取消全选' : '全选',
            size: AppTextButtonSize.small,
            isSelected: allSelected,
            onPressed: () => toggleSelectAll(clipIds),
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
                key: const Key(
                  'mobile-clip-collection-batch-add-collection-button',
                ),
                label: '加入合集',
                variant: AppButtonVariant.secondary,
                onPressed: hasSelection ? _batchAddToOtherCollection : null,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: AppButton(
                key: const Key(
                  'mobile-clip-collection-batch-remove-button',
                ),
                label: '移除',
                variant: AppButtonVariant.secondary,
                onPressed: hasSelection ? _batchRemove : null,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: AppButton(
                key: const Key(
                  'mobile-clip-collection-batch-delete-button',
                ),
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
