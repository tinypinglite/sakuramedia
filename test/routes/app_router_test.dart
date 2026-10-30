import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/pages/shared/image_search_content.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_player_page.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_hero_card.dart';
import 'package:sakuramedia/features/plugins/data/plugin_market_source.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/l10n/app_localizations_en.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/routes/desktop_routes.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_navigation_route_state.dart';
import 'package:sakuramedia/routes/desktop_search_route_state.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';

import '../support/test_api_bundle.dart';
import '../features/plugins/support/plugin_market_test_data.dart';

/// 断言用文案实例：直接取具体语言实现，不依赖 Widget 上下文。
final AppLocalizations _zhL10n = AppLocalizationsZh();
final AppLocalizations _enL10n = AppLocalizationsEn();

const List<_MobileSettingsRouteCase> _mobileSettingsRouteCases =
    <_MobileSettingsRouteCase>[
      _MobileSettingsRouteCase(
        path: mobileSystemOverviewPath,
        title: '概览',
        pageKey: Key('mobile-system-overview-page'),
      ),
      _MobileSettingsRouteCase(
        path: mobileMediaImportPath,
        title: '资源导入',
        pageKey: Key('media-import-page'),
      ),
      _MobileSettingsRouteCase(
        path: mobileActivityPath,
        title: '任务中心',
        pageKey: Key('desktop-activity-page'),
      ),
      _MobileSettingsRouteCase(
        path: mobileDownloadTasksPath,
        title: '下载任务',
        pageKey: Key('download-tasks-page'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsMediaLibrariesPath,
        title: '媒体库',
        pageKey: Key('mobile-settings-media-libraries'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsMediaTagsPath,
        title: '媒体文件标签',
        pageKey: Key('mobile-settings-media-tags'),
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
        path: mobileSettingsDownloadSelectionPath,
        title: '选种策略',
        pageKey: Key('mobile-settings-download-selection'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsPluginsPath,
        title: '插件',
        pageKey: Key('mobile-settings-plugins'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsPluginMarketPath,
        title: '插件市场',
        pageKey: Key('mobile-plugin-market'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsSystemMaintenancePath,
        title: '系统维护',
        pageKey: Key('mobile-settings-system-maintenance'),
      ),
      _MobileSettingsRouteCase(
        path: mobileSettingsAccountSecurityPath,
        title: '账号安全',
        pageKey: Key('mobile-settings-account-security'),
      ),
      _MobileSettingsRouteCase(
        path: mobileMediaManagementPath,
        title: '媒体管理',
        pageKey: Key('mobile-media-management-page'),
      ),
    ];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('desktop navigation tree contains moments entry', () {
    expect(desktopNavGroups(_zhL10n).length, 21);
    // 管理区顺序：媒体管理 / 资源导入 / 下载任务 / 任务中心 / 订阅管理 / 通知 / 系统设置。
    expect(desktopNavGroups(_zhL10n).map((group) => group.label), [
      '概览',
      '发现',
      '影片',
      '女优',
      '标签',
      '时刻',
      '切片',
      '播放列表',
      '我的收藏',
      '最近播放',
      '最近浏览',
      '我的评分',
      'PornBox',
      '排行榜',
      '媒体管理',
      '资源导入',
      '下载任务',
      '任务中心',
      '订阅管理',
      '通知',
      '系统设置',
    ]);
    // 人物已彻底移除、视频合集并入 PornBox 页（不再独占侧栏 seed），
    // 故两者均不在 nav 生成的 route spec 列表中。
    expect(desktopRouteSpecs.map((spec) => spec.path), [
      desktopOverviewPath,
      desktopDiscoverPath,
      desktopMoviesPath,
      desktopActorsPath,
      desktopTagsPath,
      desktopMomentsPath,
      desktopClipsPath,
      desktopPlaylistsPath,
      desktopFavoritesPath,
      desktopRecentlyPlayedPath,
      desktopRecentViewsPath,
      desktopRatingsPath,
      desktopVideosPath,
      desktopRankingsPath,
      desktopMediaPath,
      desktopMediaImportPath,
      desktopDownloadTasksPath,
      desktopActivityPath,
      desktopMovieSubscriptionsPath,
      desktopNotificationsPath,
      desktopConfigurationPath,
    ]);
  });

  test('mobile navigation tree contains expected skeleton entries', () {
    expect(mobileNavGroups(_zhL10n).length, 5);
    expect(mobileNavGroups(_zhL10n).map((group) => group.label), [
      '概览',
      '影片',
      '女优',
      '榜单',
      'PornBox',
    ]);
    expect(mobileRouteSpecs.map((spec) => spec.path), [
      mobileOverviewPath,
      mobileMoviesPath,
      mobileActorsPath,
      mobileRankingsPath,
      mobilePornboxPath,
    ]);
  });

  test('navigation labels follow the current language', () {
    expect(
      desktopNavGroups(_zhL10n).map((group) => group.label).take(3),
      <String>['概览', '发现', '影片'],
    );
    expect(
      desktopNavGroups(_enL10n).map((group) => group.label).take(3),
      <String>['Overview', 'Discover', 'Movies'],
    );
    expect(
      desktopNavGroups(
        _enL10n,
      ).map((group) => group.sectionLabel).whereType<String>().toSet(),
      <String>{'Browse', 'Manage'},
    );
    expect(mobileNavGroups(_enL10n).map((group) => group.label), <String>[
      'Overview',
      'Movies',
      'Actors',
      'Rankings',
      'PornBox',
    ]);
    expect(
      resolveDesktopTopBarConfig(
        currentPath: desktopOverviewPath,
        navGroups: desktopNavGroups(_enL10n),
        l10n: _enL10n,
      ).title,
      'Overview',
    );
    expect(
      resolveDesktopTopBarConfig(
        currentPath: desktopMoviesPath,
        navGroups: desktopNavGroups(_enL10n),
        l10n: _enL10n,
      ).title,
      'Movies',
    );
  });

  testWidgets('desktop sidebar labels follow the language provider', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    final router = buildAppRouter(AppPlatform.desktop, sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    final overviewNav = find.byKey(const Key('nav-group-overview'));
    expect(overviewNav, findsOneWidget);
    expect(
      find.descendant(of: overviewNav, matching: find.text('概览')),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(overviewNav),
      listen: false,
    );
    await container
        .read(appLanguageControllerProvider.notifier)
        .setLanguage(AppLanguage.en);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: overviewNav, matching: find.text('Overview')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overviewNav, matching: find.text('概览')),
      findsNothing,
    );
  });

  testWidgets('desktop follow route renders desktop follow page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueDesktopFollowResponses(bundle);
    final router = buildAppRouter(AppPlatform.desktop, sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go(desktopFollowPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-follow-page')), findsOneWidget);
    expect(find.byKey(const Key('movie-summary-card-FOL-001')), findsOneWidget);
  });

  testWidgets('desktop latest movies route renders the paged latest list', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    final router = buildAppRouter(AppPlatform.desktop, sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go(desktopLatestMoviesPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-latest-movies-page')), findsOneWidget);
    expect(find.byKey(const Key('desktop-latest-movies-total')), findsNothing);
    expect(find.text('1 部'), findsNothing);
    expect(find.text('ABC-001'), findsOneWidget);
  });

  testWidgets('desktop recent views route renders the mixed poster grid', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/view-history',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'entity_type': 'movie',
            'viewed_at': '2026-10-10T10:00:00',
            'movie': <String, dynamic>{
              'movie_number': 'HIS-001',
              'title': 'History Movie 1',
              'cover_image': null,
              'thin_cover_image': null,
            },
            'actor': null,
          },
          <String, dynamic>{
            'entity_type': 'actor',
            'viewed_at': '2026-10-10T09:00:00',
            'movie': null,
            'actor': <String, dynamic>{
              'id': 7,
              'javdb_id': 'actor-7',
              'name': '浏览女优',
              'profile_image': null,
            },
          },
        ],
      },
    );
    final router = buildAppRouter(AppPlatform.desktop, sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go(desktopRecentViewsPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recent-views-grid')), findsOneWidget);
    expect(
      find.byKey(const Key('recent-view-card-movie-HIS-001')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recent-view-card-actor-7')), findsOneWidget);
    expect(find.text('还没有浏览记录'), findsNothing);
  });

  testWidgets('desktop favorites sidebar entry returns to origin', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueSystemPlaylistResponses(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _emptyPagedMovies(),
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
    expect(router.routeInformationProvider.value.uri.path, desktopMoviesPath);

    final favoritesNav = find.byKey(const Key('nav-group-favorites'));
    await tester.ensureVisible(favoritesNav);
    await tester.pumpAndSettle();
    await tester.tap(favoritesNav);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      desktopFavoritesPath,
    );
    expect(find.byKey(const Key('playlist-banner-card-8')), findsOneWidget);

    await tester.tap(find.byKey(const Key('topbar-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, desktopMoviesPath);
  });

  testWidgets('desktop recent views sidebar entry returns to origin', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/view-history',
      body: <String, dynamic>{'items': const <Map<String, dynamic>>[]},
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _emptyPagedMovies(),
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

    final recentViewsNav = find.byKey(const Key('nav-group-recent-views'));
    await tester.ensureVisible(recentViewsNav);
    await tester.pumpAndSettle();
    await tester.tap(recentViewsNav);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      desktopRecentViewsPath,
    );

    await tester.tap(find.byKey(const Key('topbar-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, desktopMoviesPath);
  });

  testWidgets('desktop recently played route reuses playlist detail', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueSystemPlaylistResponses(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
      includeShellController: true,
    );
    await tester.pumpAndSettle();

    router.go(desktopRecentlyPlayedPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('playlist-banner-card-9')), findsOneWidget);

    await tester.tap(find.byKey(const Key('topbar-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, desktopOverviewPath);
  });

  test('desktop top bar config enables back on system playlist pages', () {
    final favorites = resolveDesktopTopBarConfig(
      currentPath: desktopFavoritesPath,
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );
    final recentlyPlayed = resolveDesktopTopBarConfig(
      currentPath: desktopRecentlyPlayedPath,
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(favorites.title, '我的收藏');
    expect(favorites.isBackEnabled, isTrue);
    expect(recentlyPlayed.title, '最近播放');
    expect(recentlyPlayed.isBackEnabled, isTrue);
  });

  test('desktop top bar config disables back on overview', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: desktopOverviewPath,
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(config.title, '概览');
    expect(config.fallbackPath, isNull);
    expect(config.isBackEnabled, isFalse);
  });

  test('desktop top bar config enables back on latest movies page', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: desktopLatestMoviesPath,
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(config.title, '最近添加');
    expect(config.fallbackPath, desktopOverviewPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config enables back on movie detail', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/movies/ABC-001',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(config.title, '影片详情');
    expect(config.fallbackPath, desktopMoviesPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config enables back on discover list pages', () {
    final moviesConfig = resolveDesktopTopBarConfig(
      currentPath: desktopDiscoverMoviesPath,
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );
    final momentsConfig = resolveDesktopTopBarConfig(
      currentPath: desktopDiscoverMomentsPath,
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );
    final hotActressConfig = resolveDesktopTopBarConfig(
      currentPath: desktopHotActressReleasesPath,
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(moviesConfig.title, '推荐影片');
    expect(moviesConfig.fallbackPath, desktopDiscoverPath);
    expect(moviesConfig.isBackEnabled, isTrue);
    expect(momentsConfig.title, '推荐时刻');
    expect(momentsConfig.fallbackPath, desktopDiscoverPath);
    expect(momentsConfig.isBackEnabled, isTrue);
    expect(hotActressConfig.title, '热门新片');
    expect(hotActressConfig.fallbackPath, desktopDiscoverPath);
    expect(hotActressConfig.isBackEnabled, isTrue);
  });

  test('mobile discover list routes expose subpage titles', () {
    const followRoute = MobileFollowRouteData();
    const moviesRoute = MobileDiscoverMoviesRouteData();
    const momentsRoute = MobileDiscoverMomentsRouteData();
    const hotActressRoute = MobileHotActressReleasesRouteData();

    expect(followRoute.location, mobileFollowPath);
    expect(followRoute.title(_zhL10n), '女优上新');
    expect(followRoute.title(_enL10n), 'New Actor Releases');
    expect(followRoute.defaultLocation, mobileOverviewPath);
    expect(moviesRoute.location, mobileDiscoverMoviesPath);
    expect(moviesRoute.title(_zhL10n), '推荐影片');
    expect(moviesRoute.title(_enL10n), 'Recommended Movies');
    expect(moviesRoute.defaultLocation, mobileOverviewPath);
    expect(momentsRoute.location, mobileDiscoverMomentsPath);
    expect(momentsRoute.title(_zhL10n), '推荐时刻');
    expect(momentsRoute.title(_enL10n), 'Recommended Moments');
    expect(momentsRoute.defaultLocation, mobileOverviewPath);
    expect(hotActressRoute.location, mobileHotActressReleasesPath);
    expect(hotActressRoute.title(_zhL10n), '热门新片');
    expect(hotActressRoute.title(_enL10n), 'Popular New Releases');
    expect(hotActressRoute.defaultLocation, mobileOverviewPath);
  });

  test('desktop top bar config enables back on movie series page', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/movies/series/7',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(config.title, '系列影片');
    expect(config.fallbackPath, desktopMoviesPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config prefers origin path from route extra', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/movies/ABC-001',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
      routeExtra: '/desktop/library/movies',
    );

    expect(config.fallbackPath, '/desktop/library/movies');
  });

  test('desktop top bar config enables back on actor detail', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/actors/1',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(config.title, '女优详情');
    expect(config.fallbackPath, desktopActorsPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config enables back on tag movies page', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/tags/5',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(config.title, '标签');
    expect(config.fallbackPath, desktopTagsPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config keeps back disabled on tags root', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: desktopTagsPath,
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(config.isBackEnabled, isFalse);
  });

  test('desktop top bar config enables back on playlist detail', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/playlists/8',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(config.title, '播放列表详情');
    expect(config.fallbackPath, desktopPlaylistsPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config prefers origin path on playlist detail', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/playlists/8',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
      routeExtra: desktopMoviesPath,
    );

    expect(config.fallbackPath, desktopMoviesPath);
  });

  test(
    'desktop top bar config prefers movie detail origin on actor detail',
    () {
      final config = resolveDesktopTopBarConfig(
        currentPath: '/desktop/library/actors/1',
        navGroups: desktopNavGroups(_zhL10n),
        l10n: _zhL10n,
        routeExtra: '/desktop/library/movies/ABC-001',
      );

      expect(config.fallbackPath, '/desktop/library/movies/ABC-001');
    },
  );

  test('desktop top bar config enables back on search route', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/search/ssni888',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(config.title, 'ssni888');
    expect(config.fallbackPath, desktopOverviewPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config prefers origin path on search route', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/search/ssni888',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
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
        navGroups: desktopNavGroups(_zhL10n),
        l10n: _zhL10n,
        routeExtra: const DesktopSearchRouteState(
          fallbackPath: desktopMoviesPath,
          useOnlineSearch: true,
        ),
      );

      expect(config.title, 'ssni888');
      expect(config.fallbackPath, desktopMoviesPath);
    },
  );

  test('desktop top bar config reads generic navigation route state', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/actors/1',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
      routeExtra: const DesktopNavigationRouteState(
        fallbackPath: desktopSearchPath,
      ),
    );

    expect(config.fallbackPath, desktopSearchPath);
  });

  test('desktop top bar config ignores non-desktop navigation fallback', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/library/actors/1',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
      routeExtra: const DesktopNavigationRouteState(
        fallbackPath: '/mobile/overview',
      ),
    );

    expect(config.fallbackPath, desktopActorsPath);
  });

  test('desktop top bar config decodes encoded search title', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/search/%E4%BC%8A%E8%97%A4%E8%88%9E%E9%9B%AA',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
    );

    expect(config.title, '伊藤舞雪');
    expect(config.fallbackPath, desktopOverviewPath);
  });

  test('desktop top bar config enables back on image search route', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: desktopImageSearchPath,
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
      routeExtra: const DesktopImageSearchRouteState(
        fallbackPath: desktopMoviesPath,
      ),
    );

    expect(config.title, '画面搜索');
    expect(config.fallbackPath, desktopMoviesPath);
    expect(config.isBackEnabled, isTrue);
  });

  test('desktop top bar config keeps literal percent in invalid title', () {
    final config = resolveDesktopTopBarConfig(
      currentPath: '/desktop/search/Rio %',
      navGroups: desktopNavGroups(_zhL10n),
      l10n: _zhL10n,
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

  test('desktop shell layout keeps movie detail on immersive layout', () {
    final layout = resolveDesktopShellLayout(
      currentPath: '/desktop/library/movies/ABC-001',
      routeSpecs: desktopRouteSpecs,
    );

    expect(layout, AppShellLayout.immersive);
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
    expect(
      const DesktopMoviePlayerRouteData(movieNumber: 'ABC-001').location,
      '/desktop/library/movies/ABC-001/player',
    );
  });

  test('desktop video collection play route 透传详情页排序到 URL', () {
    // 手动顺序：无 startIndex、无 sort。
    expect(
      const DesktopVideoCollectionPlayRouteData(collectionId: 3).location,
      '/desktop/library/video-collections/3/play',
    );
    // 选了排序后「播放全部」：sort 编码进 query（连播页据此与详情页同序）。
    expect(
      const DesktopVideoCollectionPlayRouteData(
        collectionId: 3,
        startIndex: 2,
        sort: 'duration:desc',
      ).location,
      '/desktop/library/video-collections/3/play?startIndex=2&sort=duration%3Adesc',
    );
    // sort 为 null 时不出现在 URL。
    expect(
      const DesktopVideoCollectionPlayRouteData(
        collectionId: 3,
        sort: null,
      ).location,
      '/desktop/library/video-collections/3/play',
    );
  });

  test('mobile search routes encode query parameters', () {
    expect(const MobileSearchRouteData().location, mobileSearchPath);
    expect(
      const MobileSearchQueryRouteData(query: 'abp123').location,
      '/mobile/search/abp123',
    );
    expect(
      const MobileSearchQueryRouteData(query: 'Rio %').location,
      '/mobile/search/${Uri.encodeComponent('Rio %')}',
    );
  });

  test('mobile playlist detail route builds expected path', () {
    expect(
      const MobilePlaylistDetailRouteData(playlistId: 8).location,
      '$mobileOverviewPath/playlists/8',
    );
  });

  test('mobile movie detail route helper builds expected path', () {
    expect(
      buildMobileMovieDetailRoutePath('ABP-123'),
      '$mobileMoviesPath/ABP-123',
    );
  });

  test('mobile movie player route encodes query parameters', () {
    expect(
      const MobileMoviePlayerRouteData(
        movieNumber: 'ABP-123',
        mediaId: 100,
      ).location,
      '/mobile/library/movies/ABP-123/player?mediaId=100',
    );
    expect(
      const MobileMoviePlayerRouteData(
        movieNumber: 'ABP-123',
        mediaId: 100,
        positionSeconds: 61,
      ).location,
      '/mobile/library/movies/ABP-123/player?mediaId=100&positionSeconds=61',
    );
    expect(
      const MobileMoviePlayerRouteData(movieNumber: 'ABP-123').location,
      '/mobile/library/movies/ABP-123/player',
    );
  });

  test('mobile actor detail route builds expected path', () {
    expect(
      const MobileActorDetailRouteData(actorId: 9).location,
      '$mobileActorsPath/9',
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
      method: 'GET',
      path: '/movies',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 50,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 50,
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
    expect(find.text('画面搜索'), findsWidgets);
  });

  testWidgets('desktop image search route extra fallback returns to player', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueMovieDetailResponse(bundle);
    final router = buildDesktopRouter(sessionStore: sessionStore);
    const playerPath =
        '/desktop/library/movies/ABC-001/player?mediaId=100&positionSeconds=61';

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
      extra: const DesktopImageSearchRouteState(fallbackPath: playerPath),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      desktopImageSearchPath,
    );
    expect(find.byKey(const Key('topbar-back-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('topbar-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.toString(), playerPath);
    expect(find.byKey(const Key('topbar-header')), findsNothing);
  });

  testWidgets(
    'desktop image search stack reset avoids duplicate shell after player',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueDesktopOverviewResponses(bundle);
      _enqueueMovieDetailResponse(bundle);
      _enqueueMovieDetailResponse(bundle);
      _enqueueImageSearchSingleResultResponse(bundle);
      _enqueueMovieDetailResponse(bundle);
      final router = buildDesktopRouter(sessionStore: sessionStore);
      const playerPath =
          '/desktop/library/movies/ABC-001/player?mediaId=100&positionSeconds=61';

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
      router.push<void>(playerPath);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-player-page-frame')), findsOneWidget);

      final playerContext = tester.element(
        find.byKey(const Key('movie-player-page-frame')),
      );
      playerContext.goDesktopImageSearch(
        fallbackPath: playerPath,
        initialFileName: 'query.webp',
        initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        initialMimeType: 'image/webp',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        router.routeInformationProvider.value.uri.path,
        desktopImageSearchPath,
      );
      expect(
        find.byKey(const Key('image-search-result-card-123')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('topbar-back-button')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.toString(), playerPath);
      expect(find.byKey(const Key('topbar-header')), findsNothing);
    },
  );

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
      path: '/movies/metadata-imports',
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
    // 概览「最近订阅」区块也会请求 /movies，用 fallback 兜住两条消费方。
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/movies',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 50,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'javdb_id': 'ActorA1',
            'name': 'Rio',
            'alias_name': 'Rio %',
            'profile_image': null,
            'is_subscribed': false,
          },
        ],
        'page': 1,
        'page_size': 50,
        'total': 1,
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

    router.go(const DesktopSearchQueryRouteData(query: 'Rio %').location);
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
    expect(find.text('关注'), findsNothing);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('时刻'), findsOneWidget);
  });

  testWidgets('mobile overview latest section opens the latest movies page', (
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

    expect(
      find.byKey(const Key('mobile-overview-latest-more')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('mobile-overview-latest-more')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      mobileLatestMoviesPath,
    );
    expect(find.byKey(const Key('mobile-latest-movies-page')), findsOneWidget);
    expect(find.text('最近添加'), findsOneWidget);
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
      method: 'GET',
      path: '/movies',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 50,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 50,
        'total': 0,
      },
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
      if (routeCase.path == mobileSettingsMediaLibrariesPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/media-libraries',
          body: const <Map<String, dynamic>>[],
        );
      } else if (routeCase.path == mobileSettingsMediaTagsPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/media-tags',
          body: const <Map<String, dynamic>>[],
        );
      } else if (routeCase.path == mobileSettingsDownloadersPath) {
        _enqueueMobileDownloadersResponses(bundle);
      } else if (routeCase.path == mobileSettingsIndexersPath) {
        _enqueueMobileIndexersResponses(bundle);
      } else if (routeCase.path == mobileSettingsPluginsPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/system/plugins',
          body: const <Map<String, dynamic>>[],
        );
      } else if (routeCase.path == mobileSettingsPluginMarketPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/system/plugins',
          body: const <Map<String, dynamic>>[],
        );
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: kPluginMarketIndexUrl,
          body: pluginMarketIndexJson(),
        );
      } else if (routeCase.path == mobileSettingsSystemMaintenancePath) {
        _enqueueMobileSystemMaintenanceResponses(bundle);
      } else if (routeCase.path == mobileSettingsAccountSecurityPath) {
        _enqueueAccountProfile(bundle);
      } else if (routeCase.path == mobileMediaManagementPath) {
        _enqueueMobileMediaManagementResponses(bundle);
      } else if (routeCase.path == mobileActivityPath) {
        _enqueueActivityCenterResponses(bundle);
      } else if (routeCase.path == mobileDownloadTasksPath) {
        bundle.adapter.setFallbackJson(
          method: 'GET',
          path: '/download-tasks',
          body: {
            'items': const <Map<String, dynamic>>[],
            'page': 1,
            'page_size': 20,
            'total': 0,
          },
        );
        bundle.adapter.setFallbackJson(
          method: 'GET',
          path: '/download-clients',
          body: const <Map<String, dynamic>>[],
        );
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

  testWidgets('mobile clip collections route renders real page content', (
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
      path: '/clip-collections',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(mobileClipCollectionsPath);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-clip-collections-page')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-clip-collections-create-button')),
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
      find.byKey(const Key('mobile-indexers-connection-test-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-indexers-create-button')),
      findsOneWidget,
    );
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

    router.go(const MobilePlaylistDetailRouteData(playlistId: 8).location);
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

    // 底部安全区交给滚动层：外壳内容区一直铺到屏幕物理底边（home indicator
    // 区不再露出未绘制黑底），滚动末尾由 AppAdaptiveRefreshScrollView 补留白。
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });

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
    // 沉浸详情不占标题位：顶栏只剩返回键和渐变。
    expect(find.byKey(const Key('mobile-subpage-title')), findsNothing);
    expect(find.byKey(const Key('mobile-subpage-back-button')), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const Key('mobile-subpage-body-padding')))
          .bottom,
      moreOrLessEquals(844),
    );
    expect(find.byKey(const Key('movie-detail-page')), findsOneWidget);
    final detailPage = _findPageByName(tester, 'mobile-movie-detail');
    expect(detailPage, isA<CupertinoPage<void>>());

    final heroRect = tester.getRect(find.byType(MovieDetailHeroCard));
    final appSize = tester.getSize(find.byType(MaterialApp).first);
    // 影片详情走沉浸布局：内容全幅无内边距，封面左右顶边；入口条在页面内。
    expect(heroRect.left, 0);
    expect(heroRect.right, appSize.width);
    expect(
      find.byKey(const Key('movie-detail-hero-review-icon')),
      findsOneWidget,
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
    // 页面把系列名报给返回栏（AppMobileSubpageTitle），静态标题「系列影片」被
    // 换掉——移动端窄屏放不下完整系列名，放信息槽会被压成省略号。
    expect(
      tester.widget<Text>(find.byKey(const Key('mobile-subpage-title'))).data,
      'Attackers',
    );
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

    router.go(const MobileActorDetailRouteData(actorId: 1).location);
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
    // 「最近订阅」区块把播放列表推到了更下方，拉高视口保证卡片完整露出、
    // 不落在底部导航的遮挡区里。
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

  // 回归:菜单按钮曾用 compact 尺寸(命中区仅 28dp),低于触控最小目标,
  // 表现为「图标有时点不动」。同时锁住它确实能打开概览抽屉。
  testWidgets('mobile overview menu button has a tappable hit area and opens '
      'the drawer', (WidgetTester tester) async {
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
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 12,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    final menuButton = find.byKey(const Key('mobile-overview-menu-button'));
    final size = tester.getSize(menuButton);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));

    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-overview-drawer')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-overview-drawer-version-card')),
      findsOneWidget,
    );
    expect(find.text('系统版本'), findsOneWidget);
  });

  // 抽屉「我的内容」分区：收藏/播放/浏览/评分/标签都是可返回概览的移动子页。
  testWidgets('mobile drawer content section opens favorites page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    addTearDown(sessionStore.dispose);
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/latest',
      body: _emptyPagedMovies(),
    );
    _enqueueSystemPlaylistResponses(bundle);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-overview-drawer-content-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-overview-drawer-recently-played')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-overview-drawer-recent-views')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-overview-drawer-ratings')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('mobile-overview-drawer-favorites')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-playlist-detail-page')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, mobileOverviewPath);

    // 「我的评分」入口：移动端与桌面共用同一评分列表。
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 24,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: const <Map<String, dynamic>>[],
    );
    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-overview-drawer-ratings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-rated-movies-page')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, mobileOverviewPath);
  });

  // 抽屉「管理」分区：点媒体管理 → 打开移动子页（非底栏页面，可返回概览）。
  testWidgets('mobile drawer media section opens media management page', (
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
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 12,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[],
    );
    _enqueueMobileMediaManagementResponses(bundle);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-overview-drawer-media-connections-section')),
      findsOneWidget,
    );

    // 抽屉内容可滚动，「媒体与连接」分区可能落在首屏之外，先滚到可见再点。
    final mediaManagementItem = find.byKey(
      const Key('mobile-overview-drawer-media-management'),
    );
    await tester.ensureVisible(mediaManagementItem);
    await tester.pumpAndSettle();
    await tester.tap(mediaManagementItem);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-media-management-page')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, mobileOverviewPath);
  });

  testWidgets('mobile drawer media section opens media import page', (
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
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 12,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: AppPlatformScope(
          platform: AppPlatform.mobile,
          child: OKToast(
            child: MaterialApp.router(
              theme: sakuraMobileThemeData,
              locale: const Locale('zh'),
              localizationsDelegates: <LocalizationsDelegate<dynamic>>[
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-overview-drawer-media-connections-section')),
      findsOneWidget,
    );

    // 抽屉内容可滚动，「媒体与连接」分区可能落在首屏之外，先滚到可见再点。
    final mediaImportItem = find.byKey(
      const Key('mobile-overview-drawer-media-import'),
    );
    await tester.ensureVisible(mediaImportItem);
    await tester.pumpAndSettle();
    await tester.tap(mediaImportItem);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-import-page')), findsOneWidget);
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);

    _enqueueActivityCenterResponses(bundle);
    await tester.tap(find.byKey(const Key('media-import-task-center-button')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, mobileActivityPath);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      mobileMediaImportPath,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, mobileOverviewPath);
  });

  testWidgets('mobile drawer management section opens activity page', (
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
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 12,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[],
    );
    _enqueueActivityCenterResponses(bundle);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();

    final activityItem = find.byKey(
      const Key('mobile-overview-drawer-activity'),
    );
    await tester.ensureVisible(activityItem);
    await tester.tap(activityItem);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-activity-page')), findsOneWidget);
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, mobileActivityPath);
  });

  testWidgets('mobile drawer groups settings destinations and opens plugins', (
    WidgetTester tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
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
          'items': const <Map<String, dynamic>>[],
          'page': 1,
          'page_size': 12,
          'total': 0,
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: const <Map<String, dynamic>>[],
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/plugins',
        body: const <Map<String, dynamic>>[],
      );

      await _pumpRouterApp(
        tester,
        router: router,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
      await tester.pumpAndSettle();
      for (final sectionKey in <Key>[
        const Key('mobile-overview-drawer-home-section'),
        const Key('mobile-overview-drawer-content-section'),
        const Key('mobile-overview-drawer-downloads-tasks-section'),
        const Key('mobile-overview-drawer-media-connections-section'),
        const Key('mobile-overview-drawer-system-account-section'),
      ]) {
        expect(find.byKey(sectionKey), findsOneWidget);
      }
      for (final itemKey in <Key>[
        const Key('mobile-overview-drawer-media-libraries'),
        const Key('mobile-overview-drawer-media-tags'),
        const Key('mobile-overview-drawer-downloaders'),
        const Key('mobile-overview-drawer-indexers'),
        const Key('mobile-overview-drawer-download-selection'),
        const Key('mobile-overview-drawer-plugins'),
        const Key('mobile-overview-drawer-system-maintenance'),
        const Key('mobile-overview-drawer-external-player'),
        const Key('mobile-overview-drawer-appearance'),
        const Key('mobile-overview-drawer-account-security'),
      ]) {
        expect(find.byKey(itemKey), findsOneWidget);
      }
      expect(
        find.byKey(const Key('mobile-overview-drawer-settings')),
        findsNothing,
      );
      for (final label in <String>['首页', '我的内容', '下载与任务', '媒体与连接', '系统与账户']) {
        expect(find.text(label), findsOneWidget);
      }

      final pluginsItem = find.byKey(
        const Key('mobile-overview-drawer-plugins'),
      );
      await tester.ensureVisible(pluginsItem);
      await tester.tap(pluginsItem);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        mobileSettingsPluginsPath,
      );
      expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
      expect(find.text('插件'), findsOneWidget);
      expect(find.byKey(const Key('mobile-settings-plugins')), findsOneWidget);
      expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets('mobile drawer hides the external player outside Android', (
    WidgetTester tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final sessionStore = await _buildLoggedInSessionStore(
        platform: AppPlatform.mobile,
      );
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      final router = buildMobileRouter(sessionStore: sessionStore);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/latest',
        body: _emptyPagedMovies(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: const <Map<String, dynamic>>[],
      );

      await _pumpRouterApp(
        tester,
        router: router,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mobile-overview-drawer-external-player')),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets('mobile plugins page opens the plugin market', (
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
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 12,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins',
      body: const <Map<String, dynamic>>[],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: kPluginMarketIndexUrl,
      body: pluginMarketIndexJson(),
    );

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(mobileSettingsPluginsPath);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-plugins-market-button')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      mobileSettingsPluginMarketPath,
    );
    expect(find.byKey(const Key('mobile-plugin-market')), findsOneWidget);
    expect(find.text('演示插件'), findsOneWidget);
  });

  // 侧滑打开抽屉只在「概览根路由 + 停在第一个 tab」时放开:边缘拖拽区盖住多宽,
  // 下面的 TabBarView 就有多宽收不到手势,只有第一个 tab 右滑本就无处可去。
  testWidgets('mobile overview enables drawer edge swipe only on the first '
      'tab', (WidgetTester tester) async {
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
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 12,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    bool dragEnabled() => tester
        .widget<Scaffold>(
          find.ancestor(
            of: find.byKey(const Key('mobile-shell-body-safe-area')),
            matching: find.byType(Scaffold),
          ),
        )
        .drawerEnableOpenDragGesture;

    expect(dragEnabled(), isTrue);

    // 切到第二个 tab（切片）后必须让位给 TabBarView 的横滑切页。
    await tester.tap(find.text('切片'));
    await tester.pumpAndSettle();
    expect(dragEnabled(), isFalse);

    // 切回第一个 tab 恢复。
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(dragEnabled(), isTrue);
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
    expect(find.text('画面搜索'), findsOneWidget);
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
    debugMobileImageSearchFilePicker = () async => ImageSearchPickedFile(
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

    await tester.tap(
      find.byKey(const Key('desktop-image-search-toggle-filter')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-image-search-filter-drawer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('desktop-image-search-filter-panel')),
      findsNothing,
    );
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

      final content = tester.widget<ImageSearchContent>(
        find.byType(ImageSearchContent),
      );
      expect(
        content.resultPreviewPresentation,
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

    final content = tester.widget<ImageSearchContent>(
      find.byType(ImageSearchContent),
    );
    expect(content.onSearchSimilar, isNotNull);
    expect(content.onOpenPlayer, isNotNull);
    expect(content.onOpenMovieDetail, isNotNull);
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

      final content = tester.widget<ImageSearchContent>(
        find.byType(ImageSearchContent),
      );
      final hostContext = tester.element(find.byType(ImageSearchContent));
      final resultItem = ImageSearchResultItemDto(
        thumbnailId: 123,
        mediaId: 456,
        movieId: 789,
        movieNumber: 'ABC-001',
        offsetSeconds: 120,
        score: 0.91,
        image: const MovieImageDto(id: 10, origin: '/thumb-1.webp'),
      );

      content.onOpenMovieDetail!(hostContext, resultItem);
      expect(
        router.routeInformationProvider.value.uri.path,
        buildMobileMovieDetailRoutePath('ABC-001'),
      );

      router.go(mobileImageSearchPath);
      await tester.pumpAndSettle();
      final contentAfterDetail = tester.widget<ImageSearchContent>(
        find.byType(ImageSearchContent),
      );
      final contextAfterDetail = tester.element(
        find.byType(ImageSearchContent),
      );

      contentAfterDetail.onOpenPlayer!(contextAfterDetail, resultItem);
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
      if (routeCase.path == mobileSettingsMediaLibrariesPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/media-libraries',
          body: const <Map<String, dynamic>>[],
        );
      } else if (routeCase.path == mobileSettingsMediaTagsPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/media-tags',
          body: const <Map<String, dynamic>>[],
        );
      } else if (routeCase.path == mobileSettingsDownloadersPath) {
        _enqueueMobileDownloadersResponses(bundle);
      } else if (routeCase.path == mobileSettingsIndexersPath) {
        _enqueueMobileIndexersResponses(bundle);
      } else if (routeCase.path == mobileSettingsDownloadSelectionPath) {
        _enqueueDownloadSelectionResponses(bundle);
      } else if (routeCase.path == mobileSettingsPluginsPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/system/plugins',
          body: const <Map<String, dynamic>>[],
        );
      } else if (routeCase.path == mobileSettingsPluginMarketPath) {
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/system/plugins',
          body: const <Map<String, dynamic>>[],
        );
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: kPluginMarketIndexUrl,
          body: pluginMarketIndexJson(),
        );
      } else if (routeCase.path == mobileSettingsSystemMaintenancePath) {
        _enqueueMobileSystemMaintenanceResponses(bundle);
      } else if (routeCase.path == mobileSettingsAccountSecurityPath) {
        _enqueueAccountProfile(bundle);
      } else if (routeCase.path == mobileMediaManagementPath) {
        _enqueueMobileMediaManagementResponses(bundle);
      } else if (routeCase.path == mobileActivityPath) {
        _enqueueActivityCenterResponses(bundle);
      } else if (routeCase.path == mobileDownloadTasksPath) {
        bundle.adapter.setFallbackJson(
          method: 'GET',
          path: '/download-tasks',
          body: {
            'items': const <Map<String, dynamic>>[],
            'page': 1,
            'page_size': 20,
            'total': 0,
          },
        );
        bundle.adapter.setFallbackJson(
          method: 'GET',
          path: '/download-clients',
          body: const <Map<String, dynamic>>[],
        );
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

  testWidgets('dirty download selection policy confirms before leaving', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);
    _enqueueDownloadSelectionResponses(bundle);

    await _pumpRouterApp(
      tester,
      router: router,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    router.go(mobileSettingsDownloadSelectionPath);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const Key('download-selection-min-seeders')),
      '8',
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('download-selection-discard-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('download-selection-discard-confirm')),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, mobileOverviewPath);
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

    router.go(const MobileActorDetailRouteData(actorId: 1).location);
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
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
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
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
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
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go(loginPath);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, desktopOverviewPath);
    expect(find.byKey(const Key('overview-asset-movies')), findsOneWidget);
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
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
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
  });

  testWidgets('mobile bottom navigation labels follow the language provider', (
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

    final bottomNav = find.byKey(const Key('mobile-bottom-navigation'));
    expect(bottomNav, findsOneWidget);
    expect(
      find.descendant(of: bottomNav, matching: find.text('影片')),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(bottomNav),
      listen: false,
    );
    await container
        .read(appLanguageControllerProvider.notifier)
        .setLanguage(AppLanguage.en);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: bottomNav, matching: find.text('Movies')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bottomNav, matching: find.text('影片')),
      findsNothing,
    );
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
      // 概览「最近订阅」区块也会请求 /movies，用 fallback 兜住两条消费方。
      bundle.adapter.setFallbackJson(
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
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/desktop/library/movies/ABC-001');
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/movies/ABC-001',
    );
    expect(find.byKey(const Key('app-topbar-title')), findsNothing);
    expect(find.text('影片详情'), findsNothing);
    expect(find.byKey(const Key('topbar-back-button')), findsOneWidget);
    expect(find.text('Movie 1'), findsOneWidget);
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
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
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

  testWidgets('desktop tags root hides shell topbar, tag detail keeps it', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/tags',
      body: <Map<String, dynamic>>[
        <String, dynamic>{'tag_id': 1, 'name': '巨乳', 'movie_count': 100},
      ],
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/taste-profile',
      body: const <String, dynamic>{
        'sample_movie_count': 0,
        'actresses': <dynamic>[],
        'unsubscribed_actresses': <dynamic>[],
        'tags': <dynamic>[],
      },
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/movies',
      body: const <String, dynamic>{
        'items': <dynamic>[],
        'page': 1,
        'page_size': 24,
        'total': 0,
      },
    );
    final router = buildDesktopRouter(sessionStore: sessionStore);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go(desktopTagsPath);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop-shell-topbar')), findsNothing);
    expect(find.text('按标签发现'), findsOneWidget);
    expect(find.byKey(const Key('tags-page')), findsOneWidget);

    router.go('$desktopTagsPath/1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop-shell-topbar')), findsOneWidget);
    expect(find.byKey(const Key('topbar-back-button')), findsOneWidget);

    router.go(desktopTagsPath);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop-shell-topbar')), findsNothing);
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
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
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
      const MobileMoviePlayerRouteData(
        movieNumber: 'ABC-001',
        mediaId: 100,
        positionSeconds: 61,
      ).location,
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
    final swipeBackGuard = tester.widget<PopScope<void>>(
      find.descendant(
        of: find.byType(MobileMoviePlayerPage),
        matching: find.byType(PopScope<void>),
      ),
    );
    expect(swipeBackGuard.canPop, isFalse);
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
    // 影片详情走沉浸布局：内容全幅，左缘比标准内边距页面更靠左。
    expect(detailStart.dx, lessThan(overviewStart.dx));
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
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 概览页改成统计工作台后，最近添加网格落在首屏之外，先滚动到卡片再点。
    await tester.ensureVisible(
      find.byKey(const Key('movie-summary-card-ABC-001')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/movies/ABC-001',
    );
    expect(find.byKey(const Key('topbar-back-button')), findsOneWidget);
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
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 概览页改成统计工作台后，最近添加网格落在首屏之外，先滚动到卡片再点。
    await tester.ensureVisible(
      find.byKey(const Key('movie-summary-card-ABC-001')),
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
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/desktop/library/movies/ABC-001');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('topbar-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, desktopMoviesPath);
  });

  for (final platform in [AppPlatform.desktop, AppPlatform.mobile]) {
    testWidgets('$platform image search actor navigation returns to results', (
      tester,
    ) async {
      final sessionStore = await _buildLoggedInSessionStore(platform: platform);
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueImageSearchSingleResultResponse(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: {
          'movie_number': 'ABC-001',
          'title': '测试影片',
          'actors': [
            {'id': 1, 'name': '测试演员', 'gender': 1},
          ],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/456/points',
        body: [],
      );
      _enqueueActorDetailResponse(bundle);
      _enqueueActorMoviesResponse(bundle);
      final mobile = platform == AppPlatform.mobile;
      final router = mobile
          ? buildMobileRouter(sessionStore: sessionStore)
          : buildDesktopRouter(sessionStore: sessionStore);
      final drafts = ImageSearchDraftStore();
      final draftId = drafts.save(
        fileName: 'query.png',
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      );
      final location = _buildImageSearchLocation(
        mobile ? mobileImageSearchPath : desktopImageSearchPath,
        draftId: draftId,
      );
      await _pumpRouterApp(
        tester,
        router: router,
        sessionStore: sessionStore,
        bundle: bundle,
        includeShellController: !mobile,
        imageSearchDraftStore: drafts,
      );
      router.go(location);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('image-search-result-card-123')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('image-search-result-preview-actor-1')),
      );
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '${mobile ? mobileActorsPath : desktopActorsPath}/1',
      );
      expect(
        find.byKey(const Key('image-search-result-preview-movie-cover')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(
          Key(mobile ? 'mobile-subpage-back-button' : 'topbar-back-button'),
        ),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), location);
      expect(
        find.byKey(const Key('image-search-result-card-123')),
        findsOneWidget,
      );
      expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);
      expect(tester.takeException(), isNull);
    });
  }

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
      find.byKey(const Key('image-search-result-preview-movie-cover')),
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
      // 概览「最近订阅」区块 1 次 + 影片列表页 1 次。
      expect(bundle.adapter.hitCount('GET', '/movies'), 2);

      await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('topbar-back-button')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, desktopMoviesPath);
      expect(bundle.adapter.hitCount('GET', '/movies'), 2);

      router.go(desktopActorsPath);
      await tester.pumpAndSettle();
      router.go(desktopMoviesPath);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/movies'), 2);
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
      // 概览「最近订阅」区块也会请求 /movies，用 fallback 兜住两条消费方。
      bundle.adapter.setFallbackJson(
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
      // 概览「最近订阅」区块也会请求 /movies，用 fallback 兜住两条消费方。
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/movies',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
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
          'page': 1,
          'page_size': 50,
          'total': 1,
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[],
          'page': 1,
          'page_size': 50,
          'total': 0,
        },
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
      // 概览「最近订阅」区块 1 次 + 搜索页 1 次。
      expect(bundle.adapter.hitCount('GET', '/movies'), 2);
      expect(bundle.adapter.hitCount('GET', '/actors'), 1);

      await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('topbar-back-button')));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/desktop/search/abc001',
      );
      expect(bundle.adapter.hitCount('GET', '/movies'), 2);
      expect(bundle.adapter.hitCount('GET', '/actors'), 1);

      router.go(desktopActorsPath);
      await tester.pumpAndSettle();
      router.go('/desktop/search/abc001');
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/movies'), 2);
      expect(bundle.adapter.hitCount('GET', '/actors'), 2);
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
        find.byKey(const Key('image-search-result-preview-movie-cover')),
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
      // 概览「最近订阅」区块 1 次 + 影片列表页 1 次。
      expect(bundle.adapter.hitCount('GET', '/movies'), 2);

      await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, mobileMoviesPath);
      expect(bundle.adapter.hitCount('GET', '/movies'), 2);

      router.go(mobileOverviewPath);
      await tester.pumpAndSettle();
      router.go(mobileMoviesPath);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/movies'), 2);
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
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('topbar-back-button')), findsNothing);
  });

  testWidgets('评论内搜索番号返回后保留弹窗和评论滚动位置', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDesktopOverviewResponses(bundle);
    _enqueueMovieDetailResponse(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/reviews',
      body: <Map<String, dynamic>>[
        for (var index = 0; index < 20; index++)
          <String, dynamic>{
            'id': index + 1,
            'score': 5,
            'content': '评论 $index 提到 SSNI-888',
            'created_at': '2026-03-10T08:00:00Z',
            'username': 'tester-$index',
            'like_count': 8,
            'watch_count': 15,
          },
      ],
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/movies',
      body: _emptyPagedMovies(),
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/actors',
      body: _emptyPagedMovies(),
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

    router.go('/desktop/library/movies/ABC-001');
    await tester.pumpAndSettle();

    final reviewButton = find.byKey(const Key('movie-detail-hero-review-icon'));
    await tester.ensureVisible(reviewButton);
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    final dialogFinder = find.byKey(const Key('movie-detail-inspector-dialog'));
    expect(dialogFinder, findsOneWidget);

    final reviewListFinder = find.byKey(const Key('movie-detail-review-list'));
    final scrollableFinder = find
        .descendant(of: reviewListFinder, matching: find.byType(Scrollable))
        .first;
    await tester.drag(reviewListFinder, const Offset(0, -240));
    await tester.pumpAndSettle();
    final offsetBeforeSearch = tester
        .state<ScrollableState>(scrollableFinder)
        .position
        .pixels;
    expect(offsetBeforeSearch, greaterThan(0));

    await tester.longPress(
      find.byKey(const Key('movie-detail-review-content')).hitTestable().first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('搜索番号'));
    await tester.pumpAndSettle();

    // 搜索页必须可交互：它压在评论弹窗之上，而不是被弹窗的 barrier 挡住。
    expect(
      find.byKey(const Key('catalog-search-page-input')).hitTestable(),
      findsOneWidget,
    );
    expect(dialogFinder.hitTestable(), findsNothing);

    router.pop();
    await tester.pumpAndSettle();

    expect(dialogFinder.hitTestable(), findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollableFinder).position.pixels,
      moreOrLessEquals(offsetBeforeSearch),
    );
  });

  testWidgets('移动端评论内搜索番号返回后保留抽屉和评论滚动位置', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sessionStore = await _buildLoggedInSessionStore(
      platform: AppPlatform.mobile,
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueMobileMoviesResponse(bundle);
    _enqueueMovieDetailResponse(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/reviews',
      body: <Map<String, dynamic>>[
        for (var index = 0; index < 20; index++)
          <String, dynamic>{
            'id': index + 1,
            'score': 5,
            'content': '评论 $index 提到 SSNI-888',
            'created_at': '2026-03-10T08:00:00Z',
            'username': 'tester-$index',
            'like_count': 8,
            'watch_count': 15,
          },
      ],
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/actors',
      body: _emptyPagedMovies(),
    );

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

    final reviewButton = find.byKey(const Key('movie-detail-hero-review-icon'));
    await tester.ensureVisible(reviewButton);
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    final sheetFinder = find.byKey(
      const Key('movie-detail-inspector-bottom-sheet'),
    );
    expect(sheetFinder, findsOneWidget);

    final reviewListFinder = find.byKey(const Key('movie-detail-review-list'));
    final scrollableFinder = find
        .descendant(of: reviewListFinder, matching: find.byType(Scrollable))
        .first;
    await tester.drag(reviewListFinder, const Offset(0, -180));
    await tester.pumpAndSettle();
    final offsetBeforeSearch = tester
        .state<ScrollableState>(scrollableFinder)
        .position
        .pixels;
    expect(offsetBeforeSearch, greaterThan(0));

    // 移动端抽屉会接管长按拖拽，直接构造选区并拉起选择菜单更稳定。
    final contentFinder = find
        .byKey(const Key('movie-detail-review-content'))
        .hitTestable()
        .first;
    final editableState = tester.state<EditableTextState>(
      find.descendant(of: contentFinder, matching: find.byType(EditableText)),
    );
    final reviewText = editableState.textEditingValue.text;
    editableState.userUpdateTextEditingValue(
      TextEditingValue(
        text: reviewText,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: reviewText.length,
        ),
      ),
      SelectionChangedCause.longPress,
    );
    editableState.showToolbar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('搜索番号'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('catalog-search-page-input')).hitTestable(),
      findsOneWidget,
    );
    expect(sheetFinder.hitTestable(), findsNothing);

    router.pop();
    await tester.pumpAndSettle();

    expect(sheetFinder.hitTestable(), findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollableFinder).position.pixels,
      moreOrLessEquals(offsetBeforeSearch),
    );
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
  final pageStateCache = RiverpodPageCache()..bindSessionStore(sessionStore);

  return tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(
        pageStateCache: pageStateCache,
        imageSearchDraftStore: draftStore,
      ),
      child: OKToast(
        child: MaterialApp.router(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          routerConfig: router,
        ),
      ),
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

String _buildImageSearchLocation(String path, {required String draftId}) {
  return Uri(
    path: path,
    queryParameters: <String, String>{'draftId': draftId},
  ).toString();
}

Map<String, dynamic> _emptyPagedMovies() => <String, dynamic>{
  'items': const <Map<String, dynamic>>[],
  'page': 1,
  'page_size': 24,
  'total': 0,
};

Map<String, dynamic> _playlistJson({
  required int id,
  required String name,
  required String kind,
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'kind': kind,
  'description': '',
  'is_system': true,
  'is_mutable': false,
  'is_deletable': false,
  'movie_count': 0,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-02T00:00:00Z',
};

void _enqueueSystemPlaylistResponses(TestApiBundle bundle) {
  final favorites = _playlistJson(id: 8, name: '收藏', kind: 'favorites');
  final recentlyPlayed = _playlistJson(
    id: 9,
    name: '最近播放',
    kind: 'recently_played',
  );
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/playlists',
    body: <Map<String, dynamic>>[favorites, recentlyPlayed],
  );
  for (final playlist in <Map<String, dynamic>>[favorites, recentlyPlayed]) {
    final id = playlist['id'] as int;
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/$id',
      body: playlist,
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/$id/movies',
      body: _emptyPagedMovies(),
    );
  }
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
  // Riverpod 迁移后：/status 至少被两个消费方触发（概览统计条 +
  // 侧边栏版本行的 appVersionInfoProvider.load），用 fallback 兜住多次调用。
  bundle.adapter.setFallbackJson(
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
      'embedding_service': <String, dynamic>{
        'healthy': true,
        'space_id': 'clip-vit-l-14',
        'dimension': 768,
        'modalities': <String>['image', 'text'],
      },
      'indexing': <String, dynamic>{
        'pending_thumbnails': 23,
        'failed_thumbnails': 2,
      },
    },
  );
}

void _enqueueMobileSystemMaintenanceResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    body: <String, dynamic>{
      'healthy': true,
      'embedding_service': <String, dynamic>{
        'healthy': true,
        'space_id': 'clip-vit-l-14',
        'dimension': 768,
        'modalities': <String>['image', 'text'],
      },
      'indexing': <String, dynamic>{
        'pending_thumbnails': 0,
        'failed_thumbnails': 0,
      },
      'index_space': <String, dynamic>{
        'state': 'ready',
        'indexed_space_id': 'clip-vit-l-14',
        'current_space_id': 'clip-vit-l-14',
        'is_rebuilding': false,
      },
    },
  );
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
          'image': <String, dynamic>{'id': 10, 'origin': '/thumb-1.webp'},
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
  // /movies 会被概览「最近订阅」区块和影片列表页共同请求，用 fallback 兜住，
  // 避免先到者把队列里的一次性响应吃掉。
  bundle.adapter.setFallbackJson(
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
    body: const <String, dynamic>{'indexers': <Map<String, dynamic>>[]},
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
    body: const <String, dynamic>{'indexers': <Map<String, dynamic>>[]},
  );
}

void _enqueueDownloadSelectionResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/indexer-settings',
    body: const <String, dynamic>{'indexers': <Map<String, dynamic>>[]},
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-selection-policy',
    body: _downloadSelectionPolicyJson(),
  );
}

Map<String, dynamic> _downloadSelectionPolicyJson({int version = 1}) {
  return <String, dynamic>{
    'version': version,
    'created_at': '2026-10-29T12:00:00Z',
    'updated_at': '2026-10-29T12:00:00Z',
    'rules': <String, dynamic>{
      'schema_version': 1,
      'indexer_kinds': <String>[],
      'indexer_names': <String>[],
      'min_size_bytes': 1024 * 1024 * 1024,
      'max_size_bytes': 40 * 1024 * 1024 * 1024,
      'min_seeders': 1,
      'max_age_days': null,
      'match_title': true,
      'match_description': true,
      'required_groups': <Map<String, dynamic>>[],
      'excluded_terms': <String>[],
      'preferred_groups': <Map<String, dynamic>>[],
      'ranking': <String>['size_desc'],
      'indexer_priority_names': <String>[],
    },
  };
}

void _enqueueDesktopFollowResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/subscribed-actors/latest',
    body: <String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'javdb_id': 'MovieFOL-001',
          'movie_number': 'FOL-001',
          'title': 'Movie FOL-001',
          'cover_image': null,
          'release_date': '2026-05-01',
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

void _enqueueDesktopRankingsResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/ranking-sources',
    body: <Map<String, dynamic>>[
      <String, dynamic>{'source_key': 'javdb', 'name': 'JavDB'},
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
  // 账号安全页同时加载 API 密钥列表。
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/account/api-keys',
    body: const <dynamic>[],
  );
}

/// 「媒体管理」页挂载即发媒体列表和媒体库请求。
/// 媒体列表用 fallback 常驻空响应（避免后续切 tab 再打穿），媒体库 enqueue 一次。
void _enqueueMobileMediaManagementResponses(TestApiBundle bundle) {
  const emptyPage = <String, dynamic>{
    'items': <Map<String, dynamic>>[],
    'page': 1,
    'page_size': 20,
    'total': 0,
  };
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/media',
    body: emptyPage,
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: const <Map<String, dynamic>>[],
  );
}

void _enqueueActivityCenterResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/jobs',
    body: const <Map<String, dynamic>>[],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/activity/bootstrap',
    body: <String, dynamic>{
      'notifications': <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
      'unread_count': 0,
      'active_task_runs': const <Map<String, dynamic>>[],
      'task_runs': <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
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
