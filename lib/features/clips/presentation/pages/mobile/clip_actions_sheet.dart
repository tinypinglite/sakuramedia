import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/clips/clip_cover_overlays.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/media/media_preview_action_grid.dart';

/// 移动端切片操作抽屉：点击切片卡 / 行任意位置后从底部弹出。
///
/// 仿「时刻」预览弹窗的结构（封面预览 + 横向操作格），但更轻——切片的封面 / 番号 /
/// 时长 / 大小本地都有，无需额外请求。动作按调用方传入的回调动态展示：
/// 「全部切片」用 加入合集 / 重命名 / 删除，「合集详情」用 移出合集。点选后先关闭
/// 抽屉再执行（重命名 / 加入合集 / 删除会弹各自的抽屉或确认，避免抽屉叠抽屉）。
Future<void> showMobileClipActionsSheet(
  BuildContext context, {
  required MediaClipDto clip,
  required VoidCallback onPlay,
  VoidCallback? onOpenMovie,
  VoidCallback? onAddToCollection,
  VoidCallback? onRename,
  VoidCallback? onDelete,
  VoidCallback? onRemoveFromCollection,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-clip-actions-sheet'),
    maxHeightFactor: 0.62,
    builder:
        (_) => MobileClipActionsSheet(
          clip: clip,
          onPlay: onPlay,
          onOpenMovie: onOpenMovie,
          onAddToCollection: onAddToCollection,
          onRename: onRename,
          onDelete: onDelete,
          onRemoveFromCollection: onRemoveFromCollection,
        ),
  );
}

class MobileClipActionsSheet extends StatelessWidget {
  const MobileClipActionsSheet({
    super.key,
    required this.clip,
    required this.onPlay,
    this.onOpenMovie,
    this.onAddToCollection,
    this.onRename,
    this.onDelete,
    this.onRemoveFromCollection,
  });

  final MediaClipDto clip;
  final VoidCallback onPlay;
  final VoidCallback? onOpenMovie;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onRemoveFromCollection;

  // 先关闭抽屉再执行动作，避免抽屉叠抽屉。
  void _run(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  List<MediaPreviewActionItem> _buildActions(BuildContext context) {
    return <MediaPreviewActionItem>[
      MediaPreviewActionItem(
        key: const Key('mobile-clip-action-play'),
        label: '播放',
        icon: Icons.play_circle_outline_rounded,
        onTap: () => _run(context, onPlay),
      ),
      if (onOpenMovie != null)
        MediaPreviewActionItem(
          key: const Key('mobile-clip-action-movie'),
          label: '影片',
          icon: Icons.movie_outlined,
          onTap: () => _run(context, onOpenMovie!),
        ),
      if (onAddToCollection != null)
        MediaPreviewActionItem(
          key: const Key('mobile-clip-action-add-to-collection'),
          label: '加入合集',
          icon: Icons.playlist_add_rounded,
          onTap: () => _run(context, onAddToCollection!),
        ),
      if (onRename != null)
        MediaPreviewActionItem(
          key: const Key('mobile-clip-action-rename'),
          label: '重命名',
          icon: Icons.edit_outlined,
          onTap: () => _run(context, onRename!),
        ),
      if (onRemoveFromCollection != null)
        MediaPreviewActionItem(
          key: const Key('mobile-clip-action-remove-from-collection'),
          label: '移出合集',
          icon: Icons.playlist_remove_rounded,
          onTap: () => _run(context, onRemoveFromCollection!),
        ),
      if (onDelete != null)
        MediaPreviewActionItem(
          key: const Key('mobile-clip-action-delete'),
          label: '删除',
          icon: Icons.delete_outline_rounded,
          onTap: () => _run(context, onDelete!),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final coverUrl = clip.coverImage?.bestAvailableUrl;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: context.appRadius.mdBorder,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null && coverUrl.isNotEmpty)
                    MaskedImage(url: coverUrl, fit: BoxFit.cover)
                  else
                    ColoredBox(color: colors.surfaceMuted),
                  Positioned(
                    right: spacing.xs,
                    bottom: spacing.xs,
                    child: ClipDurationBadge(seconds: clip.durationSeconds),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            clip.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            clip.metaLine,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.lg),
          MediaPreviewActionGrid(
            gridKey: const Key('mobile-clip-actions-grid'),
            layout: MediaPreviewActionGridLayout.horizontalScroll,
            spacing: spacing.xs,
            tileWidth: 64,
            actions: _buildActions(context),
          ),
        ],
      ),
    );
  }
}
