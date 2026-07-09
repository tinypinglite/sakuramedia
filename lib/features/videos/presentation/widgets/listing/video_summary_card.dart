import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 非 JAV 视频列表卡片：封面 + 标题，中部播放按钮，右键 / 长按弹菜单（加入合集 / 删除）。
///
/// 与 `MovieSummaryCard` 平行，但去掉订阅/热度/番号等 JAV 概念，主键为 [VideoItemListItemDto.id]。
class VideoSummaryCard extends StatelessWidget {
  const VideoSummaryCard({
    super.key,
    required this.video,
    this.onTap,
    this.onAddToCollection,
    this.onDelete,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  final VideoItemListItemDto video;

  /// 点击卡片（弹窗快速播放）。中部播放 icon 仅作视觉提示，点击落在整卡上同样触发。
  final VoidCallback? onTap;

  /// 右键 / 长按菜单的「加入合集」动作；与 [onDelete] 任一非空时启用菜单。
  final VoidCallback? onAddToCollection;

  /// 右键 / 长按菜单的「删除」动作。
  final VoidCallback? onDelete;

  /// 选择模式:整卡点击改为切换选中,隐藏播放浮层与右键菜单,叠加勾选标记。
  final bool selectionMode;

  /// 当前是否被选中（仅 [selectionMode] 下有意义）。
  final bool isSelected;

  /// 选择模式下切换选中态的回调，入参为切换后的目标值。
  final ValueChanged<bool>? onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    final borderColor =
        selectionMode && isSelected ? colors.selectionBorder : colors.borderSubtle;

    final card = Container(
      key: Key('video-summary-card-${video.id}'),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(
          color: borderColor,
          width: selectionMode && isSelected ? 2 : 1,
        ),
        boxShadow: context.appShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      // 卡片整体由瀑布流网格按封面真实比例分配高度，不再固定 AspectRatio。
      child: Stack(
        fit: StackFit.expand,
        children: [
          _VideoCover(videoId: video.id, coverImage: video.coverImage),
          const _VideoCardBottomShade(),
          // 选择模式：整卡点击切换选中；非选择模式：整卡点击播放（落在浮层之下，避免吃掉菜单点击）。
          if (selectionMode)
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: Key('video-summary-card-select-${video.id}'),
                  onTap: () => onSelectedChanged?.call(!isSelected),
                ),
              ),
            )
          else if (onTap != null)
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: Key('video-summary-card-tap-${video.id}'),
                  onTap: onTap,
                ),
              ),
            ),
          if (!selectionMode) const _PlayOverlay(),
          Positioned(
            left: spacing.md,
            right: spacing.md,
            bottom: spacing.md,
            child: IgnorePointer(
              child: Text(
                video.preferredTitle,
                key: Key('video-summary-card-title-${video.id}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.onMedia,
                ),
              ),
            ),
          ),
          if (selectionMode)
            Positioned(
              top: spacing.xs,
              left: spacing.xs,
              child: IgnorePointer(
                child: SelectionCheckBadge(isSelected: isSelected),
              ),
            ),
        ],
      ),
    );

    final hasMenuActions =
        !selectionMode && (onAddToCollection != null || onDelete != null);
    if (!hasMenuActions) {
      return card;
    }

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: card,
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
    final action = await showMenu<_VideoCardAction>(
      context: context,
      position: position,
      useRootNavigator: false,
      items: <PopupMenuEntry<_VideoCardAction>>[
        if (onAddToCollection != null)
          PopupMenuItem<_VideoCardAction>(
            value: _VideoCardAction.addToCollection,
            child: Text(
              '加入合集',
              style: resolveAppTextStyle(context, size: AppTextSize.s14),
            ),
          ),
        if (onDelete != null)
          PopupMenuItem<_VideoCardAction>(
            value: _VideoCardAction.delete,
            child: Text(
              '删除',
              style: resolveAppTextStyle(context, size: AppTextSize.s14),
            ),
          ),
      ],
    );
    if (action == null) {
      return;
    }
    switch (action) {
      case _VideoCardAction.addToCollection:
        onAddToCollection?.call();
      case _VideoCardAction.delete:
        onDelete?.call();
    }
  }
}

enum _VideoCardAction { addToCollection, delete }

class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white.withValues(alpha: 0.92),
          size: context.appComponentTokens.iconSize4xl,
        ),
      ),
    );
  }
}

class _VideoCover extends StatelessWidget {
  const _VideoCover({required this.videoId, required this.coverImage});

  final int videoId;
  final MovieImageDto? coverImage;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final coverUrl = coverImage?.bestAvailableUrl.trim();

    if (coverUrl != null && coverUrl.isNotEmpty) {
      // 瀑布流网格按 coverWidth/coverHeight 切 tile，cover 填满不再留底色；
      // 罕见极端比例（探测缺失走 16:9 fallback、与真实比例差距大）会少量裁切。
      return MaskedImage(url: coverUrl, fit: BoxFit.cover);
    }

    return DecoratedBox(
      key: Key('video-summary-card-placeholder-$videoId'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceMuted,
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.38),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.video_library_outlined,
          size: componentTokens.iconSize3xl,
          color: context.appTextPalette.muted,
        ),
      ),
    );
  }
}

class _VideoCardBottomShade extends StatelessWidget {
  const _VideoCardBottomShade();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.mediaOverlaySoft.withValues(alpha: 0),
            colors.mediaOverlaySoft,
            colors.mediaOverlayStrong,
          ],
          stops: const [0.45, 0.72, 1],
        ),
      ),
    );
  }
}
