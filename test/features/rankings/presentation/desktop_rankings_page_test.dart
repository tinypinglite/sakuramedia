import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/rankings/presentation/desktop_rankings_page.dart';
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

  testWidgets('desktop rankings page shows loading skeletons before data resolves',
      (WidgetTester tester) async {
    final completer = Completer<void>();
    _enqueueDefaultSourcesAndBoards(bundle);
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      responder: (options, body) async {
        await completer.future;
        return ResponseBody.fromString(
          jsonEncode(_rankingItemsJson(total: 2)),
          200,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    await _pumpRankingsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pump();

    expect(find.byKey(const Key('ranked-movie-summary-grid')), findsOneWidget);
    expect(
      find.byKey(const Key('ranked-movie-summary-card-skeleton-0')),
      findsOneWidget,
    );

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('desktop rankings page renders total count and rank badges',
      (WidgetTester tester) async {
    _enqueueDefaultSourcesAndBoards(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(total: 2),
    );

    await _pumpRankingsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-rankings-page-total')), findsOneWidget);
    expect(find.text('2 部'), findsOneWidget);
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(
      find.byKey(const Key('movie-summary-card-rank-ABC-001')),
      findsOneWidget,
    );
  });

  testWidgets('desktop rankings filter panel supports immediate reload and keeps open',
      (WidgetTester tester) async {
    _enqueueDefaultSourcesAndBoards(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(total: 1),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(total: 1),
    );

    await _pumpRankingsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(_queryValue(bundle, 2, 'period'), 'daily');

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rankings-filter-period-weekly')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_queryValue(bundle, 3, 'period'), 'weekly');
    expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);
  });

  testWidgets('desktop rankings filter panel closes when tapping outside',
      (WidgetTester tester) async {
    _enqueueDefaultSourcesAndBoards(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(total: 1),
    );

    await _pumpRankingsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rankings-filter-panel')), findsNothing);
  });

  testWidgets('desktop rankings page uses board default_period and supported_periods',
      (WidgetTester tester) async {
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
          'supported_periods': <String>['daily', 'weekly'],
          'default_period': 'weekly',
        },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(total: 1),
    );

    await _pumpRankingsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(_queryValue(bundle, 2, 'period'), 'weekly');

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rankings-filter-period-daily')), findsOneWidget);
    expect(
      find.byKey(const Key('rankings-filter-period-weekly')),
      findsOneWidget,
    );
    expect(find.text('月榜'), findsNothing);
  });

  testWidgets('desktop rankings page retries failed load-more without clearing items',
      (WidgetTester tester) async {
    _enqueueDefaultSourcesAndBoards(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(
        total: 30,
        items: List<Map<String, dynamic>>.generate(
          24,
          (index) => _rankingItem(
            rank: index + 1,
            movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
          ),
        ),
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    await _pumpRankingsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2800),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(find.text('加载更多失败，请点击重试'), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(
        page: 2,
        total: 30,
        items: List<Map<String, dynamic>>.generate(
          6,
          (index) => _rankingItem(
            rank: index + 25,
            movieNumber: 'ABC-${(index + 25).toString().padLeft(3, '0')}',
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.widgetWithText(TextButton, '重试'));
    await tester.tap(find.widgetWithText(TextButton, '重试'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-summary-card-ABC-025')), findsOneWidget);
  });

  testWidgets('desktop rankings page navigates to movie detail with fallback path',
      (WidgetTester tester) async {
    _enqueueDefaultSourcesAndBoards(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(total: 1),
    );

    String? receivedExtra;
    final router = GoRouter(
      initialLocation: desktopRankingsPath,
      routes: [
        GoRoute(
          path: desktopRankingsPath,
          builder: (context, state) => const DesktopRankingsPage(),
        ),
        GoRoute(
          path: '/desktop/library/movies/:movieNumber',
          builder: (context, state) {
            receivedExtra = state.extra as String?;
            return const SizedBox(key: Key('movie-detail-destination'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          Provider<RankingsApi>.value(value: bundle.rankingsApi),
        ],
        child: OKToast(
          child: MaterialApp.router(
            theme: sakuraThemeData,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-detail-destination')), findsOneWidget);
    expect(receivedExtra, desktopRankingsPath);
  });
}

Future<void> _pumpRankingsPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<RankingsApi>.value(value: bundle.rankingsApi),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: DesktopRankingsPage()),
        ),
      ),
    ),
  );
}

void _enqueueDefaultSourcesAndBoards(TestApiBundle bundle) {
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
    ],
  );
}

String? _queryValue(TestApiBundle bundle, int requestIndex, String key) {
  if (requestIndex >= bundle.adapter.requests.length) {
    return null;
  }
  return bundle.adapter.requests[requestIndex].uri.queryParameters[key];
}

Map<String, dynamic> _rankingItemsJson({
  int page = 1,
  int pageSize = 24,
  int total = 1,
  List<Map<String, dynamic>>? items,
}) {
  return <String, dynamic>{
    'items': items ?? <Map<String, dynamic>>[_rankingItem()],
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}

Map<String, dynamic> _rankingItem({
  int rank = 1,
  String movieNumber = 'ABC-001',
  bool isSubscribed = true,
}) {
  return <String, dynamic>{
    'rank': rank,
    'javdb_id': 'MovieA$rank',
    'movie_number': movieNumber,
    'title': 'Movie $rank',
    'cover_image': null,
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'is_subscribed': isSubscribed,
    'can_play': true,
  };
}
