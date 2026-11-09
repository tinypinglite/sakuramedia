import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/discovery/data/taste_profile_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';

/// 统一的横向女优卡：已订阅和未订阅共用同一套壳，只有心的状态不同。
class TasteActressCard extends StatelessWidget {
  const TasteActressCard({
    super.key,
    required this.entry,
    required this.isFollowUpdating,
    this.onTap,
    this.onFollowTap,
  });

  final TasteProfileActressDto entry;
  final bool isFollowUpdating;
  final VoidCallback? onTap;
  final VoidCallback? onFollowTap;

  @override
  Widget build(BuildContext context) {
    final actor = entry.actor;
    final colors = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final ringGap = spacing.xs / 2;

    final avatar = Container(
      padding: EdgeInsets.all(ringGap),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.primary, colors.secondary],
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(ringGap),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: appColors.surfaceCard,
        ),
        child: ActorAvatar(
          imageUrl: actor.profileImage?.origin,
          size: tokens.iconSize4xl,
          placeholderKey: Key('taste-actress-avatar-placeholder-${actor.id}'),
        ),
      ),
    );

    final card = Container(
      key: Key('taste-actress-${actor.id}'),
      width: spacing.xxxl * 4 + spacing.xxl,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: appColors.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          avatar,
          SizedBox(width: spacing.sm),
          Expanded(
            child: Tooltip(
              message: actor.displayName,
              waitDuration: const Duration(milliseconds: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    actor.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.semibold,
                    ),
                  ),
                  SizedBox(height: spacing.xs / 2),
                  Text(
                    AppLocalizations.of(
                      context,
                    ).widgetTasteMatchedMovies(entry.matchedMovieCount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s10,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: spacing.xs),
          SubscriptionHeartBadge(
            key: Key('taste-follow-${actor.id}'),
            loadingKey: Key('taste-follow-loading-${actor.id}'),
            isSubscribed: actor.isSubscribed,
            isUpdating: isFollowUpdating,
            onTap: onFollowTap,
          ),
        ],
      ),
    );

    return AppInteractiveSurface(
      onTap: onTap,
      semanticLabel: AppLocalizations.of(
        context,
      ).widgetTasteOpenActor(actor.displayName),
      child: card,
    );
  }
}
