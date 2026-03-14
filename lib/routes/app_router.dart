import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/desktop_actor_detail_page.dart';
import 'package:sakuramedia/features/auth/presentation/login_page.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_detail_page.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_player_page.dart';
import 'package:sakuramedia/features/playlists/presentation/desktop_playlist_detail_page.dart';
import 'package:sakuramedia/features/playlists/presentation/mobile_playlist_detail_page.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_page.dart';
import 'package:sakuramedia/features/search/presentation/mobile_catalog_search_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/routes/desktop_search_route_state.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/widgets/app_shell/app_desktop_shell.dart';
import 'package:sakuramedia/widgets/app_shell/app_mobile_shell.dart';
import 'package:sakuramedia/widgets/app_shell/app_mobile_subpage_shell.dart';

GoRouter buildAppRouter(AppPlatform platform, SessionStore sessionStore) {
  switch (platform) {
    case AppPlatform.desktop:
      return buildDesktopRouter(sessionStore: sessionStore);
    case AppPlatform.mobile:
      return buildMobileRouter(sessionStore: sessionStore);
    case AppPlatform.web:
      return buildWebRouter(sessionStore: sessionStore);
  }
}

GoRouter buildDesktopRouter({required SessionStore sessionStore}) {
  return _buildRouter(
    platform: AppPlatform.desktop,
    sessionStore: sessionStore,
    navGroups: desktopNavGroups,
    routeSpecs: desktopRouteSpecs,
    rootRedirectPath: desktopOverviewPath,
  );
}

GoRouter buildMobileRouter({required SessionStore sessionStore}) {
  return _buildRouter(
    platform: AppPlatform.mobile,
    sessionStore: sessionStore,
    navGroups: mobileNavGroups,
    routeSpecs: mobileRouteSpecs,
    rootRedirectPath: mobileOverviewPath,
  );
}

GoRouter buildWebRouter({required SessionStore sessionStore}) {
  return _buildRouter(
    platform: AppPlatform.web,
    sessionStore: sessionStore,
    navGroups: webNavGroups,
    routeSpecs: webRouteSpecs,
    rootRedirectPath: webOverviewPath,
  );
}

GoRouter _buildRouter({
  required AppPlatform platform,
  required SessionStore sessionStore,
  required List<AppNavGroup> navGroups,
  required List<AppRouteSpec> routeSpecs,
  required String rootRedirectPath,
}) {
  final shellRoutes = routeSpecs
      .map(
        (spec) =>
            platform == AppPlatform.desktop
                ? GoRoute(
                  path: spec.path,
                  name: spec.name,
                  pageBuilder:
                      (context, state) => _buildDesktopNoTransitionPage(
                        state: state,
                        name: spec.name,
                        child: spec.builder(context),
                      ),
                )
                : GoRoute(
                  path: spec.path,
                  name: spec.name,
                  builder: (context, state) => spec.builder(context),
                ),
      )
      .toList(growable: true);
  final mobileSubpageRoutes = <RouteBase>[];

  if (platform == AppPlatform.desktop) {
    shellRoutes.add(
      GoRoute(
        path: desktopImageSearchPath,
        name: 'desktop-image-search',
        pageBuilder:
            (context, state) => _buildDesktopNoTransitionPage(
              state: state,
              name: 'desktop-image-search',
              child: DesktopImageSearchPage(
                fallbackPath:
                    DesktopImageSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).fallbackPath,
                initialFileName:
                    DesktopImageSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).initialFileName,
                initialFileBytes:
                    DesktopImageSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).initialFileBytes,
                initialMimeType:
                    DesktopImageSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).initialMimeType,
                currentMovieNumber:
                    DesktopImageSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).currentMovieNumber,
                initialCurrentMovieScope:
                    DesktopImageSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).initialCurrentMovieScope,
              ),
            ),
      ),
    );
    shellRoutes.add(
      GoRoute(
        path: desktopSearchPath,
        name: 'desktop-search-empty',
        pageBuilder:
            (context, state) => _buildDesktopNoTransitionPage(
              state: state,
              name: 'desktop-search-empty',
              child: CatalogSearchPage(
                initialQuery: '',
                fallbackPath:
                    DesktopSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).fallbackPath,
                initialUseOnlineSearch:
                    DesktopSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).useOnlineSearch,
              ),
            ),
      ),
    );
    shellRoutes.add(
      GoRoute(
        path: '$desktopSearchPath/:query',
        name: 'desktop-search',
        pageBuilder:
            (context, state) => _buildDesktopNoTransitionPage(
              state: state,
              name: 'desktop-search',
              child: CatalogSearchPage(
                initialQuery: state.pathParameters['query'] ?? '',
                fallbackPath:
                    DesktopSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).fallbackPath,
                initialUseOnlineSearch:
                    DesktopSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).useOnlineSearch,
              ),
            ),
      ),
    );
    shellRoutes.add(
      GoRoute(
        path: '/desktop/library/movies/:movieNumber',
        name: 'desktop-movie-detail',
        pageBuilder:
            (context, state) => _buildDesktopNoTransitionPage(
              state: state,
              name: 'desktop-movie-detail',
              child: DesktopMovieDetailPage(
                movieNumber: state.pathParameters['movieNumber'] ?? '',
              ),
            ),
      ),
    );
    shellRoutes.add(
      GoRoute(
        path: '/desktop/library/playlists/:playlistId',
        name: 'desktop-playlist-detail',
        pageBuilder:
            (context, state) => _buildDesktopNoTransitionPage(
              state: state,
              name: 'desktop-playlist-detail',
              child: DesktopPlaylistDetailPage(
                playlistId:
                    int.tryParse(state.pathParameters['playlistId'] ?? '') ?? 0,
              ),
            ),
      ),
    );
    shellRoutes.add(
      GoRoute(
        path: '/desktop/library/actors/:actorId',
        name: 'desktop-actor-detail',
        pageBuilder:
            (context, state) => _buildDesktopNoTransitionPage(
              state: state,
              name: 'desktop-actor-detail',
              child: DesktopActorDetailPage(
                actorId:
                    int.tryParse(state.pathParameters['actorId'] ?? '') ?? 0,
              ),
            ),
      ),
    );
  } else if (platform == AppPlatform.mobile) {
    mobileSubpageRoutes.add(
      GoRoute(
        path: '$mobilePlaylistDetailPathPrefix/:playlistId',
        name: 'mobile-playlist-detail',
        builder:
            (context, state) => MobilePlaylistDetailPage(
              playlistId:
                  int.tryParse(state.pathParameters['playlistId'] ?? '') ?? 0,
            ),
      ),
    );
    mobileSubpageRoutes.add(
      GoRoute(
        path: mobileSearchPath,
        name: 'mobile-search-empty',
        builder:
            (context, state) => MobileCatalogSearchPage(
              initialQuery: '',
              initialUseOnlineSearch:
                  DesktopSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).useOnlineSearch,
            ),
      ),
    );
    mobileSubpageRoutes.add(
      GoRoute(
        path: mobileImageSearchPath,
        name: 'mobile-image-search',
        builder:
            (context, state) => DesktopImageSearchPage(
              fallbackPath:
                  DesktopImageSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).fallbackPath,
              initialFileName:
                  DesktopImageSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).initialFileName,
              initialFileBytes:
                  DesktopImageSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).initialFileBytes,
              initialMimeType:
                  DesktopImageSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).initialMimeType,
              currentMovieNumber:
                  DesktopImageSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).currentMovieNumber,
              initialCurrentMovieScope:
                  DesktopImageSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).initialCurrentMovieScope,
              imagePicker: pickMobileImageSearchFile,
              onSearchSimilar: (context, item) async {
                showToast('移动端以图搜图开发中');
                return false;
              },
              onOpenPlayer: (_, __) => showToast('移动端播放器开发中'),
              onOpenMovieDetail: (_, __) => showToast('移动端影片详情开发中'),
            ),
      ),
    );
    mobileSubpageRoutes.add(
      GoRoute(
        path: '$mobileSearchPath/:query',
        name: 'mobile-search',
        builder:
            (context, state) => MobileCatalogSearchPage(
              initialQuery: state.pathParameters['query'] ?? '',
              initialUseOnlineSearch:
                  DesktopSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).useOnlineSearch,
            ),
      ),
    );
  }

  final routes = <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
    platform == AppPlatform.desktop
        ? GoRoute(
          path: loginPath,
          name: 'login',
          pageBuilder:
              (context, state) => _buildDesktopNoTransitionPage(
                state: state,
                name: 'login',
                child: LoginPage(platform: platform),
              ),
        )
        : GoRoute(
          path: loginPath,
          name: 'login',
          builder: (context, state) => LoginPage(platform: platform),
        ),
  ];

  if (platform == AppPlatform.desktop) {
    routes.add(
      GoRoute(
        path: '/desktop/library/movies/:movieNumber/player',
        name: 'desktop-movie-player',
        pageBuilder:
            (context, state) => _buildDesktopNoTransitionPage(
              state: state,
              name: 'desktop-movie-player',
              child: DesktopMoviePlayerPage(
                movieNumber: state.pathParameters['movieNumber'] ?? '',
                initialMediaId: int.tryParse(
                  state.uri.queryParameters['mediaId'] ?? '',
                ),
                initialPositionSeconds: int.tryParse(
                  state.uri.queryParameters['positionSeconds'] ?? '',
                ),
              ),
            ),
      ),
    );
    routes.add(
      ShellRoute(
        builder:
            (context, state, child) => AppDesktopShell(
              currentPath: state.uri.path,
              layout: resolveDesktopShellLayout(
                currentPath: state.uri.path,
                routeSpecs: routeSpecs,
              ),
              topBarConfig: resolveDesktopTopBarConfig(
                currentPath: state.uri.path,
                routeSpecs: routeSpecs,
                routeExtra: state.extra,
              ),
              navGroups: navGroups,
              child: child,
            ),
        routes: shellRoutes,
      ),
    );
  } else if (platform == AppPlatform.mobile) {
    routes.add(
      ShellRoute(
        builder:
            (context, state, child) => AppMobileShell(
              currentPath: state.uri.path,
              navGroups: navGroups,
              child: child,
            ),
        routes: shellRoutes,
      ),
    );
    routes.add(
      ShellRoute(
        builder:
            (context, state, child) => AppMobileSubpageShell(
              title: _mobileSubpageTitleFromPath(state.uri.path),
              fallbackPath: _mobileSubpageFallbackPathFromExtra(state.extra),
              child: child,
            ),
        routes: mobileSubpageRoutes,
      ),
    );
  } else {
    routes.addAll(shellRoutes);
  }

  return GoRouter(
    initialLocation: '/',
    refreshListenable: sessionStore,
    redirect: (context, state) {
      final path = state.uri.path;
      final hasSession = sessionStore.hasSession;
      final isLoginPage = path == loginPath;

      if (!hasSession && !isLoginPage) {
        return loginPath;
      }
      if (hasSession && isLoginPage) {
        return rootRedirectPath;
      }
      if (path == '/') {
        return hasSession ? rootRedirectPath : loginPath;
      }
      return null;
    },
    routes: routes,
  );
}

NoTransitionPage<void> _buildDesktopNoTransitionPage({
  required GoRouterState state,
  required String name,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: state.pageKey, name: name, child: child);
}

String _mobileSubpageFallbackPathFromExtra(Object? routeExtra) {
  if (routeExtra is String && routeExtra.startsWith('/mobile/')) {
    return routeExtra;
  }
  final searchState = DesktopSearchRouteState.maybeFromExtra(routeExtra);
  final searchFallbackPath = searchState.fallbackPath;
  if (searchFallbackPath != null && searchFallbackPath.startsWith('/mobile/')) {
    return searchFallbackPath;
  }
  final imageSearchState = DesktopImageSearchRouteState.maybeFromExtra(
    routeExtra,
  );
  final imageSearchFallbackPath = imageSearchState.fallbackPath;
  if (imageSearchFallbackPath != null &&
      imageSearchFallbackPath.startsWith('/mobile/')) {
    return imageSearchFallbackPath;
  }
  return mobileOverviewPath;
}

String _mobileSubpageTitleFromPath(String path) {
  if (path == mobileImageSearchPath) {
    return '以图搜图';
  }
  if (path == mobileSearchPath || path.startsWith('$mobileSearchPath/')) {
    return '搜索';
  }
  if (path.startsWith('$mobilePlaylistDetailPathPrefix/')) {
    return '播放列表详情';
  }
  return '详情';
}
