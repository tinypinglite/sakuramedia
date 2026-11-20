import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_cover_card.dart';
import 'package:sakuramedia/widgets/base/media/images/app_cover_bottom_shade.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 电视端女优卡：与全站封面卡共用卡片壳和底部遮罩。
class TvActorCard extends StatelessWidget {
  const TvActorCard({super.key, required this.actor, required this.onPressed});

  final ActorListItemDto actor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final imageUrl = actor.profileImage?.origin.trim();

    return AppInteractiveSurface(
      onTap: onPressed,
      focusRingRadius: context.appRadius.lgBorder,
      semanticLabel: actor.displayName,
      child: AppCoverCard(
        cover: imageUrl == null || imageUrl.isEmpty
            ? ColoredBox(color: context.appColors.surfaceMuted)
            : MaskedImage(url: imageUrl, fit: BoxFit.cover, memCacheWidth: 512),
        overlays: [
          const Positioned.fill(
            child: AppCoverBottomShade(stops: [0.42, 0.7, 1]),
          ),
          Positioned(
            left: spacing.md,
            right: spacing.md,
            bottom: spacing.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actor.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: resolveCoverOverlayTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.semibold,
                  ),
                ),
                SizedBox(height: spacing.xs / 2),
                Text(
                  AppLocalizations.of(
                    context,
                  ).playlistMovieCount(actor.movieCount),
                  style: resolveCoverOverlayTextStyle(
                    context,
                    size: AppTextSize.s10,
                    opacity: 0.72,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
