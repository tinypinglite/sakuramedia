import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

class MoviePlayerPlaybackErrorOverlay extends StatelessWidget {
  const MoviePlayerPlaybackErrorOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                l10n.widgetMoviePlayerPlaybackFailed,
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
                l10n.widgetMoviePlayerPlaybackUnavailable,
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
