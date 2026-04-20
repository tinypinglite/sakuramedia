import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actors/actor_avatar.dart';

class MovieActorWrap extends StatelessWidget {
  const MovieActorWrap({super.key, required this.actors, this.onActorTap});

  final List<MovieActorDto> actors;
  final ValueChanged<MovieActorDto>? onActorTap;

  @override
  Widget build(BuildContext context) {
    if (actors.isEmpty) {
      return Text(
        '暂无演员信息',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      );
    }

    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;

    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      children: actors.map((actor) {
        final avatarUrl = actor.profileImage?.bestAvailableUrl;
        return Tooltip(
          message: actor.aliasName.isEmpty ? actor.name : actor.aliasName,
          child: Builder(
            builder: (context) {
              Widget child = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ActorAvatar(
                    imageUrl: avatarUrl,
                    size: tokens.movieDetailActorAvatarSize,
                  ),
                  SizedBox(height: spacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: tokens.movieDetailActorCardWidth,
                    ),
                    child: Text(
                      actor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ),
                ],
              );

              child = KeyedSubtree(
                key: Key('movie-actor-${actor.id}'),
                child: child,
              );

              final canTap = onActorTap != null && actor.id > 0;
              if (!canTap) {
                return child;
              }

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onActorTap!(actor),
                  child: child,
                ),
              );
            },
          ),
        );
      }).toList(growable: false),
    );
  }
}
