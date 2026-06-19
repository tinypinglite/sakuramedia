import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/clips/clip_cover_overlays.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

enum _ClipCardAction { openMovie, addToCollection, rename, delete }

/// 切片网格卡：封面上压底部信息条（左番号、右时长），与时刻卡风格统一。
class ClipGridCard extends StatelessWidget {
  const ClipGridCard({
    super.key,
    required this.clip,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
    required this.onAddToCollection,
    this.onOpenMovie,
  });

  final MediaClipDto clip;
  final VoidCallback onPlay;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAddToCollection;

  /// 跳转到切片来源影片详情；切片无番号时为 `null`，对应菜单项隐藏。
  final VoidCallback? onOpenMovie;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final coverUrl = clip.coverImage?.bestAvailableUrl;
    final number = clip.movieNumber?.isNotEmpty == true
        ? clip.movieNumber!
        : '无番号';
    final duration = formatMediaTimecode(clip.durationSeconds);
    final labelTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.onMedia,
    );

    return Material(
      color: colors.surfaceCard,
      borderRadius: context.appRadius.lgBorder,
      child: InkWell(
        key: Key('clip-grid-card-tap-${clip.clipId}'),
        borderRadius: context.appRadius.lgBorder,
        onTap: onPlay,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: context.appRadius.lgBorder,
            boxShadow: context.appShadows.card,
          ),
          child: ClipRRect(
            borderRadius: context.appRadius.lgBorder,
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null && coverUrl.isNotEmpty)
                    MaskedImage(url: coverUrl, fit: BoxFit.cover)
                  else
                    ColoredBox(color: colors.surfaceMuted),
                  const ClipPlayOverlay(),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.44),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.md,
                          vertical: spacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                number,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: labelTextStyle,
                              ),
                            ),
                            SizedBox(width: spacing.sm),
                            Text(duration, style: labelTextStyle),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: spacing.xs,
                    top: spacing.xs,
                    child: _ClipMenu(
                      menuKey: Key('clip-grid-menu-${clip.clipId}'),
                      onOpenMovie: onOpenMovie,
                      onAddToCollection: onAddToCollection,
                      onRename: onRename,
                      onDelete: onDelete,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClipMenu extends StatelessWidget {
  const _ClipMenu({
    required this.menuKey,
    required this.onAddToCollection,
    required this.onRename,
    required this.onDelete,
    this.onOpenMovie,
  });

  final Key menuKey;
  final VoidCallback? onOpenMovie;
  final VoidCallback onAddToCollection;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: PopupMenuButton<_ClipCardAction>(
          key: menuKey,
          tooltip: '更多',
          padding: EdgeInsets.zero,
          iconSize: 16,
          position: PopupMenuPosition.under,
          icon: const Icon(
            Icons.more_horiz_rounded,
            color: Colors.white,
            size: 16,
          ),
          onSelected: (action) {
          switch (action) {
            case _ClipCardAction.openMovie:
              onOpenMovie?.call();
            case _ClipCardAction.addToCollection:
              onAddToCollection();
            case _ClipCardAction.rename:
              onRename();
            case _ClipCardAction.delete:
              onDelete();
          }
        },
        itemBuilder:
            (context) => <PopupMenuEntry<_ClipCardAction>>[
              if (onOpenMovie != null)
                const PopupMenuItem<_ClipCardAction>(
                  value: _ClipCardAction.openMovie,
                  child: Text('影片'),
                ),
              const PopupMenuItem<_ClipCardAction>(
                value: _ClipCardAction.addToCollection,
                child: Text('加入合集'),
              ),
              const PopupMenuItem<_ClipCardAction>(
                value: _ClipCardAction.rename,
                child: Text('重命名'),
              ),
              const PopupMenuItem<_ClipCardAction>(
                value: _ClipCardAction.delete,
                child: Text('删除'),
              ),
            ],
          ),
        ),
    );
  }
}
