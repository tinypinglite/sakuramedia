import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/mobile_movies_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
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
    'mobile movies page shows loading skeletons before data resolves',
    (WidgetTester tester) async {
      final completer = Completer<void>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/movies',
        responder: (options, body) async {
          await completer.future;
          return ResponseBody.fromString(
            jsonEncode(_moviesJson(total: 2)),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
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

  testWidgets('mobile movies page renders total count and grid', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(
        total: 2,
        items: <Map<String, dynamic>>[
          _movieItem(heat: 1777),
          _movieItem(movieNumber: 'ABC-002', isSubscribed: false, heat: 4),
        ],
      ),
    );

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-movies-page-total')), findsOneWidget);
    expect(find.text('2 部'), findsOneWidget);
    expect(find.byType(MovieSummaryCard), findsNWidgets(2));
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(
      find.byKey(const Key('movie-summary-card-heat-ABC-001')),
      findsOneWidget,
    );
    expect(find.text('1.8k'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('mobile movies page shows empty state', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: 0, items: const <Map<String, dynamic>>[]),
    );

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('暂无影片数据'), findsOneWidget);
  });

  testWidgets('mobile movies page shows error state', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('影片列表加载失败，请稍后重试'), findsOneWidget);
  });

  testWidgets('mobile movies page adds collection feature from long press', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(
        total: 1,
        items: <Map<String, dynamic>>[
          _movieItem(movieNumber: 'OFJE-888', isSubscribed: false),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/OFJE-888/collection-status',
      body: <String, dynamic>{
        'movie_number': 'OFJE-888',
        'is_collection': false,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/collection-number-features',
      body: <String, dynamic>{
        'features': <String>['CJOB-'],
        'sync_stats': null,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/collection-number-features',
      body: <String, dynamic>{
        'features': <String>['CJOB-', 'OFJE-'],
        'sync_stats': <String, dynamic>{
          'total_movies': 50,
          'matched_count': 10,
          'updated_to_collection_count': 3,
          'updated_to_single_count': 0,
          'unchanged_count': 47,
        },
      },
    );

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final center = tester.getCenter(
      find.byKey(const Key('movie-summary-card-OFJE-888')),
    );
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('标记为合集'), findsOneWidget);
    expect(find.text('将"OFJE-"加入合集特征'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('movie-collection-feature-menu-add-item')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = bundle.adapter.requests.singleWhere(
      (request) =>
          request.method == 'PATCH' &&
          request.path == '/collection-number-features',
    );
    expect(patchRequest.body['features'], <String>['CJOB-', 'OFJE-']);
    expect(patchRequest.uri.queryParameters['apply_now'], 'true');
    expect(
      bundle.adapter.hitCount('GET', '/movies/OFJE-888/collection-status'),
      1,
    );
    expect(find.text('已将 OFJE- 加入合集特征，并重新统计合集影片'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('mobile movies page toggles collection type from long press', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(
        total: 1,
        items: <Map<String, dynamic>>[
          _movieItem(movieNumber: 'OFJE-888', isSubscribed: false),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/OFJE-888/collection-status',
      body: <String, dynamic>{
        'movie_number': 'OFJE-888',
        'is_collection': true,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/movies/collection-type',
      body: <String, dynamic>{'requested_count': 1, 'updated_count': 1},
    );

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final center = tester.getCenter(
      find.byKey(const Key('movie-summary-card-OFJE-888')),
    );
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('标记为单体'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('movie-collection-feature-menu-toggle-item')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = bundle.adapter.requests.singleWhere(
      (request) =>
          request.method == 'PATCH' &&
          request.path == '/movies/collection-type',
    );
    expect(patchRequest.body, <String, dynamic>{
      'movie_numbers': <String>['OFJE-888'],
      'collection_type': 'single',
    });
    expect(find.text('已将 OFJE-888 标记为单体'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('mobile movies page applies filter using overlay panel', (
    WidgetTester tester,
  ) async {
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

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('movies-filter-panel')), findsOneWidget);

    await tester.tap(find.text('可播放'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_queryValue(bundle, 1, 'status'), 'playable');
    expect(_queryValue(bundle, 1, 'collection_type'), 'single');
    expect(_queryValue(bundle, 1, 'sort'), 'release_date:desc');
  });

  testWidgets('mobile movies page applies quick filter presets', (
    WidgetTester tester,
  ) async {
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
          _movieItem(movieNumber: 'ABC-101', isSubscribed: true),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(
        total: 1,
        items: <Map<String, dynamic>>[
          _movieItem(movieNumber: 'ABC-102', canPlay: true),
        ],
      ),
    );

    await _pumpMoviesPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      physicalSize: const Size(360, 900),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movies-filter-preset-latest-subscribed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movies-filter-preset-latest-added')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const Key('movies-filter-preset-latest-subscribed')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_queryValue(bundle, 1, 'status'), 'subscribed');
    expect(_queryValue(bundle, 1, 'collection_type'), 'single');
    expect(_queryValue(bundle, 1, 'sort'), 'subscribed_at:desc');
    expect(
      tester
          .widget<AppButton>(
            find.byKey(const Key('movies-filter-preset-latest-subscribed')),
          )
          .isSelected,
      isTrue,
    );

    await tester.tap(
      find.byKey(const Key('movies-filter-preset-latest-added')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_queryValue(bundle, 2, 'status'), 'playable');
    expect(_queryValue(bundle, 2, 'collection_type'), 'single');
    expect(_queryValue(bundle, 2, 'sort'), 'added_at:desc');
    expect(
      tester
          .widget<AppButton>(
            find.byKey(const Key('movies-filter-preset-latest-added')),
          )
          .isSelected,
      isTrue,
    );
  });

  testWidgets(
    'mobile movies page aligns header filter buttons to same height',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: _moviesJson(total: 2),
      );

      await _pumpMoviesPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        physicalSize: const Size(360, 900),
      );
      await tester.pumpAndSettle();

      final triggerHeight = _buttonHeightForLabel(tester, '全部');
      final latestSubscribedHeight = _buttonHeightForLabel(tester, '最新订阅');
      final latestAddedHeight = _buttonHeightForLabel(tester, '最新入库');

      expect(latestSubscribedHeight, triggerHeight);
      expect(latestAddedHeight, triggerHeight);
    },
  );

  testWidgets(
    'mobile movies page loads next page on scroll and retries failed load more',
    (WidgetTester tester) async {
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

      await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
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
      expect(
        find.byKey(const Key('movie-summary-card-ABC-025')),
        findsOneWidget,
      );
    },
  );

  testWidgets('mobile movies page toggles movie subscription', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(
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

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('PUT', '/movies/ABC-001/subscription'), 1);
    expect(find.text('已订阅影片'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('mobile movies page card tap navigates to movie detail', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: 1, items: <Map<String, dynamic>>[_movieItem()]),
    );

    Object? movieDetailExtra;
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: mobileMoviesPath,
          builder: (_, __) => const MobileMoviesPage(),
        ),
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber',
          builder: (_, state) {
            movieDetailExtra = state.extra;
            return Text(
              'movie:${state.pathParameters['movieNumber']}',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ],
      initialLocation: mobileMoviesPath,
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<CollectionNumberFeaturesApi>.value(
            value: bundle.collectionNumberFeaturesApi,
          ),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
    await tester.pumpAndSettle();

    expect(find.text('movie:ABC-001'), findsOneWidget);
    expect(movieDetailExtra, isNull);
  });
}

Future<void> _pumpMoviesPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  Size physicalSize = const Size(430, 900),
}) {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<CollectionNumberFeaturesApi>.value(
          value: bundle.collectionNumberFeaturesApi,
        ),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: OKToast(child: const Scaffold(body: MobileMoviesPage())),
      ),
    ),
  );
}

String? _queryValue(TestApiBundle bundle, int requestIndex, String key) {
  final request = bundle.adapter.requests[requestIndex];
  return request.uri.queryParameters[key];
}

double _buttonHeightForLabel(WidgetTester tester, String label) {
  final containerFinder = find.ancestor(
    of: find.text(label).first,
    matching: find.byType(AnimatedContainer),
  );

  return tester.getSize(containerFinder.first).height;
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
  int heat = 0,
}) {
  return <String, dynamic>{
    'javdb_id': 'Movie$movieNumber',
    'movie_number': movieNumber,
    'title': 'Movie $movieNumber',
    'cover_image': null,
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'heat': heat,
    'is_subscribed': isSubscribed,
    'can_play': canPlay,
  };
}
