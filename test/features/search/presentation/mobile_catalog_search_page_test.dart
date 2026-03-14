import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/search/presentation/mobile_catalog_search_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';

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
    bundle.dispose();
  });

  testWidgets('mobile catalog search submits query with push stack', (
    WidgetTester tester,
  ) async {
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

    final router = _buildRouter();
    await _pumpPage(tester, bundle: bundle, router: router);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('catalog-search-page-input')),
      'abp123',
    );
    await tester.tap(find.byKey(const Key('catalog-search-page-submit')));
    await tester.pumpAndSettle();

    expect(router.canPop(), isTrue);
    expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 1);
  });

  testWidgets('mobile catalog search keeps query history on repeated submits', (
    WidgetTester tester,
  ) async {
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
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'ssni001',
        'parsed': true,
        'movie_number': 'SSNI-001',
        'reason': null,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/search/local',
      body: <Map<String, dynamic>>[],
    );

    final router = _buildRouter();
    await _pumpPage(tester, bundle: bundle, router: router);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('catalog-search-page-input')),
      'abp123',
    );
    await tester.tap(find.byKey(const Key('catalog-search-page-submit')));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);

    await tester.enterText(
      find.byKey(const Key('catalog-search-page-input')),
      'ssni001',
    );
    await tester.tap(find.byKey(const Key('catalog-search-page-submit')));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 2);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse);
  });

  testWidgets(
    'mobile catalog search does not push duplicate route for identical query',
    (WidgetTester tester) async {
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

      final router = _buildRouter();
      await _pumpPage(tester, bundle: bundle, router: router);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('catalog-search-page-input')),
        'abp123',
      );
      await tester.tap(find.byKey(const Key('catalog-search-page-submit')));
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);

      await tester.enterText(
        find.byKey(const Key('catalog-search-page-input')),
        'abp123',
      );
      await tester.tap(find.byKey(const Key('catalog-search-page-submit')));
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(router.canPop(), isFalse);
    },
  );

  testWidgets(
    'mobile catalog search does not push when current route is empty search',
    (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: mobileOverviewPath,
        routes: [
          GoRoute(
            path: mobileOverviewPath,
            builder:
                (context, state) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => context.push(mobileSearchPath),
                      child: const Text('open-search'),
                    ),
                  ),
                ),
          ),
          GoRoute(
            path: mobileSearchPath,
            builder: (_, __) => const MobileCatalogSearchPage(initialQuery: ''),
          ),
          GoRoute(
            path: '$mobileSearchPath/:query',
            builder:
                (_, state) => MobileCatalogSearchPage(
                  initialQuery: state.pathParameters['query'] ?? '',
                ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await _pumpPage(tester, bundle: bundle, router: router);
      await tester.pumpAndSettle();

      await tester.tap(find.text('open-search'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('catalog-search-page-input')),
        findsOneWidget,
      );
      expect(router.canPop(), isTrue);

      await tester.tap(find.byKey(const Key('catalog-search-page-submit')));
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('open-search'), findsOneWidget);
    },
  );

  testWidgets('mobile catalog search movie tap shows developing toast', (
    WidgetTester tester,
  ) async {
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
      body: <Map<String, dynamic>>[
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
    );

    final router = _buildRouter();
    await _pumpPage(tester, bundle: bundle, router: router);
    router.go('/mobile/search/abp123');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-summary-card-ABP-123')));
    await tester.pumpAndSettle();

    expect(find.text('移动端影片详情开发中'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: mobileSearchPath,
    routes: [
      GoRoute(
        path: mobileSearchPath,
        builder: (_, __) => const MobileCatalogSearchPage(initialQuery: ''),
      ),
      GoRoute(
        path: '$mobileSearchPath/:query',
        builder:
            (_, state) => MobileCatalogSearchPage(
              initialQuery: state.pathParameters['query'] ?? '',
            ),
      ),
    ],
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<ActorsApi>.value(value: bundle.actorsApi),
      ],
      child: OKToast(
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    ),
  );
}
