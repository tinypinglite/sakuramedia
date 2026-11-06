import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';

class MovieActorWrap extends StatelessWidget {
  const MovieActorWrap({
    super.key,
    required this.actors,
    this.onActorTap,
    this.editing = false,
    this.onRemoveTap,
    this.removingActorIds = const <int>{},
    this.trailing,
  });

  final List<MovieActorDto> actors;
  final ValueChanged<MovieActorDto>? onActorTap;

  /// 编辑态：卡片整体变成「点击移除」，并禁用进入女优详情。
  final bool editing;
  final ValueChanged<MovieActorDto>? onRemoveTap;

  /// 正在提交移除请求的演员；卡片显示转圈并临时禁用。
  final Set<int> removingActorIds;

  /// 追加在演员卡片之后的入口（如「添加」卡）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final onRemoveTap = this.onRemoveTap;
    final l10n = AppLocalizations.of(context);

    final cards = actors
        .map((actor) {
          final avatarUrl = actor.profileImage?.origin;
          final isRemoving = removingActorIds.contains(actor.id);
          final canTap = editing
              ? onRemoveTap != null && !isRemoving
              : onActorTap != null && actor.id > 0;

          Widget avatar = ActorAvatar(
            imageUrl: avatarUrl,
            size: tokens.movieDetailActorAvatarSize,
          );
          if (editing) {
            avatar = Stack(
              clipBehavior: Clip.none,
              children: [
                avatar,
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.appColors.mediaOverlayStrong.withValues(
                        alpha: 0.42,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isRemoving
                          ? AppInlineSpinner(
                              color: context.appTextPalette.onMedia,
                            )
                          : Icon(
                              Icons.remove_rounded,
                              size: tokens.iconSizeSm,
                              color: context.appTextPalette.onMedia,
                            ),
                    ),
                  ),
                ),
              ],
            );
          }

          Widget child = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              avatar,
              SizedBox(height: spacing.sm),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: tokens.movieDetailActorCardWidth,
                ),
                child: Text(
                  actor.displayName,
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

          return Tooltip(
            message: editing
                ? l10n.movieWidgetRemoveActorFromCast(actor.displayName)
                : actor.displayName,
            child: Builder(
              builder: (context) {
                if (!canTap) {
                  return child;
                }
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        editing ? onRemoveTap!(actor) : onActorTap!(actor),
                    child: child,
                  ),
                );
              },
            ),
          );
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (actors.isEmpty) ...[
          Text(
            l10n.movieWidgetNoActors,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          if (trailing != null) SizedBox(height: spacing.sm),
        ],
        if (cards.isNotEmpty || trailing != null)
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [...cards, ?trailing],
          ),
      ],
    );
  }
}
