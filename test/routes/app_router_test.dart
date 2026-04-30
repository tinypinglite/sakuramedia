import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/app_state.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/activity/presentation/desktop_activity_page.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_api.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_reviews_api.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/mobile_movie_player_page.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';

import '../support/test_api_bundle.dart';

const List<_MobileSettingsRouteCase> _mobileSettingsRouteCases =
    <_MobileSettingsRouteCase>[
      _MobileSettingsRouteCase(
        path: mobileSystemOverviewPath,
        title: '概览',
        pageKey: Key('mobile-system-overview-page'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsDataSourcesPath,
        title: '数据源',
        pageKey: Key('mobile-settings-data-sources'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsMediaLibrariesPath,
        title: '媒体库',
        pageKey: Key('mobile-settings-media-libraries'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsDownloadersPath,
        title: '下载器',
        pageKey: Key('mobile-settings-downloaders'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsIndexersPath,
        title: '索引器',
        pageKey: Key('mobile-settings-indexers'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsLlmPath,
        title: 'LLM 配置',
        pageKey: Key('mobile-settings-llm'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsPlaylistsPath,
        title: '播放列表',
        pageKey: Key('mobile-settings-playlists'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsUsernamePath,
        title: '修改用户名',
        pageKey: Key('mobile-settings-username'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsPasswordPath,
        title: '修改密码',
        pageKey: Key('mobile-settings-password'),
      ),
    ];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('desktop navigation tree contains moments entry', () {
    expect(desktopNavGroups.length, 10);
    expect(desktopNavGroups.map((group) => group.label), [
      '概览',
      '女优上新',
      '影片',
      '女优',
      '时刻',
      '播放列表',
      '排行榜',
      '热评',
      '活动中心',
      '配置管理',
    ]);
    expect(desktopRouteSpecs.map((spec) => spec.path), [
      desktopOverviewPath,
      desktopFollowPath,
      desktopMoviesPath,
      desktopActorsPath,
      desktopMomentsPath,
      desktopPlaylistsPath,
      desktopRankingsPath,
      desktopHotReviewsPath,
      desktopActivityPath,
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

  test('web overview path resolves to desktop overview path', () {
    expect(overviewPathForPlatform(AppPlatform.web), desktopOverviewPath);
    expect(
      webRouteSpecs.every((spec) => spec.path.startsWith('/desktop/')),
      isTrue,
    );
  });

  testWidgets('web platform reuses desktop router shell and paths', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.web,
    );
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    final router = buildAppRouter(AppPlatform.web, sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, desktopOverviewPath);
    expect(find.byKey(const Key('desktop-shell-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('nav-group-follow')), findsOneWidget);
    expect(find.text('女优上新'), findsOneWidget);
    expect(find.byKey(const Key('nav-group-rankings')), findsOneWidget);
    expect(find.text('排行榜'), findsOneWidget);
  });

  testWidgets('web rankings route renders desktop rankings page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.web,
    );
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueDesktopRankingsResponses(bundle);
    final router = buildAppRouter(AppPlatform.web, sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go(desktopRankingsPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-rankings-page')), findsOneWidget);
    expect(
      find.byKey(const Key('desktop-rankings-page-total')),
      findsOneWidget,
    );
    expect(find.text('1 部'), findsOneWidget);
  });

  testWidgets('web hot reviews route renders desktop hot reviews page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.web,
    );
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueDesktopHotReviewsResponses(bundle);
    final router = buildAppRouter(AppPlatform.web, sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go(desktopHotReviewsPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-hot-reviews-page')), findsOneWidget);
    expect(
      find.byKey(const Key('desktop-hot-reviews-page-total')),
      findsOneWidget,
    );
    expect(find.text('1 条'), findsOneWidget);
  });

  testWidgets('web activity route renders desktop activity page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.web,
    );
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueActivityResponses(bundle);
    final router = buildAppRouter(AppPlatform.web, sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go(desktopActivityPath);
    await tester.pumpAndSettle();

    expect(find.byType(DesktopActivityPage), findsOneWidget);
    expect(find.byKey(const Key('desktop-activity-page')), findsOneWidget);
    expect(find.byKey(const Key('activity-tab-notifications')), findsOneWidget);
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
    expect(config.fallbackPath, desktopMoviesPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config enables back on movie series page', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/movies/series/7',
      routeSpecs: desktopRouteSpecs,
    );

    expect(config.title, '系列影片');
    expect(config.fallbackPath, desktopMoviesPath);
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

  test('mobile search route helper encodes query parameters', () {
    expect(buildMobileSearchRoutePath(''), mobileSearchPath);
    expect(buildMobileSearchRoutePath('abp123'), '/mobile/search/abp123');
    expect(
      buildMobileSearchRoutePath('Rio %'),
      '/mobile/search/${Uri.encodeComponent('Rio %')}',
    );
  });

  test('mobile playlist detail route helper builds expected path', () {
    expect(
      buildMobilePlaylistDetailRoutePath(8),
      '$mobileOverviewPath/playlists/8',
    );
  });

  test('mobile movie detail route helper builds expected path', () {
    expect(
      buildMobileMovieDetailRoutePath('ABP-123'),
      '$mobileMoviesPath/ABP-123',
    );
  });

  test('mobile movie player route helper encodes query parameters', () {
    expect(
      buildMobileMoviePlayerRoutePath('ABP-123', mediaId: 100),
      '/mobile/library/movies/ABP-123/player?mediaId=100',
    );
    expect(
      buildMobileMoviePlayerRoutePath(
        'ABP-123',
        mediaId: 100,
        positionSeconds: 61,
      ),
      '/mobile/library/movies/ABP-123/player?mediaId=100&positionSeconds=61',
    );
    expect(
      buildMobileMoviePlayerRoutePath('ABP-123'),
      '/mobile/library/movies/ABP-123/player',
    );
  });

  test('mobile actor detail route helper builds expected path', () {
    expect(buildMobileActorDetailRoutePath(9), '$mobileActorsPath/9');
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

  testWidgets('desktop movie series route uses NoTransitionPage inside shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueMovieSeriesResponse(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go('/desktop/library/movies/series/7?seriesName=Attackers');
    await tester.pumpAndSettle();

    final seriesPage = _findPageByName(tester, 'desktop-movie-series');

    expect(seriesPage, isA<NoTransitionPage<void>>());
    expect(find.byKey(const Key('desktop-series-movies-page')), findsOneWidget);
    expect(find.text('Attackers'), findsOneWidget);
    expect(bundle.adapter.hitCount('POST', '/movies/by-series'), 1);
    expect(bundle.adapter.requests.last.body, <String, dynamic>{
      'series_id': 7,
      'page': 1,
      'page_size': 24,
    });
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
    bundle.adapter.enqueueSse(
      method: 'POST',
      path: '/actors/search/javdb/stream',
      chunks: <String>[
        'event: completed\n'
            'data: {"success":true,"actors":[{"id":1,"javdb_id":"ActorA1","name":"Rio","alias_name":"Rio %","profile_image":null,"is_subscribed":false}]}\n\n',
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

  testWidgets('mobile overview route uses NoTransitionPage', (
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

    expect(overviewPage, isA<NoTransitionPage<void>>());
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const Key('mobile-overview-tabs')), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('关注'), findsOneWidget);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('时刻'), findsOneWidget);
    expect(find.text('热评'), findsOneWidget);
  });

  testWidgets('mobile system overview route uses subpage shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueMobileSystemOverviewResponses(bundle);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(mobileSystemOverviewPath);
    await tester.pumpAndSettle();

    final systemOverviewPage = _findPageByName(
      tester,
      'mobile-system-overview',
    );

    expect(systemOverviewPage, isA<CupertinoPage<void>>());
    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('概览'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-system-overview-page')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
  });

  testWidgets('mobile search routes use subpage shell and are reachable', (
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

    router.go('/mobile/search/abp123');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.byKey(const Key('catalog-search-page-field')), findsOneWidget);
  });

  for (final routeCase in _mobileSettingsRouteCases) {
    testWidgets('${routeCase.title} route uses subpage shell', (
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

      if (routeCase.path == mobileSettingsDataSourcesPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/metadata-provider-license/status',
          body: _metadataProviderLicenseStatusJson(),
        );
      } else if (routeCase.path == mobileSettingsMediaLibrariesPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/media-libraries',
          body: const <Map<String, dynamic>>[],
        );
      } else if (routeCase.path == mobileSettingsDownloadersPath) {
        _enqueueMobileDownloadersResponses(bundle);
      } else if (routeCase.path == mobileSettingsIndexersPath) {
        _enqueueMobileIndexersResponses(bundle);
      } else if (routeCase.path == mobileSettingsLlmPath) {
        _enqueueMobileLlmResponses(bundle);
      } else if (routeCase.path == mobileSettingsPlaylistsPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/playlists',
          body: const <Map<String, dynamic>>[],
        );
      } else if (routeCase.path == mobileSettingsUsernamePath) {
        _enqueueAccountProfile(bundle);
      }

      router.go(routeCase.path);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
      expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('mobile-subpage-topbar')),
          matching: find.text(routeCase.title),
        ),
        findsOneWidget,
      );
      expect(find.byKey(routeCase.pageKey), findsOneWidget);
    });
  }

  testWidgets('mobile media libraries route renders real page content', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(mobileSettingsMediaLibrariesPath);
    await tester.pumpAndSettle();

    expect(find.text('开发中'), findsNothing);
    expect(
      find.byKey(const Key('mobile-media-libraries-create-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-libraries-notice-card')),
      findsOneWidget,
    );
  });

  testWidgets('mobile indexers route renders real page content', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
    _enqueueMobileIndexersResponses(bundle);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(mobileSettingsIndexersPath);
    await tester.pumpAndSettle();

    expect(find.text('开发中'), findsNothing);
    expect(
      find.byKey(const Key('mobile-indexers-api-key-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-indexers-create-button')),
      findsOneWidget,
    );
  });

  testWidgets('mobile llm route renders real page content', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
    _enqueueMobileLlmResponses(bundle);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(mobileSettingsLlmPath);
    await tester.pumpAndSettle();

    expect(find.text('开发中'), findsNothing);
    expect(find.byKey(const Key('mobile-llm-overview-card')), findsOneWidget);
    expect(find.byKey(const Key('mobile-llm-form-card')), findsOneWidget);
    expect(find.byKey(const Key('mobile-llm-save-button')), findsOneWidget);
  });

  testWidgets('mobile playlist detail route uses subpage shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
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

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(buildMobilePlaylistDetailRoutePath(8));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('播放列表详情'), findsOneWidget);
  });

  testWidgets('mobile movie detail route uses subpage shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
    _enqueueMovieDetailResponse(bundle);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(buildMobileMovieDetailRoutePath('ABC-001'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('影片详情'), findsOneWidget);
    expect(find.byKey(const Key('movie-detail-page')), findsOneWidget);
    final detailPage = _findPageByName(tester, 'mobile-movie-detail');
    expect(detailPage, isA<CupertinoPage<void>>());

    final infoBarRect = tester.getRect(
      find.byKey(const Key('movie-detail-fixed-info-bar')),
    );
    final appSize = tester.getSize(find.byType(MaterialApp).first);
    expect(infoBarRect.left, AppPageInsets.compact);
    expect(infoBarRect.right, appSize.width - AppPageInsets.compact);
    expect(
      infoBarRect.bottom,
      closeTo(appSize.height - AppPageInsets.compact, 0.1),
    );
  });

  testWidgets('mobile movie series route uses subpage shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
    _enqueueMovieSeriesResponse(bundle);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go('/mobile/library/movies/series/7?seriesName=Attackers');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('系列影片'), findsWidgets);
    expect(find.byKey(const Key('mobile-series-movies-page')), findsOneWidget);
    final seriesPage = _findPageByName(tester, 'mobile-movie-series');
    expect(seriesPage, isA<CupertinoPage<void>>());
    expect(bundle.adapter.hitCount('POST', '/movies/by-series'), 1);
  });

  testWidgets('mobile actor detail route uses subpage shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
    _enqueueActorDetailResponse(bundle);
    _enqueueActorMoviesResponse(bundle);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(buildMobileActorDetailRoutePath(1));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('女优详情'), findsOneWidget);
    expect(find.byKey(const Key('mobile-actor-detail-page')), findsOneWidget);
    expect(find.byKey(const Key('mobile-actor-detail-header')), findsOneWidget);
    final detailPage = _findPageByName(tester, 'mobile-actor-detail');
    expect(detailPage, isA<CupertinoPage<void>>());
  });

  testWidgets('mobile overview playlist supports system back to overview', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
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
        'page_size': 12,
        'total': 1,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': '收藏夹',
          'kind': 'custom',
          'description': 'Favorite movies',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 1,
          'created_at': '2026-03-12T10:10:00Z',
          'updated_at': '2026-03-12T11:20:00Z',
        },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/1/movies',
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
            'playlist_item_updated_at': '2026-03-12T10:20:00Z',
          },
        ],
        'page': 1,
        'page_size': 1,
        'total': 1,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/1',
      body: <String, dynamic>{
        'id': 1,
        'name': '收藏夹',
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
      path: '/playlists/1/movies',
      body: <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 24,
        'total': 0,
      },
    );

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-playlist-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('播放列表详情'), findsOneWidget);
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    expect(router.canPop(), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-overview-tabs')), findsOneWidget);
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('mobile image search route uses subpage shell and is reachable', (
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

    router.go(mobileImageSearchPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('以图搜图'), findsOneWidget);
    expect(
      find.byKey(const Key('desktop-image-search-empty-select-button')),
      findsOneWidget,
    );
  });

  testWidgets('mobile image search route uses injected mobile picker', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(() => debugMobileImageSearchFilePicker = null);
    final router = buildMobileRouter(sessionStore: sessionStore);
    debugMobileImageSearchFilePicker =
        () async => ImageSearchPickedFile(
          bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
          fileName: 'picked.png',
          mimeType: 'image/png',
        );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: <String, dynamic>{
        'session_id': 'mobile-image-session',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': null,
        'expires_at': '2026-03-08T10:10:00Z',
        'items': const <Map<String, dynamic>>[],
      },
    );

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(mobileImageSearchPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    await tester.tap(
      find.byKey(const Key('desktop-image-search-empty-select-button')),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);
  });

  testWidgets(
    'mobile image search route configures bottom drawer result preview presentation',
    (WidgetTester tester) async {
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

      router.go(mobileImageSearchPath);
      await tester.pumpAndSettle();

      final page = tester.widget<DesktopImageSearchPage>(
        find.byType(DesktopImageSearchPage),
      );
      expect(
        page.resultPreviewPresentation,
        ImageSearchResultPreviewPresentation.bottomDrawer,
      );
    },
  );

  testWidgets('mobile image search route wires preview action callbacks', (
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

    router.go(mobileImageSearchPath);
    await tester.pumpAndSettle();

    final page = tester.widget<DesktopImageSearchPage>(
      find.byType(DesktopImageSearchPage),
    );
    expect(page.onSearchSimilar, isNotNull);
    expect(page.onOpenPlayer, isNotNull);
    expect(page.onOpenMovieDetail, isNotNull);
  });

  testWidgets(
    'mobile image search route callbacks navigate to mobile detail and player pages',
    (WidgetTester tester) async {
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

      router.go(mobileImageSearchPath);
      await tester.pumpAndSettle();

      final page = tester.widget<DesktopImageSearchPage>(
        find.byType(DesktopImageSearchPage),
      );
      final hostContext = tester.element(find.byType(DesktopImageSearchPage));
      final resultItem = ImageSearchResultItemDto(
        thumbnailId: 123,
        mediaId: 456,
        movieId: 789,
        movieNumber: 'ABC-001',
        offsetSeconds: 120,
        score: 0.91,
        image: const MovieImageDto(
          id: 10,
          origin: '/thumb-1.webp',
          small: '/thumb-1.webp',
          medium: '/thumb-1.webp',
          large: '/thumb-1.webp',
        ),
      );

      page.onOpenMovieDetail!(hostContext, resultItem);
      expect(
        router.routeInformationProvider.value.uri.path,
        buildMobileMovieDetailRoutePath('ABC-001'),
      );

      router.go(mobileImageSearchPath);
      await tester.pumpAndSettle();
      final pageAfterDetail = tester.widget<DesktopImageSearchPage>(
        find.byType(DesktopImageSearchPage),
      );
      final contextAfterDetail = tester.element(
        find.byType(DesktopImageSearchPage),
      );

      pageAfterDetail.onOpenPlayer!(contextAfterDetail, resultItem);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/mobile/library/movies/ABC-001/player',
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['mediaId'],
        '456',
      );
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['positionSeconds'],
        '120',
      );
    },
  );

  testWidgets('mobile search deep link back falls back to overview', (
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

    router.go(mobileSearchPath);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, mobileOverviewPath);
  });

  testWidgets('mobile image search deep link back falls back to overview', (
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

    router.go(mobileImageSearchPath);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, mobileOverviewPath);
  });

  for (final routeCase in _mobileSettingsRouteCases) {
    testWidgets('${routeCase.title} deep link back falls back to overview', (
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

      if (routeCase.path == mobileSettingsDataSourcesPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/metadata-provider-license/status',
          body: _metadataProviderLicenseStatusJson(),
        );
      } else if (routeCase.path == mobileSettingsMediaLibrariesPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/media-libraries',
          body: const <Map<String, dynamic>>[],
        );
      } else if (routeCase.path == mobileSettingsDownloadersPath) {
        _enqueueMobileDownloadersResponses(bundle);
      } else if (routeCase.path == mobileSettingsIndexersPath) {
        _enqueueMobileIndexersResponses(bundle);
      } else if (routeCase.path == mobileSettingsUsernamePath) {
        _enqueueAccountProfile(bundle);
      }

      router.go(routeCase.path);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        mobileOverviewPath,
      );
    });
  }

  testWidgets('mobile movie detail deep link back falls back to movie list', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
    _enqueueMovieDetailResponse(bundle);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(buildMobileMovieDetailRoutePath('ABC-001'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, mobileMoviesPath);
  });

  testWidgets('mobile actor detail deep link back falls back to actor list', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
    _enqueueActorDetailResponse(bundle);
    _enqueueActorMoviesResponse(bundle);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(buildMobileActorDetailRoutePath(1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, mobileActorsPath);
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
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
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
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
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
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
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
    _enqueueMobileMoviesResponse(bundle);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
          Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
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
    expect(find.byKey(const Key('mobile-movies-page')), findsOneWidget);
    expect(find.byKey(const Key('mobile-movies-page-total')), findsOneWidget);
    expect(find.byKey(const Key('login-form-base-url')), findsNothing);
  });

  testWidgets('mobile bottom navigation switches to movies route', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueMobileMoviesResponse(bundle);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('影片').last);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, mobileMoviesPath);
    expect(find.byKey(const Key('mobile-movies-page')), findsOneWidget);
    expect(find.byKey(const Key('mobile-movies-page-total')), findsOneWidget);
  });

  testWidgets('mobile bottom navigation switches to actors route', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueMobileActorsResponse(bundle);
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
    expect(find.byKey(const Key('mobile-actors-page')), findsOneWidget);
    expect(find.byKey(const Key('mobile-actors-page-total')), findsOneWidget);
  });

  testWidgets('mobile movies root route renders real page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueMobileMoviesResponse(bundle);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(mobileMoviesPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-movies-page')), findsOneWidget);
    expect(find.text('1 部'), findsOneWidget);
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
  });

  testWidgets(
    'mobile movies page syncs subscription state after detail subscribe and back',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore(
        platform: AppPlatform.mobile,
      );
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
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
              'is_subscribed': false,
              'can_play': true,
            },
          ],
          'page': 1,
          'page_size': 24,
          'total': 1,
        },
      );
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
          'is_subscribed': false,
          'can_play': true,
          'summary': '',
          'actors': [],
          'tags': [],
          'thin_cover_image': null,
          'plot_images': [],
          'media_items': [],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/movies/ABC-001/subscription',
        statusCode: 204,
      );
      final router = buildMobileRouter(sessionStore: sessionStore);

      await _pumpRouterApp(
        tester,
        router: router,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      router.go(mobileMoviesPath);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
          matching: find.byIcon(Icons.favorite_border_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('movie-detail-hero-subscription-icon')),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, mobileMoviesPath);
      expect(
        find.descendant(
          of: find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
          matching: find.byIcon(Icons.favorite_rounded),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('mobile actors root route renders real page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueMobileActorsResponse(bundle);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(mobileActorsPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-actors-page')), findsOneWidget);
    expect(find.text('1 位'), findsOneWidget);
    expect(find.byKey(const Key('actor-summary-card-1')), findsOneWidget);
  });

  testWidgets('mobile rankings root route renders real page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopRankingsResponses(bundle);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(mobileRankingsPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-rankings-page')), findsOneWidget);
    expect(find.text('1 部'), findsOneWidget);
  });

  testWidgets('desktop rankings root route renders real page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueDesktopRankingsResponses(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go(desktopRankingsPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-rankings-page')), findsOneWidget);
    expect(find.text('1 部'), findsOneWidget);
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
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
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
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
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
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
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

  testWidgets('mobile router opens movie player route outside shell', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueMovieDetailResponse(bundle);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(
      buildMobileMoviePlayerRoutePath(
        'ABC-001',
        mediaId: 100,
        positionSeconds: 61,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/mobile/library/movies/ABC-001/player?mediaId=100&positionSeconds=61',
    );
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    expect(find.byKey(const Key('mobile-subpage-topbar')), findsNothing);
    expect(find.byKey(const Key('movie-player-page-frame')), findsOneWidget);
    final moviePlayerPage = _findPageByName(tester, 'mobile-movie-player');
    expect(moviePlayerPage, isA<CupertinoPage<void>>());
    final playerWidget = tester.widget<MobileMoviePlayerPage>(
      find.byType(MobileMoviePlayerPage),
    );
    expect(playerWidget.initialMediaId, 100);
    expect(playerWidget.initialPositionSeconds, 61);
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
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
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
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
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

  testWidgets('desktop detail series link opens series movies page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueMovieDetailResponse(bundle);
    _enqueueMovieSeriesResponse(bundle);
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

    router.go('/desktop/library/movies/ABC-001');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-detail-series-link')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/movies/series/7',
    );
    expect(find.byKey(const Key('desktop-series-movies-page')), findsOneWidget);
    expect(find.text('Attackers'), findsOneWidget);
  });

  testWidgets('top bar back falls back to movies list for deep-linked detail', (
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
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/desktop/library/movies/ABC-001');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('topbar-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, desktopMoviesPath);
  });

  testWidgets('image search detail back keeps image search route in history', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueImageSearchSingleResultResponse(bundle);
    _enqueueMovieDetailResponse(bundle);
    _enqueueMovieDetailResponse(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/456/points',
      body: const <Map<String, dynamic>>[],
    );
    final router = buildDesktopRouter(sessionStore: sessionStore);
    final draftStore = ImageSearchDraftStore();
    final draftId = draftStore.save(
      fileName: 'query.png',
      bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      mimeType: 'image/png',
    );
    final imageSearchLocation = _buildImageSearchLocation(
      desktopImageSearchPath,
      draftId: draftId,
    );

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
      imageSearchDraftStore: draftStore,
    );
    await tester.pumpAndSettle();

    router.go(imageSearchLocation);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const Key('image-search-result-card-123'),
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('影片详情'), matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/movies/ABC-001',
    );

    await tester.tap(find.byKey(const Key('topbar-back-button')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      imageSearchLocation,
    );
  });

  testWidgets(
    'desktop movies page keeps list state after detail back and route switches',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueDesktopOverviewResponses(bundle);
      _enqueueMobileMoviesResponse(bundle);
      _enqueueMovieDetailResponse(bundle);
      _enqueueMobileActorsResponse(bundle);
      final router = buildDesktopRouter(sessionStore: sessionStore);

      await _pumpRouterApp(
        tester,
        router: router,
        sessionStore: sessionStore,
        bundle: bundle,
        includeShellController: true,
      );
      await tester.pumpAndSettle();

      router.go(desktopMoviesPath);
      await tester.pumpAndSettle();
      expect(bundle.adapter.hitCount('GET', '/movies'), 1);

      await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('topbar-back-button')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, desktopMoviesPath);
      expect(bundle.adapter.hitCount('GET', '/movies'), 1);

      router.go(desktopActorsPath);
      await tester.pumpAndSettle();
      router.go(desktopMoviesPath);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/movies'), 1);
      expect(
        find.byKey(const Key('movie-summary-card-ABC-001')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'desktop movies page syncs subscription state after detail subscribe and back',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueDesktopOverviewResponses(bundle);
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
              'is_subscribed': false,
              'can_play': true,
            },
          ],
          'page': 1,
          'page_size': 24,
          'total': 1,
        },
      );
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
          'is_subscribed': false,
          'can_play': true,
          'summary': '',
          'actors': [],
          'tags': [],
          'thin_cover_image': null,
          'plot_images': [],
          'media_items': [],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/movies/ABC-001/subscription',
        statusCode: 204,
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

      router.go(desktopMoviesPath);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
          matching: find.byIcon(Icons.favorite_border_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('movie-detail-hero-subscription-icon')),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('topbar-back-button')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, desktopMoviesPath);
      expect(
        find.descendant(
          of: find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
          matching: find.byIcon(Icons.favorite_rounded),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'desktop actors page keeps list state after detail back and route switches',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueDesktopOverviewResponses(bundle);
      _enqueueMobileActorsResponse(bundle);
      _enqueueActorDetailResponse(bundle);
      _enqueueActorMoviesResponse(bundle);
      _enqueueMobileMoviesResponse(bundle);
      final router = buildDesktopRouter(sessionStore: sessionStore);

      await _pumpRouterApp(
        tester,
        router: router,
        sessionStore: sessionStore,
        bundle: bundle,
        includeShellController: true,
      );
      await tester.pumpAndSettle();

      router.go(desktopActorsPath);
      await tester.pumpAndSettle();
      expect(bundle.adapter.hitCount('GET', '/actors'), 1);

      await tester.tap(find.byKey(const Key('actor-summary-card-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('topbar-back-button')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, desktopActorsPath);
      expect(bundle.adapter.hitCount('GET', '/actors'), 1);

      router.go(desktopMoviesPath);
      await tester.pumpAndSettle();
      router.go(desktopActorsPath);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/actors'), 1);
      expect(find.byKey(const Key('actor-summary-card-1')), findsOneWidget);
    },
  );

  testWidgets(
    'desktop search page keeps results after detail back and route switches',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueDesktopOverviewResponses(bundle);
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/movies/search/parse-number',
        body: <String, dynamic>{
          'query': 'abc001',
          'parsed': true,
          'movie_number': 'ABC-001',
          'reason': null,
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/search/local',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
            'javdb_id': 'MovieA1',
            'movie_number': 'ABC-001',
            'title': 'Movie 1',
            'cover_image': null,
            'release_date': null,
            'duration_minutes': 120,
            'is_subscribed': false,
            'can_play': true,
          },
        ],
      );
      _enqueueMovieDetailResponse(bundle);
      _enqueueMobileActorsResponse(bundle);
      final router = buildDesktopRouter(sessionStore: sessionStore);

      await _pumpRouterApp(
        tester,
        router: router,
        sessionStore: sessionStore,
        bundle: bundle,
        includeShellController: true,
      );
      await tester.pumpAndSettle();

      router.go('/desktop/search/abc001');
      await tester.pumpAndSettle();
      expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 1);
      expect(bundle.adapter.hitCount('GET', '/movies/search/local'), 1);

      await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('topbar-back-button')));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/desktop/search/abc001',
      );
      expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 1);
      expect(bundle.adapter.hitCount('GET', '/movies/search/local'), 1);

      router.go(desktopActorsPath);
      await tester.pumpAndSettle();
      router.go('/desktop/search/abc001');
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 1);
      expect(bundle.adapter.hitCount('GET', '/movies/search/local'), 1);
      expect(
        find.byKey(const Key('movie-summary-card-ABC-001')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'desktop image search keeps source and results after route switches',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueDesktopOverviewResponses(bundle);
      _enqueueImageSearchSingleResultResponse(bundle);
      _enqueueMovieDetailResponse(bundle);
      _enqueueMobileActorsResponse(bundle);
      final router = buildDesktopRouter(sessionStore: sessionStore);
      final draftStore = ImageSearchDraftStore();
      final draftId = draftStore.save(
        fileName: 'query.png',
        bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        mimeType: 'image/png',
      );
      final imageSearchLocation = _buildImageSearchLocation(
        desktopImageSearchPath,
        draftId: draftId,
      );

      await _pumpRouterApp(
        tester,
        router: router,
        sessionStore: sessionStore,
        bundle: bundle,
        includeShellController: true,
        imageSearchDraftStore: draftStore,
      );
      await tester.pumpAndSettle();

      router.go(imageSearchLocation);
      await tester.pumpAndSettle();
      expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);
      expect(
        find.byKey(const Key('image-search-result-card-123')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const Key('image-search-result-card-123'),
          skipOffstage: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(of: find.text('影片详情'), matching: find.byType(InkWell)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('topbar-back-button')));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        imageSearchLocation,
      );
      expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);

      router.go(desktopActorsPath);
      await tester.pumpAndSettle();
      router.go(imageSearchLocation);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);
      expect(
        find.byKey(const Key('image-search-result-card-123')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'mobile movies page keeps list state when leaving and returning',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore(
        platform: AppPlatform.mobile,
      );
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueMobileMoviesResponse(bundle);
      _enqueueMovieDetailResponse(bundle);
      final router = buildMobileRouter(sessionStore: sessionStore);

      await _pumpRouterApp(
        tester,
        router: router,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      router.go(mobileMoviesPath);
      await tester.pumpAndSettle();
      expect(bundle.adapter.hitCount('GET', '/movies'), 1);

      await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, mobileMoviesPath);
      expect(bundle.adapter.hitCount('GET', '/movies'), 1);

      router.go(mobileOverviewPath);
      await tester.pumpAndSettle();
      router.go(mobileMoviesPath);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/movies'), 1);
      expect(
        find.byKey(const Key('movie-summary-card-ABC-001')),
        findsOneWidget,
      );
    },
  );

  testWidgets('mobile detail series link opens series movies page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueMovieDetailResponse(bundle);
    _enqueueMovieSeriesResponse(bundle);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(buildMobileMovieDetailRoutePath('ABC-001'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-detail-series-link')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/mobile/library/movies/series/7',
    );
    expect(find.byKey(const Key('mobile-series-movies-page')), findsOneWidget);
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    expect(find.text('Attackers'), findsOneWidget);
  });

  testWidgets(
    'movie detail deep link ignores legacy extra and falls back to canonical list',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueDesktopOverviewResponses(bundle);
      _enqueueMobileMoviesResponse(bundle);
      _enqueueMobileActorsResponse(bundle);
      _enqueueDesktopPlaylistsOverviewResponses(bundle);
      for (var i = 0; i < 5; i += 1) {
        _enqueueMovieDetailResponse(bundle);
      }
      final router = buildDesktopRouter(sessionStore: sessionStore);

      await _pumpRouterApp(
        tester,
        router: router,
        sessionStore: sessionStore,
        bundle: bundle,
        includeShellController: true,
      );
      await tester.pumpAndSettle();

      final origins = <String>[
        desktopOverviewPath,
        desktopMoviesPath,
        desktopActorsPath,
        desktopSearchPath,
        desktopPlaylistsPath,
      ];
      for (final origin in origins) {
        router.go('/desktop/library/movies/ABC-001', extra: origin);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/desktop/library/movies/ABC-001',
        );

        await tester.tap(find.byKey(const Key('topbar-back-button')));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          desktopMoviesPath,
        );
      }
    },
  );

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
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
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
  ImageSearchDraftStore? imageSearchDraftStore,
}) {
  final draftStore = imageSearchDraftStore ?? ImageSearchDraftStore();
  final providers = [
    ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
    ChangeNotifierProvider<AppPageStateCache>(
      create: (_) => AppPageStateCache()..bindSessionStore(sessionStore),
    ),
    if (includeShellController)
      ChangeNotifierProvider(create: (_) => AppShellController()),
    // 路由现在只传 draftId，测试环境也要注入临时草稿仓库。
    Provider<ImageSearchDraftStore>.value(value: draftStore),
    Provider<ApiClient>.value(value: bundle.apiClient),
    Provider<AccountApi>.value(value: bundle.accountApi),
    Provider<ActivityEventStreamClient>.value(
      value: bundle.activityEventStreamClient,
    ),
    Provider<ActivityApi>.value(value: bundle.activityApi),
    Provider<ActorsApi>.value(value: bundle.actorsApi),
    Provider<MediaApi>(create: (_) => MediaApi(apiClient: bundle.apiClient)),
    Provider<ImageSearchApi>(
      create: (_) => ImageSearchApi(apiClient: bundle.apiClient),
    ),
    Provider<StatusApi>.value(value: bundle.statusApi),
    Provider<MetadataProviderLicenseApi>.value(
      value: bundle.metadataProviderLicenseApi,
    ),
    Provider<MoviesApi>.value(value: bundle.moviesApi),
    ChangeNotifierProvider(create: (_) => MovieCollectionTypeChangeNotifier()),
    ChangeNotifierProvider(create: (_) => MovieSubscriptionChangeNotifier()),
    Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
    Provider<RankingsApi>.value(value: bundle.rankingsApi),
    Provider<HotReviewsApi>.value(value: bundle.hotReviewsApi),
    Provider<CollectionNumberFeaturesApi>.value(
      value: bundle.collectionNumberFeaturesApi,
    ),
    Provider<DownloadClientsApi>.value(value: bundle.downloadClientsApi),
    Provider<DownloadsApi>.value(value: bundle.downloadsApi),
    Provider<IndexerSettingsApi>.value(value: bundle.indexerSettingsApi),
    Provider<MediaLibrariesApi>.value(value: bundle.mediaLibrariesApi),
    Provider<MovieDescTranslationSettingsApi>.value(
      value: bundle.movieDescTranslationSettingsApi,
    ),
  ];

  return tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: OKToast(
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    ),
  );
}

void _enqueueActivityResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/activity/bootstrap',
    body: <String, dynamic>{
      'latest_event_id': 120,
      'notifications': <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 101,
            'category': 'reminder',
            'title': '有新的影片可以播放了',
            'content': '本次后台处理新增可播放影片 1 部：SSIS-123',
            'is_read': false,
            'archived': false,
            'created_at': '2026-03-26T09:10:00Z',
            'updated_at': '2026-03-26T09:10:00Z',
            'related_task_run_id': 88,
            'related_resource_type': 'movie',
            'related_resource_id': 123,
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
      'unread_count': 1,
      'active_task_runs': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 88,
          'task_key': 'download_task_import',
          'task_name': '下载任务导入 SSIS-123',
          'trigger_type': 'manual',
          'state': 'running',
          'progress_current': 1,
          'progress_total': 3,
          'progress_text': '正在导入影片文件 SSIS-123',
          'result_text': null,
          'result_summary': <String, dynamic>{'imported_count': 1},
          'error_message': null,
          'started_at': '2026-03-26T09:10:00Z',
          'finished_at': null,
          'created_at': '2026-03-26T09:10:00Z',
          'updated_at': '2026-03-26T09:11:00Z',
        },
      ],
      'task_runs': <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 88,
            'task_key': 'download_task_import',
            'task_name': '下载任务导入 SSIS-123',
            'trigger_type': 'manual',
            'state': 'running',
            'progress_current': 1,
            'progress_total': 3,
            'progress_text': '正在导入影片文件 SSIS-123',
            'result_text': null,
            'result_summary': <String, dynamic>{'imported_count': 1},
            'error_message': null,
            'started_at': '2026-03-26T09:10:00Z',
            'finished_at': null,
            'created_at': '2026-03-26T09:10:00Z',
            'updated_at': '2026-03-26T09:11:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    },
  );
  bundle.adapter.enqueueSse(
    method: 'GET',
    path: '/system/events/stream',
    chunks: const <String>[
      'id: 1\n'
          'event: heartbeat\n'
          'data: {}\n\n',
    ],
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

String _buildImageSearchLocation(String path, {required String draftId}) {
  return Uri(
    path: path,
    queryParameters: <String, String>{'draftId': draftId},
  ).toString();
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
  _enqueueMobileSystemOverviewResponses(bundle);
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

void _enqueueMobileSystemOverviewResponses(TestApiBundle bundle) {
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
    path: '/status/image-search',
    body: <String, dynamic>{
      'healthy': true,
      'joytag': <String, dynamic>{'healthy': true, 'used_device': 'GPU'},
      'indexing': <String, dynamic>{
        'pending_thumbnails': 23,
        'failed_thumbnails': 2,
      },
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/metadata-provider-license/status',
    body: _metadataProviderLicenseStatusJson(),
  );
}

Map<String, dynamic> _metadataProviderLicenseStatusJson() {
  return <String, dynamic>{
    'configured': true,
    'active': true,
    'instance_id': 'inst_test',
    'expires_at': 1777181126,
    'license_valid_until': 4102444800,
    'renew_after_seconds': 21600,
    'error_code': null,
    'message': null,
  };
}

void _enqueueImageSearchSingleResultResponse(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/image-search/sessions',
    body: <String, dynamic>{
      'session_id': 'desktop-image-session',
      'status': 'ready',
      'page_size': 20,
      'next_cursor': null,
      'expires_at': '2026-03-08T10:10:00Z',
      'items': [
        <String, dynamic>{
          'thumbnail_id': 123,
          'media_id': 456,
          'movie_id': 789,
          'movie_number': 'ABC-001',
          'offset_seconds': 120,
          'score': 0.91,
          'image': <String, dynamic>{
            'id': 10,
            'origin': '/thumb-1.webp',
            'small': '/thumb-1.webp',
            'medium': '/thumb-1.webp',
            'large': '/thumb-1.webp',
          },
        },
      ],
    },
  );
}

void _enqueueMobileActorsResponse(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/actors',
    body: <String, dynamic>{
      'items': [
        <String, dynamic>{
          'id': 1,
          'javdb_id': 'ActorA1',
          'name': '三上悠亚',
          'alias_name': '三上悠亚 / 鬼头桃菜',
          'profile_image': null,
          'is_subscribed': true,
        },
      ],
      'page': 1,
      'page_size': 24,
      'total': 1,
    },
  );
}

void _enqueueMobileMoviesResponse(TestApiBundle bundle) {
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

void _enqueueMobileDownloadersResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: const <Map<String, dynamic>>[],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: const <Map<String, dynamic>>[],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/indexer-settings',
    body: const <String, dynamic>{
      'type': 'builtin',
      'api_key': '',
      'indexers': <Map<String, dynamic>>[],
    },
  );
}

void _enqueueMobileIndexersResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: const <Map<String, dynamic>>[],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/indexer-settings',
    body: const <String, dynamic>{
      'type': 'jackett',
      'api_key': '',
      'indexers': <Map<String, dynamic>>[],
    },
  );
}

void _enqueueMobileLlmResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movie-desc-translation-settings',
    body: const <String, dynamic>{
      'enabled': false,
      'base_url': 'http://llm.internal:8000',
      'api_key': '',
      'model': 'gpt-4o-mini',
      'timeout_seconds': 300.0,
      'connect_timeout_seconds': 3.0,
    },
  );
}

void _enqueueDesktopRankingsResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/ranking-sources',
    body: <Map<String, dynamic>>[
      <String, dynamic>{'source_key': 'javdb', 'name': 'JavDB'},
      <String, dynamic>{'source_key': 'missav', 'name': 'MissAV'},
    ],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/ranking-sources/javdb/boards',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'source_key': 'javdb',
        'board_key': 'censored',
        'name': '有码',
        'supported_periods': <String>['daily', 'weekly', 'monthly'],
        'default_period': 'daily',
      },
      <String, dynamic>{
        'source_key': 'javdb',
        'board_key': 'uncensored',
        'name': '无码',
        'supported_periods': <String>['daily', 'weekly', 'monthly'],
        'default_period': 'daily',
      },
      <String, dynamic>{
        'source_key': 'javdb',
        'board_key': 'fc2',
        'name': 'FC2',
        'supported_periods': <String>['daily', 'weekly', 'monthly'],
        'default_period': 'daily',
      },
    ],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/ranking-sources/javdb/boards/censored/items',
    body: <String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'rank': 1,
          'javdb_id': 'MovieA1',
          'movie_number': 'ABC-001',
          'title': 'Movie 1',
          'cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'heat': 0,
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

void _enqueueDesktopHotReviewsResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/hot-reviews',
    body: <String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'rank': 1,
          'review_id': 101,
          'score': 5,
          'content': '值得反复看',
          'created_at': '2026-03-21T01:00:00Z',
          'username': 'demo-user',
          'like_count': 11,
          'watch_count': 21,
          'movie': <String, dynamic>{
            'javdb_id': 'javdb-abp001',
            'movie_number': 'ABP-001',
            'title': 'Movie A',
            'cover_image': null,
            'release_date': null,
            'duration_minutes': 0,
            'is_subscribed': false,
            'can_play': false,
          },
        },
      ],
      'page': 1,
      'page_size': 20,
      'total': 1,
    },
  );
}

void _enqueueDesktopPlaylistsOverviewResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/playlists',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': '收藏夹',
        'kind': 'custom',
        'description': 'Favorite movies',
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'movie_count': 1,
        'created_at': '2026-03-12T10:10:00Z',
        'updated_at': '2026-03-12T11:20:00Z',
      },
    ],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/playlists/1/movies',
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
          'playlist_item_updated_at': '2026-03-12T10:20:00Z',
        },
      ],
      'page': 1,
      'page_size': 1,
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
      'series_id': 7,
      'series_name': 'Attackers',
      'summary': '',
      'actors': [],
      'tags': [],
      'thin_cover_image': null,
      'plot_images': [],
      'media_items': [],
    },
  );
}

void _enqueueAccountProfile(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/account',
    body: <String, dynamic>{
      'username': 'account',
      'created_at': '2026-03-08T09:00:00Z',
      'last_login_at': '2026-03-08T10:00:00Z',
    },
  );
}

void _enqueueMovieSeriesResponse(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/movies/by-series',
    body: <String, dynamic>{
      'items': [
        <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABC-001',
          'title': 'Movie 1',
          'series_id': 7,
          'series_name': 'Attackers',
          'cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'heat': 9,
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

class _MobileSettingsRouteCase {
  const _MobileSettingsRouteCase({
    required this.path,
    required this.title,
    required this.pageKey,
  });

  final String path;
  final String title;
  final Key pageKey;
}
