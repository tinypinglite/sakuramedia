import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

/// 非 JAV 视频列表卡片：封面 + 标题，右上角标媒体数、左上角可播放标记。
///
/// 与 `MovieSummaryCard` 平行，但去掉订阅/热度/番号等 JAV 概念，主键为 [VideoItemListItemDto.id]。
class VideoSummaryCard extends StatelessWidget {
  const VideoSummaryCard({
    super.key,
    required this.video,
    this.onTap,
    this.onRequestMenu,
    this.showStatusBadges = true,
  });

  final VideoItemListItemDto video;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onRequestMenu;
  final bool showStatusBadges;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final spacing = context.appSpacing;

    final card = Container(
      key: Key('video-summary-card-${video.id}'),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: componentTokens.movieCardAspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _VideoCover(videoId: video.id, coverImage: video.coverImage),
            const _VideoCardBottomShade(),
            Positioned(
              left: spacing.md,
              right: spacing.md,
              bottom: spacing.md,
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
          ],
        ),
      ),
    );

    final interactiveCard = onTap == null && onRequestMenu == null
        ? card
        : MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onLongPressStart: onRequestMenu == null
                  ? null
                  : (details) => onRequestMenu!(details.globalPosition),
              onSecondaryTapDown: onRequestMenu == null
                  ? null
                  : (details) => onRequestMenu!(details.globalPosition),
              child: card,
            ),
          );

    if (!showStatusBadges) {
      return interactiveCard;
    }

    return Stack(
      children: [
        interactiveCard,
        if (video.mediaCount > 0)
          Positioned(
            top: spacing.xs,
            right: spacing.xs,
            child: Container(
              key: Key('video-summary-card-media-count-${video.id}'),
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm,
                vertical: spacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.mediaOverlayStrong,
                borderRadius: context.appRadius.pillBorder,
                border: Border.all(
                  color: colors.borderSubtle.withValues(alpha: 0.42),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.video_library_rounded,
                    size: componentTokens.iconSizeXs,
                    color: context.appTextPalette.onMedia,
                  ),
                  SizedBox(width: spacing.xs),
                  Text(
                    '${video.mediaCount}',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s10,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.onMedia,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (video.canPlay)
          Positioned(
            top: spacing.xs,
            left: spacing.xs,
            child: Container(
              key: Key('video-summary-card-status-playable-${video.id}'),
              width: componentTokens.movieCardStatusBadgeSize,
              height: componentTokens.movieCardStatusBadgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.movieCardPlayableBadgeBackground,
                borderRadius: context.appRadius.pillBorder,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: componentTokens.iconSizeXl,
                color: context.appTextPalette.onMedia,
              ),
            ),
          ),
      ],
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
      return MaskedImage(url: coverUrl, fit: BoxFit.contain);
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
