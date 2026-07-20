import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_media_source.dart';

class MoviePlayerPlaybackErrorOverlay extends StatelessWidget {
  const MoviePlayerPlaybackErrorOverlay({
    super.key,
    required this.sourceKind,
  });

  final MoviePlayerMediaSourceKind sourceKind;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('movie-player-playback-error-overlay'),
      color: context.appColors.movieDetailHeroBackgroundStart,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(context.appSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: context.appComponentTokens.iconSizeLg,
                color: context.appTextPalette.onMedia,
              ),
              SizedBox(height: context.appSpacing.md),
              Text(
                '播放失败',
                key: const Key('movie-player-playback-error-title'),
                textAlign: TextAlign.center,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.onMedia,
                ),
              ),
              SizedBox(height: context.appSpacing.sm),
              Text(
                moviePlayerPlaybackErrorMessage(sourceKind),
                key: const Key('movie-player-playback-error-message'),
                textAlign: TextAlign.center,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  tone: AppTextTone.onMedia,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
