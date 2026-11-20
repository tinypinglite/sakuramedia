import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/tv/tv_focusable.dart';

class TvPlaylistCard extends StatelessWidget {
  const TvPlaylistCard({
    super.key,
    required this.playlist,
    required this.onPressed,
    this.coverUrl,
  });

  final PlaylistDto playlist;
  final String? coverUrl;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hasCover = coverUrl != null && coverUrl!.trim().isNotEmpty;
    return TvFocusable(
      onPressed: onPressed,
      borderRadius: context.appRadius.lgBorder,
      semanticLabel: playlist.name,
      child: SizedBox(
        width: AppTvTokens.playlistCardWidth,
        height: AppTvTokens.playlistCardHeight,
        child: ClipRRect(
          borderRadius: context.appRadius.lgBorder,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCover)
                MaskedImage(url: coverUrl!, fit: BoxFit.cover)
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.appColors.movieDetailHeroBackgroundStart,
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.55),
                        context.appColors.movieDetailHeroBackgroundEnd,
                      ],
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.appColors.surfacePage.withValues(alpha: 0.08),
                      context.appColors.surfacePage.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(context.appSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (playlist.isSmart)
                      Text(
                        AppLocalizations.of(context).playlistSmartBadge,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.accent,
                        ),
                      ),
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s24,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.onMedia,
                      ),
                    ),
                    SizedBox(height: context.appSpacing.xs),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).playlistMovieCount(playlist.movieCount),
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
