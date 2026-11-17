import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/movie_player_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/rated_movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/series_movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_player_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/rated_movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/series_movies_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/definitions/query_params.dart';
import 'package:sakuramedia/theme.dart';

final AppRouteDefinition desktopMoviesRoute = AppRouteDefinition(
  id: AppRouteId.desktopMovies,
  name: 'desktop-movies',
  platform: AppPlatform.desktop,
  path: desktopMoviesPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopMoviesPage(),
  title: (l10n, [_]) => l10n.routeMoviesTitle,
  nav: AppNavDestination(
    groupId: 'movies',
    order: 2,
    icon: Icons.movie_creation_outlined,
    description: (l10n) => l10n.routeNavMoviesDescription,
    sectionId: 'browse',
  ),
);

final AppRouteDefinition desktopRatedMoviesRoute = AppRouteDefinition(
  id: AppRouteId.desktopRatedMovies,
  name: 'desktop-rated-movies',
  platform: AppPlatform.desktop,
  path: desktopRatingsPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const DesktopRatedMoviesPage(),
  title: (l10n, [_]) => l10n.routeRatingsTitle,
  nav: AppNavDestination(
    groupId: 'ratings',
    order: 11,
    icon: Icons.star_outline_rounded,
    activeIcon: Icons.star_rounded,
    description: (l10n) => l10n.routeNavRatingsDescription,
    sectionId: 'browse',
  ),
);

final AppRouteDefinition desktopMovieSeriesRoute = AppRouteDefinition(
  id: AppRouteId.desktopMovieSeries,
  name: 'desktop-movie-series',
  platform: AppPlatform.desktop,
  path: '$desktopMovieSeriesPathPrefix/:seriesId',
  scope: AppRouteScope.shellLevel,
  queryParameters: seriesQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(seriesQueryParameters, state);
    return DesktopSeriesMoviesPage(
      seriesId: int.parse(state.pathParameters['seriesId']!),
      seriesName: query.string('seriesName'),
    );
  },
  title: (l10n, [_]) => l10n.routeSeriesMoviesTitle,
  backTarget: (state) => desktopMoviesPath,
);

final AppRouteDefinition desktopMovieDetailRoute = AppRouteDefinition(
  id: AppRouteId.desktopMovieDetail,
  name: 'desktop-movie-detail',
  platform: AppPlatform.desktop,
  path: '$desktopMoviesPath/:movieNumber',
  scope: AppRouteScope.shellLevel,
  layout: AppShellLayout.immersive,
  pageBuilder: (context, state) => MovieDetailPage(
    movieNumber: state.pathParameters['movieNumber']!,
    mobile: false,
  ),
  title: (l10n, [_]) => l10n.routeMovieDetailsTitle,
  backTarget: (state) => desktopMoviesPath,
);

final AppRouteDefinition desktopMoviePlayerRoute = AppRouteDefinition(
  id: AppRouteId.desktopMoviePlayer,
  name: 'desktop-movie-player',
  platform: AppPlatform.desktop,
  path: '$desktopMoviesPath/:movieNumber/player',
  scope: AppRouteScope.outsideShell,
  queryParameters: moviePlaybackQueryParameters,
  pageBuilder: (context, state) {
    final movieNumber = state.pathParameters['movieNumber']!;
    final query = AppQueryValues(moviePlaybackQueryParameters, state);
    return DesktopMoviePlayerPage(
      movieNumber: movieNumber,
      mergedLibraryId: query.integer('mergedLibraryId'),
      fallbackPath:
          AppRouteExtra.fallbackPathOf(
            state.extra,
            platform: AppPlatform.desktop,
          ) ??
          _desktopMovieDetailLocation(movieNumber),
      initialMediaId: query.integer('mediaId'),
      initialPositionSeconds: query.integer('positionSeconds'),
    );
  },
  title: (l10n, [_]) => l10n.routeMovieDetailsTitle,
);

final AppRouteDefinition mobileMoviesRoute = AppRouteDefinition(
  id: AppRouteId.mobileMovies,
  name: 'mobile-movies',
  platform: AppPlatform.mobile,
  path: mobileMoviesPath,
  scope: AppRouteScope.branchRoot,
  pageBuilder: (context, state) => const MobileMoviesPage(),
  title: (l10n, [_]) => l10n.routeMoviesTitle,
  nav: AppNavDestination(
    groupId: 'movies',
    order: 1,
    icon: Icons.movie_outlined,
    activeIcon: Icons.movie,
    description: (l10n) => l10n.routeNavMobileMoviesDescription,
  ),
);

final AppRouteDefinition mobileRatedMoviesRoute = AppRouteDefinition(
  id: AppRouteId.mobileRatedMovies,
  name: 'mobile-rated-movies',
  platform: AppPlatform.mobile,
  path: mobileRatingsPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  pageBuilder: (context, state) => const MobileRatedMoviesPage(),
  title: (l10n, [_]) => l10n.routeRatingsTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileMovieSeriesRoute = AppRouteDefinition(
  id: AppRouteId.mobileMovieSeries,
  name: 'mobile-movie-series',
  platform: AppPlatform.mobile,
  path: '$mobileMovieSeriesPathPrefix/:seriesId',
  scope: AppRouteScope.branchChild,
  parentId: AppRouteId.mobileMovies,
  useRootNavigator: true,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(glassChrome: true),
  queryParameters: seriesQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(seriesQueryParameters, state);
    return MobileSeriesMoviesPage(
      seriesId: int.parse(state.pathParameters['seriesId']!),
      seriesName: query.string('seriesName'),
    );
  },
  title: (l10n, [_]) => l10n.routeSeriesMoviesTitle,
  backTarget: (state) => mobileMoviesPath,
);

final AppRouteDefinition mobileMovieDetailRoute = AppRouteDefinition(
  id: AppRouteId.mobileMovieDetail,
  name: 'mobile-movie-detail',
  platform: AppPlatform.mobile,
  path: '$mobileMoviesPath/:movieNumber',
  scope: AppRouteScope.branchChild,
  parentId: AppRouteId.mobileMovies,
  useRootNavigator: true,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(
    bodyPadding: AppPageInsets.zero,
    immersive: true,
  ),
  pageBuilder: (context, state) => MovieDetailPage(
    movieNumber: state.pathParameters['movieNumber']!,
    mobile: true,
  ),
  title: (l10n, [_]) => l10n.routeMovieDetailsTitle,
  backTarget: (state) => mobileMoviesPath,
);

final AppRouteDefinition mobileMoviePlayerRoute = AppRouteDefinition(
  id: AppRouteId.mobileMoviePlayer,
  name: 'mobile-movie-player',
  platform: AppPlatform.mobile,
  path: '$mobileMoviesPath/:movieNumber/player',
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  queryParameters: moviePlaybackQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(moviePlaybackQueryParameters, state);
    return MobileMoviePlayerPage(
      movieNumber: state.pathParameters['movieNumber']!,
      mergedLibraryId: query.integer('mergedLibraryId'),
      initialMediaId: query.integer('mediaId'),
      initialPositionSeconds: query.integer('positionSeconds'),
    );
  },
  title: (l10n, [_]) => l10n.routeMovieDetailsTitle,
);

String _desktopMovieDetailLocation(String movieNumber) {
  return '$desktopMoviesPath/${Uri.encodeComponent(movieNumber)}';
}
