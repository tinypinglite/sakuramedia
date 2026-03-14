import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/overview/presentation/mobile_overview_skeleton_page.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/search/presentation/mobile_catalog_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    debugMobileImageSearchFilePicker = null;
    bundle.dispose();
  });

  testWidgets('mobile overview page uses AppTabBar mobileTop variant', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle);

    await tester.pumpWidget(
      _buildTestApp(
        sessionStore: sessionStore,
        bundle: bundle,
        child: const MobileOverviewSkeletonPage(),
      ),
    );
    await tester.pumpAndSettle();

    final tabBar = tester.widget<AppTabBar>(
      find.byKey(const Key('mobile-overview-tabs')),
    );
    expect(tabBar.variant, AppTabBarVariant.mobileTop);
  });

  testWidgets('mobile overview supports swipe to switch tabs', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle);

    await tester.pumpWidget(
      _buildTestApp(
        sessionStore: sessionStore,
        bundle: bundle,
        child: const MobileOverviewSkeletonPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近添加'), findsOneWidget);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('关注内容骨架搭建中'), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
    await tester.pumpAndSettle();

    expect(find.text('关注内容骨架搭建中'), findsOneWidget);
  });

  testWidgets('mobile overview search submits to mobile search route', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'abp123',
        'parsed': true,
        'movie_number': 'ABP-123',
        'reason': null,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/search/local',
      body: <Map<String, dynamic>>[],
    );
    final router = GoRouter(
      initialLocation: mobileOverviewPath,
      routes: [
        GoRoute(
          path: mobileOverviewPath,
          builder:
              (_, __) => const Scaffold(body: MobileOverviewSkeletonPage()),
        ),
        GoRoute(
          path: mobileSearchPath,
          builder:
              (_, __) => const Scaffold(
                body: MobileCatalogSearchPage(initialQuery: ''),
              ),
        ),
        GoRoute(
          path: '$mobileSearchPath/:query',
          builder:
              (_, state) => Scaffold(
                body: MobileCatalogSearchPage(
                  initialQuery: state.pathParameters['query'] ?? '',
                ),
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _buildRouterApp(
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('mobile-overview-my-search-input')),
      'abp123',
    );
    await tester.tap(find.byKey(const Key('mobile-overview-my-search-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog-search-page-input')), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('mobile overview image search opens route with picked image', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle);
    debugMobileImageSearchFilePicker =
        () async => ImageSearchPickedFile(
          bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
          fileName: 'picked.png',
          mimeType: 'image/png',
        );
    Object? routeExtra;
    final router = GoRouter(
      initialLocation: mobileOverviewPath,
      routes: [
        GoRoute(
          path: mobileOverviewPath,
          builder:
              (_, __) => const Scaffold(body: MobileOverviewSkeletonPage()),
        ),
        GoRoute(
          path: mobileImageSearchPath,
          builder: (_, state) {
            routeExtra = state.extra;
            return const Scaffold(body: Text('mobile-image-search'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _buildRouterApp(
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-my-search-image')));
    await tester.pumpAndSettle();

    expect(find.text('mobile-image-search'), findsOneWidget);
    expect(router.canPop(), isTrue);
    final routeState = routeExtra as DesktopImageSearchRouteState;
    expect(routeState.fallbackPath, mobileOverviewPath);
    expect(routeState.initialFileName, 'picked.png');
    expect(routeState.initialMimeType, 'image/png');
    expect(routeState.initialFileBytes, isNotNull);
    expect(routeState.initialFileBytes!, const <int>[1, 2, 3, 4]);
  });

  testWidgets(
    'mobile overview playlist tap navigates to playlist detail route',
    (WidgetTester tester) async {
      _enqueueOverviewResponses(bundle);
      final router = GoRouter(
        initialLocation: mobileOverviewPath,
        routes: [
          GoRoute(
            path: mobileOverviewPath,
            builder:
                (_, __) => const Scaffold(body: MobileOverviewSkeletonPage()),
          ),
          GoRoute(
            path: '$mobileOverviewPath/playlists/:playlistId',
            builder:
                (_, state) => Scaffold(
                  body: Text(
                    'playlist:${state.pathParameters['playlistId']}',
                    textDirection: TextDirection.ltr,
                  ),
                ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _buildRouterApp(
          sessionStore: sessionStore,
          bundle: bundle,
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mobile-overview-playlist-1')));
      await tester.pumpAndSettle();

      expect(find.text('playlist:1'), findsOneWidget);
      expect(router.canPop(), isTrue);
    },
  );

  testWidgets(
    'mobile overview playlist entry supports system back to overview',
    (WidgetTester tester) async {
      _enqueueOverviewResponses(bundle);
      final router = GoRouter(
        initialLocation: mobileOverviewPath,
        routes: [
          GoRoute(
            path: mobileOverviewPath,
            builder:
                (_, __) => const Scaffold(body: MobileOverviewSkeletonPage()),
          ),
          GoRoute(
            path: '$mobileOverviewPath/playlists/:playlistId',
            builder:
                (_, state) => Scaffold(
                  body: Text(
                    'playlist:${state.pathParameters['playlistId']}',
                    textDirection: TextDirection.ltr,
                  ),
                ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _buildRouterApp(
          sessionStore: sessionStore,
          bundle: bundle,
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mobile-overview-playlist-1')));
      await tester.pumpAndSettle();
      expect(find.text('playlist:1'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mobile-overview-my-search-input')),
        findsOneWidget,
      );
      expect(router.canPop(), isFalse);
    },
  );

  testWidgets(
    'mobile overview image search keeps page when picker is cancelled',
    (WidgetTester tester) async {
      _enqueueOverviewResponses(bundle);
      debugMobileImageSearchFilePicker = () async => null;
      final router = GoRouter(
        initialLocation: mobileOverviewPath,
        routes: [
          GoRoute(
            path: mobileOverviewPath,
            builder:
                (_, __) => const Scaffold(body: MobileOverviewSkeletonPage()),
          ),
          GoRoute(
            path: mobileImageSearchPath,
            builder:
                (_, state) => const Scaffold(body: Text('mobile-image-search')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _buildRouterApp(
          sessionStore: sessionStore,
          bundle: bundle,
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('mobile-overview-my-search-image')),
      );
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        mobileOverviewPath,
      );
      expect(find.text('mobile-image-search'), findsNothing);
    },
  );
}

Widget _buildTestApp({
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
      Provider<ActorsApi>.value(value: bundle.actorsApi),
      Provider<MoviesApi>.value(value: bundle.moviesApi),
      Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
    ],
    child: MaterialApp(theme: sakuraThemeData, home: Scaffold(body: child)),
  );
}

Widget _buildRouterApp({
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  required GoRouter router,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
      Provider<ActorsApi>.value(value: bundle.actorsApi),
      Provider<MoviesApi>.value(value: bundle.moviesApi),
      Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
    ],
    child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
  );
}

void _enqueueOverviewResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/latest',
    statusCode: 200,
    body: <String, dynamic>{
      'items': [
        <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABP-123',
          'title': 'Movie 1',
          'cover_image': null,
          'release_date': null,
          'duration_minutes': 120,
          'is_subscribed': false,
          'can_play': true,
        },
      ],
      'page': 1,
      'page_size': 12,
      'total': 1,
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/playlists',
    statusCode: 200,
    body: [
      <String, dynamic>{
        'id': 1,
        'name': '最近观看',
        'kind': 'recently_watched',
        'description': '',
        'is_system': true,
        'is_mutable': false,
        'is_deletable': false,
        'movie_count': 0,
        'created_at': null,
        'updated_at': null,
      },
    ],
  );
}
