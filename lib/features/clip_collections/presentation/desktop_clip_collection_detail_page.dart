import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/add_clips_to_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/clip_collection_detail_controller.dart';
import 'package:sakuramedia/features/clip_collections/presentation/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clip_mutation_change_notifier.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/clips/clip_cover_overlays.dart';
import 'package:sakuramedia/widgets/collections/collection_member_views.dart';

/// 合集详情的切片排布方式：纵向列表（可拖序）或网格（侧重浏览）。
enum _ClipLayout { list, grid }

/// 切片合集详情页：有序切片列表，支持拖序、移除、添加切片、改名与播放。
class DesktopClipCollectionDetailPage extends StatefulWidget {
  const DesktopClipCollectionDetailPage({super.key, required this.collectionId});

  final int collectionId;

  @override
  State<DesktopClipCollectionDetailPage> createState() =>
      _DesktopClipCollectionDetailPageState();
}

class _DesktopClipCollectionDetailPageState
    extends State<DesktopClipCollectionDetailPage> {
  late final ClipCollectionDetailController _controller;
  late final ClipMutationChangeNotifier _mutationNotifier;
  int? _hoveredClipId;
  _ClipLayout _layout = _ClipLayout.list;

  @override
  void initState() {
    super.initState();
    _mutationNotifier = context.read<ClipMutationChangeNotifier>();
    _controller = ClipCollectionDetailController(
      collectionId: widget.collectionId,
      api: context.read<ClipCollectionsApi>(),
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
    return ColoredBox(
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    final collection = _controller.collection;
    final count = collection?.clipCount ?? _controller.clips.length;
    return Row(
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
                  SizedBox(width: context.appSpacing.xs),
                  AppIconButton(
                    key: const Key('clip-collection-rename-button'),
                    tooltip: '编辑合集',
                    onPressed: collection == null ? null : _editCollection,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: context.appComponentTokens.iconSizeSm,
                    ),
                  ),
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
        // 空合集没有可排布的内容，隐藏视图切换。
        if (_controller.clips.isNotEmpty) ...[
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
          emphasis: AppTextButtonEmphasis.accent,
          onPressed: _addClips,
        ),
        // 无切片时无可播放内容，直接隐藏播放按钮。
        if (_controller.clips.isNotEmpty) ...[
          SizedBox(width: context.appSpacing.sm),
          AppTextButton(
            key: const Key('clip-collection-play-all-button'),
            label: '播放',
            size: AppTextButtonSize.small,
            emphasis: AppTextButtonEmphasis.accent,
            onPressed: () => _playFrom(0),
          ),
        ],
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
    return ReorderableListView.builder(
      key: const Key('clip-collection-detail-list'),
      buildDefaultDragHandles: false,
      itemCount: clips.length,
      onReorder: _onReorder,
      // 默认 proxyDecorator 会给拖动项叠加带阴影的 Material（主题色偏粉），
      // 这里换成无阴影透明包装，去掉拖动时的粉色投影。
      proxyDecorator: (child, index, animation) => Material(
        type: MaterialType.transparency,
        child: child,
      ),
      itemBuilder: (context, index) {
        final clip = clips[index];
        final title = clip.title.trim();
        final metaParts = <String>[
          if (clip.movieNumber != null && clip.movieNumber!.isNotEmpty)
            clip.movieNumber!
          else
            '无番号',
          formatMediaTimecode(clip.durationSeconds),
          if (clip.fileSizeBytes > 0) formatFileSize(clip.fileSizeBytes),
        ];
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
            child: CollectionMemberRow(
              index: index,
              coverUrl: clip.coverImage?.bestAvailableUrl,
              coverWidth: 120,
              coverAspectRatio: 16 / 9,
              title: title.isEmpty ? '未命名切片' : title,
              subtitle: metaParts.join(' · '),
              isHovered: _hoveredClipId == clip.clipId,
              onTap: () => _playFrom(index),
              menuKey: Key('clip-collection-menu-${clip.clipId}'),
              dragHandleKey: Key('clip-reorder-handle-${clip.clipId}'),
              onOpenSource: _openMovieCallback(clip),
              openSourceLabel: '影片',
              onRemove: () => _removeClip(clip),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context) {
    final clips = _controller.clips;
    final spacing = context.appSpacing;
    return GridView.builder(
      key: const Key('clip-collection-detail-grid'),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: spacing.md,
        crossAxisSpacing: spacing.md,
        childAspectRatio: 1.15,
      ),
      itemCount: clips.length,
      itemBuilder: (context, index) {
        final clip = clips[index];
        final title = clip.title.trim();
        final number =
            clip.movieNumber?.isNotEmpty == true ? clip.movieNumber! : '无番号';
        // 时长已在封面徽标显示，下方元信息保留番号与大小，和列表视图信息对齐。
        final subtitle = clip.fileSizeBytes > 0
            ? '$number · ${formatFileSize(clip.fileSizeBytes)}'
            : number;
        return CollectionMemberCard(
          key: ValueKey<int>(clip.clipId),
          coverUrl: clip.coverImage?.bestAvailableUrl,
          coverAspectRatio: 16 / 9,
          title: title.isEmpty ? '未命名切片' : title,
          subtitle: subtitle,
          onTap: () => _playFrom(index),
          menuKey: Key('clip-collection-grid-menu-${clip.clipId}'),
          onOpenSource: _openMovieCallback(clip),
          openSourceLabel: '影片',
          onRemove: () => _removeClip(clip),
          coverBadge: ClipDurationBadge(seconds: clip.durationSeconds),
        );
      },
    );
  }

  void _playFrom(int index) {
    context.pushDesktopClipCollectionPlay(
      collectionId: widget.collectionId,
      startIndex: index,
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
      memberClipIds:
          _controller.clips.map((clip) => clip.clipId).toSet(),
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
