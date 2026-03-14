import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/app_state.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';

import '../support/test_api_bundle.dart';

void main() {
  test('desktop navigation tree contains moments entry', () {
    expect(desktopNavGroups.length, 6);
    expect(desktopNavGroups.map((group) => group.label), [
      '概览',
      '影片',
      '女优',
      '时刻',
      '播放列表',
      '配置管理',
    ]);
    expect(desktopRouteSpecs.map((spec) => spec.path), [
      desktopOverviewPath,
      desktopMoviesPath,
      desktopActorsPath,
      desktopMomentsPath,
      desktopPlaylistsPath,
      desktopConfigurationPath,
    ]);
  });

  test('mobile navigation tree contains expected skeleton entries', () {
    expect(mobileNavGroups.length, 4);
    expect(mobileNavGroups.map((group) => group.label), [
      '概览',
      '影片',
      '女优',
      '榜单',
    ]);
    expect(mobileRouteSpecs.map((spec) => spec.path), [
      mobileOverviewPath,
      mobileMoviesPath,
      mobileActorsPath,
      mobileRankingsPath,
    ]);
  });

  test('web route placeholders remain intact', () {
    expect(webRouteSpecs.length, greaterThan(1));
    expect(
      webRouteSpecs.any((spec) => spec.path.endsWith('/system/ui-kit')),
      isTrue,
    );
  });

  test('desktop top bar config disables back on overview', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: desktopOverviewPath,
      routeSpecs: desktopRouteSpecs,
    );

    expect(config.title, '概览');
    expect(config.fallbackPath, isNull);
    expect(config.isBackEnabled, isFalse);
  });

  test('desktop top bar config enables back on movie detail', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/movies/ABC-001',
      routeSpecs: desktopRouteSpecs,
    );

    expect(config.title, '影片详情');
    expect(config.fallbackPath, desktopOverviewPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config prefers origin path from route extra', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/movies/ABC-001',
      routeSpecs: desktopRouteSpecs,
      routeExtra: '/desktop/library/movies',
    );

    expect(config.fallbackPath, '/desktop/library/movies');
  });

  test('desktop top bar config enables back on actor detail', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/actors/1',
      routeSpecs: desktopRouteSpecs,
    );

    expect(config.title, '女优详情');
    expect(config.fallbackPath, desktopActorsPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config enables back on playlist detail', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/playlists/8',
      routeSpecs: desktopRouteSpecs,
    );

    expect(config.title, '播放列表详情');
    expect(config.fallbackPath, desktopPlaylistsPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config prefers origin path on playlist detail', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/playlists/8',
      routeSpecs: desktopRouteSpecs,
      routeExtra: desktopMoviesPath,
    );

    expect(config.fallbackPath, desktopMoviesPath);
  });

  test(
    'desktop top bar config prefers movie detail origin on actor detail',
    () {
      final config = resolveDesktopTopBarConfig(
        currentPath: '/desktop/library/actors/1',
        routeSpecs: desktopRouteSpecs,
        routeExtra: '/desktop/library/movies/ABC-001',
      );

      expect(config.fallbackPath, '/desktop/library/movies/ABC-001');
    },
  );

  test('desktop top bar config enables back on search route', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/search/ssni888',
      routeSpecs: desktopRouteSpecs,
    );

    expect(config.title, 'ssni888');
    expect(config.fallbackPath, desktopOverviewPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config prefers origin path on search route', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/search/ssni888',
      routeSpecs: desktopRouteSpecs,
      routeExtra: desktopMoviesPath,
    );

    expect(config.title, 'ssni888');
    expect(config.fallbackPath, desktopMoviesPath);
  });

  test(
    'desktop top bar config reads fallback path from search route state',
    () {
      final config = resolveDesktopTopBarConfig(
        currentPath: '/desktop/search/ssni888',
        routeSpecs: desktopRouteSpecs,
        routeExtra: const DesktopSearchRouteState(
          fallbackPath: desktopMoviesPath,
          useOnlineSearch: true,
        ),
      );

      expect(config.title, 'ssni888');
      expect(config.fallbackPath, desktopMoviesPath);
    },
  );

  test('desktop top bar config decodes encoded search title', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/search/%E4%BC%8A%E8%97%A4%E8%88%9E%E9%9B%AA',
      routeSpecs: desktopRouteSpecs,
    );

    expect(config.title, '伊藤舞雪');
    expect(config.fallbackPath, desktopOverviewPath);
  });

  test('desktop top bar config enables back on image search route', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: desktopImageSearchPath,
      routeSpecs: desktopRouteSpecs,
      routeExtra: const DesktopImageSearchRouteState(
        fallbackPath: desktopMoviesPath,
      ),
    );

    expect(config.title, '以图搜图');
    expect(config.fallbackPath, desktopMoviesPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config keeps literal percent in invalid title', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/search/Rio %',
      routeSpecs: desktopRouteSpecs,
    );

    expect(config.title, 'Rio %');
    expect(config.fallbackPath, desktopOverviewPath);
  });

  test('desktop shell layout resolves route spec layout', () {
    final layout = resolveDesktopShellLayout(
      currentPath: desktopOverviewPath,
      routeSpecs: desktopRouteSpecs,
    );

    expect(layout, AppShellLayout.standard);
  });

  test('desktop shell layout keeps movie detail on standard inset layout', () {
    final layout = resolveDesktopShellLayout(
      currentPath: '/desktop/library/movies/ABC-001',
      routeSpecs: desktopRouteSpecs,
    );

    expect(layout, AppShellLayout.standard);
  });

  test('desktop shell layout keeps actor detail on standard inset layout', () {
    final layout = resolveDesktopShellLayout(
      currentPath: '/desktop/library/actors/1',
      routeSpecs: desktopRouteSpecs,
    );

    expect(layout, AppShellLayout.standard);
  });

  test('desktop movie player route helper encodes query parameters', () {
    expect(
      buildDesktopMoviePlayerRoutePath('ABC-001', mediaId: 100),
      '/desktop/library/movies/ABC-001/player?mediaId=100',
    );
    expect(
      buildDesktopMoviePlayerRoutePath(
        'ABC-001',
        mediaId: 100,
        positionSeconds: 61,
      ),
      '/desktop/library/movies/ABC-001/player?mediaId=100&positionSeconds=61',
    );
    expect(
      buildDesktopMoviePlayerRoutePath('ABC-001'),
      '/desktop/library/movies/ABC-001/player',
    );
  });

  testWidgets('desktop overview route uses NoTransitionPage', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    final overviewPage = _findPageByName(
      tester,
      desktopRouteSpecs
          .firstWhere((spec) => spec.path == desktopOverviewPath)
          .name,
    );

    expect(overviewPage, isA<NoTransitionPage<void>>());
  });

  testWidgets('desktop actors route uses NoTransitionPage', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 24,
        'total': 0,
      },
    );
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    router.go(desktopActorsPath);
    await tester.pumpAndSettle();

    final actorsPage = _findPageByName(
      tester,
      desktopRouteSpecs
          .firstWhere((spec) => spec.path == desktopActorsPath)
          .name,
    );

    expect(actorsPage, isA<NoTransitionPage<void>>());
    expect(find.text('女优'), findsWidgets);
  });

  testWidgets('desktop detail route uses NoTransitionPage inside shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueMovieDetailResponse(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go('/desktop/library/movies/ABC-001');
    await tester.pumpAndSettle();

    final detailPage = _findPageByName(tester, 'desktop-movie-detail');

    expect(detailPage, isA<NoTransitionPage<void>>());
  });

  testWidgets('desktop search route uses NoTransitionPage inside shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
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
      method: 'POST',
      path: '/movies/search/javdb/stream',
      body: <Map<String, dynamic>>[],
    );
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go('/desktop/search/abp123');
    await tester.pumpAndSettle();

    final searchPage = _findPageByName(tester, 'desktop-search');

    expect(searchPage, isA<NoTransitionPage<void>>());
  });

  testWidgets('desktop image search route uses NoTransitionPage inside shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go(
      desktopImageSearchPath,
      extra: const DesktopImageSearchRouteState(
        fallbackPath: desktopMoviesPath,
      ),
    );
    await tester.pumpAndSettle();

    final imageSearchPage = _findPageByName(tester, 'desktop-image-search');

    expect(imageSearchPage, isA<NoTransitionPage<void>>());
    expect(find.text('以图搜图'), findsWidgets);
  });

  testWidgets('desktop search route accepts search route state extra', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
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
    bundle.adapter.enqueueSse(
      method: 'POST',
      path: '/movies/search/javdb/stream',
      chunks: <String>[
        'event: completed\n'
            'data: {"success":true,"movies":[],"failed_items":[],"stats":{"total":0,"created_count":0,"already_exists_count":0,"failed_count":0}}\n\n',
      ],
    );
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go(
      '/desktop/search/abp123',
      extra: const DesktopSearchRouteState(
        fallbackPath: desktopMoviesPath,
        useOnlineSearch: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
  });

  testWidgets('desktop search route accepts query containing percent sign', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'Rio %',
        'parsed': false,
        'movie_number': null,
        'reason': 'movie_number_not_found',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/search/local',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'javdb_id': 'ActorA1',
          'name': 'Rio',
          'alias_name': 'Rio %',
          'profile_image': null,
          'is_subscribed': false,
        },
      ],
    );
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go(buildDesktopSearchRoutePath('Rio %'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('actor-summary-grid')), findsOneWidget);
    expect(find.text('Rio %'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop actor detail route uses NoTransitionPage inside shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueActorDetailResponse(bundle);
    _enqueueActorMoviesResponse(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go('/desktop/library/actors/1');
    await tester.pumpAndSettle();

    final detailPage = _findPageByName(tester, 'desktop-actor-detail');

    expect(detailPage, isA<NoTransitionPage<void>>());
  });

  testWidgets(
    'desktop playlist detail route uses NoTransitionPage inside shell',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueDesktopOverviewResponses(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/8',
        body: <String, dynamic>{
          'id': 8,
          'name': '我的收藏',
          'kind': 'custom',
          'description': 'Favorite movies',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 1,
          'created_at': '2026-03-12T10:10:00Z',
          'updated_at': '2026-03-12T11:20:00Z',
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/8/movies',
        body: <String, dynamic>{
          'items': const <Map<String, dynamic>>[],
          'page': 1,
          'page_size': 24,
          'total': 0,
        },
      );
      final router = buildDesktopRouter(sessionStore: sessionStore);

      await _pumpRouterApp(
        tester,
        router: router,
        sessionStore: sessionStore,
        bundle: bundle,
        includeShellController: true,
      );
      await tester.pumpAndSettle();

      router.go('/desktop/library/playlists/8');
      await tester.pumpAndSettle();

      final detailPage = _findPageByName(tester, 'desktop-playlist-detail');

      expect(detailPage, isA<NoTransitionPage<void>>());
    },
  );

  testWidgets('desktop login route uses NoTransitionPage', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    final loginPage = _findPageByName(tester, 'login');

    expect(loginPage, isA<NoTransitionPage<void>>());
  });

  testWidgets('mobile overview route keeps default page transition type', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    final overviewPage = _findPageByName(
      tester,
      mobileRouteSpecs
          .firstWhere((spec) => spec.path == mobileOverviewPath)
          .name,
    );

    expect(overviewPage, isNot(isA<NoTransitionPage<void>>()));
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const Key('mobile-overview-tabs')), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('关注'), findsOneWidget);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('时刻'), findsOneWidget);
    expect(find.text('热评'), findsNothing);
  });

  testWidgets('desktop router redirects root to overview', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ChangeNotifierProvider(create: (_) => AppShellController()),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      desktopOverviewPath,
    );
    expect(find.text('概览'), findsWidgets);
  });

  testWidgets('unauthenticated user is redirected to /login', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ChangeNotifierProvider(create: (_) => AppShellController()),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, loginPath);
    expect(find.byKey(const Key('login-form-base-url')), findsOneWidget);
  });

  testWidgets('authenticated user visiting /login is redirected to overview', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ChangeNotifierProvider(create: (_) => AppShellController()),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go(loginPath);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, desktopOverviewPath);
    expect(find.byKey(const Key('overview-stat-movies-total')), findsOneWidget);
  });

  testWidgets('authenticated user can access protected mobile routes', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/mobile/library/movies');
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/mobile/library/movies',
    );
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
    expect(find.text('影片'), findsWidgets);
    expect(find.byKey(const Key('login-form-base-url')), findsNothing);
  });

  testWidgets('mobile bottom navigation switches between skeleton routes', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('女优').last);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, mobileActorsPath);
    expect(find.text('路径: $mobileActorsPath'), findsOneWidget);
  });

  testWidgets('desktop router opens movie detail route inside shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueMovieDetailResponse(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ChangeNotifierProvider(create: (_) => AppShellController()),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/desktop/library/movies/ABC-001');
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/movies/ABC-001',
    );
    expect(find.byKey(const Key('app-topbar-title')), findsOneWidget);
    expect(find.text('影片详情'), findsOneWidget);
    expect(find.byKey(const Key('topbar-back-button')), findsOneWidget);
    expect(find.text('ABC-001'), findsWidgets);
  });

  testWidgets('desktop router opens actor detail route inside shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueActorDetailResponse(bundle);
    _enqueueActorMoviesResponse(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ChangeNotifierProvider(create: (_) => AppShellController()),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/desktop/library/actors/1');
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/actors/1',
    );
    expect(find.byKey(const Key('app-topbar-title')), findsOneWidget);
    expect(find.text('女优详情'), findsOneWidget);
    expect(find.byKey(const Key('topbar-back-button')), findsOneWidget);
    expect(find.text('三上悠亚 / 鬼头桃菜'), findsOneWidget);
  });

  testWidgets('desktop router opens movie player route outside shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: <String, dynamic>{
        'javdb_id': 'MovieA1',
        'movie_number': 'ABC-001',
        'title': 'Movie 1',
        'cover_image': null,
        'release_date': '2024-01-02',
        'duration_minutes': 120,
        'score': 4.5,
        'watched_count': 12,
        'want_watch_count': 23,
        'comment_count': 34,
        'score_number': 45,
        'is_collection': false,
        'is_subscribed': true,
        'can_play': true,
        'summary': '',
        'actors': const <Map<String, dynamic>>[],
        'tags': const <Map<String, dynamic>>[],
        'thin_cover_image': null,
        'plot_images': const <Map<String, dynamic>>[],
        'media_items': const <Map<String, dynamic>>[],
      },
    );
    final router = buildDesktopRouter(sessionStore: sessionStore);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ChangeNotifierProvider(create: (_) => AppShellController()),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/desktop/library/movies/ABC-001/player?mediaId=100');
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/desktop/library/movies/ABC-001/player?mediaId=100',
    );
    expect(find.byKey(const Key('topbar-header')), findsNothing);
    expect(find.text('暂无可播放媒体'), findsOneWidget);
  });

  testWidgets('desktop shell keeps consistent page inset across routes', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 24,
        'total': 0,
      },
    );
    _enqueueMovieDetailResponse(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    final overviewStart = tester.getTopLeft(
      find.byKey(const Key('overview-page')),
    );
    final overviewTitleStart = tester.getTopLeft(
      find.byKey(const Key('app-topbar-title')),
    );
    expect(overviewStart.dx, overviewTitleStart.dx);

    router.go(desktopActorsPath);
    await tester.pumpAndSettle();
    final actorsStart = tester.getTopLeft(find.byKey(const Key('actors-page')));
    expect(actorsStart.dx, overviewStart.dx);

    router.go(desktopConfigurationPath);
    await tester.pumpAndSettle();
    final configurationStart = tester.getTopLeft(
      find.byKey(const Key('configuration-page')),
    );
    expect(configurationStart.dx, overviewStart.dx);

    router.go('/desktop/library/movies/ABC-001');
    await tester.pumpAndSettle();
    final detailStart = tester.getTopLeft(
      find.byKey(const Key('movie-detail-page')),
    );
    expect(detailStart.dx, overviewStart.dx);
  });

  testWidgets('tapping a latest movie card navigates to desktop detail route', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueMovieDetailResponse(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ChangeNotifierProvider(create: (_) => AppShellController()),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/movies/ABC-001',
    );
    expect(find.text('影片详情'), findsOneWidget);
  });

  testWidgets('top bar back returns to overview after opening movie detail', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueMovieDetailResponse(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ChangeNotifierProvider(create: (_) => AppShellController()),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/movies/ABC-001',
    );

    await tester.tap(find.byKey(const Key('topbar-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, desktopOverviewPath);
  });

  testWidgets('top bar back falls back to overview for deep-linked detail', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueMovieDetailResponse(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ChangeNotifierProvider(create: (_) => AppShellController()),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/desktop/library/movies/ABC-001');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('topbar-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, desktopOverviewPath);
  });

  testWidgets('overview top bar back button stays disabled', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ChangeNotifierProvider(create: (_) => AppShellController()),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('topbar-back-button')), findsNothing);
  });
}

Future<void> _pumpRouterApp(
  WidgetTester tester, {
  required GoRouter router,
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  bool includeShellController = false,
}) {
  final providers = [
    ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
    if (includeShellController)
      ChangeNotifierProvider(create: (_) => AppShellController()),
    Provider<ActorsApi>.value(value: bundle.actorsApi),
    Provider<ImageSearchApi>(
      create: (_) => ImageSearchApi(apiClient: bundle.apiClient),
    ),
    Provider<StatusApi>.value(value: bundle.statusApi),
    Provider<MoviesApi>.value(value: bundle.moviesApi),
    Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
  ];

  return tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
    ),
  );
}

Page<dynamic> _findPageByName(WidgetTester tester, String pageName) {
  for (final navigator in tester.widgetList<Navigator>(
    find.byType(Navigator),
  )) {
    for (final page in navigator.pages) {
      if (page.name == pageName) {
        return page;
      }
    }
  }

  throw TestFailure('No page found with name "$pageName".');
}

Future<SessionStore> _buildLoggedInSessionStore({
  AppPlatform platform = AppPlatform.desktop,
}) async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: '${platform.name}-access-token',
    refreshToken: '${platform.name}-refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}

void _enqueueDesktopOverviewResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status',
    body: <String, dynamic>{
      'actors': <String, dynamic>{'female_total': 12, 'female_subscribed': 8},
      'movies': <String, dynamic>{
        'total': 120,
        'subscribed': 35,
        'playable': 88,
      },
      'media_files': <String, dynamic>{
        'total': 156,
        'total_size_bytes': 987654321,
      },
      'media_libraries': <String, dynamic>{'total': 3},
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/latest',
    body: <String, dynamic>{
      'items': [
        <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABC-001',
          'title': 'Movie 1',
          'cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'is_subscribed': true,
          'can_play': true,
        },
      ],
      'page': 1,
      'page_size': 8,
      'total': 1,
    },
  );
}

void _enqueueMovieDetailResponse(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/ABC-001',
    body: <String, dynamic>{
      'javdb_id': 'MovieA1',
      'movie_number': 'ABC-001',
      'title': 'Movie 1',
      'cover_image': null,
      'release_date': '2024-01-02',
      'duration_minutes': 120,
      'score': 4.5,
      'watched_count': 12,
      'want_watch_count': 23,
      'comment_count': 34,
      'score_number': 45,
      'is_collection': false,
      'is_subscribed': true,
      'can_play': true,
      'summary': '',
      'actors': [],
      'tags': [],
      'thin_cover_image': null,
      'plot_images': [],
      'media_items': [],
    },
  );
}

void _enqueueActorDetailResponse(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/actors/1',
    body: <String, dynamic>{
      'id': 1,
      'javdb_id': 'ActorA1',
      'name': '三上悠亚',
      'alias_name': '三上悠亚 / 鬼头桃菜',
      'profile_image': null,
      'is_subscribed': true,
    },
  );
}

void _enqueueActorMoviesResponse(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies',
    body: <String, dynamic>{
      'items': [
        <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABC-001',
          'title': 'Movie 1',
          'cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'is_subscribed': true,
          'can_play': true,
        },
      ],
      'page': 1,
      'page_size': 24,
      'total': 1,
    },
  );
}
