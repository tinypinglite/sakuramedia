import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/auth/presentation/login_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/tv/tv_settings_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_actor_movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_movie_detail_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_movie_player_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_playlist_detail_page.dart';
import 'package:sakuramedia/features/overview/presentation/pages/tv/tv_home_page.dart';
import 'package:sakuramedia/features/search/presentation/tv_search_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/definitions/query_params.dart';

const _tvPlaylistQueryParameters = <AppQueryParam>[
  AppQueryParam(name: 'playlistName', type: AppQueryType.string),
];
const _tvActorQueryParameters = <AppQueryParam>[
  AppQueryParam(name: 'actorName', type: AppQueryType.string),
];

final AppRouteDefinition tvLoginRoute = AppRouteDefinition(
  id: AppRouteId.tvLogin,
  name: 'login',
  platform: AppPlatform.tv,
  path: loginPath,
  scope: AppRouteScope.outsideShell,
  pageBuilder: (context, state) => const LoginPage(platform: AppPlatform.tv),
  title: (l10n, [_]) => l10n.appTitle,
);

final AppRouteDefinition tvHomeRoute = AppRouteDefinition(
  id: AppRouteId.tvHome,
  name: 'tv-home',
  platform: AppPlatform.tv,
  path: tvHomePath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const TvHomePage(),
  title: (l10n, [_]) => l10n.routeOverviewTitle,
  nav: AppNavDestination(
    groupId: 'home',
    order: 0,
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    description: (l10n) => l10n.routeNavOverviewDescription,
  ),
);

final AppRouteDefinition tvMoviesRoute = AppRouteDefinition(
  id: AppRouteId.tvMovies,
  name: 'tv-movies',
  platform: AppPlatform.tv,
  path: tvMoviesPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const TvMoviesPage(),
  title: (l10n, [_]) => l10n.routeMoviesTitle,
  nav: AppNavDestination(
    groupId: 'movies',
    order: 1,
    icon: Icons.movie_outlined,
    activeIcon: Icons.movie_rounded,
    description: (l10n) => l10n.routeNavMoviesDescription,
  ),
);

final AppRouteDefinition tvSearchRoute = AppRouteDefinition(
  id: AppRouteId.tvSearch,
  name: 'tv-search',
  platform: AppPlatform.tv,
  path: tvSearchPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const TvSearchPage(),
  title: (l10n, [_]) => l10n.routeSearchTitle,
  nav: AppNavDestination(
    groupId: 'search',
    order: 2,
    icon: Icons.search_rounded,
    description: (l10n) => l10n.routeSearchTitle,
  ),
);

final AppRouteDefinition tvSettingsRoute = AppRouteDefinition(
  id: AppRouteId.tvSettings,
  name: 'tv-settings',
  platform: AppPlatform.tv,
  path: tvSettingsPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const TvSettingsPage(),
  title: (l10n, [_]) => l10n.routeConfigurationTitle,
  nav: AppNavDestination(
    groupId: 'settings',
    order: 3,
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    description: (l10n) => l10n.routeConfigurationTitle,
  ),
);

final AppRouteDefinition tvMovieDetailRoute = AppRouteDefinition(
  id: AppRouteId.tvMovieDetail,
  name: 'tv-movie-detail',
  platform: AppPlatform.tv,
  path: '$tvMoviesPath/:movieNumber',
  scope: AppRouteScope.shellLevel,
  pageBuilder: (context, state) =>
      TvMovieDetailPage(movieNumber: state.pathParameters['movieNumber']!),
  title: (l10n, [_]) => l10n.routeMovieDetailsTitle,
  backTarget: (state) => tvMoviesPath,
);

final AppRouteDefinition tvPlaylistDetailRoute = AppRouteDefinition(
  id: AppRouteId.tvPlaylistDetail,
  name: 'tv-playlist-detail',
  platform: AppPlatform.tv,
  path: '$tvPlaylistsPath/:playlistId',
  scope: AppRouteScope.shellLevel,
  queryParameters: _tvPlaylistQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(_tvPlaylistQueryParameters, state);
    return TvPlaylistDetailPage(
      playlistId: int.parse(state.pathParameters['playlistId']!),
      playlistName: query.string('playlistName'),
    );
  },
  title: (l10n, [_]) => l10n.routePlaylistDetailsTitle,
  backTarget: (state) => tvHomePath,
);

final AppRouteDefinition tvActorMoviesRoute = AppRouteDefinition(
  id: AppRouteId.tvActorMovies,
  name: 'tv-actor-movies',
  platform: AppPlatform.tv,
  path: '$tvActorsPath/:actorId',
  scope: AppRouteScope.shellLevel,
  queryParameters: _tvActorQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(_tvActorQueryParameters, state);
    return TvActorMoviesPage(
      actorId: int.parse(state.pathParameters['actorId']!),
      actorName: query.string('actorName'),
    );
  },
  title: (l10n, [_]) => l10n.routeActorsTitle,
  backTarget: (state) => tvHomePath,
);

final AppRouteDefinition tvMoviePlayerRoute = AppRouteDefinition(
  id: AppRouteId.tvMoviePlayer,
  name: 'tv-movie-player',
  platform: AppPlatform.tv,
  path: '$tvMoviesPath/:movieNumber/player',
  scope: AppRouteScope.outsideShell,
  queryParameters: moviePlaybackQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(moviePlaybackQueryParameters, state);
    return TvMoviePlayerPage(
      movieNumber: state.pathParameters['movieNumber']!,
      initialMediaId: query.integer('mediaId'),
      mergedLibraryId: query.integer('mergedLibraryId'),
      initialPositionSeconds: query.integer('positionSeconds'),
      fallbackPath:
          AppRouteExtra.fallbackPathOf(state.extra, platform: AppPlatform.tv) ??
          '$tvMoviesPath/${state.pathParameters['movieNumber']}',
    );
  },
  title: (l10n, [_]) => l10n.routeMovieDetailsTitle,
);
