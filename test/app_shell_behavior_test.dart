import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_state.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';

import 'support/test_api_bundle.dart';

void main() {
  testWidgets('desktop sidebar collapses to the token width', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);
    await _pumpDesktopApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
    );
    await tester.pumpAndSettle();

    final expandedWidth =
        tester.getSize(find.byKey(const Key('desktop-shell-sidebar'))).width;
    expect(expandedWidth, AppSidebarTokens.defaults().expandedWidth);
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-shell-sidebar')),
        matching: find.byKey(const Key('sidebar-toggle-button')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('topbar-header')),
        matching: find.byKey(const Key('sidebar-toggle-button')),
      ),
      findsNothing,
    );
    expect(find.text('SakuraMedia'), findsNothing);
    expect(find.text('SA'), findsNothing);

    await tester.tap(find.byKey(const Key('sidebar-toggle-button')));
    await tester.pumpAndSettle();

    final collapsedWidth =
        tester.getSize(find.byKey(const Key('desktop-shell-sidebar'))).width;
    expect(collapsedWidth, AppSidebarTokens.defaults().collapsedWidth);
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-shell-sidebar')),
        matching: find.text('概览'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('sidebar-header')),
        matching: find.byKey(const Key('sidebar-toggle-button')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('topbar-header')),
        matching: find.byKey(const Key('sidebar-toggle-button')),
      ),
      findsNothing,
    );
    expect(find.byTooltip('概览'), findsOneWidget);
  });

  testWidgets('topbar divider aligns with sidebar divider', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);
    await _pumpDesktopApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
    );
    await tester.pumpAndSettle();

    final sidebarDivider = tester.getTopLeft(
      find.byKey(const Key('sidebar-header-divider')),
    );
    final topbarDivider = tester.getTopLeft(
      find.byKey(const Key('topbar-header-divider')),
    );
    expect(sidebarDivider.dy, topbarDivider.dy);
  });

  testWidgets('desktop sidebar does not overflow while expanding', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);
    await _pumpDesktopApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar-toggle-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar-toggle-button')));
    await tester.pump(const Duration(milliseconds: 40));

    expect(tester.takeException(), isNull);
  });

  testWidgets('macOS desktop shell keeps top bar and sidebar toggle layout', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);
    await _pumpDesktopApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-title-bar')), findsNothing);
    expect(find.text('概览'), findsWidgets);
    expect(find.byKey(const Key('topbar-header')), findsOneWidget);
    expect(find.byKey(const Key('sidebar-header')), findsOneWidget);
    expect(find.byKey(const Key('sidebar-header-divider')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-shell-sidebar')),
        matching: find.byKey(const Key('sidebar-toggle-button')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('sidebar-toggle-button')));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('desktop-shell-sidebar'))).width,
      72,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-shell-sidebar')),
        matching: find.byKey(const Key('sidebar-toggle-button')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('sidebar-toggle-button')));
    await tester.pump(const Duration(milliseconds: 40));

    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS desktop shell uses transparent root and opaque content', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);
    await _pumpDesktopApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final contentContainer = tester.widget<Container>(
      find.byKey(const Key('desktop-shell-content-surface')),
    );

    expect(scaffold.backgroundColor, Colors.transparent);
    expect(
      contentContainer.color,
      sakuraThemeData.extension<AppColors>()!.surfaceElevated,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop sidebar decoration adapts for macOS glass effect', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);

    await _pumpDesktopApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
    );
    await tester.pumpAndSettle();

    final defaultSidebar = tester.widget<AnimatedContainer>(
      find.byKey(const Key('desktop-shell-sidebar')),
    );
    final defaultDecoration = defaultSidebar.decoration! as BoxDecoration;
    final themeColors = sakuraThemeData.extension<AppColors>()!;

    expect(defaultDecoration.color, themeColors.sidebarBackground);
    expect(defaultDecoration.boxShadow, isNotEmpty);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    await _pumpDesktopApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
    );
    await tester.pumpAndSettle();

    final macSidebar = tester.widget<AnimatedContainer>(
      find.byKey(const Key('desktop-shell-sidebar')),
    );
    final macDecoration = macSidebar.decoration! as BoxDecoration;

    expect(macDecoration.color, themeColors.desktopSidebarGlassTint);
    expect(macDecoration.boxShadow, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop shell shows only the compact desktop navigation set', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);
    await _pumpDesktopApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nav-group-overview')), findsOneWidget);
    expect(find.byKey(const Key('nav-group-movies')), findsOneWidget);
    expect(find.byKey(const Key('nav-group-actors')), findsOneWidget);
    expect(find.byKey(const Key('nav-group-moments')), findsOneWidget);
    expect(find.byKey(const Key('nav-group-configuration')), findsOneWidget);
    expect(find.byKey(const Key('nav-group-library')), findsNothing);
    expect(find.byKey(const Key('nav-group-resources')), findsNothing);
    expect(find.byKey(const Key('nav-group-system')), findsNothing);
  });

  testWidgets('desktop sidebar navigation items use compact height', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);
    await _pumpDesktopApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('nav-group-overview'))).height,
      AppSidebarTokens.defaults().itemHeight + AppSpacing.defaults().xs,
    );
  });

  testWidgets('desktop sidebar shows search field when expanded', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);

    await _pumpDesktopApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sidebar-search-field')), findsOneWidget);
    expect(find.byKey(const Key('sidebar-search-image')), findsOneWidget);
    expect(find.byKey(const Key('sidebar-search-button')), findsNothing);
  });

  testWidgets('desktop sidebar image search button opens image search page', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(() => debugImageSearchFilePicker = null);
    _enqueueOverviewResponses(bundle);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: <String, dynamic>{
        'session_id': 'session-1',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': null,
        'expires_at': '2026-03-08T10:10:00Z',
        'items': const <Map<String, dynamic>>[],
      },
    );
    debugImageSearchFilePicker =
        () async => ImageSearchPickedFile(
          bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
          fileName: 'picked.png',
          mimeType: 'image/png',
        );

    final router = await _pumpDesktopAppWithRouter(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
      actorsApi: bundle.actorsApi,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar-search-image')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/search/image',
    );
    expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);
  });

  testWidgets(
    'desktop sidebar collapsed search button navigates to search page',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
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

      final router = await _pumpDesktopAppWithRouter(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        statusApi: bundle.statusApi,
        moviesApi: bundle.moviesApi,
        actorsApi: bundle.actorsApi,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sidebar-toggle-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sidebar-search-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sidebar-search-button')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/desktop/search');
    },
  );

  testWidgets('desktop shell uses compact top bar and overview content', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);
    await _pumpDesktopApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      statusApi: bundle.statusApi,
      moviesApi: bundle.moviesApi,
    );
    await tester.pumpAndSettle();

    final titleText = tester.widget<Text>(
      find.byKey(const Key('app-topbar-title')),
    );
    expect(titleText.style?.fontSize, 16);
    expect(
      tester.getSize(find.byKey(const Key('topbar-header'))).height,
      AppComponentTokens.defaults().desktopTitleBarHeight,
    );
    expect(find.byKey(const Key('topbar-back-button')), findsNothing);
    expect(find.text('Desktop Workbench'), findsNothing);
    expect(find.text('系统信息'), findsOneWidget);
    expect(find.text('最近添加'), findsOneWidget);
  });

  testWidgets(
    'desktop sidebar logout button clears session and returns to login',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueOverviewResponses(bundle);
      await _pumpDesktopApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        statusApi: bundle.statusApi,
        moviesApi: bundle.moviesApi,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sidebar-logout-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sidebar-logout-button')));
      await tester.pumpAndSettle();

      expect(sessionStore.hasSession, isFalse);
      expect(find.byKey(const Key('login-form-base-url')), findsOneWidget);
    },
  );
}

Future<SessionStore> _buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}

Future<void> _pumpDesktopApp(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required SessionStore sessionStore,
  required StatusApi statusApi,
  required MoviesApi moviesApi,
}) async {
  final router = buildDesktopRouter(sessionStore: sessionStore);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        ChangeNotifierProvider(create: (_) => AppShellController()),
        Provider<StatusApi>.value(value: statusApi),
        Provider<MoviesApi>.value(value: moviesApi),
        Provider<ImageSearchApi>(
          create: (_) => ImageSearchApi(apiClient: bundle.apiClient),
        ),
      ],
      child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
    ),
  );
}

Future<GoRouter> _pumpDesktopAppWithRouter(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required SessionStore sessionStore,
  required StatusApi statusApi,
  required MoviesApi moviesApi,
  required ActorsApi actorsApi,
}) async {
  final router = buildDesktopRouter(sessionStore: sessionStore);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        ChangeNotifierProvider(create: (_) => AppShellController()),
        Provider<StatusApi>.value(value: statusApi),
        Provider<MoviesApi>.value(value: moviesApi),
        Provider<ActorsApi>.value(value: actorsApi),
        Provider<ImageSearchApi>(
          create: (_) => ImageSearchApi(apiClient: bundle.apiClient),
        ),
      ],
      child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
    ),
  );
  return router;
}

void _enqueueOverviewResponses(TestApiBundle bundle) {
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
      'items': List<Map<String, dynamic>>.generate(
        8,
        (index) => <String, dynamic>{
          'javdb_id': 'MovieA${index + 1}',
          'movie_number': 'ABC-${(index + 1).toString().padLeft(3, '0')}',
          'title': 'Movie ${index + 1}',
          'cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'is_subscribed': index.isEven,
          'can_play': true,
        },
      ),
      'page': 1,
      'page_size': 8,
      'total': 8,
    },
  );
}
