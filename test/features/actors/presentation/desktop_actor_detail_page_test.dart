import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/desktop_actor_detail_page.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
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
    'actor detail page shows loading skeleton before actor request completes',
    (WidgetTester tester) async {
      final completer = Completer<void>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/actors/1',
        responder: (options, requestBody) async {
          await completer.future;
          return ResponseBody.fromString(
            jsonEncode(_actorDetailJson()),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: _moviesJson(total: 0, items: const <Map<String, dynamic>>[]),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pump();

      expect(
        find.byKey(const Key('actor-detail-loading-skeleton')),
        findsOneWidget,
      );

      completer.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('actor detail page renders header, filter, and movie grid', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1',
      body: _actorDetailJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: 2),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('actor-detail-header')), findsOneWidget);
    expect(find.byKey(const Key('actor-detail-name')), findsOneWidget);
    expect(find.text('三上悠亚 / 鬼头桃菜'), findsOneWidget);
    final nameText = tester.widget<Text>(
      find.byKey(const Key('actor-detail-name')),
    );
    expect(nameText.style?.fontSize, 16);
    expect(find.byKey(const Key('actor-detail-total')), findsOneWidget);
    expect(find.text('2 部'), findsOneWidget);
    expect(
      find.byKey(const Key('actor-detail-subscription-1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('actor-detail-subscription-1')),
        matching: find.byIcon(Icons.favorite_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movies-filter-trigger-label')),
      findsOneWidget,
    );
    expect(find.byType(MovieSummaryCard), findsNWidgets(2));

    expect(_queryValue(bundle, 1, 'actor_id'), '1');
    expect(_queryValue(bundle, 1, 'status'), 'all');
    expect(_queryValue(bundle, 1, 'collection_type'), 'single');
    expect(_queryValue(bundle, 1, 'sort'), 'release_date:desc');
  });

  testWidgets('actor detail page updates filters and keeps actor_id', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1',
      body: _actorDetailJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: 2),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(
        total: 1,
        items: <Map<String, dynamic>>[
          _movieItem(movieNumber: 'ABC-009', isSubscribed: false),
        ],
      ),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('可播放'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('1 部'), findsOneWidget);
    expect(_queryValue(bundle, 2, 'actor_id'), '1');
    expect(_queryValue(bundle, 2, 'status'), 'playable');
    expect(_queryValue(bundle, 2, 'collection_type'), 'single');
    expect(_queryValue(bundle, 2, 'sort'), 'release_date:desc');
  });

  testWidgets('actor detail page shows empty movie state', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1',
      body: _actorDetailJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: 0, items: const <Map<String, dynamic>>[]),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('暂无影片数据'), findsOneWidget);
    expect(find.text('三上悠亚 / 鬼头桃菜'), findsOneWidget);
  });

  testWidgets(
    'actor detail page shows page-level error when actor load fails',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors/1',
        statusCode: 404,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'actor_not_found',
            'message': '演员不存在',
          },
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: _moviesJson(total: 0, items: const <Map<String, dynamic>>[]),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('未找到该女优'), findsOneWidget);
    },
  );

  testWidgets('actor detail page keeps header when movie load fails', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1',
      body: _actorDetailJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('三上悠亚 / 鬼头桃菜'), findsOneWidget);
    expect(find.text('0 部'), findsOneWidget);
    expect(find.text('影片列表加载失败，请稍后重试'), findsOneWidget);
  });

  testWidgets(
    'actor detail page loads next page on scroll and retries failed load more',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors/1',
        body: _actorDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: _moviesJson(
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
        path: '/movies',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
        },
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2800),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(MovieSummaryCard), findsNWidgets(24));
      expect(find.text('加载更多失败，请点击重试'), findsOneWidget);
      expect(_queryValue(bundle, 2, 'actor_id'), '1');

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: _moviesJson(
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

      expect(bundle.adapter.hitCount('GET', '/movies'), 3);
      expect(find.byType(MovieSummaryCard), findsNWidgets(30));
      expect(_queryValue(bundle, 3, 'actor_id'), '1');
      expect(
        find.byKey(const Key('movie-summary-card-ABC-025')),
        findsOneWidget,
      );
    },
  );

  testWidgets('actor detail page toggles actor subscription from header', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1',
      body: _actorDetailJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: 0, items: const <Map<String, dynamic>>[]),
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/actors/1/subscription',
      statusCode: 204,
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('actor-detail-subscription-1')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('DELETE', '/actors/1/subscription'), 1);
    expect(find.text('已取消订阅女优'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'actor detail page toggles movie subscription from related list',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors/1',
        body: _actorDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: _moviesJson(
          total: 1,
          items: <Map<String, dynamic>>[
            _movieItem(movieNumber: 'ABC-001', isSubscribed: true),
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/movies/ABC-001/subscription',
        statusCode: 204,
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        bundle.adapter.hitCount('DELETE', '/movies/ABC-001/subscription'),
        1,
      );
      expect(find.text('已取消订阅影片'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ActorsApi>.value(value: bundle.actorsApi),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: OKToast(
          child: const Scaffold(body: DesktopActorDetailPage(actorId: 1)),
        ),
      ),
    ),
  );
}

String? _queryValue(TestApiBundle bundle, int requestIndex, String key) {
  final request = bundle.adapter.requests[requestIndex];
  return request.uri.queryParameters[key];
}

Map<String, dynamic> _actorDetailJson() {
  return <String, dynamic>{
    'id': 1,
    'javdb_id': 'ActorA1',
    'name': '三上悠亚',
    'alias_name': '三上悠亚 / 鬼头桃菜',
    'profile_image': <String, dynamic>{
      'id': 10,
      'origin': '/files/images/actors/Actor1.jpg',
      'small': '/files/images/actors/Actor1-small.jpg',
      'medium': '/files/images/actors/Actor1-medium.jpg',
      'large': '/files/images/actors/Actor1-large.jpg',
    },
    'is_subscribed': true,
  };
}

Map<String, dynamic> _moviesJson({
  int page = 1,
  int total = 2,
  List<Map<String, dynamic>>? items,
}) {
  return <String, dynamic>{
    'items':
        items ??
        <Map<String, dynamic>>[
          _movieItem(movieNumber: 'ABC-001'),
          _movieItem(movieNumber: 'ABC-002'),
        ],
    'page': page,
    'page_size': 24,
    'total': total,
  };
}

Map<String, dynamic> _movieItem({
  required String movieNumber,
  bool isSubscribed = true,
  bool canPlay = true,
}) {
  return <String, dynamic>{
    'javdb_id': 'Movie-$movieNumber',
    'movie_number': movieNumber,
    'title': 'Movie $movieNumber',
    'cover_image': null,
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'is_subscribed': isSubscribed,
    'can_play': canPlay,
  };
}
