import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_collection_chips.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/domain/media/media_duration_badge.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_action_grid.dart';

/// 桌面版视频操作弹窗：点击视频卡后弹出居中对话框。
///
/// 结构与移动端 `showMobileVideoActionsSheet` 完全对齐（封面预览 + 标题 +
/// 「所属合集」分组 + 横排操作按钮），只把外壳换成 `AppDesktopDialog`。动作
/// 按调用方回调是否非空动态显隐：「全部视频」用 加入合集 / 删除，「合集详情」
/// 用 移出合集 / 删除。点选后先关闭弹窗再执行（加入合集 / 删除会再弹各自
/// 的弹窗，避免弹窗叠弹窗）。
///
/// [collections] / [onCollectionTap] 用于渲染「所属合集」分组：为空时整段
/// 隐去；点某个 chip 后先关闭本弹窗再调回调（跳转由调用方决定）。合集详情页
/// 调用时应过滤掉当前合集 id，避免"跳回自己"。
Future<void> showDesktopVideoActionsDialog(
  BuildContext context, {
  required VideoItemListItemDto video,
  required VoidCallback onPlay,
  VoidCallback? onAddToCollection,
  VoidCallback? onDelete,
  VoidCallback? onRemoveFromCollection,
  List<VideoCollectionRef> collections = const <VideoCollectionRef>[],
  ValueChanged<VideoCollectionRef>? onCollectionTap,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AppDesktopDialog(
        dialogKey: const Key('desktop-video-actions-dialog'),
        width: dialogContext.appLayoutTokens.dialogWidthMd,
        child: DesktopVideoActionsDialogBody(
          video: video,
          onPlay: onPlay,
          onAddToCollection: onAddToCollection,
          onDelete: onDelete,
          onRemoveFromCollection: onRemoveFromCollection,
          collections: collections,
          onCollectionTap: onCollectionTap,
        ),
      );
    },
  );
}

class DesktopVideoActionsDialogBody extends StatelessWidget {
  const DesktopVideoActionsDialogBody({
    super.key,
    required this.video,
    required this.onPlay,
    this.onAddToCollection,
    this.onDelete,
    this.onRemoveFromCollection,
    this.collections = const <VideoCollectionRef>[],
    this.onCollectionTap,
  });

  final VideoItemListItemDto video;
  final VoidCallback onPlay;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onDelete;
  final VoidCallback? onRemoveFromCollection;

  final List<VideoCollectionRef> collections;
  final ValueChanged<VideoCollectionRef>? onCollectionTap;

  // 先关闭弹窗再执行动作，避免播放弹窗 / 加入合集 / 删除确认叠在本弹窗上。
  void _run(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  List<MediaPreviewActionItem> _buildActions(BuildContext context) {
    return <MediaPreviewActionItem>[
      MediaPreviewActionItem(
        key: const Key('desktop-video-action-play'),
        label: '播放',
        icon: Icons.play_circle_outline_rounded,
        onTap: video.canPlay ? () => _run(context, onPlay) : null,
      ),
      if (onAddToCollection != null)
        MediaPreviewActionItem(
          key: const Key('desktop-video-action-add-to-collection'),
          label: '加入合集',
          icon: Icons.playlist_add_rounded,
          onTap: () => _run(context, onAddToCollection!),
        ),
      if (onRemoveFromCollection != null)
        MediaPreviewActionItem(
          key: const Key('desktop-video-action-remove-from-collection'),
          label: '移出合集',
          icon: Icons.playlist_remove_rounded,
          onTap: () => _run(context, onRemoveFromCollection!),
        ),
      if (onDelete != null)
        MediaPreviewActionItem(
          key: const Key('desktop-video-action-delete'),
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
    final tokens = context.appComponentTokens;
    final coverUrl = video.coverImage?.bestAvailableUrl;

    // 关闭按钮浮在弹窗右上角(约 40px)，标题右侧留同宽度空隙避免遮挡。
    final closeGutter = tokens.iconSizeLg + spacing.md;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: MediaDurationBadge(seconds: video.durationSeconds),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.md),
        Padding(
          padding: EdgeInsets.only(right: closeGutter),
          child: Text(
            video.preferredTitle,
            key: const Key('desktop-video-actions-title'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
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
        if (collections.isNotEmpty && onCollectionTap != null) ...[
          SizedBox(height: spacing.lg),
          Text(
            '所属合集',
            key: const Key('desktop-video-actions-collections-title'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.medium,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.sm),
          VideoCollectionChips(
            collections: collections,
            onCollectionTap: (ref) {
              // 先关闭本弹窗再跳转，避免跳转后本弹窗仍覆盖新页面。
              Navigator.of(context).pop();
              onCollectionTap!(ref);
            },
          ),
        ],
        SizedBox(height: spacing.lg),
        MediaPreviewActionGrid(
          gridKey: const Key('desktop-video-actions-grid'),
          layout: MediaPreviewActionGridLayout.horizontalScroll,
          spacing: spacing.sm,
          tileWidth: 72,
          actions: _buildActions(context),
        ),
      ],
    );
  }
}
