import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/widgets/external_player_picker.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_action_result.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_interaction_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/tv/tv_action_button.dart';
import 'package:sakuramedia/widgets/base/tv/tv_actor_chip.dart';
import 'package:sakuramedia/widgets/base/tv/tv_focusable.dart';
import 'package:sakuramedia/widgets/base/tv/tv_page.dart';
import 'package:sakuramedia/widgets/base/tv/tv_section_header.dart';

class TvMovieDetailPage extends ConsumerStatefulWidget {
  const TvMovieDetailPage({super.key, required this.movieNumber});

  final String movieNumber;

  @override
  ConsumerState<TvMovieDetailPage> createState() => _TvMovieDetailPageState();
}

class _TvMovieDetailPageState extends ConsumerState<TvMovieDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadDetail();
      unawaited(
        ref
            .read(movieDetailInteractionProvider(widget.movieNumber).notifier)
            .loadMovieCollectionStatus(),
      );
    });
  }

  void _loadDetail() {
    unawaited(
      ref.read(movieDetailProvider(widget.movieNumber).notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(movieDetailProvider(widget.movieNumber));
    final interaction = ref.watch(
      movieDetailInteractionProvider(widget.movieNumber),
    );
    final movie = state.movie;
    if (movie == null) {
      return TvPagePadding(
        child: Center(
          child: state.errorMessage == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.errorMessage!,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s20,
                        tone: AppTextTone.error,
                      ),
                    ),
                    SizedBox(height: context.appSpacing.lg),
                    TvActionButton(
                      label: l10n.commonRetry,
                      icon: Icons.refresh_rounded,
                      onPressed: _loadDetail,
                    ),
                  ],
                ),
        ),
      );
    }

    final derived = interaction.derive(movie);
    final selectedMedia = derived.selectedMedia;
    final isFavorite = movie.playlists.any(
      (playlist) => playlist.kind == PlaylistKind.favorites,
    );
    final hasProgress = (selectedMedia?.progress?.lastPositionSeconds ?? 0) > 0;
    return TvPagePadding(
      child: CustomScrollView(
        key: const Key('tv-movie-detail-page'),
        slivers: [
          SliverToBoxAdapter(
            child: _TvDetailHero(
              movie: movie,
              playLabel: hasProgress
                  ? l10n.baseResumeContinue
                  : l10n.moviePageActionPlay,
              canPlay: selectedMedia?.hasPlayableUrl ?? false,
              onPlay: selectedMedia == null || !selectedMedia.hasPlayableUrl
                  ? null
                  : () => TvRoutes.moviePlayer(
                      movieNumber: movie.movieNumber,
                      mediaId: selectedMedia.mediaId,
                    ).push(context),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
          SliverToBoxAdapter(
            child: Wrap(
              spacing: context.appSpacing.md,
              runSpacing: context.appSpacing.md,
              children: [
                TvActionButton(
                  label: isFavorite
                      ? l10n.movieWidgetRemoveFavorite
                      : l10n.movieWidgetFavoriteMovie,
                  icon: isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  tone: TvActionButtonTone.secondary,
                  onPressed: derived.isActionControlsLocked
                      ? null
                      : () => _toggleFavorite(movie, isFavorite),
                ),
                TvActionButton(
                  label: derived.isWatched
                      ? l10n.movieActionMarkUnwatched
                      : l10n.movieActionMarkWatched,
                  icon: derived.isWatched
                      ? Icons.remove_done_rounded
                      : Icons.done_rounded,
                  tone: TvActionButtonTone.secondary,
                  onPressed: derived.isActionControlsLocked
                      ? null
                      : () => _toggleWatched(derived.isWatched),
                ),
                if (const ExternalPlayerChannel().isSupported)
                  TvActionButton(
                    label: l10n.movieActionPlayExternal,
                    icon: Icons.open_in_new_rounded,
                    tone: TvActionButtonTone.secondary,
                    onPressed: selectedMedia == null
                        ? null
                        : () => _openExternalPlayer(
                            movie: movie,
                            mediaId: selectedMedia.mediaId,
                          ),
                  ),
              ],
            ),
          ),
          if (derived.mediaItems.length > 1) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: TvSectionHeader(title: l10n.moviePageSectionMediaSources),
            ),
            SliverToBoxAdapter(
              child: Wrap(
                spacing: context.appSpacing.md,
                runSpacing: context.appSpacing.md,
                children: [
                  for (final media in derived.mediaItems)
                    _TvMediaSourceChip(
                      media: media,
                      selected: media.mediaId == selectedMedia?.mediaId,
                      onPressed: () => ref
                          .read(
                            movieDetailInteractionProvider(
                              widget.movieNumber,
                            ).notifier,
                          )
                          .selectMedia(media),
                    ),
                ],
              ),
            ),
          ],
          if (movie.actors.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: TvSectionHeader(title: l10n.routeActorsTitle),
            ),
            SliverToBoxAdapter(
              child: Wrap(
                spacing: context.appSpacing.md,
                runSpacing: context.appSpacing.md,
                children: [
                  for (final actor in movie.actors)
                    TvActorChip(
                      name: actor.displayName,
                      imageUrl: actor.profileImage?.origin,
                      onPressed: () => TvRoutes.actorMovies(
                        actorId: actor.id,
                        actorName: actor.displayName,
                      ).push(context),
                    ),
                ],
              ),
            ),
          ],
          if (movie.plotImages.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: TvSectionHeader(title: l10n.imageSearchTargetPlot),
            ),
            SliverToBoxAdapter(
              child: _TvPlotRail(
                images: movie.plotImages,
                onPressed: (index) => showMoviePlotPreviewOverlay(
                  context: context,
                  plotImages: movie.plotImages,
                  initialIndex: index,
                  thumbnailStripLayout:
                      MoviePlotPreviewThumbnailStripLayout.fixed,
                ),
              ),
            ),
          ],
          if (movie.preferredDescription.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: Text(
                movie.preferredDescription,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s20,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 64)),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(MovieDetailDto movie, bool isFavorite) async {
    final result = await ref
        .read(movieDetailInteractionProvider(widget.movieNumber).notifier)
        .toggleFavorite(movie: movie, isFavorite: isFavorite);
    _showResult(result);
  }

  Future<void> _toggleWatched(bool isWatched) async {
    final result = await ref
        .read(movieDetailInteractionProvider(widget.movieNumber).notifier)
        .setWatchState(
          isWatched
              ? MovieWatchStatusFilter.unwatched
              : MovieWatchStatusFilter.watched,
        );
    _showResult(result);
  }

  Future<void> _openExternalPlayer({
    required MovieDetailDto movie,
    required int mediaId,
  }) async {
    final player = await showExternalPlayerPicker(context);
    if (!mounted || player == null) {
      return;
    }
    await launchMoviePlayback(
      context,
      movieNumber: movie.movieNumber,
      mediaId: mediaId,
      movie: movie,
      inAppFallbackPath: TvRoutes.movieDetail(
        movieNumber: movie.movieNumber,
      ).location,
      target: MoviePlaybackTarget.external,
      externalPlayer: player,
    );
  }

  void _showResult(MovieDetailActionResult result) {
    final message = result.message;
    if (!mounted || message == null) {
      return;
    }
    showToast(
      message,
      context: context,
      tone: result.status == MovieDetailActionResultStatus.error
          ? AppToastTone.error
          : AppToastTone.success,
    );
  }
}

class _TvDetailHero extends StatelessWidget {
  const _TvDetailHero({
    required this.movie,
    required this.playLabel,
    required this.canPlay,
    required this.onPlay,
  });

  final MovieDetailDto movie;
  final String playLabel;
  final bool canPlay;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: AppTvTokens.heroHeight,
      child: ClipRRect(
        borderRadius: context.appRadius.xlBorder,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MaskedImage(
              url: movie.wideCoverUrl ?? '',
              fit: BoxFit.cover,
              memCacheWidth: 1920,
              memCacheHeight: 1080,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    context.appColors.surfacePage.withValues(alpha: 0.97),
                    context.appColors.surfacePage.withValues(alpha: 0.7),
                    context.appColors.surfacePage.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(context.appSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (movie.seriesName.trim().isNotEmpty) ...[
                    Text(
                      movie.seriesName,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s20,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                    SizedBox(height: context.appSpacing.sm),
                  ],
                  Text(
                    movie.preferredTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s48,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  SizedBox(height: context.appSpacing.md),
                  Text(
                    [
                      if (movie.releaseDate case final date?) '${date.year}',
                      if (movie.durationMinutes > 0)
                        l10n.moviePageMetaDuration(movie.durationMinutes),
                    ].join('  ·  '),
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s18,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                  SizedBox(height: context.appSpacing.xl),
                  TvActionButton(
                    label: playLabel,
                    icon: Icons.play_arrow_rounded,
                    autofocus: true,
                    onPressed: canPlay ? onPlay : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvMediaSourceChip extends StatelessWidget {
  const _TvMediaSourceChip({
    required this.media,
    required this.selected,
    required this.onPressed,
  });

  final MovieMediaItemDto media;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final resolution = media.resolution?.trim() ?? '';
    final label = resolution.isEmpty ? media.fileName : resolution;
    return TvFocusable(
      onPressed: onPressed,
      borderRadius: context.appRadius.mdBorder,
      scale: 1.02,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.lg,
          vertical: context.appSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : context.appColors.surfaceElevated,
          borderRadius: context.appRadius.mdBorder,
          border: Border.all(color: context.appColors.borderStrong),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.medium,
            tone: selected ? AppTextTone.onMedia : AppTextTone.primary,
          ),
        ),
      ),
    );
  }
}

class _TvPlotRail extends StatelessWidget {
  const _TvPlotRail({required this.images, required this.onPressed});

  final List<MovieImageDto> images;
  final ValueChanged<int> onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: context.appSpacing.md),
        itemBuilder: (context, index) {
          return TvFocusable(
            key: Key('tv-plot-image-$index'),
            onPressed: () => onPressed(index),
            borderRadius: context.appRadius.mdBorder,
            semanticLabel:
                '${AppLocalizations.of(context).imageSearchTargetPlot} ${index + 1}',
            child: SizedBox(
              width: AppTvTokens.plotThumbnailWidth,
              height: AppTvTokens.plotThumbnailHeight,
              child: ClipRRect(
                borderRadius: context.appRadius.mdBorder,
                child: MaskedImage(
                  url: images[index].origin,
                  fit: BoxFit.cover,
                  memCacheWidth: 676,
                  memCacheHeight: 380,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
