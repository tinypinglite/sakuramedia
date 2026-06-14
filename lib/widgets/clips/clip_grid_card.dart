import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/clips/clip_cover_overlays.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

enum _ClipCardAction { openMovie, addToCollection, rename, delete }

/// 切片网格卡：静态封面 + 标题 + 元信息。点击播放，右上角菜单可跳转影片 / 加入合集 / 改名 / 删除。
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
    final title = clip.title.trim();

    return Material(
      color: colors.surfaceCard,
      borderRadius: context.appRadius.mdBorder,
      child: InkWell(
        key: Key('clip-grid-card-tap-${clip.clipId}'),
        borderRadius: context.appRadius.mdBorder,
        onTap: onPlay,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(context.appRadius.md),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (coverUrl != null && coverUrl.isNotEmpty)
                        MaskedImage(url: coverUrl, fit: BoxFit.cover)
                      else
                        ColoredBox(color: colors.surfaceMuted),
                      const ClipPlayOverlay(),
                      Positioned(
                        right: spacing.xs,
                        bottom: spacing.xs,
                        child: ClipDurationBadge(seconds: clip.durationSeconds),
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
              Padding(
                padding: EdgeInsets.all(spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      clip.movieNumber?.isNotEmpty == true
                          ? clip.movieNumber!
                          : '无番号',
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
            ],
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
