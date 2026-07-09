import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/app_cover_bottom_shade.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';

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
            const AppCoverBottomShade(stops: [0.42, 0.7, 1]),
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
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.onMedia,
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
          top: spacing.xs,
          left: spacing.xs,
          child: SubscriptionHeartBadge(
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
            color: context.appTextPalette.muted,
          ),
        ),
      );
    }

    return MaskedImage(url: imageUrl, fit: BoxFit.cover);
  }
}

