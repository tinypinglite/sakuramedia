import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 小图放大到整条横幅即可得到柔和模糊，避免运行时 ImageFilter。
const int _playlistBannerBackgroundDecodeWidth = 32;

class PlaylistBannerCard extends StatelessWidget {
  const PlaylistBannerCard({
    super.key,
    required this.title,
    this.coverImageUrl,
    this.onTap,
  });

  final String title;
  final String? coverImageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final radius = context.appRadius.lgBorder;
    final Widget background;
    if (coverImageUrl != null && coverImageUrl!.trim().isNotEmpty) {
      background = MaskedImage(
        url: coverImageUrl!,
        fit: BoxFit.cover,
        memCacheWidth: _playlistBannerBackgroundDecodeWidth,
        filterQuality: FilterQuality.high,
        animateReveal: false,
      );
    } else {
      background = DecoratedBox(
        key: const Key('playlist-banner-placeholder'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.movieDetailHeroBackgroundStart,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.72),
              colors.movieDetailHeroBackgroundEnd,
            ],
          ),
        ),
      );
    }

    final card = Container(
      height: context.appComponentTokens.playlistBannerHeight,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      // 骨架态整条横幅收敛成一块 shimmer 圆角块（非骨架态原样渲染）。
      child: AppSkeletonUnite(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: background),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.mediaOverlaySoft.withValues(alpha: 0.18),
                      colors.mediaOverlayStrong.withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.xl),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s20,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.onMedia,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: radius,
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}

/// 播放列表横幅骨架，保持真实横幅的高度、圆角和阴影，供列表与详情首屏共用。
