import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/downloads/presentation/pages/mobile/download_tasks_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_registry.dart';
import 'package:sakuramedia/routes/app_routes.dart';

void main() {
  test('desktop fallback metadata only accepts desktop paths', () {
    expect(
      AppRouteExtra.fallbackPathOf(
        const AppRouteExtra(fallbackPath: '/desktop/library/movies'),
        platform: AppPlatform.desktop,
      ),
      '/desktop/library/movies',
    );
    expect(
      AppRouteExtra.fallbackPathOf(
        const AppRouteExtra(fallbackPath: '/mobile/overview'),
        platform: AppPlatform.desktop,
      ),
      isNull,
    );
    expect(
      AppRouteExtra.fallbackPathOf(
        '/desktop/library/actors',
        platform: AppPlatform.desktop,
      ),
      '/desktop/library/actors',
    );
    expect(
      AppRouteExtra.fallbackPathOf(
        '/mobile/library/actors',
        platform: AppPlatform.mobile,
      ),
      '/mobile/library/actors',
    );
  });

  test('path parameters are URI encoded', () {
    expect(
      DesktopRoutes.movieDetail(movieNumber: 'ABC 001').path,
      '/desktop/library/movies/ABC%20001',
    );
  });

  testWidgets('desktop detail targets keep fallback metadata in route extra', (
    tester,
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
        for (final path in <String>[
          '/desktop/library/movies/:movieNumber',
          '/desktop/library/movies/series/:seriesId',
          '/desktop/library/actors/:actorId',
          '/desktop/library/playlists/:playlistId',
          '/desktop/library/movies/:movieNumber/player',
          '/desktop/search',
          '/desktop/search/:query',
        ])
          GoRoute(
            path: path,
            builder: (context, state) {
              routeExtra = state.extra;
              return const SizedBox.shrink();
            },
          ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    Future<void> reset() async {
      router.go('/home');
      await tester.pumpAndSettle();
      routeExtra = null;
    }

    await _pushAndSettle(
      tester,
      router,
      () => DesktopRoutes.movieDetail(
        movieNumber: 'ABC-001',
        fallbackPath: '/desktop/library/movies',
      ).push(actionContext),
    );
    expect(routeExtra, isA<AppRouteExtra>());
    expect(
      (routeExtra! as AppRouteExtra).fallbackPath,
      '/desktop/library/movies',
    );

    await reset();
    await _pushAndSettle(
      tester,
      router,
      () => DesktopRoutes.movieSeries(
        seriesId: 7,
        fallbackPath: '/desktop/library/movies/ABC-001',
      ).push(actionContext),
    );
    expect(
      (routeExtra! as AppRouteExtra).fallbackPath,
      '/desktop/library/movies/ABC-001',
    );

    await reset();
    await _pushAndSettle(
      tester,
      router,
      () => DesktopRoutes.actorDetail(
        actorId: 1,
        fallbackPath: '/desktop/search/舞雪',
      ).push(actionContext),
    );
    expect((routeExtra! as AppRouteExtra).fallbackPath, '/desktop/search/舞雪');

    await reset();
    await _pushAndSettle(
      tester,
      router,
      () => DesktopRoutes.playlistDetail(
        playlistId: 8,
        fallbackPath: '/desktop/library/movies/ABC-001',
      ).push(actionContext),
    );
    expect(
      (routeExtra! as AppRouteExtra).fallbackPath,
      '/desktop/library/movies/ABC-001',
    );

    await reset();
    await _pushAndSettle(
      tester,
      router,
      () => DesktopRoutes.moviePlayer(
        movieNumber: 'ABC-001',
        fallbackPath: '/desktop/library/movies/ABC-001',
        mediaId: 100,
      ).push(actionContext),
    );
    expect(
      (routeExtra! as AppRouteExtra).fallbackPath,
      '/desktop/library/movies/ABC-001',
    );
  });

  testWidgets(
    'desktop search target keeps fallback for empty and query routes',
    (tester) async {
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

      DesktopRoutes.search(
        query: '',
        fallbackPath: '/desktop/library/movies',
        useOnlineSearch: true,
      ).push(actionContext);
      await tester.pumpAndSettle();
      expect(
        (routeExtra! as AppRouteExtra).fallbackPath,
        '/desktop/library/movies',
      );
      expect(
        Uri.parse(
          router.routeInformationProvider.value.uri.toString(),
        ).queryParameters['useOnlineSearch'],
        'true',
      );

      router.go('/home');
      await tester.pumpAndSettle();
      DesktopRoutes.search(
        query: 'ssni888',
        fallbackPath: '/desktop/library/actors',
      ).push(actionContext);
      await tester.pumpAndSettle();
      expect(
        (routeExtra! as AppRouteExtra).fallbackPath,
        '/desktop/library/actors',
      );
    },
  );

  testWidgets('mobile download tasks uses camelCase and accepts legacy alias', (
    tester,
  ) async {
    late BuildContext actionContext;
    late BuildContext routeContext;
    late GoRouterState routeState;
    const downloadsPath = '/mobile/system/download-tasks';
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
          path: downloadsPath,
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

    MobileRoutes.downloadTasks(movieNumber: 'SSIS-801').go(actionContext);
    await tester.pumpAndSettle();
    final uri = router.routeInformationProvider.value.uri;
    expect(uri.queryParameters['downloadMovieNumber'], 'SSIS-801');
    expect(uri.queryParameters.containsKey('download-movie-number'), isFalse);

    router.go('$downloadsPath?download-movie-number=SSIS-801');
    await tester.pumpAndSettle();
    final page = appRoutes
        .byId(AppRouteId.mobileDownloadTasks)
        .pageBuilder(routeContext, routeState);
    expect(page, isA<MobileDownloadTasksPage>());
    expect(
      (page as MobileDownloadTasksPage).initialDownloadMovieNumber,
      'SSIS-801',
    );
  });

  testWidgets('mobile series target carries fallback metadata', (tester) async {
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
          path: '/mobile/library/movies/series/:seriesId',
          builder: (context, state) {
            routeExtra = state.extra;
            return const SizedBox.shrink();
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _pushAndSettle(
      tester,
      router,
      () => MobileRoutes.movieSeries(
        seriesId: 7,
        fallbackPath: '/mobile/library/movies/ABC-001',
      ).push(actionContext),
    );
    expect(
      (routeExtra! as AppRouteExtra).fallbackPath,
      '/mobile/library/movies/ABC-001',
    );
  });
}

Future<void> _pushAndSettle(
  WidgetTester tester,
  GoRouter router,
  VoidCallback action,
) async {
  action();
  await tester.pumpAndSettle();
  expect(router.routeInformationProvider.value.uri.path, isNotEmpty);
}
