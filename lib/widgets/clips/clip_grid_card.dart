import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

enum _ClipCardAction { openMovie, addToCollection, rename, delete }

/// 切片网格卡：封面 + 底部一条信息条（左番号、右时长）。
/// 左键 / 单击播放，右键 / 长按弹菜单（影片 / 加入合集 / 重命名 / 删除），
/// 与「时刻」卡的右键菜单形式对齐。
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

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: Material(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        child: InkWell(
          key: Key('clip-grid-card-tap-${clip.clipId}'),
          borderRadius: context.appRadius.mdBorder,
          onTap: onPlay,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: context.appRadius.mdBorder,
              boxShadow: context.appShadows.card,
            ),
            child: ClipRRect(
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final navigator = Navigator.of(context);
    final overlay =
        navigator.overlay!.context.findRenderObject() as RenderBox;
    final localPosition = overlay.globalToLocal(globalPosition);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(localPosition, localPosition),
      Offset.zero & overlay.size,
    );
    final openMovie = onOpenMovie;
    final action = await showMenu<_ClipCardAction>(
      context: context,
      position: position,
      useRootNavigator: false,
      items: <PopupMenuEntry<_ClipCardAction>>[
        if (openMovie != null)
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
    );
    if (action == null) {
      return;
    }
    switch (action) {
      case _ClipCardAction.openMovie:
        openMovie?.call();
      case _ClipCardAction.addToCollection:
        onAddToCollection();
      case _ClipCardAction.rename:
        onRename();
      case _ClipCardAction.delete:
        onDelete();
    }
  }
}
