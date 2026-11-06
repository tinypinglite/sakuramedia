import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_mask.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 低分辨率解码后再做高斯模糊：保留旧版柔和背景，同时避免高分辨率解码。
const int _playlistBannerBackgroundDecodeWidth = 128;
const double _playlistBannerBackgroundBlurSigma = 14;

final ui.ImageFilter _playlistBannerBackgroundBlur = ui.ImageFilter.blur(
  sigmaX: _playlistBannerBackgroundBlurSigma,
  sigmaY: _playlistBannerBackgroundBlurSigma,
);

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
      final image = MaskedImage(
        url: coverImageUrl!,
        fit: BoxFit.cover,
        memCacheWidth: _playlistBannerBackgroundDecodeWidth,
        filterQuality: FilterQuality.high,
        animateReveal: false,
      );
      background = AppImageMask.enabled
          ? image
          : ImageFiltered(
              imageFilter: _playlistBannerBackgroundBlur,
              child: image,
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

    return AppInteractiveSurface(
      onTap: onTap,
      focusRingRadius: radius,
      child: card,
    );
  }
}

/// 播放列表横幅骨架，保持真实横幅的高度、圆角和阴影，供列表与详情首屏共用。
