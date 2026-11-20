import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/app_date_format.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/features/external_player/presentation/widgets/external_player_picker.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_merge_playback_candidates.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_action_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_interaction_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_actor_wrap.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_media_item_list.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_thumbnail.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_scroll_rail.dart';
import 'package:sakuramedia/widgets/base/navigation/app_section_header.dart';
import 'package:sakuramedia/widgets/base/tv/tv_hero_banner.dart';
import 'package:sakuramedia/widgets/base/tv/tv_page.dart';

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
        child: state.errorMessage == null
            ? const Center(child: CircularProgressIndicator())
            : AppErrorState(
                title: l10n.baseActionFailed,
                message: state.errorMessage!,
                onRetry: _loadDetail,
              ),
      );
    }

    final derived = interaction.derive(movie);
    final selectedMedia = derived.selectedMedia;
    final isFavorite = movie.playlists.any(
      (playlist) => playlist.kind == PlaylistKind.favorites,
    );
    final hasProgress = (selectedMedia?.progress?.lastPositionSeconds ?? 0) > 0;
    final canPlay = selectedMedia?.hasPlayableUrl ?? false;
    final externalPlayerSelection = ref
        .watch(externalPlayerPreferenceProvider)
        .value;
    final useExternalPlayer =
        externalPlayerSelection != null &&
        isExternalPlayerAvailable(externalPlayerSelection);
    final mergePlaybackCandidates = resolveMovieMergePlaybackCandidates(
      movie,
      useExternalPlayer: useExternalPlayer,
      l10n: l10n,
    );
    final mergePlaybackLabel = resolveMovieMergePlaybackLabel(
      mergePlaybackCandidates,
      l10n,
    );
    return TvPagePadding(
      child: CustomScrollView(
        key: const Key('tv-movie-detail-page'),
        slivers: [
          SliverToBoxAdapter(
            child: TvHeroBanner(
              imageUrl: movie.wideCoverUrl,
              eyebrow: movie.movieNumber,
              seriesName: movie.seriesName,
              title: movie.preferredTitle,
              metaItems: _metaItems(
                context,
                l10n,
                movie,
                statsEnabled: ref.watch(statsFeaturesEnabledProvider),
              ),
              actions: [
                AppButton(
                  label: hasProgress
                      ? l10n.baseResumeContinue
                      : l10n.moviePageActionPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  size: AppButtonSize.tvLarge,
                  variant: AppButtonVariant.primary,
                  autofocus: true,
                  onPressed: selectedMedia == null || !canPlay
                      ? null
                      : () => TvRoutes.moviePlayer(
                          movieNumber: movie.movieNumber,
                          mediaId: selectedMedia.mediaId,
                        ).push(context),
                ),
                if (mergePlaybackLabel != null)
                  AppButton(
                    label: mergePlaybackLabel,
                    icon: const Icon(Icons.merge_rounded),
                    size: AppButtonSize.tvLarge,
                    variant: AppButtonVariant.secondary,
                    onPressed: interaction.isLaunchingPlayback
                        ? null
                        : () => unawaited(
                            openMovieMergedPlayback(
                              context: context,
                              ref: ref,
                              movieNumber: widget.movieNumber,
                              movie: movie,
                              candidates: mergePlaybackCandidates,
                              mobile: false,
                            ),
                          ),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
          SliverToBoxAdapter(
            child: Wrap(
              spacing: context.appSpacing.md,
              runSpacing: context.appSpacing.md,
              children: [
                AppButton(
                  label: isFavorite
                      ? l10n.movieWidgetRemoveFavorite
                      : l10n.movieWidgetFavoriteMovie,
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                  size: AppButtonSize.tvLarge,
                  variant: AppButtonVariant.secondary,
                  onPressed: derived.isActionControlsLocked
                      ? null
                      : () => _toggleFavorite(movie, isFavorite),
                ),
                AppButton(
                  label: derived.isWatched
                      ? l10n.movieActionMarkUnwatched
                      : l10n.movieActionMarkWatched,
                  icon: Icon(
                    derived.isWatched
                        ? Icons.remove_done_rounded
                        : Icons.done_rounded,
                  ),
                  size: AppButtonSize.tvLarge,
                  variant: AppButtonVariant.secondary,
                  onPressed: derived.isActionControlsLocked
                      ? null
                      : () => _toggleWatched(derived.isWatched),
                ),
                if (const ExternalPlayerChannel().isSupported)
                  AppButton(
                    label: l10n.movieActionPlayExternal,
                    icon: const Icon(Icons.open_in_new_rounded),
                    size: AppButtonSize.tvLarge,
                    variant: AppButtonVariant.secondary,
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
          if (derived.mediaItems.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: AppSectionHeader(
                title: l10n.moviePageSectionMediaSources,
                titleSize: AppTextSize.s32,
              ),
            ),
            SliverToBoxAdapter(
              child: MovieMediaItemList(
                mediaItems: derived.mediaItems,
                selectedMediaId: selectedMedia?.mediaId,
                onSelect: (media) => ref
                    .read(
                      movieDetailInteractionProvider(
                        widget.movieNumber,
                      ).notifier,
                    )
                    .selectMedia(media),
              ),
            ),
          ],
          if (movie.actors.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: AppSectionHeader(
                title: l10n.routeActorsTitle,
                titleSize: AppTextSize.s32,
              ),
            ),
            SliverToBoxAdapter(
              child: MovieActorWrap(
                actors: movie.actors,
                onActorTap: (actor) => TvRoutes.actorMovies(
                  actorId: actor.id,
                  actorName: actor.displayName,
                ).push(context),
              ),
            ),
          ],
          if (movie.plotImages.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: AppSectionHeader(
                title: l10n.imageSearchTargetPlot,
                titleSize: AppTextSize.s32,
              ),
            ),
            SliverToBoxAdapter(
              child: AppScrollRail(
                height: AppTvTokens.plotThumbnailHeight,
                itemCount: movie.plotImages.length,
                itemBuilder: (context, index) => SizedBox(
                  width: AppTvTokens.plotThumbnailWidth,
                  child: AppInteractiveSurface(
                    key: Key('tv-plot-image-$index'),
                    onTap: () => showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: movie.plotImages,
                      initialIndex: index,
                      thumbnailStripLayout:
                          MoviePlotPreviewThumbnailStripLayout.fixed,
                    ),
                    focusRingRadius: context.appRadius.mdBorder,
                    semanticLabel: '${l10n.imageSearchTargetPlot} ${index + 1}',
                    child: MoviePlotThumbnail(
                      maxHeight: AppTvTokens.plotThumbnailHeight,
                      fallbackAspectRatio:
                          AppTvTokens.plotThumbnailWidth /
                          AppTvTokens.plotThumbnailHeight,
                      borderRadius: context.appRadius.mdBorder,
                      url: movie.plotImages[index].origin,
                    ),
                  ),
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

/// 电视详情 hero 的元信息：与桌面详情同一套内容（热度 / 上映 / 时长 /
/// 厂商 / 导演），互动数等插件字段留给后续按需接入。
List<TvHeroMetaItem> _metaItems(
  BuildContext context,
  AppLocalizations l10n,
  MovieDetailDto movie, {
  required bool statsEnabled,
}) {
  final colors = context.appColors;
  return <TvHeroMetaItem>[
    if (statsEnabled && movie.heat > 0)
      TvHeroMetaItem(
        icon: Icons.local_fire_department_rounded,
        iconColor: colors.movieDetailHeatIcon,
        text: formatAppCompactCount(movie.heat),
      ),
    if (movie.releaseDate case final date?)
      TvHeroMetaItem(text: l10n.moviePageMetaReleased(formatAppDate(date))),
    if (movie.durationMinutes > 0)
      TvHeroMetaItem(
        icon: Icons.schedule_outlined,
        iconColor: colors.movieDetailDurationIcon,
        text: l10n.moviePageMetaDuration(movie.durationMinutes),
      ),
    if (movie.makerName.trim().isNotEmpty)
      TvHeroMetaItem(text: l10n.moviePageMetaStudio(movie.makerName.trim())),
    if (movie.directorName.trim().isNotEmpty)
      TvHeroMetaItem(
        text: l10n.moviePageMetaDirector(movie.directorName.trim()),
      ),
  ];
}
