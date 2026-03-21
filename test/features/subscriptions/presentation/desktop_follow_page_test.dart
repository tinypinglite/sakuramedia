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
import 'package:sakuramedia/features/subscriptions/presentation/desktop_follow_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_card.dart';

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
    'desktop follow page shows loading skeletons before data resolves',
    (WidgetTester tester) async {
      final completer = Completer<void>();
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/movies/subscribed-actors/latest',
        responder: (options, body) async {
          await completer.future;
          return ResponseBody.fromString(
            jsonEncode(_followMoviesJson(total: 2)),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpFollowPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pump();

      expect(find.byKey(const Key('movie-summary-grid')), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-skeleton-0')),
        findsOneWidget,
      );

      completer.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('desktop follow page renders list and total count', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/subscribed-actors/latest',
      body: _followMoviesJson(total: 2),
    );

    await _pumpFollowPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('女优上新'), findsOneWidget);
    expect(find.byKey(const Key('desktop-follow-page-total')), findsOneWidget);
    expect(find.text('2 部'), findsOneWidget);
    expect(find.byType(MovieSummaryCard), findsNWidgets(2));
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
  });

  testWidgets('desktop follow page shows empty state', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/subscribed-actors/latest',
      body: _followMoviesJson(total: 0, items: const <Map<String, dynamic>>[]),
    );

    await _pumpFollowPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('暂无关注影片'), findsOneWidget);
  });

  testWidgets('desktop follow page shows error state', (
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

    await _pumpFollowPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('关注影片加载失败，请稍后重试'), findsOneWidget);
  });

  testWidgets(
    'desktop follow page loads next page on scroll and retries failed load more',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/subscribed-actors/latest',
        body: _followMoviesJson(
          total: 30,
          items: List<Map<String, dynamic>>.generate(
            24,
            (index) => _movieItem(
              movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
            ),
          ),
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/subscribed-actors/latest',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
        },
      );

      await _pumpFollowPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2800),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(MovieSummaryCard), findsNWidgets(24));
      expect(find.text('加载更多失败，请点击重试'), findsOneWidget);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/subscribed-actors/latest',
        body: _followMoviesJson(
          page: 2,
          total: 30,
          items: List<Map<String, dynamic>>.generate(
            6,
            (index) => _movieItem(
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
        bundle.adapter.hitCount('GET', '/movies/subscribed-actors/latest'),
        3,
      );
      expect(find.byType(MovieSummaryCard), findsNWidgets(30));
      expect(
        find.byKey(const Key('movie-summary-card-ABC-025')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'desktop follow page navigates to detail with follow fallback path',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/subscribed-actors/latest',
        body: _followMoviesJson(
          total: 1,
          items: <Map<String, dynamic>>[_movieItem()],
        ),
      );

      String? receivedExtra;
      final router = GoRouter(
        initialLocation: desktopFollowPath,
        routes: <RouteBase>[
          GoRoute(
            path: desktopFollowPath,
            builder:
                (context, state) => const Scaffold(body: DesktopFollowPage()),
          ),
          GoRoute(
            path: '/desktop/library/movies/:movieNumber',
            builder: (context, state) {
              receivedExtra = state.extra as String?;
              return Scaffold(
                body: Text('detail: ${state.pathParameters['movieNumber']}'),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await _pumpFollowRouter(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
      await tester.pumpAndSettle();

      expect(find.text('detail: ABC-001'), findsOneWidget);
      expect(receivedExtra, desktopFollowPath);
    },
  );

  testWidgets(
    'desktop follow page toggles movie subscription and shows toast',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/subscribed-actors/latest',
        body: _followMoviesJson(
          total: 1,
          items: <Map<String, dynamic>>[
            _movieItem(movieNumber: 'ABC-001', isSubscribed: false),
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/movies/ABC-001/subscription',
        statusCode: 204,
      );

      final router = GoRouter(
        initialLocation: desktopFollowPath,
        routes: <RouteBase>[
          GoRoute(
            path: desktopFollowPath,
            builder:
                (context, state) => const Scaffold(body: DesktopFollowPage()),
          ),
        ],
      );
      addTearDown(router.dispose);

      await _pumpFollowRouter(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('PUT', '/movies/ABC-001/subscription'), 1);
      expect(router.routeInformationProvider.value.uri.path, desktopFollowPath);
      expect(find.text('已订阅影片'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );
}

Future<void> _pumpFollowPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: const OKToast(child: Scaffold(body: DesktopFollowPage())),
      ),
    ),
  );
}

Future<void> _pumpFollowRouter(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  required GoRouter router,
}) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
      ],
      child: OKToast(
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    ),
  );
}

Map<String, dynamic> _followMoviesJson({
  int page = 1,
  int total = 2,
  List<Map<String, dynamic>>? items,
}) {
  return <String, dynamic>{
    'items':
        items ??
        <Map<String, dynamic>>[
          _movieItem(),
          _movieItem(movieNumber: 'ABC-002', isSubscribed: false),
        ],
    'page': page,
    'page_size': 24,
    'total': total,
  };
}

Map<String, dynamic> _movieItem({
  String movieNumber = 'ABC-001',
  bool isSubscribed = true,
  bool canPlay = true,
}) {
  return <String, dynamic>{
    'javdb_id': 'Movie$movieNumber',
    'movie_number': movieNumber,
    'title': 'Movie $movieNumber',
    'cover_image': null,
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'is_subscribed': isSubscribed,
    'can_play': canPlay,
  };
}
