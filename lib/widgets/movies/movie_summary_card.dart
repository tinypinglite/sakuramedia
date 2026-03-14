import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

class MovieSummaryCard extends StatelessWidget {
  const MovieSummaryCard({
    super.key,
    required this.movie,
    this.showStatusBadges = true,
    this.onTap,
    this.onSubscriptionTap,
    this.isSubscriptionUpdating = false,
  });

  final MovieListItemDto movie;
  final bool showStatusBadges;
  final VoidCallback? onTap;
  final VoidCallback? onSubscriptionTap;
  final bool isSubscriptionUpdating;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final spacing = context.appSpacing;

    final card = Container(
      key: Key('movie-summary-card-${movie.movieNumber}'),
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
            _MovieCover(
              movieNumber: movie.movieNumber,
              imageUrl: movie.coverImage?.bestAvailableUrl,
            ),
            const _MovieCardBottomShade(),
            Positioned(
              left: context.appSpacing.md,
              right: context.appSpacing.md,
              bottom: context.appSpacing.md,
              child: Text(
                movie.movieNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textOnMedia,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final tappableCard =
        onTap == null
            ? card
            : MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(onTap: onTap, child: card),
            );

    if (!showStatusBadges) {
      return tappableCard;
    }

    return Stack(
      children: [
        tappableCard,
        Positioned(
          top: spacing.sm,
          left: spacing.sm,
          child: Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: [
              _SubscriptionBadge(
                key: Key(
                  'movie-summary-card-subscription-${movie.movieNumber}',
                ),
                loadingKey: Key(
                  'movie-summary-card-subscription-loading-${movie.movieNumber}',
                ),
                isSubscribed: movie.isSubscribed,
                isUpdating: isSubscriptionUpdating,
                onTap: onSubscriptionTap,
              ),
              if (movie.canPlay)
                _StatusBadge(
                  key: Key(
                    'movie-summary-card-status-playable-${movie.movieNumber}',
                  ),
                  icon: Icons.play_arrow_rounded,
                  iconColor: colors.textOnMedia,
                  background: colors.movieCardPlayableBadgeBackground,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MovieCover extends StatelessWidget {
  const _MovieCover({required this.movieNumber, required this.imageUrl});

  final String movieNumber;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    if (!hasImage) {
      return DecoratedBox(
        key: Key('movie-summary-card-placeholder-$movieNumber'),
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
            Icons.movie_creation_outlined,
            size: componentTokens.iconSize3xl,
            color: colors.textMuted,
          ),
        ),
      );
    }

    return MaskedImage(
      url: imageUrl!,
      fit: BoxFit.cover,
      visibleWidthFactor: componentTokens.movieCardCoverVisibleWidthFactor,
      visibleAlignment: Alignment.centerRight,
    );
  }
}

class _MovieCardBottomShade extends StatelessWidget {
  const _MovieCardBottomShade();

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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.background,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;

    return Container(
      width: componentTokens.movieCardStatusBadgeSize,
      height: componentTokens.movieCardStatusBadgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: context.appRadius.pillBorder,
      ),
      child: Icon(icon, size: componentTokens.iconSizeXl, color: iconColor),
    );
  }
}

class _SubscriptionBadge extends StatelessWidget {
  const _SubscriptionBadge({
    super.key,
    required this.loadingKey,
    required this.isSubscribed,
    required this.isUpdating,
    required this.onTap,
  });

  final Key loadingKey;
  final bool isSubscribed;
  final bool isUpdating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;
    final colors = context.appColors;

    final badge = SizedBox(
      width: componentTokens.movieCardStatusBadgeSize,
      height: componentTokens.movieCardStatusBadgeSize,
      child: Center(
        child:
            isUpdating
                ? SizedBox(
                  width: componentTokens.movieCardLoaderSize,
                  height: componentTokens.movieCardLoaderSize,
                  child: CircularProgressIndicator(
                    key: loadingKey,
                    strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
                    color: colors.subscriptionHeartIcon,
                  ),
                )
                : Icon(
                  isSubscribed
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: componentTokens.iconSizeXl,
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
