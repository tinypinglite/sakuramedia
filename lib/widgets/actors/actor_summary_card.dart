import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

class ActorSummaryCard extends StatelessWidget {
  const ActorSummaryCard({
    super.key,
    required this.actor,
    this.onTap,
    this.onSubscriptionTap,
    this.isSubscriptionUpdating = false,
  });

  final ActorListItemDto actor;
  final VoidCallback? onTap;
  final VoidCallback? onSubscriptionTap;
  final bool isSubscriptionUpdating;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final displayName = actor.displayName;
    final spacing = context.appSpacing;

    final card = Container(
      key: Key('actor-summary-card-${actor.id}'),
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
            _ActorPoster(actor: actor),
            const _ActorCardBottomShade(),
            Positioned(
              left: context.appSpacing.md,
              right: context.appSpacing.md,
              bottom: context.appSpacing.md,
              child: Tooltip(
                message: displayName,
                waitDuration: const Duration(milliseconds: 300),
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.textOnMedia,
                    fontWeight: FontWeight.w700,
                  ),
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

    return Stack(
      children: [
        tappableCard,
        Positioned(
          top: spacing.sm,
          left: spacing.sm,
          child: _SubscriptionBadge(
            key: Key('actor-summary-card-subscription-${actor.id}'),
            loadingKey: Key(
              'actor-summary-card-subscription-loading-${actor.id}',
            ),
            isSubscribed: actor.isSubscribed,
            isUpdating: isSubscriptionUpdating,
            onTap: onSubscriptionTap,
          ),
        ),
      ],
    );
  }
}

class _ActorPoster extends StatelessWidget {
  const _ActorPoster({required this.actor});

  final ActorListItemDto actor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final imageUrl = actor.profileImage?.bestAvailableUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    if (!hasImage) {
      return DecoratedBox(
        key: Key('actor-summary-card-placeholder-${actor.id}'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.85),
              colors.surfaceMuted,
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.face_retouching_natural_outlined,
            size: context.appComponentTokens.iconSize3xl,
            color: colors.textMuted,
          ),
        ),
      );
    }

    return MaskedImage(url: imageUrl, fit: BoxFit.cover);
  }
}

class _ActorCardBottomShade extends StatelessWidget {
  const _ActorCardBottomShade();

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
          stops: const [0.42, 0.7, 1],
        ),
      ),
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
