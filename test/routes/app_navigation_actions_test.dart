import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/movie_player_page.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/desktop_navigation_route_state.dart';
import 'package:sakuramedia/routes/desktop_routes.dart';
import 'package:sakuramedia/routes/desktop_search_route_state.dart';

void main() {
  testWidgets('desktop detail actions keep fallback metadata in route extra', (
    WidgetTester tester,
  ) async {
    Object? routeExtra;
    late BuildContext actionContext;
    final router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          builder: (context, state) => Builder(
            builder: (context) {
              actionContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
        GoRoute(
          path: '/desktop/library/movies/:movieNumber',
          builder: (context, state) {
            routeExtra = state.extra;
            return const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: '/desktop/library/movies/series/:seriesId',
          builder: (context, state) {
            routeExtra = state.extra;
            return const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: '/desktop/library/actors/:actorId',
          builder: (context, state) {
            routeExtra = state.extra;
            return const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: '/desktop/library/playlists/:playlistId',
          builder: (context, state) {
            routeExtra = state.extra;
            return const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: '/desktop/library/movies/:movieNumber/player',
          builder: (context, state) {
            routeExtra = state.extra;
            return const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: '/desktop/search',
          builder: (context, state) {
            routeExtra = state.extra;
            return const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: '/desktop/search/:query',
          builder: (context, state) {
            routeExtra = state.extra;
            return const SizedBox.shrink();
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    Future<void> resetToHome() async {
      router.go('/home');
      await tester.pumpAndSettle();
      routeExtra = null;
    }

    await _pushAndSettle(
      tester,
      router,
      () => actionContext.pushDesktopMovieDetail(
        movieNumber: 'ABC-001',
        fallbackPath: '/desktop/library/movies',
      ),
    );
    expect(routeExtra, isA<DesktopNavigationRouteState>());
    expect(
      (routeExtra! as DesktopNavigationRouteState).fallbackPath,
      '/desktop/library/movies',
    );

    await resetToHome();
    await _pushAndSettle(
      tester,
      router,
      () => actionContext.pushDesktopMovieSeries(
        seriesId: 7,
        fallbackPath: '/desktop/library/movies/ABC-001',
      ),
    );
    expect(
      (routeExtra! as DesktopNavigationRouteState).fallbackPath,
      '/desktop/library/movies/ABC-001',
    );

    await resetToHome();
    await _pushAndSettle(
      tester,
      router,
      () => actionContext.pushDesktopActorDetail(
        actorId: 1,
        fallbackPath: '/desktop/search/舞雪',
      ),
    );
    expect(
      (routeExtra! as DesktopNavigationRouteState).fallbackPath,
      '/desktop/search/舞雪',
    );

    await resetToHome();
    await _pushAndSettle(
      tester,
      router,
      () => actionContext.pushDesktopPlaylistDetail(
        playlistId: 8,
        fallbackPath: '/desktop/library/movies/ABC-001',
      ),
    );
    expect(
      (routeExtra! as DesktopNavigationRouteState).fallbackPath,
      '/desktop/library/movies/ABC-001',
    );

    await resetToHome();
    await _pushAndSettle(
      tester,
      router,
      () => actionContext.pushDesktopMoviePlayer(
        movieNumber: 'ABC-001',
        fallbackPath: '/desktop/library/movies/ABC-001',
        mediaId: 100,
      ),
    );
    expect(
      (routeExtra! as DesktopNavigationRouteState).fallbackPath,
      '/desktop/library/movies/ABC-001',
    );
  });

  testWidgets(
    'desktop search action keeps fallback state for empty and query routes',
    (WidgetTester tester) async {
      Object? routeExtra;
      late BuildContext actionContext;
      final router = GoRouter(
        initialLocation: '/home',
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (context, state) => Builder(
              builder: (context) {
                actionContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
          GoRoute(
            path: '/desktop/search',
            builder: (context, state) {
              routeExtra = state.extra;
              return const SizedBox.shrink();
            },
          ),
          GoRoute(
            path: '/desktop/search/:query',
            builder: (context, state) {
              routeExtra = state.extra;
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      actionContext.pushDesktopSearch(
        query: '',
        fallbackPath: '/desktop/library/movies',
        useOnlineSearch: true,
      );
      await tester.pumpAndSettle();
      expect(routeExtra, isA<DesktopSearchRouteState>());
      expect(
        (routeExtra! as DesktopSearchRouteState).fallbackPath,
        '/desktop/library/movies',
      );
      expect((routeExtra! as DesktopSearchRouteState).useOnlineSearch, isTrue);

      router.go('/home');
      await tester.pumpAndSettle();
      actionContext.pushDesktopSearch(
        query: 'ssni888',
        fallbackPath: '/desktop/library/actors',
      );
      await tester.pumpAndSettle();
      expect(routeExtra, isA<DesktopSearchRouteState>());
      expect(
        (routeExtra! as DesktopSearchRouteState).fallbackPath,
        '/desktop/library/actors',
      );
      expect((routeExtra! as DesktopSearchRouteState).useOnlineSearch, isFalse);
    },
  );

  testWidgets(
    'desktop player route reads only valid desktop fallback metadata',
    (WidgetTester tester) async {
      late BuildContext routeContext;
      late GoRouterState routeState;
      const playerPath = '/desktop/library/movies/ABC-001/player';
      final router = GoRouter(
        initialLocation: playerPath,
        routes: <RouteBase>[
          GoRoute(
            path: playerPath,
            builder: (context, state) {
              routeContext = context;
              routeState = state;
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final route = const DesktopMoviePlayerRouteData(movieNumber: 'ABC-001');

      router.go(
        playerPath,
        extra: const DesktopNavigationRouteState(
          fallbackPath: '/desktop/library/movies',
        ),
      );
      await tester.pumpAndSettle();
      final validPage = route.buildContent(routeContext, routeState);
      expect(validPage, isA<DesktopMoviePlayerPage>());
      expect(
        (validPage as DesktopMoviePlayerPage).fallbackPath,
        '/desktop/library/movies',
      );

      router.go(
        playerPath,
        extra: const DesktopNavigationRouteState(
          fallbackPath: '/mobile/overview',
        ),
      );
      await tester.pumpAndSettle();
      final invalidPage = route.buildContent(routeContext, routeState);
      expect(invalidPage, isA<DesktopMoviePlayerPage>());
      expect((invalidPage as DesktopMoviePlayerPage).fallbackPath, isNull);
    },
  );
}

Future<void> _pushAndSettle(
  WidgetTester tester,
  GoRouter router,
  VoidCallback action,
) async {
  action();
  await tester.pumpAndSettle();
  expect(
    router.routeInformationProvider.value.uri.path,
    startsWith('/desktop/'),
  );
}
