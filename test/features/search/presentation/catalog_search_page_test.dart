import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_page.dart';
import 'package:sakuramedia/routes/desktop_search_route_state.dart';
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

  testWidgets('search page shows movies tab active after movie-number match', (
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

    final router = _buildRouter(bundle);
    await _pumpSearchApp(tester, bundle: bundle, router: router);
    router.go('/desktop/search/abp123');
    await tester.pumpAndSettle();

    expect(find.text('影片'), findsWidgets);
    expect(find.text('女优'), findsWidgets);
    expect(find.byKey(const Key('movie-summary-grid')), findsOneWidget);
    expect(find.byKey(const Key('actor-summary-grid')), findsNothing);
    expect(find.text('另一类结果未执行搜索'), findsNothing);
  });

  testWidgets('search page shows actors tab active after actor-name search', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'mikami',
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
          'name': '三上悠亚',
          'alias_name': '三上悠亚 / 鬼头桃菜',
          'profile_image': null,
          'is_subscribed': false,
        },
      ],
    );

    final router = _buildRouter(bundle);
    await _pumpSearchApp(tester, bundle: bundle, router: router);
    router.go('/desktop/search/mikami');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('actor-summary-grid')), findsOneWidget);
    expect(find.text('三上悠亚 / 鬼头桃菜'), findsOneWidget);
    expect(find.text('另一类结果未执行搜索'), findsNothing);
  });

  testWidgets('search page top field pushes a new query route on submit', (
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
        'query': 'mikami',
        'parsed': false,
        'movie_number': null,
        'reason': 'movie_number_not_found',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/search/local',
      body: <Map<String, dynamic>>[],
    );

    final router = _buildRouter(bundle);
    await _pumpSearchApp(tester, bundle: bundle, router: router);
    router.go('/desktop/search/abp123');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'mikami');
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/search/mikami',
    );
  });

  testWidgets('search page shows online toggle from route state extra', (
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
    bundle.adapter.enqueueSse(
      method: 'POST',
      path: '/movies/search/javdb/stream',
      chunks: <String>[
        'event: search_started\n'
            'data: {"movie_number":"ABP-123"}\n\n'
            'event: completed\n'
            'data: {"success":true,"movies":[],"failed_items":[],"stats":{"total":0,"created_count":0,"already_exists_count":0,"failed_count":0}}\n\n',
      ],
    );

    final router = _buildRouter(bundle);
    await _pumpSearchApp(tester, bundle: bundle, router: router);
    router.go(
      '/desktop/search/abp123',
      extra: const DesktopSearchRouteState(
        fallbackPath: '/desktop/overview',
        useOnlineSearch: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    final request = bundle.adapter.requests.last;
    expect(request.path, '/movies/search/javdb/stream');
  });

  testWidgets('search page submits online movie search and shows stream status', (
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
    bundle.adapter.enqueueSse(
      method: 'POST',
      path: '/movies/search/javdb/stream',
      chunkInterval: const Duration(milliseconds: 20),
      chunks: <String>[
        'event: search_started\n'
            'data: {"movie_number":"ABP-123"}\n\n',
        'event: upsert_started\n'
            'data: {"total":1}\n\n',
        'event: completed\n'
            'data: {"success":true,"movies":[{"javdb_id":"MovieA1","movie_number":"ABP-123","title":"Movie 1","cover_image":null,"release_date":null,"duration_minutes":120,"is_subscribed":false,"can_play":true}],"failed_items":[],"stats":{"total":1,"created_count":1,"already_exists_count":0,"failed_count":0}}\n\n',
      ],
    );

    final router = _buildRouter(bundle);
    await _pumpSearchApp(tester, bundle: bundle, router: router);
    await tester.pumpAndSettle();

    router.go(
      '/desktop/search/abp123',
      extra: const DesktopSearchRouteState(
        fallbackPath: '/desktop/overview',
        useOnlineSearch: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('catalog-search-stream-status-card')),
      findsOneWidget,
    );
    expect(find.text('在线搜索已完成'), findsOneWidget);
    expect(find.byKey(const Key('movie-summary-card-ABP-123')), findsOneWidget);
  });

  testWidgets(
    'search page re-submits same online movie query when tapping search button again',
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
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/movies/search/javdb/stream',
        chunks: <String>[
          'event: completed\n'
              'data: {"success":true,"movies":[],"failed_items":[],"stats":{"total":0,"created_count":0,"already_exists_count":0,"failed_count":0}}\n\n',
        ],
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
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/movies/search/javdb/stream',
        chunks: <String>[
          'event: completed\n'
              'data: {"success":true,"movies":[{"javdb_id":"MovieA1","movie_number":"ABP-123","title":"Movie 1","cover_image":null,"release_date":null,"duration_minutes":120,"is_subscribed":false,"can_play":true}],"failed_items":[],"stats":{"total":1,"created_count":1,"already_exists_count":0,"failed_count":0}}\n\n',
        ],
      );

      final router = _buildRouter(bundle);
      await _pumpSearchApp(tester, bundle: bundle, router: router);
      router.go(
        '/desktop/search/abp123',
        extra: const DesktopSearchRouteState(
          fallbackPath: '/desktop/overview',
          useOnlineSearch: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('在线源未找到该番号或未成功入库'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 2);
      expect(bundle.adapter.hitCount('POST', '/movies/search/javdb/stream'), 2);
      expect(
        find.byKey(const Key('movie-summary-card-ABP-123')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'search page shows centered adaptive spinner while online movie search is running',
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
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/movies/search/javdb/stream',
        chunkInterval: const Duration(milliseconds: 20),
        chunks: <String>[
          'event: search_started\n'
              'data: {"movie_number":"ABP-123"}\n\n',
          'event: completed\n'
              'data: {"success":true,"movies":[],"failed_items":[],"stats":{"total":0,"created_count":0,"already_exists_count":0,"failed_count":0}}\n\n',
        ],
      );

      final router = _buildRouter(bundle);
      await _pumpSearchApp(tester, bundle: bundle, router: router);

      router.go(
        '/desktop/search/abp123',
        extra: const DesktopSearchRouteState(
          fallbackPath: '/desktop/overview',
          useOnlineSearch: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(
        find.byKey(const Key('catalog-search-loading-indicator')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-skeleton-0')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'search page shows centered adaptive spinner while online actor search is running',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/movies/search/parse-number',
        body: <String, dynamic>{
          'query': 'mikami',
          'parsed': false,
          'movie_number': null,
          'reason': 'movie_number_not_found',
        },
      );
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/actors/search/javdb/stream',
        chunkInterval: const Duration(milliseconds: 20),
        chunks: <String>[
          'event: search_started\n'
              'data: {"actor_name":"mikami"}\n\n',
          'event: completed\n'
              'data: {"success":false,"reason":"actor_not_found","actors":[]}\n\n',
        ],
      );

      final router = _buildRouter(bundle);
      await _pumpSearchApp(tester, bundle: bundle, router: router);

      router.go(
        '/desktop/search/mikami',
        extra: const DesktopSearchRouteState(
          fallbackPath: '/desktop/overview',
          useOnlineSearch: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(
        find.byKey(const Key('catalog-search-loading-indicator')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byKey(const Key('actor-summary-card-skeleton-0')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'search page shows online empty state when stream completes without actor results',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/movies/search/parse-number',
        body: <String, dynamic>{
          'query': 'mikami',
          'parsed': false,
          'movie_number': null,
          'reason': 'movie_number_not_found',
        },
      );
      bundle.adapter.enqueueSse(
        method: 'POST',
        path: '/actors/search/javdb/stream',
        chunks: <String>[
          'event: search_started\n'
              'data: {"actor_name":"mikami"}\n\n'
              'event: completed\n'
              'data: {"success":false,"reason":"actor_not_found","actors":[]}\n\n',
        ],
      );

      final router = _buildRouter(bundle);
      await _pumpSearchApp(tester, bundle: bundle, router: router);
      router.go(
        '/desktop/search/mikami',
        extra: const DesktopSearchRouteState(
          fallbackPath: '/desktop/overview',
          useOnlineSearch: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('在线源未找到匹配女优'), findsOneWidget);
      expect(find.text('在线搜索已完成'), findsOneWidget);
    },
  );

  testWidgets('search page re-submits same online actor query on keyboard action', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'mikami',
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
            'data: {"success":false,"reason":"actor_not_found","actors":[]}\n\n',
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'mikami',
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
            'data: {"success":true,"actors":[{"id":1,"javdb_id":"ActorA1","name":"三上悠亚","alias_name":"三上悠亚 / 鬼头桃菜","profile_image":null,"is_subscribed":false}]}\n\n',
      ],
    );

    final router = _buildRouter(bundle);
    await _pumpSearchApp(tester, bundle: bundle, router: router);
    router.go(
      '/desktop/search/mikami',
      extra: const DesktopSearchRouteState(
        fallbackPath: '/desktop/overview',
        useOnlineSearch: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('在线源未找到匹配女优'), findsOneWidget);

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 2);
    expect(bundle.adapter.hitCount('POST', '/actors/search/javdb/stream'), 2);
    expect(find.byKey(const Key('actor-summary-card-1')), findsOneWidget);
  });

  testWidgets('search page cards navigate to detail pages', (
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

    final router = _buildRouter(bundle);
    await _pumpSearchApp(tester, bundle: bundle, router: router);
    router.go('/desktop/search/abp123');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-summary-card-ABP-123')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/movies/ABP-123',
    );
  });

  testWidgets('search page movie subscription button toggles existing card', (
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
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABP-123/subscription',
      statusCode: 204,
    );

    final router = _buildRouter(bundle);
    await _pumpSearchApp(tester, bundle: bundle, router: router);
    router.go('/desktop/search/abp123');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('movie-summary-card-subscription-ABP-123')),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('PUT', '/movies/ABP-123/subscription'), 1);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/search/abp123',
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('search page shows toast when movie unsubscribe is blocked', (
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
          'is_subscribed': true,
          'can_play': true,
        },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/ABP-123/subscription',
      statusCode: 409,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'movie_subscription_has_media',
          'message': '影片存在媒体文件，若需取消订阅请传 delete_media=true',
        },
      },
    );

    final router = _buildRouter(bundle);
    await _pumpSearchApp(tester, bundle: bundle, router: router);
    router.go('/desktop/search/abp123');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('movie-summary-card-subscription-ABP-123')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('该影片存在媒体，默认不能取消订阅'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('search page actor subscription button toggles existing card', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'mikami',
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
          'name': '三上悠亚',
          'alias_name': '三上悠亚 / 鬼头桃菜',
          'profile_image': null,
          'is_subscribed': false,
        },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/actors/1/subscription',
      statusCode: 204,
    );

    final router = _buildRouter(bundle);
    await _pumpSearchApp(tester, bundle: bundle, router: router);
    router.go('/desktop/search/mikami');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('actor-summary-card-subscription-1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(bundle.adapter.hitCount('PUT', '/actors/1/subscription'), 1);
    expect(find.text('已订阅女优'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'search page resets to idle state when query route becomes empty',
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

      final router = _buildRouter(bundle);
      await _pumpSearchApp(tester, bundle: bundle, router: router);
      router.go('/desktop/search/abp123');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-summary-card-ABP-123')),
        findsOneWidget,
      );

      router.go('/desktop/search');
      await tester.pumpAndSettle();

      expect(find.text('输入关键词开始搜索'), findsOneWidget);
      expect(find.byKey(const Key('movie-summary-card-ABP-123')), findsNothing);
    },
  );
}

GoRouter _buildRouter(TestApiBundle bundle) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/desktop/search',
        builder:
            (context, state) => CatalogSearchPage(
              initialQuery: '',
              fallbackPath:
                  DesktopSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).fallbackPath,
              initialUseOnlineSearch:
                  DesktopSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).useOnlineSearch,
            ),
      ),
      GoRoute(
        path: '/desktop/search/:query',
        builder:
            (context, state) => CatalogSearchPage(
              initialQuery: state.pathParameters['query']!,
              fallbackPath:
                  DesktopSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).fallbackPath,
              initialUseOnlineSearch:
                  DesktopSearchRouteState.maybeFromExtra(
                    state.extra,
                  ).useOnlineSearch,
            ),
      ),
      GoRoute(
        path: '/desktop/library/movies/:movieNumber',
        builder: (context, state) => const Scaffold(body: Text('movie detail')),
      ),
      GoRoute(
        path: '/desktop/library/actors/:actorId',
        builder: (context, state) => const Scaffold(body: Text('actor detail')),
      ),
    ],
  );
}

Future<void> _pumpSearchApp(
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
