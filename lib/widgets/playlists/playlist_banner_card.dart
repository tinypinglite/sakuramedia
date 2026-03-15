import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

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
    final Widget blurredBackground;
    if (coverImageUrl != null && coverImageUrl!.trim().isNotEmpty) {
      blurredBackground = MaskedImage(url: coverImageUrl!, fit: BoxFit.cover);
    } else {
      blurredBackground = DecoratedBox(
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
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: blurredBackground,
            ),
          ),
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textOnMedia,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
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
          borderRadius: context.appRadius.lgBorder,
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}
