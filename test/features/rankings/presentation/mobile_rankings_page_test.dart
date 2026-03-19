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
import 'package:sakuramedia/features/rankings/presentation/mobile_rankings_page.dart';
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
    'mobile rankings page shows loading skeletons before data resolves',
    (WidgetTester tester) async {
      final completer = Completer<void>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

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

  testWidgets('mobile rankings page renders total count and rank badges', (
    WidgetTester tester,
  ) async {
    _enqueueDefaultSourcesAndBoards(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(total: 2),
    );

    await _pumpRankingsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-rankings-page-total')), findsOneWidget);
    expect(find.text('2 部'), findsOneWidget);
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(
      find.byKey(const Key('movie-summary-card-rank-ABC-001')),
      findsOneWidget,
    );
  });

  testWidgets(
    'mobile rankings filter panel supports source board and period selection',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/ranking-sources',
        body: <Map<String, dynamic>>[
          <String, dynamic>{'source_key': 'javdb', 'name': 'JavDB'},
          <String, dynamic>{'source_key': 'dmm', 'name': 'DMM'},
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
        path: '/ranking-sources/dmm/boards',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
            'source_key': 'dmm',
            'board_key': 'hot',
            'name': '热门',
            'supported_periods': <String>['monthly'],
            'default_period': 'monthly',
          },
          <String, dynamic>{
            'source_key': 'dmm',
            'board_key': 'trending',
            'name': '趋势',
            'supported_periods': <String>['weekly', 'daily'],
            'default_period': 'weekly',
          },
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/ranking-sources/dmm/boards/hot/items',
        body: _rankingItemsJson(total: 1),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/ranking-sources/dmm/boards/trending/items',
        body: _rankingItemsJson(total: 1),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/ranking-sources/dmm/boards/trending/items',
        body: _rankingItemsJson(total: 1),
      );

      await _pumpRankingsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('rankings-filter-source-dmm')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);
      expect(
        bundle.adapter.requests.last.uri.path,
        '/ranking-sources/dmm/boards/hot/items',
      );
      expect(
        bundle.adapter.requests.last.uri.queryParameters['period'],
        'monthly',
      );

      await tester.ensureVisible(
        find.byKey(const Key('rankings-filter-board-trending')),
      );
      await tester.tap(find.byKey(const Key('rankings-filter-board-trending')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);
      expect(
        bundle.adapter.requests.last.uri.path,
        '/ranking-sources/dmm/boards/trending/items',
      );
      expect(
        bundle.adapter.requests.last.uri.queryParameters['period'],
        'weekly',
      );

      await tester.tap(find.byKey(const Key('rankings-filter-period-daily')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);
      expect(
        bundle.adapter.requests.last.uri.path,
        '/ranking-sources/dmm/boards/trending/items',
      );
      expect(
        bundle.adapter.requests.last.uri.queryParameters['period'],
        'daily',
      );
    },
  );

  testWidgets(
    'mobile rankings page retries failed load-more without clearing items',
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

      await _pumpRankingsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2800),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-summary-card-ABC-001')),
        findsOneWidget,
      );
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

      expect(
        find.byKey(const Key('movie-summary-card-ABC-025')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'mobile rankings page navigates to movie detail with fallback path',
    (WidgetTester tester) async {
      _enqueueDefaultSourcesAndBoards(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/ranking-sources/javdb/boards/censored/items',
        body: _rankingItemsJson(total: 1),
      );

      String? receivedExtra;
      final router = GoRouter(
        initialLocation: mobileRankingsPath,
        routes: [
          GoRoute(
            path: mobileRankingsPath,
            builder: (context, state) => const MobileRankingsPage(),
          ),
          GoRoute(
            path: '$mobileMoviesPath/:movieNumber',
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
      expect(receivedExtra, mobileRankingsPath);
    },
  );
}

Future<void> _pumpRankingsPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<RankingsApi>.value(value: bundle.rankingsApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: OKToast(child: const Scaffold(body: MobileRankingsPage())),
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

Map<String, dynamic> _rankingItemsJson({
  int page = 1,
  int pageSize = 24,
  int total = 2,
  List<Map<String, dynamic>>? items,
}) {
  return <String, dynamic>{
    'items':
        items ??
        <Map<String, dynamic>>[
          _rankingItem(rank: 1, movieNumber: 'ABC-001', isSubscribed: true),
          _rankingItem(rank: 2, movieNumber: 'ABC-002'),
        ],
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}

Map<String, dynamic> _rankingItem({
  required int rank,
  required String movieNumber,
  bool isSubscribed = false,
  bool canPlay = true,
}) {
  return <String, dynamic>{
    'rank': rank,
    'javdb_id': 'Movie$movieNumber',
    'movie_number': movieNumber,
    'title': 'Movie $movieNumber',
    'cover_image':
        rank == 1
            ? <String, dynamic>{
              'id': 100 + rank,
              'origin': '/covers/$movieNumber.jpg',
              'small': '/covers/$movieNumber-small.jpg',
              'medium': '/covers/$movieNumber-medium.jpg',
              'large': '/covers/$movieNumber-large.jpg',
            }
            : null,
    'release_date': '2024-01-0${(rank % 9) + 1}',
    'duration_minutes': 120 + rank,
    'is_subscribed': isSubscribed,
    'can_play': canPlay,
  };
}
