import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/core/format/media_technical.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_scope.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/system_playlist_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_scroll_rail.dart';
import 'package:sakuramedia/widgets/base/navigation/app_section_header.dart';
import 'package:sakuramedia/widgets/base/tv/tv_hero_banner.dart';
import 'package:sakuramedia/widgets/base/tv/tv_movie_rail.dart';
import 'package:sakuramedia/widgets/base/tv/tv_page.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_banner_card.dart';

final _tvRecentlyPlayedPlaylistProvider = systemPlaylistProvider(
  PlaylistKind.recentlyPlayed,
);
final _tvFavoritesPlaylistProvider = systemPlaylistProvider(
  PlaylistKind.favorites,
);

class TvHomePage extends ConsumerWidget {
  const TvHomePage({super.key});

  static const _latestScope = MovieSummaryScope.latest(pageSize: 18);
  static const _recentlySubscribedScope = MovieSummaryScope.recentlySubscribed(
    pageSize: 18,
  );
  static const _playlistsScope = PlaylistsOverviewScope(
    orderScopeKey: 'tv:home',
  );
  static const _continueWatchingFilter = MovieFilterState(
    watchStatus: MovieWatchStatusFilter.watching,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final latestAsync = ref.watch(movieSummaryProvider(_latestScope));
    final recentPlaylist = ref.watch(_tvRecentlyPlayedPlaylistProvider).value;
    final favoritesPlaylist = ref.watch(_tvFavoritesPlaylistProvider).value;
    final continueScope = recentPlaylist == null
        ? null
        : MovieSummaryScope.playlist(
            playlistId: recentPlaylist.id,
            pageSize: 18,
            initialMovieFilter: _continueWatchingFilter,
          );
    final continueAsync = continueScope == null
        ? null
        : ref.watch(movieSummaryProvider(continueScope));
    final favoritesScope = favoritesPlaylist == null
        ? null
        : MovieSummaryScope.playlist(
            playlistId: favoritesPlaylist.id,
            pageSize: 18,
          );
    final favoritesAsync = favoritesScope == null
        ? null
        : ref.watch(movieSummaryProvider(favoritesScope));
    final recentlySubscribedAsync = ref.watch(
      movieSummaryProvider(_recentlySubscribedScope),
    );
    final playlistsState = ref
        .watch(playlistsOverviewProvider(_playlistsScope))
        .value;

    final continueItems =
        continueAsync?.value?.paged.items ?? const <MovieListItemDto>[];
    final latestItems =
        latestAsync.value?.paged.items ?? const <MovieListItemDto>[];
    final favoritesItems =
        favoritesAsync?.value?.paged.items ?? const <MovieListItemDto>[];
    final recentlySubscribedItems =
        recentlySubscribedAsync.value?.paged.items ??
        const <MovieListItemDto>[];
    final customPlaylists =
        playlistsState?.playlists
            .where((playlist) => !playlist.isSystem)
            .toList(growable: false) ??
        const <PlaylistDto>[];
    final heroMovie = continueItems.isNotEmpty
        ? continueItems.first
        : latestItems.isNotEmpty
        ? latestItems.first
        : null;

    return TvPagePadding(
      child: CustomScrollView(
        key: const Key('tv-home-page'),
        slivers: [
          SliverToBoxAdapter(
            child: heroMovie == null
                ? _TvHomeLoading(
                    error: latestAsync.hasError,
                    onRetry: () =>
                        ref.invalidate(movieSummaryProvider(_latestScope)),
                  )
                : TvHeroBanner(
                    imageUrl: heroMovie.wideCoverUrl,
                    eyebrow: heroMovie.movieNumber,
                    seriesName: heroMovie.seriesName,
                    title: heroMovie.preferredTitle,
                    metaItems: _heroMetaItems(
                      context,
                      l10n,
                      heroMovie,
                      statsEnabled: ref.watch(statsFeaturesEnabledProvider),
                    ),
                    actions: [
                      AppButton(
                        label: l10n.moviePageActionPlay,
                        icon: const Icon(Icons.play_arrow_rounded),
                        size: AppButtonSize.tvLarge,
                        variant: AppButtonVariant.primary,
                        autofocus: true,
                        onPressed: () => TvRoutes.moviePlayer(
                          movieNumber: heroMovie.movieNumber,
                        ).push(context),
                      ),
                      AppButton(
                        label: l10n.widgetMediaActionMovieDetail,
                        icon: const Icon(Icons.info_outline_rounded),
                        size: AppButtonSize.tvLarge,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => TvRoutes.movieDetail(
                          movieNumber: heroMovie.movieNumber,
                        ).push(context),
                      ),
                    ],
                  ),
          ),
          if (continueItems.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: AppSectionHeader(
                title: l10n.overviewContinueWatching,
                titleSize: AppTextSize.s32,
              ),
            ),
            SliverToBoxAdapter(
              child: TvMovieRail(
                items: continueItems,
                onPressed: (movie) => _openDetail(context, movie),
              ),
            ),
          ],
          if (latestItems.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: AppSectionHeader(
                title: l10n.overviewRecentlyAdded,
                titleSize: AppTextSize.s32,
              ),
            ),
            SliverToBoxAdapter(
              child: TvMovieRail(
                items: latestItems,
                onPressed: (movie) => _openDetail(context, movie),
              ),
            ),
          ],
          if (favoritesItems.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: AppSectionHeader(
                title: l10n.shellNavFavorites,
                titleSize: AppTextSize.s32,
              ),
            ),
            SliverToBoxAdapter(
              child: TvMovieRail(
                items: favoritesItems,
                onPressed: (movie) => _openDetail(context, movie),
              ),
            ),
          ],
          if (recentlySubscribedItems.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: AppSectionHeader(
                title: l10n.overviewRecentlySubscribed,
                titleSize: AppTextSize.s32,
              ),
            ),
            SliverToBoxAdapter(
              child: TvMovieRail(
                items: recentlySubscribedItems,
                onPressed: (movie) => _openDetail(context, movie),
              ),
            ),
          ],
          if (customPlaylists.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: AppSectionHeader(
                title: l10n.overviewPlaylists,
                titleSize: AppTextSize.s32,
              ),
            ),
            SliverToBoxAdapter(
              child: AppScrollRail(
                height: context.appComponentTokens.playlistBannerHeight,
                itemCount: customPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = customPlaylists[index];
                  return SizedBox(
                    width: AppTvTokens.playlistCardWidth,
                    child: PlaylistBannerCard(
                      title: playlist.name,
                      coverImageUrl: playlistsState!.coverUrlFor(playlist.id),
                      badgeLabel: playlist.isSmart
                          ? l10n.playlistSmartBadge
                          : null,
                      onTap: () => TvRoutes.playlistDetail(
                        playlistId: playlist.id,
                        playlistName: playlist.name,
                      ).push(context),
                    ),
                  );
                },
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 64)),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, MovieListItemDto movie) {
    TvRoutes.movieDetail(movieNumber: movie.movieNumber).push(context);
  }
}

List<TvHeroMetaItem> _heroMetaItems(
  BuildContext context,
  AppLocalizations l10n,
  MovieListItemDto movie, {
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
      TvHeroMetaItem(text: '${date.year}'),
    if (movie.durationMinutes > 0)
      TvHeroMetaItem(
        icon: Icons.schedule_outlined,
        iconColor: colors.movieDetailDurationIcon,
        text: l10n.moviePageMetaDuration(movie.durationMinutes),
      ),
    if (movie.maxMediaWidth > 0)
      TvHeroMetaItem(text: formatMovieResolutionLabel(movie.maxMediaWidth)),
  ];
}

class _TvHomeLoading extends StatelessWidget {
  const _TvHomeLoading({required this.error, required this.onRetry});

  final bool error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!error) {
      return const SizedBox(
        height: AppTvTokens.heroHeight,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: AppTvTokens.heroHeight,
      child: AppErrorState(
        title: l10n.baseActionFailed,
        message: l10n.errorLatestMovieListLoadFailed,
        onRetry: onRetry,
      ),
    );
  }
}
