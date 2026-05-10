import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/actors/presentation/desktop_actor_detail_page.dart';
import 'package:sakuramedia/features/auth/presentation/login_page.dart';
import 'package:sakuramedia/features/discovery/presentation/discovery_recommendation_list_pages.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_detail_page.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_player_page.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_series_movies_page.dart';
import 'package:sakuramedia/features/playlists/presentation/desktop_playlist_detail_page.dart';
import 'package:sakuramedia/routes/app_route_helpers.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/widgets/app_shell/app_desktop_shell.dart';

part 'desktop_routes.g.dart';

final GlobalKey<NavigatorState> desktopRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'desktop-root-navigator');
final GlobalKey<NavigatorState> desktopShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'desktop-shell-navigator');
AppPlatform currentDesktopRoutePlatform = AppPlatform.desktop;

@TypedGoRoute<DesktopLoginRouteData>(path: loginPath)
class DesktopLoginRouteData extends _DesktopNoTransitionRouteData
    with $DesktopLoginRouteData {
  const DesktopLoginRouteData();

  @override
  String get pageName => 'login';

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return LoginPage(platform: currentDesktopRoutePlatform);
  }
}

@TypedGoRoute<DesktopMoviePlayerRouteData>(
  path: '/desktop/library/movies/:movieNumber/player',
)
class DesktopMoviePlayerRouteData extends _DesktopNoTransitionRouteData
    with $DesktopMoviePlayerRouteData {
  const DesktopMoviePlayerRouteData({
    required this.movieNumber,
    this.mediaId,
    this.positionSeconds,
  });

  final String movieNumber;
  final int? mediaId;
  final int? positionSeconds;

  @override
  String get pageName => 'desktop-movie-player';

  @override
  String get location => buildRouteLocation(
    path: '/desktop/library/movies/${Uri.encodeComponent(movieNumber)}/player',
    queryParameters: <String, String?>{
      if (mediaId != null) 'mediaId': '$mediaId',
      if (positionSeconds != null) 'positionSeconds': '$positionSeconds',
    },
  );

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    // 兼容 typed route 新参数名与现有 URL 中的旧参数名。
    return DesktopMoviePlayerPage(
      movieNumber: movieNumber,
      initialMediaId: resolveIntQueryParameter(
        state,
        names: const <String>['mediaId', 'media-id'],
        fallback: mediaId,
      ),
      initialPositionSeconds: resolveIntQueryParameter(
        state,
        names: const <String>['positionSeconds', 'position-seconds'],
        fallback: positionSeconds,
      ),
    );
  }
}

@TypedShellRoute<DesktopShellRouteData>(
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<DesktopOverviewRouteData>(path: desktopOverviewPath),
    TypedGoRoute<DesktopDiscoverRouteData>(path: desktopDiscoverPath),
    TypedGoRoute<DesktopDiscoverMoviesRouteData>(
      path: desktopDiscoverMoviesPath,
    ),
    TypedGoRoute<DesktopDiscoverMomentsRouteData>(
      path: desktopDiscoverMomentsPath,
    ),
    TypedGoRoute<DesktopFollowRouteData>(path: desktopFollowPath),
    TypedGoRoute<DesktopMoviesRouteData>(path: desktopMoviesPath),
    TypedGoRoute<DesktopActorsRouteData>(path: desktopActorsPath),
    TypedGoRoute<DesktopMomentsRouteData>(path: desktopMomentsPath),
    TypedGoRoute<DesktopPlaylistsRouteData>(path: desktopPlaylistsPath),
    TypedGoRoute<DesktopRankingsRouteData>(path: desktopRankingsPath),
    TypedGoRoute<DesktopHotReviewsRouteData>(path: desktopHotReviewsPath),
    TypedGoRoute<DesktopActivityRouteData>(path: desktopActivityPath),
    TypedGoRoute<DesktopConfigurationRouteData>(path: desktopConfigurationPath),
    TypedGoRoute<DesktopSearchRouteData>(path: desktopSearchPath),
    // 以图搜图必须先于 `:query` 声明，避免 `/desktop/search/image` 被吞成普通搜索。
    TypedGoRoute<DesktopImageSearchRouteData>(path: desktopImageSearchPath),
    TypedGoRoute<DesktopSearchQueryRouteData>(
      path: '$desktopSearchPath/:query',
    ),
    TypedGoRoute<DesktopMovieSeriesRouteData>(
      path: '$desktopMovieSeriesPathPrefix/:seriesId',
    ),
    TypedGoRoute<DesktopMovieDetailRouteData>(
      path: '/desktop/library/movies/:movieNumber',
    ),
    TypedGoRoute<DesktopPlaylistDetailRouteData>(
      path: '/desktop/library/playlists/:playlistId',
    ),
    TypedGoRoute<DesktopActorDetailRouteData>(
      path: '/desktop/library/actors/:actorId',
    ),
  ],
)
class DesktopShellRouteData extends ShellRouteData {
  const DesktopShellRouteData();

  static final GlobalKey<NavigatorState> $navigatorKey =
      desktopShellNavigatorKey;

  @override
  Widget builder(BuildContext context, GoRouterState state, Widget navigator) {
    return AppDesktopShell(
      currentPath: state.uri.path,
      layout: resolveDesktopShellLayout(
        currentPath: state.uri.path,
        routeSpecs: desktopRouteSpecs,
      ),
      topBarConfig: resolveDesktopTopBarConfig(
        currentPath: state.uri.path,
        routeSpecs: desktopRouteSpecs,
        routeExtra: state.extra,
      ),
      shellNavigatorKey: desktopShellNavigatorKey,
      navGroups: desktopNavGroups,
      child: navigator,
    );
  }
}

class DesktopOverviewRouteData extends _DesktopShellSpecRouteData
    with $DesktopOverviewRouteData {
  const DesktopOverviewRouteData() : super(desktopOverviewPath);
}

class DesktopDiscoverRouteData extends _DesktopShellSpecRouteData
    with $DesktopDiscoverRouteData {
  const DesktopDiscoverRouteData() : super(desktopDiscoverPath);
}

class DesktopDiscoverMoviesRouteData extends _DesktopShellPageRouteData
    with $DesktopDiscoverMoviesRouteData {
  const DesktopDiscoverMoviesRouteData();

  @override
  String get pageName => 'desktop-discover-movies';

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return const DesktopDiscoverMoviesPage();
  }
}

class DesktopDiscoverMomentsRouteData extends _DesktopShellPageRouteData
    with $DesktopDiscoverMomentsRouteData {
  const DesktopDiscoverMomentsRouteData();

  @override
  String get pageName => 'desktop-discover-moments';

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return const DesktopDiscoverMomentsPage();
  }
}

class DesktopFollowRouteData extends _DesktopShellSpecRouteData
    with $DesktopFollowRouteData {
  const DesktopFollowRouteData() : super(desktopFollowPath);
}

class DesktopMoviesRouteData extends _DesktopShellSpecRouteData
    with $DesktopMoviesRouteData {
  const DesktopMoviesRouteData() : super(desktopMoviesPath);
}

class DesktopActorsRouteData extends _DesktopShellSpecRouteData
    with $DesktopActorsRouteData {
  const DesktopActorsRouteData() : super(desktopActorsPath);
}

class DesktopMomentsRouteData extends _DesktopShellSpecRouteData
    with $DesktopMomentsRouteData {
  const DesktopMomentsRouteData() : super(desktopMomentsPath);
}

class DesktopPlaylistsRouteData extends _DesktopShellSpecRouteData
    with $DesktopPlaylistsRouteData {
  const DesktopPlaylistsRouteData() : super(desktopPlaylistsPath);
}

class DesktopRankingsRouteData extends _DesktopShellSpecRouteData
    with $DesktopRankingsRouteData {
  const DesktopRankingsRouteData() : super(desktopRankingsPath);
}

class DesktopHotReviewsRouteData extends _DesktopShellSpecRouteData
    with $DesktopHotReviewsRouteData {
  const DesktopHotReviewsRouteData() : super(desktopHotReviewsPath);
}

class DesktopConfigurationRouteData extends _DesktopShellSpecRouteData
    with $DesktopConfigurationRouteData {
  const DesktopConfigurationRouteData() : super(desktopConfigurationPath);
}

class DesktopActivityRouteData extends _DesktopShellSpecRouteData
    with $DesktopActivityRouteData {
  const DesktopActivityRouteData() : super(desktopActivityPath);
}

class DesktopSearchRouteData extends _DesktopShellPageRouteData
    with $DesktopSearchRouteData {
  const DesktopSearchRouteData({this.useOnlineSearch = false});

  final bool useOnlineSearch;

  @override
  String get pageName => 'desktop-search-empty';

  @override
  String get location => buildRouteLocation(
    path: desktopSearchPath,
    queryParameters: <String, String?>{
      if (useOnlineSearch) 'useOnlineSearch': '$useOnlineSearch',
    },
  );

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return CatalogSearchPage(
      initialQuery: '',
      initialUseOnlineSearch: resolveBoolQueryParameter(
        state,
        names: const <String>['useOnlineSearch', 'use-online-search'],
        fallback: useOnlineSearch,
      ),
    );
  }
}

class DesktopSearchQueryRouteData extends _DesktopShellPageRouteData
    with $DesktopSearchQueryRouteData {
  const DesktopSearchQueryRouteData({
    required this.query,
    this.useOnlineSearch = false,
  });

  final String query;
  final bool useOnlineSearch;

  @override
  String get pageName => 'desktop-search';

  @override
  String get location => buildRouteLocation(
    path: '$desktopSearchPath/${Uri.encodeComponent(query)}',
    queryParameters: <String, String?>{
      if (useOnlineSearch) 'useOnlineSearch': '$useOnlineSearch',
    },
  );

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return CatalogSearchPage(
      initialQuery: query,
      initialUseOnlineSearch: resolveBoolQueryParameter(
        state,
        names: const <String>['useOnlineSearch', 'use-online-search'],
        fallback: useOnlineSearch,
      ),
    );
  }
}

class DesktopImageSearchRouteData extends _DesktopShellPageRouteData
    with $DesktopImageSearchRouteData {
  const DesktopImageSearchRouteData({
    this.draftId,
    this.currentMovieNumber,
    this.currentMovieScope = 'all',
  });

  final String? draftId;
  final String? currentMovieNumber;
  final String currentMovieScope;

  @override
  String get pageName => 'desktop-image-search';

  @override
  String get location => buildRouteLocation(
    path: desktopImageSearchPath,
    queryParameters: <String, String?>{
      if (draftId != null) 'draftId': draftId,
      if (currentMovieNumber != null) 'currentMovieNumber': currentMovieNumber,
      if (currentMovieScope != 'all') 'currentMovieScope': currentMovieScope,
    },
  );

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    final routeState = DesktopImageSearchRouteState.maybeFromExtra(state.extra);
    final resolvedDraftId = resolveStringQueryParameter(
      state,
      names: const <String>['draftId', 'draft-id'],
      fallback: draftId,
    );
    final draft = context.read<ImageSearchDraftStore>().get(resolvedDraftId);
    return DesktopImageSearchPage(
      fallbackPath: routeState.fallbackPath,
      initialFileName: draft?.fileName,
      initialFileBytes: draft?.bytes,
      initialMimeType: draft?.mimeType,
      currentMovieNumber: resolveStringQueryParameter(
        state,
        names: const <String>['currentMovieNumber', 'current-movie-number'],
        fallback: currentMovieNumber,
      ),
      initialCurrentMovieScope: parseImageSearchCurrentMovieScope(
        resolveStringQueryParameter(
              state,
              names: const <String>['currentMovieScope', 'current-movie-scope'],
              fallback: currentMovieScope,
            ) ??
            currentMovieScope,
      ),
    );
  }
}

class DesktopMovieSeriesRouteData extends _DesktopShellPageRouteData
    with $DesktopMovieSeriesRouteData {
  const DesktopMovieSeriesRouteData({required this.seriesId, this.seriesName});

  final int seriesId;
  final String? seriesName;

  @override
  String get pageName => 'desktop-movie-series';

  @override
  String get location => buildRouteLocation(
    path: '$desktopMovieSeriesPathPrefix/$seriesId',
    queryParameters: <String, String?>{
      if (seriesName != null && seriesName!.trim().isNotEmpty)
        'seriesName': seriesName!.trim(),
    },
  );

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return DesktopSeriesMoviesPage(
      seriesId: seriesId,
      seriesName: resolveStringQueryParameter(
        state,
        names: const <String>['seriesName', 'series-name'],
        fallback: seriesName,
      ),
    );
  }
}

class DesktopMovieDetailRouteData extends _DesktopShellPageRouteData
    with $DesktopMovieDetailRouteData {
  const DesktopMovieDetailRouteData({required this.movieNumber});

  final String movieNumber;

  @override
  String get pageName => 'desktop-movie-detail';

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return DesktopMovieDetailPage(movieNumber: movieNumber);
  }
}

class DesktopPlaylistDetailRouteData extends _DesktopShellPageRouteData
    with $DesktopPlaylistDetailRouteData {
  const DesktopPlaylistDetailRouteData({required this.playlistId});

  final int playlistId;

  @override
  String get pageName => 'desktop-playlist-detail';

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return DesktopPlaylistDetailPage(playlistId: playlistId);
  }
}

class DesktopActorDetailRouteData extends _DesktopShellPageRouteData
    with $DesktopActorDetailRouteData {
  const DesktopActorDetailRouteData({required this.actorId});

  final int actorId;

  @override
  String get pageName => 'desktop-actor-detail';

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return DesktopActorDetailPage(actorId: actorId);
  }
}

abstract class _DesktopNoTransitionRouteData extends GoRouteData {
  const _DesktopNoTransitionRouteData();

  String get pageName;
  Widget buildContent(BuildContext context, GoRouterState state);

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return buildContent(context, state);
  }

  @override
  NoTransitionPage<void> buildPage(BuildContext context, GoRouterState state) {
    return NoTransitionPage<void>(
      key: state.pageKey,
      name: pageName,
      child: buildContent(context, state),
    );
  }
}

abstract class _DesktopShellPageRouteData
    extends _DesktopNoTransitionRouteData {
  const _DesktopShellPageRouteData();
}

abstract class _DesktopShellSpecRouteData extends _DesktopShellPageRouteData {
  const _DesktopShellSpecRouteData(this.path);

  final String path;

  @override
  String get pageName => routeSpecNameForPath(desktopRouteSpecs, path);

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return buildRouteSpecContent(desktopRouteSpecs, path, context);
  }
}
