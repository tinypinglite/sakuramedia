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
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
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

  testWidgets(
    'desktop rankings page shows loading skeletons before data resolves',
    (WidgetTester tester) async {
      final completer = Completer<void>();
      _enqueueDefaultSourcesAndBoards(bundle);
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/ranking-sources/javdb/boards/censored/items',
        responder: (options, body) async {
          await completer.future;
          return ResponseBody.fromString(
            jsonEncode(_rankingItemsJson(total: 1)),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpRankingsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pump();

      expect(
        find.byKey(const Key('ranked-movie-summary-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ranked-movie-summary-card-skeleton-0')),
        findsOneWidget,
      );

      completer.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('desktop rankings page renders total count and rank badges', (
    WidgetTester tester,
  ) async {
    _enqueueDefaultSourcesAndBoards(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(
        total: 2,
        items: <Map<String, dynamic>>[
          _rankingItem(
            rank: 1,
            movieNumber: 'ABC-001',
            isSubscribed: true,
            heat: 1777,
          ),
          _rankingItem(rank: 2, movieNumber: 'ABC-002', heat: 888),
        ],
      ),
    );

    await _pumpRankingsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('desktop-rankings-page-total')),
      findsOneWidget,
    );
    expect(find.text('2 部'), findsOneWidget);
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(
      find.byKey(const Key('movie-summary-card-rank-ABC-001')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('movie-summary-card-heat-text-ABC-001')),
          )
          .data,
      '1.8k',
    );
  });

  testWidgets(
    'desktop rankings filter panel supports immediate reload and keeps open',
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

      await _pumpRankingsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
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
    },
  );

  testWidgets('desktop rankings filter panel closes when tapping outside', (
    WidgetTester tester,
  ) async {
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

  testWidgets(
    'desktop rankings page uses board default_period and supported_periods',
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

      await _pumpRankingsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      expect(_queryValue(bundle, 2, 'period'), 'weekly');

      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('rankings-filter-period-daily')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('rankings-filter-period-weekly')),
        findsOneWidget,
      );
      expect(find.text('月榜'), findsNothing);
    },
  );

  testWidgets(
    'desktop rankings filter panel supports switching to missav source and period',
    (WidgetTester tester) async {
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
        body: _rankingItemsJson(total: 1),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/ranking-sources/missav/boards',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
            'source_key': 'missav',
            'board_key': 'all',
            'name': '综合',
            'supported_periods': <String>['daily', 'weekly', 'monthly'],
            'default_period': 'daily',
          },
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/ranking-sources/missav/boards/all/items',
        body: _rankingItemsJson(total: 1),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/ranking-sources/missav/boards/all/items',
        body: _rankingItemsJson(total: 1),
      );

      await _pumpRankingsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      expect(
        bundle.adapter.requests[2].uri.path,
        '/ranking-sources/javdb/boards/censored/items',
      );
      expect(_queryValue(bundle, 2, 'period'), 'daily');

      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('rankings-filter-source-missav')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);
      expect(
        bundle.adapter.requests[4].uri.path,
        '/ranking-sources/missav/boards/all/items',
      );
      expect(_queryValue(bundle, 4, 'period'), 'daily');

      await tester.tap(find.byKey(const Key('rankings-filter-period-weekly')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);
      expect(
        bundle.adapter.requests[5].uri.path,
        '/ranking-sources/missav/boards/all/items',
      );
      expect(_queryValue(bundle, 5, 'period'), 'weekly');
    },
  );

  testWidgets(
    'desktop rankings page sorts by heat locally without extra requests',
    (WidgetTester tester) async {
      _enqueueDefaultSourcesAndBoards(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/ranking-sources/javdb/boards/censored/items',
        body: _rankingItemsJson(
          total: 3,
          items: <Map<String, dynamic>>[
            _rankingItem(rank: 1, movieNumber: 'ABC-001', heat: 500),
            _rankingItem(rank: 2, movieNumber: 'ABC-002', heat: 900),
            _rankingItem(rank: 3, movieNumber: 'ABC-003', heat: 100),
          ],
        ),
      );

      await _pumpRankingsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      // 全量一次拉回：仅 sources + boards + items 三次请求。
      final requestsAfterLoad = bundle.adapter.requests.length;
      expect(requestsAfterLoad, 3);

      // 默认按名次：ABC-001(rank1) 在 ABC-003(rank3) 之前。
      expect(_readingPos(tester, 'ABC-001'), lessThan(_readingPos(tester, 'ABC-003')));

      // 点「热度」→ 降序：热度最高的 ABC-002 排在最前。
      await tester.tap(find.byKey(const Key('rankings-sort-heat')));
      await tester.pumpAndSettle();
      expect(_readingPos(tester, 'ABC-002'), lessThan(_readingPos(tester, 'ABC-001')));
      expect(_readingPos(tester, 'ABC-001'), lessThan(_readingPos(tester, 'ABC-003')));

      // 再点「热度」→ 升序：热度最低的 ABC-003 排在最前。
      await tester.tap(find.byKey(const Key('rankings-sort-heat')));
      await tester.pumpAndSettle();
      expect(_readingPos(tester, 'ABC-003'), lessThan(_readingPos(tester, 'ABC-001')));
      expect(_readingPos(tester, 'ABC-001'), lessThan(_readingPos(tester, 'ABC-002')));

      // 本地排序不触发任何额外请求。
      expect(bundle.adapter.requests.length, requestsAfterLoad);
    },
  );

  testWidgets(
    'desktop rankings page navigates to movie detail with fallback path',
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
            ChangeNotifierProvider(
              create: (_) => MovieSubscriptionChangeNotifier(),
            ),
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
      expect(receivedExtra, isNull);
    },
  );
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
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
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
}

/// 卡片在网格内的「阅读顺序」位置（先按行后按列），用于断言排序结果，
/// 不受网格列数影响。
double _readingPos(WidgetTester tester, String movieNumber) {
  final topLeft = tester.getTopLeft(
    find.byKey(Key('movie-summary-card-$movieNumber')),
  );
  return topLeft.dy * 100000 + topLeft.dx;
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
  int heat = 0,
}) {
  return <String, dynamic>{
    'rank': rank,
    'javdb_id': 'MovieA$rank',
    'movie_number': movieNumber,
    'title': 'Movie $rank',
    'cover_image': null,
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'heat': heat,
    'is_subscribed': isSubscribed,
    'can_play': true,
  };
}
