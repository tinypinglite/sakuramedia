import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';

import '../support/test_api_bundle.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'video collection detail returns to the list without animating a new shell page',
    (tester) async {
      final router = await _pumpDesktopApp(
        tester,
        initialLocation: desktopVideosPath,
      );

      router.push(desktopVideoCollectionsPath);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video-collection-card-tap-1')));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '$desktopVideoCollectionsPath/1',
      );

      router.pop();
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        desktopVideoCollectionsPath,
      );

      await tester.tap(find.byKey(const Key('video-collection-card-tap-1')));
      await tester.pumpAndSettle();
      await _tapRankingsSidebar(tester);

      expect(
        router.routeInformationProvider.value.uri.path,
        desktopRankingsPath,
      );
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'switching sidebar from a directly opened shell-level page has no shell transition',
    (tester) async {
      final router = await _pumpDesktopApp(
        tester,
        initialLocation: desktopVideoCollectionsPath,
      );

      await _tapRankingsSidebar(tester);

      expect(
        router.routeInformationProvider.value.uri.path,
        desktopRankingsPath,
      );
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpAndSettle();
    },
  );
}

Future<GoRouter> _pumpDesktopApp(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  tester.view.physicalSize = const Size(1100, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final session = SessionStore.inMemory();
  await session.saveBaseUrl('https://api.example.com');
  await session.saveTokens(
    accessToken: 'test',
    refreshToken: 'test',
    expiresAt: DateTime(2099),
  );
  final bundle = await createTestApiBundle(session);
  addTearDown(bundle.dispose);
  _enqueueNavigationResponses(bundle);

  final router = buildDesktopRouter(sessionStore: session)..go(initialLocation);
  addTearDown(router.dispose);
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
        builder: (context, child) =>
            OKToast(child: child ?? const SizedBox.shrink()),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void _enqueueNavigationResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/videos',
    body: <String, dynamic>{
      'items': <dynamic>[],
      'page': 1,
      'page_size': 24,
      'total': 0,
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/video-collections',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': '测试合集',
        'description': '',
        'item_count': 0,
        'cover_image': null,
      },
    ],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/video-collections/1',
    body: <String, dynamic>{
      'id': 1,
      'name': '测试合集',
      'description': '',
      'item_count': 0,
      'cover_image': null,
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/video-collections/1/videos',
    body: <String, dynamic>{
      'items': <dynamic>[],
      'page': 1,
      'page_size': 100,
      'total': 0,
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/ranking-sources',
    body: <dynamic>[],
  );
}

Future<void> _tapRankingsSidebar(WidgetTester tester) async {
  final rankingsNav = find.byKey(const Key('nav-group-rankings'));
  await tester.ensureVisible(rankingsNav);
  await tester.pumpAndSettle();
  await tester.tap(rankingsNav);
  await tester.pump();
  // 侧栏选中态本身有 120ms 的容器动画，等它结束后不应再有页面转场。
  await tester.pump(const Duration(milliseconds: 150));
}
