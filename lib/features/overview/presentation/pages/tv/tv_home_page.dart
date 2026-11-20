import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_scope.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/system_playlist_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/tv/tv_action_button.dart';
import 'package:sakuramedia/widgets/base/tv/tv_movie_card.dart';
import 'package:sakuramedia/widgets/base/tv/tv_movie_rail.dart';
import 'package:sakuramedia/widgets/base/tv/tv_page.dart';
import 'package:sakuramedia/widgets/base/tv/tv_playlist_rail.dart';
import 'package:sakuramedia/widgets/base/tv/tv_section_header.dart';

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
                : _TvHomeHero(
                    movie: heroMovie,
                    onPlay: () => TvRoutes.moviePlayer(
                      movieNumber: heroMovie.movieNumber,
                    ).push(context),
                    onDetails: () => TvRoutes.movieDetail(
                      movieNumber: heroMovie.movieNumber,
                    ).push(context),
                  ),
          ),
          if (continueItems.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: TvSectionHeader(title: l10n.overviewContinueWatching),
            ),
            SliverToBoxAdapter(
              child: TvMovieRail(
                items: continueItems,
                layout: TvMovieCardLayout.landscape,
                onPressed: (movie) => _openDetail(context, movie),
              ),
            ),
          ],
          if (latestItems.isNotEmpty) ...[
            SliverToBoxAdapter(child: SizedBox(height: AppTvTokens.sectionGap)),
            SliverToBoxAdapter(
              child: TvSectionHeader(title: l10n.overviewRecentlyAdded),
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
              child: TvSectionHeader(title: l10n.shellNavFavorites),
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
              child: TvSectionHeader(title: l10n.overviewRecentlySubscribed),
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
              child: TvSectionHeader(title: l10n.overviewPlaylists),
            ),
            SliverToBoxAdapter(
              child: TvPlaylistRail(
                playlists: customPlaylists,
                coverUrlFor: playlistsState!.coverUrlFor,
                onPressed: (playlist) => TvRoutes.playlistDetail(
                  playlistId: playlist.id,
                  playlistName: playlist.name,
                ).push(context),
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

class _TvHomeHero extends StatelessWidget {
  const _TvHomeHero({
    required this.movie,
    required this.onPlay,
    required this.onDetails,
  });

  final MovieListItemDto movie;
  final VoidCallback onPlay;
  final VoidCallback onDetails;

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
                    context.appColors.surfacePage.withValues(alpha: 0.96),
                    context.appColors.surfacePage.withValues(alpha: 0.72),
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
                      if (movie.maxMediaWidth > 0)
                        _resolutionLabel(movie.maxMediaWidth),
                    ].join('  ·  '),
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s18,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                  SizedBox(height: context.appSpacing.xl),
                  Row(
                    children: [
                      TvActionButton(
                        label: l10n.moviePageActionPlay,
                        icon: Icons.play_arrow_rounded,
                        autofocus: true,
                        onPressed: onPlay,
                      ),
                      SizedBox(width: context.appSpacing.md),
                      TvActionButton(
                        label: l10n.widgetMediaActionMovieDetail,
                        icon: Icons.info_outline_rounded,
                        tone: TvActionButtonTone.secondary,
                        onPressed: onDetails,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolutionLabel(int width) {
    if (width >= 7000) {
      return '8K';
    }
    if (width >= 3500) {
      return '4K';
    }
    if (width >= 2500) {
      return '2K';
    }
    if (width >= 1800) {
      return '1080P';
    }
    return 'HD';
  }
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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.errorLatestMovieListLoadFailed,
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
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
