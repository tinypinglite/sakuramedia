import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/tv/tv_focusable.dart';

enum TvMovieCardLayout { poster, landscape }

class TvMovieCard extends StatelessWidget {
  const TvMovieCard({
    super.key,
    required this.movie,
    required this.onPressed,
    this.layout = TvMovieCardLayout.poster,
    this.autofocus = false,
    this.width,
    this.height,
  });

  final MovieListItemDto movie;
  final VoidCallback onPressed;
  final TvMovieCardLayout layout;
  final bool autofocus;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final landscape = layout == TvMovieCardLayout.landscape;
    final resolvedWidth =
        width ??
        (landscape ? AppTvTokens.landscapeCardWidth : AppTvTokens.posterWidth);
    final resolvedHeight =
        height ??
        (landscape
            ? AppTvTokens.landscapeCardHeight
            : AppTvTokens.posterHeight);
    final imageUrl = landscape ? movie.wideCoverUrl : movie.preferredCoverUrl;
    final progress = movie.watchProgress;
    final title = movie.preferredTitle;

    return TvFocusable(
      onPressed: onPressed,
      autofocus: autofocus,
      borderRadius: context.appRadius.mdBorder,
      semanticLabel: title,
      child: SizedBox(
        width: resolvedWidth,
        height: resolvedHeight,
        child: ClipRRect(
          borderRadius: context.appRadius.mdBorder,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MaskedImage(
                url: imageUrl ?? '',
                fit: BoxFit.cover,
                alignment: landscape ? Alignment.center : Alignment.topCenter,
                memCacheWidth: (resolvedWidth * 2).round(),
                memCacheHeight: (resolvedHeight * 2).round(),
              ),
              const _CardVeil(),
              Positioned(
                left: context.appSpacing.md,
                right: context.appSpacing.md,
                bottom: context.appSpacing.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (movie.seriesName.trim().isNotEmpty) ...[
                      Text(
                        movie.seriesName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          tone: AppTextTone.onMedia,
                        ),
                      ),
                      SizedBox(height: context.appSpacing.xs),
                    ],
                    Text(
                      title,
                      maxLines: landscape ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: landscape ? AppTextSize.s20 : AppTextSize.s18,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.onMedia,
                      ),
                    ),
                  ],
                ),
              ),
              if (progress != null && progress.ratio > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: progress.ratio,
                    minHeight: AppTvTokens.progressBarHeight,
                    backgroundColor: context.appColors.mediaOverlaySoft,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardVeil extends StatelessWidget {
  const _CardVeil();

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.surfacePage;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.92),
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
    );
  }
}
