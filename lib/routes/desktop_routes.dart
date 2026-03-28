import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/actors/presentation/desktop_actor_detail_page.dart';
import 'package:sakuramedia/features/auth/presentation/login_page.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_detail_page.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_player_page.dart';
import 'package:sakuramedia/features/playlists/presentation/desktop_playlist_detail_page.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
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
  String get location => _buildLocation(
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
      initialMediaId: _resolveIntQueryParameter(
        state,
        names: const <String>['mediaId', 'media-id'],
        fallback: mediaId,
      ),
      initialPositionSeconds: _resolveIntQueryParameter(
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
    TypedGoRoute<DesktopSearchQueryRouteData>(path: '$desktopSearchPath/:query'),
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
      ),
      shellNavigatorKey: desktopShellNavigatorKey,
      navGroups: desktopNavGroups,
      child: navigator,
    );
  }
}

class DesktopOverviewRouteData extends _DesktopShellPageRouteData
    with $DesktopOverviewRouteData {
  const DesktopOverviewRouteData();

  @override
  String get pageName => desktopRouteSpecs
      .firstWhere((spec) => spec.path == desktopOverviewPath)
      .name;

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return desktopRouteSpecs
        .firstWhere((spec) => spec.path == desktopOverviewPath)
        .builder(context);
  }
}

class DesktopFollowRouteData extends _DesktopShellPageRouteData
    with $DesktopFollowRouteData {
  const DesktopFollowRouteData();

  @override
  String get pageName => desktopRouteSpecs
      .firstWhere((spec) => spec.path == desktopFollowPath)
      .name;

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return desktopRouteSpecs
        .firstWhere((spec) => spec.path == desktopFollowPath)
        .builder(context);
  }
}

class DesktopMoviesRouteData extends _DesktopShellPageRouteData
    with $DesktopMoviesRouteData {
  const DesktopMoviesRouteData();

  @override
  String get pageName => desktopRouteSpecs
      .firstWhere((spec) => spec.path == desktopMoviesPath)
      .name;

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return desktopRouteSpecs
        .firstWhere((spec) => spec.path == desktopMoviesPath)
        .builder(context);
  }
}

class DesktopActorsRouteData extends _DesktopShellPageRouteData
    with $DesktopActorsRouteData {
  const DesktopActorsRouteData();

  @override
  String get pageName => desktopRouteSpecs
      .firstWhere((spec) => spec.path == desktopActorsPath)
      .name;

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return desktopRouteSpecs
        .firstWhere((spec) => spec.path == desktopActorsPath)
        .builder(context);
  }
}

class DesktopMomentsRouteData extends _DesktopShellPageRouteData
    with $DesktopMomentsRouteData {
  const DesktopMomentsRouteData();

  @override
  String get pageName => desktopRouteSpecs
      .firstWhere((spec) => spec.path == desktopMomentsPath)
      .name;

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return desktopRouteSpecs
        .firstWhere((spec) => spec.path == desktopMomentsPath)
        .builder(context);
  }
}

class DesktopPlaylistsRouteData extends _DesktopShellPageRouteData
    with $DesktopPlaylistsRouteData {
  const DesktopPlaylistsRouteData();

  @override
  String get pageName => desktopRouteSpecs
      .firstWhere((spec) => spec.path == desktopPlaylistsPath)
      .name;

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return desktopRouteSpecs
        .firstWhere((spec) => spec.path == desktopPlaylistsPath)
        .builder(context);
  }
}

class DesktopRankingsRouteData extends _DesktopShellPageRouteData
    with $DesktopRankingsRouteData {
  const DesktopRankingsRouteData();

  @override
  String get pageName => desktopRouteSpecs
      .firstWhere((spec) => spec.path == desktopRankingsPath)
      .name;

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return desktopRouteSpecs
        .firstWhere((spec) => spec.path == desktopRankingsPath)
        .builder(context);
  }
}

class DesktopHotReviewsRouteData extends _DesktopShellPageRouteData
    with $DesktopHotReviewsRouteData {
  const DesktopHotReviewsRouteData();

  @override
  String get pageName => desktopRouteSpecs
      .firstWhere((spec) => spec.path == desktopHotReviewsPath)
      .name;

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return desktopRouteSpecs
        .firstWhere((spec) => spec.path == desktopHotReviewsPath)
        .builder(context);
  }
}

class DesktopConfigurationRouteData extends _DesktopShellPageRouteData
    with $DesktopConfigurationRouteData {
  const DesktopConfigurationRouteData();

  @override
  String get pageName => desktopRouteSpecs
      .firstWhere((spec) => spec.path == desktopConfigurationPath)
      .name;

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return desktopRouteSpecs
        .firstWhere((spec) => spec.path == desktopConfigurationPath)
        .builder(context);
  }
}

class DesktopActivityRouteData extends _DesktopShellPageRouteData
    with $DesktopActivityRouteData {
  const DesktopActivityRouteData();

  @override
  String get pageName => desktopRouteSpecs
      .firstWhere((spec) => spec.path == desktopActivityPath)
      .name;

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return desktopRouteSpecs
        .firstWhere((spec) => spec.path == desktopActivityPath)
        .builder(context);
  }
}

class DesktopSearchRouteData extends _DesktopShellPageRouteData
    with $DesktopSearchRouteData {
  const DesktopSearchRouteData({this.useOnlineSearch = false});

  final bool useOnlineSearch;

  @override
  String get pageName => 'desktop-search-empty';

  @override
  String get location => _buildLocation(
    path: desktopSearchPath,
    queryParameters: <String, String?>{
      if (useOnlineSearch) 'useOnlineSearch': '$useOnlineSearch',
    },
  );

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return CatalogSearchPage(
      initialQuery: '',
      initialUseOnlineSearch: _resolveBoolQueryParameter(
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
  String get location => _buildLocation(
    path: '$desktopSearchPath/${Uri.encodeComponent(query)}',
    queryParameters: <String, String?>{
      if (useOnlineSearch) 'useOnlineSearch': '$useOnlineSearch',
    },
  );

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    return CatalogSearchPage(
      initialQuery: query,
      initialUseOnlineSearch: _resolveBoolQueryParameter(
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
  String get location => _buildLocation(
    path: desktopImageSearchPath,
    queryParameters: <String, String?>{
      if (draftId != null) 'draftId': draftId,
      if (currentMovieNumber != null) 'currentMovieNumber': currentMovieNumber,
      if (currentMovieScope != 'all') 'currentMovieScope': currentMovieScope,
    },
  );

  @override
  Widget buildContent(BuildContext context, GoRouterState state) {
    final resolvedDraftId = _resolveStringQueryParameter(
      state,
      names: const <String>['draftId', 'draft-id'],
      fallback: draftId,
    );
    final draft = context.read<ImageSearchDraftStore>().get(resolvedDraftId);
    return DesktopImageSearchPage(
      initialFileName: draft?.fileName,
      initialFileBytes: draft?.bytes,
      initialMimeType: draft?.mimeType,
      currentMovieNumber: _resolveStringQueryParameter(
        state,
        names: const <String>['currentMovieNumber', 'current-movie-number'],
        fallback: currentMovieNumber,
      ),
      initialCurrentMovieScope: _scopeFromQuery(
        _resolveStringQueryParameter(
              state,
              names: const <String>[
                'currentMovieScope',
                'current-movie-scope',
              ],
              fallback: currentMovieScope,
            ) ??
            currentMovieScope,
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

abstract class _DesktopShellPageRouteData extends _DesktopNoTransitionRouteData {
  const _DesktopShellPageRouteData();
}

ImageSearchCurrentMovieScope _scopeFromQuery(String value) {
  return ImageSearchCurrentMovieScope.values.firstWhere(
    (scope) => scope.name == value,
    orElse: () => ImageSearchCurrentMovieScope.all,
  );
}

String _buildLocation({
  required String path,
  required Map<String, String?> queryParameters,
}) {
  final effectiveQueryParameters = <String, String>{};
  for (final entry in queryParameters.entries) {
    final value = entry.value;
    if (value == null || value.isEmpty) {
      continue;
    }
    effectiveQueryParameters[entry.key] = value;
  }
  return Uri(
    path: path,
    queryParameters:
        effectiveQueryParameters.isEmpty ? null : effectiveQueryParameters,
  ).toString();
}

String? _resolveStringQueryParameter(
  GoRouterState state, {
  required List<String> names,
  String? fallback,
}) {
  for (final name in names) {
    final value = state.uri.queryParameters[name];
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return fallback;
}

int? _resolveIntQueryParameter(
  GoRouterState state, {
  required List<String> names,
  int? fallback,
}) {
  final value = _resolveStringQueryParameter(state, names: names);
  return value == null ? fallback : int.tryParse(value) ?? fallback;
}

bool _resolveBoolQueryParameter(
  GoRouterState state, {
  required List<String> names,
  required bool fallback,
}) {
  final value = _resolveStringQueryParameter(state, names: names);
  switch (value) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      return fallback;
  }
}
