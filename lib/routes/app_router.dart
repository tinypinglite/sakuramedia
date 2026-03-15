import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/desktop_actor_detail_page.dart';
import 'package:sakuramedia/features/actors/presentation/mobile_actor_detail_page.dart';
import 'package:sakuramedia/features/auth/presentation/login_page.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_detail_page.dart';
import 'package:sakuramedia/features/movies/presentation/mobile_movie_detail_page.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_player_page.dart';
import 'package:sakuramedia/features/movies/presentation/mobile_movie_player_page.dart';
import 'package:sakuramedia/features/playlists/presentation/desktop_playlist_detail_page.dart';
import 'package:sakuramedia/features/playlists/presentation/mobile_playlist_detail_page.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_page.dart';
import 'package:sakuramedia/features/search/presentation/mobile_catalog_search_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/routes/desktop_search_route_state.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';
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
                : platform == AppPlatform.mobile
                ? GoRoute(
                  path: spec.path,
                  name: spec.name,
                  pageBuilder:
                      (context, state) => _buildMobileNoTransitionPage(
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
        path: '$mobileMoviesPath/:movieNumber',
        name: 'mobile-movie-detail',
        pageBuilder:
            (context, state) => _buildMobileCupertinoPage(
              state: state,
              name: 'mobile-movie-detail',
              child: MobileMovieDetailPage(
                movieNumber: state.pathParameters['movieNumber'] ?? '',
              ),
            ),
      ),
    );
    mobileSubpageRoutes.add(
      GoRoute(
        path: '$mobileActorsPath/:actorId',
        name: 'mobile-actor-detail',
        pageBuilder:
            (context, state) => _buildMobileCupertinoPage(
              state: state,
              name: 'mobile-actor-detail',
              child: MobileActorDetailPage(
                actorId:
                    int.tryParse(state.pathParameters['actorId'] ?? '') ?? 0,
              ),
            ),
      ),
    );
    mobileSubpageRoutes.add(
      GoRoute(
        path: '$mobilePlaylistDetailPathPrefix/:playlistId',
        name: 'mobile-playlist-detail',
        pageBuilder:
            (context, state) => _buildMobileCupertinoPage(
              state: state,
              name: 'mobile-playlist-detail',
              child: MobilePlaylistDetailPage(
                playlistId:
                    int.tryParse(state.pathParameters['playlistId'] ?? '') ?? 0,
              ),
            ),
      ),
    );
    mobileSubpageRoutes.add(
      GoRoute(
        path: mobileSearchPath,
        name: 'mobile-search-empty',
        pageBuilder:
            (context, state) => _buildMobileCupertinoPage(
              state: state,
              name: 'mobile-search-empty',
              child: MobileCatalogSearchPage(
                initialQuery: '',
                initialUseOnlineSearch:
                    DesktopSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).useOnlineSearch,
              ),
            ),
      ),
    );
    mobileSubpageRoutes.add(
      GoRoute(
        path: mobileImageSearchPath,
        name: 'mobile-image-search',
        pageBuilder:
            (context, state) => _buildMobileCupertinoPage(
              state: state,
              name: 'mobile-image-search',
              child: Builder(
                builder: (context) {
                  final routeState =
                      DesktopImageSearchRouteState.maybeFromExtra(state.extra);
                  return DesktopImageSearchPage(
                    fallbackPath: routeState.fallbackPath,
                    initialFileName: routeState.initialFileName,
                    initialFileBytes: routeState.initialFileBytes,
                    initialMimeType: routeState.initialMimeType,
                    currentMovieNumber: routeState.currentMovieNumber,
                    initialCurrentMovieScope:
                        routeState.initialCurrentMovieScope,
                    imagePicker: pickMobileImageSearchFile,
                    onSearchSimilar: (context, item) async {
                      final imageUrl =
                          item.image.origin.trim().isNotEmpty
                              ? item.image.origin.trim()
                              : item.image.bestAvailableUrl;
                      final fileName =
                          'image_search_${item.movieNumber}_${item.thumbnailId}.${guessImageFileExtension(imageUrl)}';
                      try {
                        final imageBytes = await context
                            .read<ApiClient>()
                            .getBytes(imageUrl);
                        if (!context.mounted) {
                          return false;
                        }
                        context.push(
                          mobileImageSearchPath,
                          extra: DesktopImageSearchRouteState(
                            fallbackPath: routeState.fallbackPath,
                            initialFileName: fileName,
                            initialFileBytes: imageBytes,
                            initialMimeType: guessImageMimeType(fileName),
                            currentMovieNumber: item.movieNumber,
                          ),
                        );
                        return true;
                      } catch (error) {
                        if (context.mounted) {
                          showToast(
                            apiErrorMessage(error, fallback: '读取结果图片失败，请稍后重试'),
                          );
                        }
                        return false;
                      }
                    },
                    onOpenPlayer: (context, item) {
                      final routePath = buildMobileMoviePlayerRoutePath(
                        item.movieNumber,
                        mediaId: item.mediaId > 0 ? item.mediaId : null,
                        positionSeconds: item.offsetSeconds,
                      );
                      debugPrint(
                        '[player-debug] mobile_image_search_open_player movie=${item.movieNumber} mediaId=${item.mediaId} offsetSeconds=${item.offsetSeconds} route=$routePath',
                      );
                      context.push(routePath);
                    },
                    onOpenMovieDetail: (context, item) {
                      context.push(
                        buildMobileMovieDetailRoutePath(item.movieNumber),
                        extra: mobileImageSearchPath,
                      );
                    },
                    resultPreviewPresentation:
                        ImageSearchResultPreviewPresentation.bottomDrawer,
                  );
                },
              ),
            ),
      ),
    );
    mobileSubpageRoutes.add(
      GoRoute(
        path: '$mobileSearchPath/:query',
        name: 'mobile-search',
        pageBuilder:
            (context, state) => _buildMobileCupertinoPage(
              state: state,
              name: 'mobile-search',
              child: MobileCatalogSearchPage(
                initialQuery: state.pathParameters['query'] ?? '',
                initialUseOnlineSearch:
                    DesktopSearchRouteState.maybeFromExtra(
                      state.extra,
                    ).useOnlineSearch,
              ),
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
      GoRoute(
        path: '$mobileMoviesPath/:movieNumber/player',
        name: 'mobile-movie-player',
        pageBuilder: (context, state) {
          final movieNumber = state.pathParameters['movieNumber'] ?? '';
          final initialMediaId = int.tryParse(
            state.uri.queryParameters['mediaId'] ?? '',
          );
          final initialPositionSeconds = int.tryParse(
            state.uri.queryParameters['positionSeconds'] ?? '',
          );
          debugPrint(
            '[player-debug] mobile_player_route_build movie=$movieNumber mediaId=$initialMediaId positionSeconds=$initialPositionSeconds uri=${state.uri}',
          );
          return _buildMobileCupertinoPage(
            state: state,
            name: 'mobile-movie-player',
            child: MobileMoviePlayerPage(
              movieNumber: movieNumber,
              initialMediaId: initialMediaId,
              initialPositionSeconds: initialPositionSeconds,
            ),
          );
        },
      ),
    );
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
              bodyPadding: _mobileSubpageBodyPaddingFromPath(state.uri.path),
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

CupertinoPage<void> _buildMobileCupertinoPage({
  required GoRouterState state,
  required String name,
  required Widget child,
}) {
  return CupertinoPage<void>(key: state.pageKey, name: name, child: child);
}

NoTransitionPage<void> _buildMobileNoTransitionPage({
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
  if (path.startsWith('$mobileMoviesPath/')) {
    return '影片详情';
  }
  if (path.startsWith('$mobileActorsPath/')) {
    return '女优详情';
  }
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

EdgeInsets _mobileSubpageBodyPaddingFromPath(String path) {
  if (path.startsWith('$mobileMoviesPath/')) {
    return const EdgeInsets.only(top: AppPageInsets.compact);
  }
  return AppPageInsets.compactStandard;
}
