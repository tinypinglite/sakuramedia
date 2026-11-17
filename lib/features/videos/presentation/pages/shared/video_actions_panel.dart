import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/video_display_title.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_collection_chips.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/domain/media/media_action_preview_header.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_action_grid.dart';

/// 视频操作面板共享主体：封面、标题、所属合集和动作区。
///
/// 桌面用居中 dialog，移动用底部 drawer；平台差异只保留在动作排列、
/// 标题字号和封面播放键上。入口壳 `showVideoActions` 传入 `mobile`。
class VideoActionsPanel extends StatelessWidget {
  const VideoActionsPanel({
    super.key,
    required this.mobile,
    required this.video,
    required this.onPlay,
    this.onThumbnails,
    this.onAddToCollection,
    this.onDelete,
    this.onRemoveFromCollection,
    this.collections = const <VideoCollectionRef>[],
    this.onCollectionTap,
  });

  final bool mobile;
  final VideoItemListItemDto video;
  final VoidCallback onPlay;
  final VoidCallback? onThumbnails;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onDelete;
  final VoidCallback? onRemoveFromCollection;
  final List<VideoCollectionRef> collections;
  final ValueChanged<VideoCollectionRef>? onCollectionTap;

  String get _keyPrefix => mobile ? 'mobile-video' : 'desktop-video';

  // 先关闭弹层再执行动作，避免播放弹窗 / 加入合集 / 删除确认叠在本层上。
  void _run(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  List<MediaPreviewActionItem> _buildSecondaryActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <MediaPreviewActionItem>[
      if (onThumbnails != null)
        MediaPreviewActionItem(
          key: Key('$_keyPrefix-action-thumbnails'),
          label: l10n.videoThumbnails,
          icon: Icons.photo_library_outlined,
          onTap: () => _run(context, onThumbnails!),
        ),
      if (onAddToCollection != null)
        MediaPreviewActionItem(
          key: Key('$_keyPrefix-action-add-to-collection'),
          label: l10n.videoAddToCollection,
          icon: Icons.playlist_add_rounded,
          onTap: () => _run(context, onAddToCollection!),
        ),
      if (onRemoveFromCollection != null)
        MediaPreviewActionItem(
          key: Key('$_keyPrefix-action-remove-from-collection'),
          label: l10n.videoRemoveFromCollection,
          icon: Icons.playlist_remove_rounded,
          onTap: () => _run(context, onRemoveFromCollection!),
        ),
      if (onDelete != null)
        MediaPreviewActionItem(
          key: Key('$_keyPrefix-action-delete'),
          label: l10n.commonDelete,
          icon: Icons.delete_outline_rounded,
          onTap: () => _run(context, onDelete!),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final l10n = AppLocalizations.of(context);
    final coverUrl = video.coverImage?.origin;
    final closeGutter = mobile ? 0.0 : tokens.iconSizeLg + spacing.md;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaActionPreviewHeader(
          coverUrl: coverUrl,
          coverFit: BoxFit.contain,
          durationSeconds: video.durationSeconds,
          onPlay: !mobile && video.canPlay ? () => _run(context, onPlay) : null,
          title: video.displayTitle(l10n),
          titleKey: Key('$_keyPrefix-actions-title'),
          titleSize: mobile ? AppTextSize.s18 : AppTextSize.s16,
          rightPadding: closeGutter,
        ),
        if (video.mediaCount > 1) ...[
          SizedBox(height: spacing.xs),
          Text(
            l10n.videoMediaCount(video.mediaCount),
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
            l10n.videoBelongsToCollections,
            key: Key('$_keyPrefix-actions-collections-title'),
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
              Navigator.of(context).pop();
              onCollectionTap!(ref);
            },
          ),
        ],
        if (mobile) ...[
          SizedBox(height: spacing.md),
          AppButton(
            key: const Key('mobile-video-action-play'),
            label: l10n.videoPlay,
            variant: AppButtonVariant.primary,
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: video.canPlay ? () => _run(context, onPlay) : null,
          ),
        ],
        SizedBox(height: spacing.lg),
        MediaPreviewActionGrid(
          gridKey: Key('$_keyPrefix-actions-grid'),
          layout: mobile
              ? MediaPreviewActionGridLayout.wrap
              : MediaPreviewActionGridLayout.horizontalScroll,
          spacing: spacing.sm,
          tileWidth: mobile ? 92 : 72,
          actions: <MediaPreviewActionItem>[
            if (!mobile)
              MediaPreviewActionItem(
                key: const Key('desktop-video-action-play'),
                label: l10n.videoPlay,
                icon: Icons.play_circle_outline_rounded,
                onTap: video.canPlay ? () => _run(context, onPlay) : null,
              ),
            ..._buildSecondaryActions(context),
          ],
        ),
      ],
    );

    if (!mobile) {
      return content;
    }
    return SingleChildScrollView(child: content);
  }
}
