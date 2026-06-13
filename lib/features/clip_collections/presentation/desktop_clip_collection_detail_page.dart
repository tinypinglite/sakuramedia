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
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

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
  int? _hoveredClipId;

  @override
  void initState() {
    super.initState();
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
            child: _ClipRow(
              clip: clip,
              index: index,
              isHovered: _hoveredClipId == clip.clipId,
              onTap: () => _playFrom(index),
              onRemove: () => _removeClip(clip),
            ),
          ),
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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final error = await _controller.reorder(oldIndex, newIndex);
    if (!mounted || error == null) {
      return;
    }
    showToast(error);
  }

  Future<void> _removeClip(MediaClipDto clip) async {
    final error = await _controller.removeClip(clip.clipId);
    if (!mounted) {
      return;
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
  }
}

class _ClipRow extends StatelessWidget {
  const _ClipRow({
    required this.clip,
    required this.index,
    required this.isHovered,
    required this.onTap,
    required this.onRemove,
  });

  final MediaClipDto clip;
  final int index;
  final bool isHovered;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final coverUrl = clip.coverImage?.bestAvailableUrl;
    final title = clip.title.trim();
    final metaParts = <String>[
      if (clip.movieNumber != null && clip.movieNumber!.isNotEmpty)
        clip.movieNumber!
      else
        '无番号',
      formatMediaTimecode(clip.durationSeconds),
      if (clip.fileSizeBytes > 0) formatFileSize(clip.fileSizeBytes),
    ];

    return Material(
      color: colors.surfaceCard,
      borderRadius: context.appRadius.mdBorder,
      child: InkWell(
        borderRadius: context.appRadius.mdBorder,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(color: colors.borderSubtle),
          ),
          padding: EdgeInsets.all(spacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: context.appRadius.smBorder,
                child: SizedBox(
                  width: 120,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child:
                        coverUrl != null && coverUrl.isNotEmpty
                            ? MaskedImage(url: coverUrl, fit: BoxFit.cover)
                            : ColoredBox(color: colors.surfaceMuted),
                  ),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title.isEmpty ? '未命名切片' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      metaParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.sm),
              // 拖拽手柄：悬停时显现，参照「播放列表」页的右侧圆形手柄。
              Visibility(
                visible: isHovered,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: IgnorePointer(
                  ignoring: !isHovered,
                  child: ReorderableDragStartListener(
                    index: index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceCard.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(spacing.xs),
                          child: Icon(
                            Icons.unfold_more_rounded,
                            key: Key('clip-reorder-handle-${clip.clipId}'),
                            size: context.appComponentTokens.iconSizeMd,
                            color: context.appTextPalette.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              AppIconButton(
                key: Key('clip-collection-remove-${clip.clipId}'),
                tooltip: '移出合集',
                iconColor: context.appTextPalette.error,
                onPressed: onRemove,
                icon: Icon(
                  Icons.remove_circle_outline_rounded,
                  size: context.appComponentTokens.iconSizeSm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
