import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/clips/clip_cover_overlays.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/media/media_preview_action_grid.dart';

/// 移动端视频操作抽屉：点击视频卡后从底部弹出。
///
/// 结构对齐切片操作抽屉（封面预览 + 横向操作格）。动作按调用方传入的回调动态展示：
/// 「全部视频」用 加入合集 / 删除，「合集详情」用 移出合集。点选后先关闭抽屉再执行
/// （加入合集 / 删除会弹各自的抽屉或确认，避免抽屉叠抽屉）。
Future<void> showMobileVideoActionsSheet(
  BuildContext context, {
  required VideoItemListItemDto video,
  required VoidCallback onPlay,
  VoidCallback? onAddToCollection,
  VoidCallback? onDelete,
  VoidCallback? onRemoveFromCollection,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-video-actions-sheet'),
    maxHeightFactor: 0.62,
    builder: (_) => MobileVideoActionsSheet(
      video: video,
      onPlay: onPlay,
      onAddToCollection: onAddToCollection,
      onDelete: onDelete,
      onRemoveFromCollection: onRemoveFromCollection,
    ),
  );
}

class MobileVideoActionsSheet extends StatelessWidget {
  const MobileVideoActionsSheet({
    super.key,
    required this.video,
    required this.onPlay,
    this.onAddToCollection,
    this.onDelete,
    this.onRemoveFromCollection,
  });

  final VideoItemListItemDto video;
  final VoidCallback onPlay;
  final VoidCallback? onAddToCollection;
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
        key: const Key('mobile-video-action-play'),
        label: '播放',
        icon: Icons.play_circle_outline_rounded,
        onTap: video.canPlay ? () => _run(context, onPlay) : null,
      ),
      if (onAddToCollection != null)
        MediaPreviewActionItem(
          key: const Key('mobile-video-action-add-to-collection'),
          label: '加入合集',
          icon: Icons.playlist_add_rounded,
          onTap: () => _run(context, onAddToCollection!),
        ),
      if (onRemoveFromCollection != null)
        MediaPreviewActionItem(
          key: const Key('mobile-video-action-remove-from-collection'),
          label: '移出合集',
          icon: Icons.playlist_remove_rounded,
          onTap: () => _run(context, onRemoveFromCollection!),
        ),
      if (onDelete != null)
        MediaPreviewActionItem(
          key: const Key('mobile-video-action-delete'),
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
    final coverUrl = video.coverImage?.bestAvailableUrl;

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
                  ColoredBox(
                    color: colors.surfaceMuted,
                    child: coverUrl != null && coverUrl.isNotEmpty
                        ? MaskedImage(url: coverUrl, fit: BoxFit.contain)
                        : null,
                  ),
                  if (video.durationSeconds > 0)
                    Positioned(
                      right: spacing.xs,
                      bottom: spacing.xs,
                      child: ClipDurationBadge(seconds: video.durationSeconds),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            video.preferredTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          if (video.mediaCount > 1) ...[
            SizedBox(height: spacing.xs),
            Text(
              '共 ${video.mediaCount} 个媒体',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ],
          SizedBox(height: spacing.lg),
          MediaPreviewActionGrid(
            gridKey: const Key('mobile-video-actions-grid'),
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
