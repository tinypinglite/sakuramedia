import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_cover_card.dart';
import 'package:sakuramedia/widgets/base/media/images/app_cover_bottom_shade.dart';
import 'package:sakuramedia/widgets/base/media/images/app_cover_progress_bar.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_card_badges.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_poster_cover.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';

/// 电视端影片卡：与全站封面卡共用卡片壳、底部遮罩、角标和观看进度条。
///
/// 电视没有 hover，所以桌面卡片悬停后才出现的标题常显在底部遮罩上，同时
/// 保留番号、订阅状态、清晰度和热度这些一眼可读的信息；焦点态沿用
/// [AppInteractiveSurface] 的焦点环。
class TvMovieCard extends ConsumerWidget {
  const TvMovieCard({
    super.key,
    required this.movie,
    required this.onPressed,
    this.autofocus = false,
  });

  final MovieListItemDto movie;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.appSpacing;
    final progress = movie.watchProgress;
    final seriesName = movie.seriesName.trim();
    final showHeat = ref.watch(statsFeaturesEnabledProvider) && movie.heat > 0;
    final showResolution = movie.maxMediaWidth >= 3840;
    final showPlayable = !showResolution && movie.canPlay;

    return AppInteractiveSurface(
      onTap: onPressed,
      autofocus: autofocus,
      focusRingRadius: context.appRadius.lgBorder,
      semanticLabel: movie.preferredTitle,
      child: AppCoverCard(
        cover: MoviePosterCover(
          movie: movie,
          memCacheWidth: 512,
          placeholderKeyPrefix: 'tv-movie-card',
        ),
        overlays: [
          const Positioned.fill(child: AppCoverBottomShade()),
          Positioned(
            top: spacing.xs,
            left: spacing.xs,
            child: Wrap(
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              children: [
                SubscriptionHeartBadge(
                  key: Key('tv-movie-card-subscription-${movie.movieNumber}'),
                  loadingKey: Key(
                    'tv-movie-card-subscription-loading-${movie.movieNumber}',
                  ),
                  isSubscribed: movie.isSubscribed,
                  isUpdating: false,
                  onTap: null,
                ),
                if (showResolution)
                  MovieResolutionBadge(
                    movieNumber: movie.movieNumber,
                    maxMediaWidth: movie.maxMediaWidth,
                    keyPrefix: 'tv-movie-card',
                  )
                else if (showPlayable)
                  MoviePlayableBadge(
                    movieNumber: movie.movieNumber,
                    keyPrefix: 'tv-movie-card',
                  ),
              ],
            ),
          ),
          if (showHeat)
            Positioned(
              top: spacing.xs,
              right: spacing.xs,
              child: MovieHeatBadge(
                movieNumber: movie.movieNumber,
                heat: movie.heat,
                keyPrefix: 'tv-movie-card',
              ),
            ),
          Positioned(
            left: spacing.md,
            right: spacing.md,
            bottom: spacing.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      movie.movieNumber,
                      key: Key('tv-movie-card-number-${movie.movieNumber}'),
                      maxLines: 1,
                      style: resolveCoverOverlayTextStyle(
                        context,
                        size: AppTextSize.s10,
                        weight: AppTextWeight.semibold,
                      ),
                    ),
                    if (seriesName.isNotEmpty) ...[
                      SizedBox(width: spacing.xs),
                      Expanded(
                        child: Text(
                          seriesName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: resolveCoverOverlayTextStyle(
                            context,
                            size: AppTextSize.s10,
                            opacity: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: spacing.xs / 2),
                Text(
                  movie.preferredTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: resolveCoverOverlayTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.semibold,
                  ),
                ),
              ],
            ),
          ),
          if (progress != null && !progress.finished)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppCoverProgressBar(ratio: progress.ratio),
            ),
        ],
      ),
    );
  }
}
