import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/media/images/app_cover_bottom_shade.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 非 JAV 视频列表卡片：封面 + 标题，中部播放按钮。
///
/// 加入合集 / 跳到合集 / 删除等动作走桌面动作弹窗（`showDesktopVideoActionsDialog`）
/// 或移动端 sheet（`showMobileVideoActionsSheet`）——由 onTap 回调统一承载，卡片
/// 本身不再挂右键 / 长按上下文菜单。
///
/// 与 `MovieSummaryCard` 平行，但去掉订阅/热度/番号等 JAV 概念，主键为 [VideoItemListItemDto.id]。
class VideoSummaryCard extends StatelessWidget {
  const VideoSummaryCard({
    super.key,
    required this.video,
    this.onTap,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  final VideoItemListItemDto video;

  /// 点击卡片：桌面走动作弹窗、移动走 sheet；两端弹窗内承载播放/加入合集/删除等。
  final VoidCallback? onTap;

  /// 选择模式:整卡点击改为切换选中,隐藏播放浮层,叠加勾选标记。
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
          const AppCoverBottomShade(),
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

    return card;
  }
}

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

