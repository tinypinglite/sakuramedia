import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/add_clips_to_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/clip_collection_detail_controller.dart';
import 'package:sakuramedia/features/clip_collections/presentation/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/clips_api.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clip_mutation_change_notifier.dart';
import 'package:sakuramedia/features/clips/presentation/mobile_clip_actions_sheet.dart';
import 'package:sakuramedia/features/clips/presentation/mobile_clip_confirm_drawer.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/clips/clip_cover_card.dart';
import 'package:sakuramedia/widgets/collections/collection_member_views.dart';

/// 合集详情的切片排布方式：纵向列表或网格（侧重浏览）。
enum _ClipLayout { list, grid }

/// 移动端切片合集详情页：有序切片列表 / 网格 + 添加切片 / 改名 / 移除 / 连播。
///
/// 列表复用桌面端同款行物料 [CollectionMemberRow]（关闭悬停与拖序）；网格用仿「时刻」
/// 版式的封面卡 [ClipCoverCard]（底部一条：左番号、右时长），与「全部切片」网格同款。
/// 交互对齐桌面：列表/网格切换、底部抽屉添加切片。点击切片走动作抽屉。
class MobileClipCollectionDetailPage extends StatefulWidget {
  const MobileClipCollectionDetailPage({super.key, required this.collectionId});

  final int collectionId;

  @override
  State<MobileClipCollectionDetailPage> createState() =>
      _MobileClipCollectionDetailPageState();
}

class _MobileClipCollectionDetailPageState
    extends State<MobileClipCollectionDetailPage> {
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
            return const Center(
              child: SizedBox(
                key: Key('mobile-clip-collection-detail-loading'),
                width: 32,
                height: 32,
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    final spacing = context.appSpacing;
    final collection = _controller.collection;
    final count = collection?.clipCount ?? _controller.clips.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.md, spacing.md, 0),
      child: Row(
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
              ],
            ),
          ),
          // 空合集没有可排布内容，隐藏视图切换。
          if (_controller.clips.isNotEmpty) ...[
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
            SizedBox(width: spacing.xs),
          ],
          AppTextButton(
            key: const Key('mobile-clip-collection-add-clips-button'),
            label: '添加',
            size: AppTextButtonSize.small,
            emphasis: AppTextButtonEmphasis.accent,
            onPressed: _addClips,
          ),
          if (_controller.clips.isNotEmpty) ...[
            SizedBox(width: spacing.xs),
            AppTextButton(
              key: const Key('mobile-clip-collection-play-all-button'),
              label: '播放',
              size: AppTextButtonSize.small,
              emphasis: AppTextButtonEmphasis.accent,
              onPressed: () => _playFrom(0),
            ),
          ],
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
      padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.lg),
      itemCount: clips.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final clip = clips[index];
        return CollectionMemberRow(
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
          onTap: () => _openClipSheet(index, clip),
          menuKey: Key('mobile-clip-collection-menu-${clip.clipId}'),
          dragHandleKey: Key('mobile-clip-reorder-handle-${clip.clipId}'),
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
          padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.lg),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing.md,
            crossAxisSpacing: spacing.md,
            childAspectRatio: 16 / 9,
          ),
          itemCount: clips.length,
          itemBuilder: (context, index) {
            final clip = clips[index];
            return ClipCoverCard(
              key: ValueKey<int>(clip.clipId),
              clip: clip,
              onTap: () => _openClipSheet(index, clip),
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
      onPlay: () => _playFrom(index),
      onOpenMovie: _openMovieCallback(clip),
      onRemoveFromCollection: () => _removeClip(clip),
      onDelete: () => _deleteClip(clip),
    );
  }

  void _playFrom(int index) {
    // 切片自带 streamUrl，把当前列表交给连播页直接用，免其二次全量拉取。
    context.read<CollectionPlaybackHandoff>().offerClips(
      collectionId: widget.collectionId,
      clips: _controller.clips,
    );
    MobileClipCollectionPlayRouteData(
      collectionId: widget.collectionId,
      startIndex: index,
    ).push(context);
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
}
