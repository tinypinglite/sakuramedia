import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
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
    final pageRoot = tester.widget<ColoredBox>(
      find.byKey(const Key('mobile-overview-skeleton-page')),
    );
    expect(tabBar.variant, AppTabBarVariant.mobileTop);
    expect(pageRoot.color, sakuraThemeData.appColors.surfaceCard);
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
    expect(find.text('暂无关注影片'), findsNothing);
    expect(find.text('开发中'), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
    await tester.pumpAndSettle();

    expect(find.text('暂无关注影片'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
    await tester.pumpAndSettle();

    expect(find.text('开发中'), findsOneWidget);
  });

  testWidgets('mobile overview moments tab renders real content', (
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

    await tester.tap(find.text('时刻'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-overview-moments-tab')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-moments-page-total')), findsOneWidget);
    expect(find.text('时刻内容骨架搭建中'), findsNothing);
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

  testWidgets('mobile overview latest movie tap navigates to movie detail', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle);
    Object? movieDetailExtra;
    final router = GoRouter(
      initialLocation: mobileOverviewPath,
      routes: [
        GoRoute(
          path: mobileOverviewPath,
          builder:
              (_, __) => const Scaffold(body: MobileOverviewSkeletonPage()),
        ),
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber',
          builder: (_, state) {
            movieDetailExtra = state.extra;
            return Scaffold(
              body: Text(
                'movie:${state.pathParameters['movieNumber']}',
                textDirection: TextDirection.ltr,
              ),
            );
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

    await tester.tap(find.byKey(const Key('movie-summary-card-ABP-123')));
    await tester.pumpAndSettle();

    expect(find.text('movie:ABP-123'), findsOneWidget);
    expect(movieDetailExtra, mobileOverviewPath);
    expect(router.canPop(), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-overview-tabs')), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('mobile overview follow tab shows error and supports retry', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/subscribed-actors/latest',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/subscribed-actors/latest',
      statusCode: 200,
      body: _followMoviesPageJson(
        page: 1,
        total: 1,
        items: <Map<String, dynamic>>[
          _followMovieItemJson(movieNumber: 'ABP-200', isSubscribed: false),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABP-200',
      statusCode: 200,
      body: _movieDetailJson(movieNumber: 'ABP-200'),
    );
    _enqueueOverviewResponses(bundle);

    await tester.pumpWidget(
      _buildTestApp(
        sessionStore: sessionStore,
        bundle: bundle,
        child: const MobileOverviewSkeletonPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('关注'));
    await tester.pumpAndSettle();
    expect(find.text('关注影片加载失败，请稍后重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-overview-follow-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-follow-movie-card-ABP-200')),
      findsOneWidget,
    );
  });

  testWidgets(
    'mobile overview follow tab loads more and retries failed load more',
    (WidgetTester tester) async {
      final page1Items = List<Map<String, dynamic>>.generate(
        20,
        (index) => _followMovieItemJson(movieNumber: 'ABP-${index + 200}'),
      );
      final page2Items = List<Map<String, dynamic>>.generate(
        10,
        (index) => _followMovieItemJson(movieNumber: 'ABP-${index + 220}'),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/subscribed-actors/latest',
        statusCode: 200,
        body: _followMoviesPageJson(page: 1, total: 30, items: page1Items),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/subscribed-actors/latest',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/subscribed-actors/latest',
        statusCode: 200,
        body: _followMoviesPageJson(page: 2, total: 30, items: page2Items),
      );
      _enqueueFollowMovieDetails(bundle, <String>[
        ...page1Items.map((item) => item['movie_number']! as String),
        ...page2Items.map((item) => item['movie_number']! as String),
      ]);
      _enqueueOverviewResponses(bundle);

      await tester.pumpWidget(
        _buildTestApp(
          sessionStore: sessionStore,
          bundle: bundle,
          child: const MobileOverviewSkeletonPage(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('关注'));
      await tester.pumpAndSettle();

      expect(
        bundle.adapter.hitCount('GET', '/movies/subscribed-actors/latest'),
        1,
      );

      for (var index = 0; index < 6; index += 1) {
        await tester.fling(
          find.byKey(const Key('mobile-overview-follow-list')),
          const Offset(0, -900),
          1500,
        );
        await tester.pumpAndSettle();
      }
      await tester.pumpAndSettle();
      expect(
        bundle.adapter.hitCount('GET', '/movies/subscribed-actors/latest'),
        greaterThanOrEqualTo(2),
      );

      await tester.fling(
        find.byKey(const Key('mobile-overview-follow-list')),
        const Offset(0, -300),
        1200,
      );
      await tester.pumpAndSettle();
      expect(
        bundle.adapter.hitCount('GET', '/movies/subscribed-actors/latest'),
        greaterThanOrEqualTo(3),
      );
      expect(
        find.byKey(const Key('mobile-follow-movie-card-ABP-229')),
        findsOneWidget,
      );
    },
  );

  testWidgets('mobile overview follow tab card tap navigates to movie detail', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/subscribed-actors/latest',
      statusCode: 200,
      body: _followMoviesPageJson(
        page: 1,
        total: 1,
        items: <Map<String, dynamic>>[
          _followMovieItemJson(movieNumber: 'ABP-300', isSubscribed: false),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABP-300',
      statusCode: 200,
      body: _movieDetailJson(movieNumber: 'ABP-300'),
    );
    _enqueueOverviewResponses(bundle);

    Object? movieDetailExtra;
    final router = GoRouter(
      initialLocation: mobileOverviewPath,
      routes: [
        GoRoute(
          path: mobileOverviewPath,
          builder:
              (_, __) => const Scaffold(body: MobileOverviewSkeletonPage()),
        ),
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber',
          builder: (_, state) {
            movieDetailExtra = state.extra;
            return Scaffold(
              body: Text(
                'movie:${state.pathParameters['movieNumber']}',
                textDirection: TextDirection.ltr,
              ),
            );
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
    await tester.tap(find.text('关注'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-follow-movie-card-ABP-300')));
    await tester.pumpAndSettle();
    expect(find.text('movie:ABP-300'), findsOneWidget);
    expect(movieDetailExtra, mobileOverviewPath);
  });

  testWidgets('mobile overview follow tab toggles movie subscription', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/subscribed-actors/latest',
      statusCode: 200,
      body: _followMoviesPageJson(
        page: 1,
        total: 1,
        items: <Map<String, dynamic>>[
          _followMovieItemJson(movieNumber: 'ABP-301', isSubscribed: false),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABP-301',
      statusCode: 200,
      body: _movieDetailJson(movieNumber: 'ABP-301'),
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABP-301/subscription',
      statusCode: 204,
      body: null,
    );
    _enqueueOverviewResponses(bundle);

    await tester.pumpWidget(
      _buildTestApp(
        sessionStore: sessionStore,
        bundle: bundle,
        child: const MobileOverviewSkeletonPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('关注'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('mobile-follow-movie-card-subscription-ABP-301')),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('PUT', '/movies/ABP-301/subscription'), 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('mobile overview follow tab caches detail request per movie', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/subscribed-actors/latest',
      statusCode: 200,
      body: _followMoviesPageJson(
        page: 1,
        total: 1,
        items: <Map<String, dynamic>>[
          _followMovieItemJson(movieNumber: 'ABP-302', isSubscribed: false),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABP-302',
      statusCode: 200,
      body: _movieDetailJson(movieNumber: 'ABP-302'),
    );
    _enqueueOverviewResponses(bundle);

    await tester.pumpWidget(
      _buildTestApp(
        sessionStore: sessionStore,
        bundle: bundle,
        child: const MobileOverviewSkeletonPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('关注'));
    await tester.pumpAndSettle();
    expect(bundle.adapter.hitCount('GET', '/movies/ABP-302'), 1);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关注'));
    await tester.pumpAndSettle();
    expect(bundle.adapter.hitCount('GET', '/movies/ABP-302'), 1);
  });
}

Widget _buildTestApp({
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
      Provider<ApiClient>.value(value: bundle.apiClient),
      Provider<ActorsApi>.value(value: bundle.actorsApi),
      Provider<MoviesApi>.value(value: bundle.moviesApi),
      Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
      Provider<MediaApi>(create: (_) => MediaApi(apiClient: bundle.apiClient)),
    ],
    child: OKToast(
      child: MaterialApp(theme: sakuraThemeData, home: Scaffold(body: child)),
    ),
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
      Provider<ApiClient>.value(value: bundle.apiClient),
      Provider<ActorsApi>.value(value: bundle.actorsApi),
      Provider<MoviesApi>.value(value: bundle.moviesApi),
      Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
      Provider<MediaApi>(create: (_) => MediaApi(apiClient: bundle.apiClient)),
    ],
    child: OKToast(
      child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
    ),
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
    path: '/movies/subscribed-actors/latest',
    statusCode: 200,
    body: _followMoviesPageJson(
      page: 1,
      total: 0,
      items: const <Map<String, dynamic>>[],
    ),
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
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-points',
    statusCode: 200,
    body: <String, dynamic>{
      'items': [
        <String, dynamic>{
          'point_id': 10,
          'media_id': 456,
          'movie_number': 'ABP-123',
          'thumbnail_id': 1,
          'offset_seconds': 120,
          'image': <String, dynamic>{
            'id': 10,
            'origin': '/thumb-1.webp',
            'small': '/thumb-1.webp',
            'medium': '/thumb-1.webp',
            'large': '/thumb-1.webp',
          },
          'created_at': '2026-03-12T10:00:00Z',
        },
      ],
      'page': 1,
      'page_size': 20,
      'total': 1,
    },
  );
}

Map<String, dynamic> _followMoviesPageJson({
  required int page,
  required int total,
  required List<Map<String, dynamic>> items,
}) {
  return <String, dynamic>{
    'items': items,
    'page': page,
    'page_size': 20,
    'total': total,
  };
}

Map<String, dynamic> _followMovieItemJson({
  required String movieNumber,
  bool isSubscribed = false,
  bool canPlay = true,
}) {
  return <String, dynamic>{
    'javdb_id': 'Movie-$movieNumber',
    'movie_number': movieNumber,
    'title': 'Title $movieNumber',
    'cover_image': null,
    'release_date': '2026-03-10',
    'duration_minutes': 120,
    'is_subscribed': isSubscribed,
    'can_play': canPlay,
  };
}

Map<String, dynamic> _movieDetailJson({required String movieNumber}) {
  return <String, dynamic>{
    'javdb_id': 'Movie-$movieNumber',
    'movie_number': movieNumber,
    'title': 'Detail $movieNumber',
    'cover_image': <String, dynamic>{
      'id': 1,
      'origin': '/files/images/movies/$movieNumber/cover.jpg',
      'small': '/files/images/movies/$movieNumber/cover-small.jpg',
      'medium': '/files/images/movies/$movieNumber/cover-medium.jpg',
      'large': '/files/images/movies/$movieNumber/cover-large.jpg',
    },
    'release_date': '2026-03-10',
    'duration_minutes': 120,
    'score': 0.0,
    'watched_count': 0,
    'want_watch_count': 0,
    'comment_count': 0,
    'score_number': 0,
    'is_collection': false,
    'is_subscribed': false,
    'can_play': true,
    'series_name': null,
    'summary': 'summary $movieNumber',
    'actors': const <Map<String, dynamic>>[],
    'tags': const <Map<String, dynamic>>[],
    'thin_cover_image': <String, dynamic>{
      'id': 2,
      'origin': '/files/images/movies/$movieNumber/thin.jpg',
      'small': '/files/images/movies/$movieNumber/thin-small.jpg',
      'medium': '/files/images/movies/$movieNumber/thin-medium.jpg',
      'large': '/files/images/movies/$movieNumber/thin-large.jpg',
    },
    'plot_images': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 3,
        'origin': '/files/images/movies/$movieNumber/plot-1.jpg',
        'small': '/files/images/movies/$movieNumber/plot-1-small.jpg',
        'medium': '/files/images/movies/$movieNumber/plot-1-medium.jpg',
        'large': '/files/images/movies/$movieNumber/plot-1-large.jpg',
      },
    ],
    'media_items': const <Map<String, dynamic>>[],
    'playlists': const <Map<String, dynamic>>[],
  };
}

void _enqueueFollowMovieDetails(
  TestApiBundle bundle,
  List<String> movieNumbers,
) {
  for (final movieNumber in movieNumbers) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/$movieNumber',
      statusCode: 200,
      body: _movieDetailJson(movieNumber: movieNumber),
    );
  }
}
