import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/app/app_version_info_controller.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_api.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_reviews_api.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/overview/presentation/mobile_overview_skeleton_page.dart';
import 'package:sakuramedia/features/playlists/data/playlist_order_store.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/search/presentation/mobile_catalog_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'SakuraMedia',
      packageName: 'sakuramedia',
      version: '0.2.2',
      buildNumber: '1',
      buildSignature: '',
    );
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
    final materialTabBar = tester.widget<TabBar>(
      find.descendant(
        of: find.byKey(const Key('mobile-overview-tabs')),
        matching: find.byType(TabBar),
      ),
    );
    final pageRoot = tester.widget<ColoredBox>(
      find.byKey(const Key('mobile-overview-skeleton-page')),
    );
    expect(tabBar.variant, AppTabBarVariant.mobileTop);
    expect(materialTabBar.tabAlignment, TabAlignment.center);
    expect(pageRoot.color, sakuraThemeData.appColors.surfaceCard);
  });

  testWidgets('mobile overview page renders menu button in header', (
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

    expect(
      find.byKey(const Key('mobile-overview-menu-button')),
      findsOneWidget,
    );
  });

  testWidgets('mobile overview menu button aligns with top tab row', (
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

    final menuCenter = tester.getCenter(
      find.byKey(const Key('mobile-overview-menu-button')),
    );
    final tabBarCenter = tester.getCenter(
      find.descendant(
        of: find.byKey(const Key('mobile-overview-tabs')),
        matching: find.byType(TabBar),
      ),
    );

    expect((menuCenter.dy - tabBarCenter.dy).abs(), lessThanOrEqualTo(1));
    expect(menuCenter.dx, lessThan(tabBarCenter.dx));
  });

  testWidgets(
    'mobile overview drawer shows settings actions and bottom logout action',
    (WidgetTester tester) async {
      _enqueueOverviewResponses(bundle);
      final router = buildMobileRouter(sessionStore: sessionStore);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _buildRouterApp(
          sessionStore: sessionStore,
          bundle: bundle,
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
      await tester.pumpAndSettle();

      final librarySection = find.byKey(
        const Key('mobile-overview-drawer-library-section'),
      );
      final overviewSection = find.byKey(
        const Key('mobile-overview-drawer-overview-section'),
      );
      final playlistsSection = find.byKey(
        const Key('mobile-overview-drawer-playlists-section'),
      );
      final overviewItem = find.byKey(
        const Key('mobile-overview-drawer-overview'),
      );
      final mediaLibrariesItem = find.byKey(
        const Key('mobile-overview-drawer-media-libraries'),
      );
      final dataSourcesItem = find.byKey(
        const Key('mobile-overview-drawer-data-sources'),
      );
      final downloadersItem = find.byKey(
        const Key('mobile-overview-drawer-downloaders'),
      );
      final indexersItem = find.byKey(
        const Key('mobile-overview-drawer-indexers'),
      );
      final llmItem = find.byKey(const Key('mobile-overview-drawer-llm'));
      final playlistsItem = find.byKey(
        const Key('mobile-overview-drawer-playlists'),
      );
      final passwordItem = find.byKey(
        const Key('mobile-overview-drawer-password'),
        skipOffstage: false,
      );
      final logoutItem = find.byKey(
        const Key('mobile-overview-drawer-logout'),
        skipOffstage: false,
      );
      final versionCard = find.byKey(
        const Key('mobile-overview-drawer-version-card'),
        skipOffstage: false,
      );
      final bottomActions = find.byKey(
        const Key('mobile-overview-drawer-bottom-actions'),
        skipOffstage: false,
      );
      final drawer = find.byKey(const Key('mobile-overview-drawer'));
      final mediaLibrariesLabel = tester.widget<Text>(
        find.descendant(of: mediaLibrariesItem, matching: find.text('媒体库')),
      );
      final logoutLabel = tester.widget<Text>(
        find.descendant(of: logoutItem, matching: find.text('退出登录')),
      );
      final mediaLibrariesPadding = tester.widget<Padding>(
        find
            .descendant(
              of: mediaLibrariesItem,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Padding &&
                    widget.padding ==
                        EdgeInsets.symmetric(
                          horizontal: sakuraThemeData.appSpacing.md,
                          vertical: sakuraThemeData.appSpacing.sm,
                        ),
              ),
            )
            .first,
      );

      expect(drawer, findsOneWidget);
      expect(find.text('菜单'), findsNothing);
      expect(find.text('配置管理'), findsNothing);
      expect(overviewSection, findsOneWidget);
      expect(librarySection, findsOneWidget);
      expect(playlistsSection, findsOneWidget);
      expect(overviewItem, findsOneWidget);
      expect(dataSourcesItem, findsOneWidget);
      expect(mediaLibrariesItem, findsOneWidget);
      expect(downloadersItem, findsOneWidget);
      expect(indexersItem, findsOneWidget);
      expect(llmItem, findsOneWidget);
      expect(playlistsItem, findsOneWidget);
      expect(passwordItem, findsOneWidget);
      expect(versionCard, findsOneWidget);
      expect(find.text('版本与服务'), findsOneWidget);
      expect(find.text('自动同步'), findsOneWidget);
      expect(find.text('客户端'), findsOneWidget);
      expect(find.text('0.2.2'), findsOneWidget);
      expect(find.text('服务端'), findsOneWidget);
      expect(find.text('v0.2.0'), findsOneWidget);
      expect(logoutItem, findsOneWidget);
      expect(
        tester.getTopLeft(overviewSection).dy,
        lessThan(tester.getTopLeft(librarySection).dy),
      );
      expect(
        find.descendant(
          of: drawer,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: librarySection,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Divider &&
                widget.color ==
                    sakuraThemeData.appColors.borderSubtle.withValues(
                      alpha: 0.56,
                    ),
          ),
        ),
        findsNWidgets(4),
      );
      expect(
        find.descendant(of: librarySection, matching: dataSourcesItem),
        findsOneWidget,
      );
      expect(
        find.descendant(of: librarySection, matching: mediaLibrariesItem),
        findsOneWidget,
      );
      expect(
        find.descendant(of: librarySection, matching: downloadersItem),
        findsOneWidget,
      );
      expect(
        find.descendant(of: librarySection, matching: indexersItem),
        findsOneWidget,
      );
      expect(
        find.descendant(of: librarySection, matching: llmItem),
        findsOneWidget,
      );
      expect(
        find.descendant(of: playlistsSection, matching: playlistsItem),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bottomActions, matching: logoutItem),
        findsOneWidget,
      );
      expect(
        mediaLibrariesLabel.style?.fontSize,
        sakuraThemeData.appTextScale.s14,
      );
      expect(logoutLabel.style?.fontSize, sakuraThemeData.appTextScale.s14);
      expect(
        mediaLibrariesPadding.padding,
        EdgeInsets.symmetric(
          horizontal: sakuraThemeData.appSpacing.md,
          vertical: sakuraThemeData.appSpacing.sm,
        ),
      );
      expect(
        tester.getTopLeft(dataSourcesItem).dy,
        lessThan(tester.getTopLeft(mediaLibrariesItem).dy),
      );
      expect(
        tester.getTopLeft(playlistsSection).dy,
        greaterThan(tester.getBottomLeft(librarySection).dy),
      );
      expect(
        tester.getTopLeft(llmItem).dy,
        greaterThan(tester.getTopLeft(indexersItem).dy),
      );
    },
  );

  testWidgets('mobile overview drawer shows placeholder for missing backend', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle, backendVersion: '');
    final router = buildMobileRouter(sessionStore: sessionStore);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _buildRouterApp(
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-overview-drawer-version-card')),
      findsOneWidget,
    );
    expect(find.text('--'), findsOneWidget);
  });

  testWidgets('mobile overview drawer data sources opens subpage shell', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/metadata-provider-license/status',
      body: _metadataProviderLicenseStatusJson(),
    );
    final router = buildMobileRouter(sessionStore: sessionStore);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _buildRouterApp(
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-overview-drawer-data-sources')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('数据源'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-settings-data-sources')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-data-sources-activate-button')),
      findsOneWidget,
    );
    expect(find.text('开发中'), findsNothing);
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
  });

  testWidgets('mobile overview drawer media libraries opens subpage shell', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle);
    _enqueueMediaLibraries(bundle, libraries: const <Map<String, dynamic>>[]);
    final router = buildMobileRouter(sessionStore: sessionStore);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _buildRouterApp(
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-overview-drawer-media-libraries')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('媒体库'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-settings-media-libraries')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-libraries-create-button')),
      findsOneWidget,
    );
    expect(find.text('开发中'), findsNothing);
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
  });

  testWidgets('mobile overview drawer overview opens system overview page', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle);
    _enqueueSystemOverviewResponses(bundle);
    final router = buildMobileRouter(sessionStore: sessionStore);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _buildRouterApp(
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-overview-drawer-overview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('概览'), findsWidgets);
    expect(
      find.byKey(const Key('mobile-system-overview-page')),
      findsOneWidget,
    );
    expect(find.text('媒体资产'), findsOneWidget);
    expect(find.text('服务健康'), findsOneWidget);
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
  });

  testWidgets('mobile overview drawer password opens real change page', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle);
    final router = buildMobileRouter(sessionStore: sessionStore);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _buildRouterApp(
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();
    final passwordItem = find.byKey(
      const Key('mobile-overview-drawer-password'),
    );
    await tester.ensureVisible(passwordItem);
    await tester.pumpAndSettle();
    await tester.tap(passwordItem);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('修改密码'), findsOneWidget);
    expect(find.byKey(const Key('mobile-settings-password')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-password-submit-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
  });

  testWidgets('mobile overview drawer llm opens real settings page', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle);
    _enqueueLlmSettings(bundle);
    final router = buildMobileRouter(sessionStore: sessionStore);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _buildRouterApp(
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();
    final llmItem = find.byKey(const Key('mobile-overview-drawer-llm'));
    await tester.ensureVisible(llmItem);
    await tester.pumpAndSettle();
    await tester.tap(llmItem);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('LLM 配置'), findsOneWidget);
    expect(find.byKey(const Key('mobile-settings-llm')), findsOneWidget);
    expect(find.byKey(const Key('mobile-llm-save-button')), findsOneWidget);
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
  });

  testWidgets('mobile overview drawer playlists opens real playlists page', (
    WidgetTester tester,
  ) async {
    _enqueueOverviewResponses(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[],
    );
    final router = buildMobileRouter(sessionStore: sessionStore);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _buildRouterApp(
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await tester.pumpAndSettle();
    final playlistsItem = find.byKey(
      const Key('mobile-overview-drawer-playlists'),
    );
    await tester.ensureVisible(playlistsItem);
    await tester.pumpAndSettle();
    await tester.tap(playlistsItem);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.byKey(const Key('mobile-settings-playlists')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-playlists-create-button')),
      findsOneWidget,
    );
    expect(find.text('开发中'), findsNothing);
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
  });

  testWidgets(
    'mobile overview drawer logout clears session and returns login',
    (WidgetTester tester) async {
      _enqueueOverviewResponses(bundle);
      final router = buildMobileRouter(sessionStore: sessionStore);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _buildRouterApp(
          sessionStore: sessionStore,
          bundle: bundle,
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
      await tester.pumpAndSettle();
      final logoutItem = find.byKey(const Key('mobile-overview-drawer-logout'));
      await tester.ensureVisible(logoutItem);
      await tester.pumpAndSettle();
      await tester.tap(logoutItem);
      await tester.pumpAndSettle();

      expect(sessionStore.hasSession, isFalse);
      expect(find.byKey(const Key('login-form-base-url')), findsOneWidget);
    },
  );

  testWidgets('mobile overview tab bar puts hot reviews after moments', (
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

    final tabBar = find.byKey(const Key('mobile-overview-tabs'));
    final momentsCenter = tester.getCenter(
      find.descendant(of: tabBar, matching: find.text('时刻')),
    );
    final hotReviewsCenter = tester.getCenter(
      find.descendant(of: tabBar, matching: find.text('热评')),
    );
    expect(hotReviewsCenter.dx, greaterThan(momentsCenter.dx));
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

  testWidgets(
    'mobile overview hot reviews tab renders reused hot reviews page',
    (WidgetTester tester) async {
      _enqueueOverviewResponses(bundle);

      await tester.pumpWidget(
        _buildTestApp(
          sessionStore: sessionStore,
          bundle: bundle,
          child: const MobileOverviewSkeletonPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('热评'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mobile-overview-hot-reviews-tab')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('desktop-hot-reviews-page-total')),
        findsOneWidget,
      );

      final reviewRequests = bundle.adapter.requests
          .where((request) => request.path == '/hot-reviews')
          .toList(growable: false);
      expect(reviewRequests, isNotEmpty);
      expect(reviewRequests.last.uri.queryParameters['period'], 'weekly');
    },
  );

  testWidgets(
    'mobile overview hot reviews grid resolves to 1 column on narrow and 2 on wide',
    (WidgetTester tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      _enqueueOverviewResponses(bundle);

      await tester.pumpWidget(
        _buildTestApp(
          sessionStore: sessionStore,
          bundle: bundle,
          child: const MobileOverviewSkeletonPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('热评'));
      await tester.pumpAndSettle();

      final gridOnNarrow = tester.widget<GridView>(
        find.byKey(const Key('hot-review-grid')),
      );
      expect(
        (gridOnNarrow.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        1,
      );

      tester.view.physicalSize = const Size(1024, 844);
      await tester.pumpAndSettle();

      final gridOnWide = tester.widget<GridView>(
        find.byKey(const Key('hot-review-grid')),
      );
      expect(
        (gridOnWide.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2,
      );
    },
  );

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
    final draftStore = ImageSearchDraftStore();
    String? draftId;
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
            draftId = state.uri.queryParameters['draftId'];
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
        imageSearchDraftStore: draftStore,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-overview-my-search-image')));
    await tester.pumpAndSettle();

    expect(find.text('mobile-image-search'), findsOneWidget);
    expect(router.canPop(), isTrue);
    final draft = draftStore.get(draftId);
    expect(draft, isNotNull);
    expect(draft!.fileName, 'picked.png');
    expect(draft.mimeType, 'image/png');
    expect(draft.bytes, const <int>[1, 2, 3, 4]);
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
    'mobile overview playlists support long-press reorder and local persistence',
    (WidgetTester tester) async {
      final orderStore = InMemoryPlaylistOrderStore();
      final playlists = <Map<String, dynamic>>[
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
        <String, dynamic>{
          'id': 2,
          'name': '收藏夹',
          'kind': 'custom',
          'description': '',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 0,
          'created_at': null,
          'updated_at': null,
        },
      ];
      _enqueueOverviewResponses(bundle, playlists: playlists);

      await tester.pumpWidget(
        _buildTestApp(
          sessionStore: sessionStore,
          bundle: bundle,
          child: MobileOverviewSkeletonPage(playlistOrderStore: orderStore),
        ),
      );
      await tester.pumpAndSettle();

      final firstCard = find.byKey(const ValueKey<int>(1));
      final secondCard = find.byKey(const ValueKey<int>(2));
      expect(firstCard, findsOneWidget);
      expect(secondCard, findsOneWidget);

      final dragGesture = await tester.startGesture(
        tester.getCenter(firstCard),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await dragGesture.moveBy(const Offset(0, 240));
      await tester.pump(const Duration(milliseconds: 300));
      await dragGesture.up();
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(firstCard).dy,
        greaterThan(tester.getTopLeft(secondCard).dy),
      );
      expect(
        await orderStore.readPlaylistOrder(scopeKey: 'https://api.example.com'),
        <int>[2, 1],
      );

      _enqueueOverviewResponses(bundle, playlists: playlists);
      await tester.pumpWidget(
        _buildTestApp(
          sessionStore: sessionStore,
          bundle: bundle,
          child: MobileOverviewSkeletonPage(playlistOrderStore: orderStore),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const ValueKey<int>(2))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey<int>(1))).dy),
      );
    },
  );

  testWidgets('mobile overview reorder start triggers medium haptic feedback', (
    WidgetTester tester,
  ) async {
    final methodCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        methodCalls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final playlists = <Map<String, dynamic>>[
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
      <String, dynamic>{
        'id': 2,
        'name': '收藏夹',
        'kind': 'custom',
        'description': '',
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'movie_count': 0,
        'created_at': null,
        'updated_at': null,
      },
    ];
    _enqueueOverviewResponses(bundle, playlists: playlists);

    await tester.pumpWidget(
      _buildTestApp(
        sessionStore: sessionStore,
        bundle: bundle,
        child: const MobileOverviewSkeletonPage(),
      ),
    );
    await tester.pumpAndSettle();

    final firstCard = find.byKey(const ValueKey<int>(1));
    final dragGesture = await tester.startGesture(tester.getCenter(firstCard));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await dragGesture.moveBy(const Offset(0, 240));
    await tester.pump(const Duration(milliseconds: 300));
    await dragGesture.up();
    await tester.pumpAndSettle();

    expect(
      methodCalls.any(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.mediumImpact',
      ),
      isTrue,
    );
  });

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

  testWidgets('mobile overview latest movie tap pushes movie detail', (
    WidgetTester tester,
  ) async {
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
          path: '$mobileMoviesPath/:movieNumber',
          builder:
              (_, state) => Scaffold(
                body: Text(
                  'movie:${state.pathParameters['movieNumber']}',
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

    await tester.tap(find.byKey(const Key('movie-summary-card-ABP-123')));
    await tester.pumpAndSettle();

    expect(find.text('movie:ABP-123'), findsOneWidget);
    expect(router.canPop(), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-overview-tabs')), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('mobile overview hot reviews card tap pushes movie detail', (
    WidgetTester tester,
  ) async {
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
          path: '$mobileMoviesPath/:movieNumber',
          builder:
              (_, state) => Scaffold(
                body: Text(
                  'movie:${state.pathParameters['movieNumber']}',
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

    await tester.tap(find.text('热评'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hot-review-card-101')));
    await tester.pumpAndSettle();

    expect(find.text('movie:ABP-001'), findsOneWidget);
    expect(router.canPop(), isTrue);
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

      final followScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );

      for (var index = 0; index < 6; index += 1) {
        await tester.fling(followScrollable, const Offset(0, -900), 1500);
        await tester.pumpAndSettle();
      }
      await tester.pumpAndSettle();
      expect(
        bundle.adapter.hitCount('GET', '/movies/subscribed-actors/latest'),
        greaterThanOrEqualTo(2),
      );

      await tester.fling(followScrollable, const Offset(0, -300), 1200);
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
          builder:
              (_, state) => Scaffold(
                body: Text(
                  'movie:${state.pathParameters['movieNumber']}',
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
    await tester.tap(find.text('关注'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-follow-movie-card-ABP-300')));
    await tester.pumpAndSettle();
    expect(find.text('movie:ABP-300'), findsOneWidget);
    expect(router.canPop(), isTrue);
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
      Provider<AccountApi>.value(value: bundle.accountApi),
      Provider<ActorsApi>.value(value: bundle.actorsApi),
      Provider<AuthApi>.value(value: bundle.authApi),
      Provider<CollectionNumberFeaturesApi>.value(
        value: bundle.collectionNumberFeaturesApi,
      ),
      Provider<DownloadClientsApi>.value(value: bundle.downloadClientsApi),
      Provider<IndexerSettingsApi>.value(value: bundle.indexerSettingsApi),
      Provider<MediaLibrariesApi>.value(value: bundle.mediaLibrariesApi),
      Provider<MetadataProviderLicenseApi>.value(
        value: bundle.metadataProviderLicenseApi,
      ),
      Provider<MovieDescTranslationSettingsApi>.value(
        value: bundle.movieDescTranslationSettingsApi,
      ),
      Provider<MoviesApi>.value(value: bundle.moviesApi),
      Provider<StatusApi>.value(value: bundle.statusApi),
      ChangeNotifierProvider<AppVersionInfoController>(
        create: (_) => AppVersionInfoController(statusApi: bundle.statusApi),
      ),
      ChangeNotifierProvider(
        create: (_) => MovieCollectionTypeChangeNotifier(),
      ),
      ChangeNotifierProvider(create: (_) => MovieSubscriptionChangeNotifier()),
      Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
      Provider<HotReviewsApi>.value(value: bundle.hotReviewsApi),
      Provider<MediaApi>(create: (_) => MediaApi(apiClient: bundle.apiClient)),
      Provider<AppPlatform>.value(value: AppPlatform.mobile),
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
  ImageSearchDraftStore? imageSearchDraftStore,
}) {
  final draftStore = imageSearchDraftStore ?? ImageSearchDraftStore();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
      Provider<ApiClient>.value(value: bundle.apiClient),
      Provider<AccountApi>.value(value: bundle.accountApi),
      Provider<ActorsApi>.value(value: bundle.actorsApi),
      Provider<AuthApi>.value(value: bundle.authApi),
      Provider<CollectionNumberFeaturesApi>.value(
        value: bundle.collectionNumberFeaturesApi,
      ),
      Provider<DownloadClientsApi>.value(value: bundle.downloadClientsApi),
      Provider<IndexerSettingsApi>.value(value: bundle.indexerSettingsApi),
      Provider<MediaLibrariesApi>.value(value: bundle.mediaLibrariesApi),
      Provider<MetadataProviderLicenseApi>.value(
        value: bundle.metadataProviderLicenseApi,
      ),
      Provider<MovieDescTranslationSettingsApi>.value(
        value: bundle.movieDescTranslationSettingsApi,
      ),
      Provider<MoviesApi>.value(value: bundle.moviesApi),
      Provider<StatusApi>.value(value: bundle.statusApi),
      ChangeNotifierProvider<AppVersionInfoController>(
        create: (_) => AppVersionInfoController(statusApi: bundle.statusApi),
      ),
      ChangeNotifierProvider(
        create: (_) => MovieCollectionTypeChangeNotifier(),
      ),
      ChangeNotifierProvider(create: (_) => MovieSubscriptionChangeNotifier()),
      Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
      Provider<HotReviewsApi>.value(value: bundle.hotReviewsApi),
      Provider<ImageSearchDraftStore>.value(value: draftStore),
      Provider<MediaApi>(create: (_) => MediaApi(apiClient: bundle.apiClient)),
    ],
    child: OKToast(
      child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
    ),
  );
}

void _enqueueOverviewResponses(
  TestApiBundle bundle, {
  List<Map<String, dynamic>>? playlists,
  String backendVersion = 'v0.2.0',
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status',
    statusCode: 200,
    body: _statusJson(backendVersion: backendVersion),
  );
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
    body:
        playlists ??
        <Map<String, dynamic>>[
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
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/hot-reviews',
    statusCode: 200,
    body: _hotReviewsPageJson(),
  );
}

void _enqueueSystemOverviewResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status',
    statusCode: 200,
    body: _statusJson(),
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    statusCode: 200,
    body: _imageSearchStatusJson(),
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/metadata-provider-license/status',
    statusCode: 200,
    body: _metadataProviderLicenseStatusJson(),
  );
}

Map<String, dynamic> _statusJson({
  int totalSizeBytes = 987654321,
  String backendVersion = 'v0.2.0',
}) {
  return <String, dynamic>{
    'backend_version': backendVersion,
    'actors': <String, dynamic>{'female_total': 12, 'female_subscribed': 8},
    'movies': <String, dynamic>{'total': 120, 'subscribed': 35, 'playable': 88},
    'media_files': <String, dynamic>{
      'total': 156,
      'total_size_bytes': totalSizeBytes,
    },
    'media_libraries': <String, dynamic>{'total': 3},
  };
}

Map<String, dynamic> _imageSearchStatusJson() {
  return <String, dynamic>{
    'healthy': true,
    'joytag': <String, dynamic>{'healthy': true, 'used_device': 'GPU'},
    'indexing': <String, dynamic>{
      'pending_thumbnails': 23,
      'failed_thumbnails': 2,
    },
  };
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

void _enqueueLlmSettings(TestApiBundle bundle) {
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

void _enqueueMediaLibraries(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> libraries,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: libraries,
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

Map<String, dynamic> _hotReviewsPageJson({
  int page = 1,
  int pageSize = 20,
  int total = 1,
  List<Map<String, dynamic>>? items,
}) {
  return <String, dynamic>{
    'items': items ?? <Map<String, dynamic>>[_hotReviewItemJson()],
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}

Map<String, dynamic> _hotReviewItemJson({
  int rank = 1,
  int reviewId = 101,
  int score = 5,
  String movieNumber = 'ABP-001',
  String content = '值得反复看',
  String username = 'demo-user',
}) {
  return <String, dynamic>{
    'rank': rank,
    'review_id': reviewId,
    'score': score,
    'content': content,
    'created_at': '2026-03-21T01:00:00Z',
    'username': username,
    'like_count': 11,
    'watch_count': 21,
    'movie': <String, dynamic>{
      'javdb_id': 'javdb-$movieNumber',
      'movie_number': movieNumber,
      'title': 'Movie $movieNumber',
      'cover_image': null,
      'release_date': null,
      'duration_minutes': 0,
      'is_subscribed': false,
      'can_play': false,
    },
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
