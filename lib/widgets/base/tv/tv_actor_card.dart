import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/tv/tv_focusable.dart';

class TvActorCard extends StatelessWidget {
  const TvActorCard({
    super.key,
    required this.actor,
    required this.onPressed,
    this.width = 188,
    this.height = 250,
  });

  final ActorListItemDto actor;
  final VoidCallback onPressed;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = actor.profileImage?.origin;
    return TvFocusable(
      onPressed: onPressed,
      borderRadius: context.appRadius.mdBorder,
      semanticLabel: actor.displayName,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: context.appRadius.mdBorder,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null && imageUrl.trim().isNotEmpty)
                MaskedImage(
                  url: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: (width * 2).round(),
                  memCacheHeight: (height * 2).round(),
                )
              else
                ColoredBox(color: context.appColors.surfaceMuted),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.appColors.surfacePage.withValues(alpha: 0),
                      context.appColors.surfacePage.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: context.appSpacing.md,
                right: context.appSpacing.md,
                bottom: context.appSpacing.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actor.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s20,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.onMedia,
                      ),
                    ),
                    SizedBox(height: context.appSpacing.xs),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).playlistMovieCount(actor.movieCount),
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        tone: AppTextTone.onMedia,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
