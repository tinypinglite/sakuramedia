import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

class MovieDetailHeroCard extends StatelessWidget {
  const MovieDetailHeroCard({
    super.key,
    required this.height,
    required this.mainImageKey,
    required this.mainImageUrl,
    required this.thinCoverUrl,
    required this.canPlay,
    required this.isSubscribed,
    required this.isCollection,
    required this.onPlayTap,
    this.onSubscriptionTap,
    this.isSubscriptionUpdating = false,
  });

  final double height;
  final String mainImageKey;
  final String? mainImageUrl;
  final String? thinCoverUrl;
  final bool canPlay;
  final bool isSubscribed;
  final bool isCollection;
  final VoidCallback? onPlayTap;
  final VoidCallback? onSubscriptionTap;
  final bool isSubscriptionUpdating;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.movieDetailHeroBackgroundStart,
            colors.movieDetailHeroBackgroundEnd,
          ],
        ),
        borderRadius: context.appRadius.lgBorder,
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: _HeroImageFrame(
                      imageKey: mainImageKey,
                      imageUrl: mainImageUrl,
                    ),
                  ),
                ),
                if (thinCoverUrl != null && thinCoverUrl!.isNotEmpty) ...[
                  SizedBox(width: spacing.lg),
                  SizedBox(
                    width: tokens.movieDetailThinCoverWidth,
                    child: ClipRRect(
                      borderRadius: context.appRadius.mdBorder,
                      child: AspectRatio(
                        aspectRatio: 0.68,
                        child: MaskedImage(
                          url: thinCoverUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: spacing.lg,
            left: spacing.lg,
            child: Wrap(
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              children: [
                _HeroSubscriptionBadge(
                  isSubscribed: isSubscribed,
                  isUpdating: isSubscriptionUpdating,
                  onTap: onSubscriptionTap,
                ),
                if (canPlay)
                  const _HeroBadge(
                    label: '可播放',
                    backgroundColorToken: _HeroBadgeColorToken.playable,
                  ),
                if (isCollection) const _HeroBadge(label: '合集'),
              ],
            ),
          ),
          if (onPlayTap != null)
            Positioned.fill(
              child: Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('movie-detail-hero-play-button'),
                      customBorder: const CircleBorder(),
                      onTap: onPlayTap,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colors.movieDetailEmptyBackground.withValues(
                            alpha: 0.28,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: colors.textOnMedia,
                          size: tokens.iconSize4xl,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroImageFrame extends StatelessWidget {
  const _HeroImageFrame({required this.imageKey, required this.imageUrl});

  final String imageKey;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final content =
        imageUrl == null || imageUrl!.isEmpty
            ? DecoratedBox(
              decoration: BoxDecoration(
                color: context.appColors.movieDetailEmptyBackground,
                borderRadius: context.appRadius.mdBorder,
              ),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: context.appComponentTokens.iconSize3xl,
                  color: context.appColors.textMuted,
                ),
              ),
            )
            : ClipRRect(
              borderRadius: context.appRadius.mdBorder,
              child: MaskedImage(url: imageUrl!, fit: BoxFit.fitHeight),
            );

    return SizedBox(
      key: Key('movie-detail-main-image-$imageKey'),
      width: double.infinity,
      height: double.infinity,
      child: content,
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    this.backgroundColorToken = _HeroBadgeColorToken.defaultMuted,
  });

  final String label;
  final _HeroBadgeColorToken backgroundColorToken;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.sm,
        vertical: context.appSpacing.xs,
      ),
      decoration: BoxDecoration(
        color:
            backgroundColorToken == _HeroBadgeColorToken.playable
                ? colors.movieDetailPlayableBadgeBackground
                : colors.movieDetailEmptyBackground.withValues(alpha: 0.9),
        borderRadius: context.appRadius.xsBorder,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.appColors.textOnMedia,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeroSubscriptionBadge extends StatelessWidget {
  const _HeroSubscriptionBadge({
    required this.isSubscribed,
    required this.isUpdating,
    required this.onTap,
  });

  final bool isSubscribed;
  final bool isUpdating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tokens = context.appComponentTokens;

    final badge = SizedBox(
      key: const Key('movie-detail-hero-subscription-icon'),
      width: tokens.movieCardStatusBadgeSize,
      height: tokens.movieCardStatusBadgeSize,
      child: Center(
        child:
            isUpdating
                ? SizedBox(
                  width: tokens.movieCardLoaderSize,
                  height: tokens.movieCardLoaderSize,
                  child: CircularProgressIndicator(
                    key: const Key('movie-detail-hero-subscription-loading'),
                    strokeWidth: tokens.movieCardLoaderStrokeWidth,
                    color: colors.subscriptionHeartIcon,
                  ),
                )
                : Icon(
                  isSubscribed
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: tokens.iconSizeXl,
                  color: colors.subscriptionHeartIcon,
                ),
      ),
    );

    if (onTap == null || isUpdating) {
      return badge;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: badge,
      ),
    );
  }
}

enum _HeroBadgeColorToken { defaultMuted, playable }
