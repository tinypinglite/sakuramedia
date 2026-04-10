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
import 'package:sakuramedia/features/movies/presentation/desktop_movies_page.dart';
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
    'desktop movies page shows loading skeletons before data resolves',
    (WidgetTester tester) async {
      final completer = Completer<void>();
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

  testWidgets('desktop movies page renders list and total count', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(
        total: 2,
        items: <Map<String, dynamic>>[
          _movieItem(heat: 23),
          _movieItem(movieNumber: 'ABC-002', isSubscribed: false, heat: 7),
        ],
      ),
    );

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movies-page-total')), findsOneWidget);
    expect(find.text('2 部'), findsOneWidget);
    expect(find.byType(MovieSummaryCard), findsNWidgets(2));
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(
      find.byKey(const Key('movie-summary-card-heat-ABC-001')),
      findsOneWidget,
    );
    expect(find.text('23'), findsOneWidget);
  });

  testWidgets('desktop movies page sends default filters on first load', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: 2),
    );

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(_queryValue(bundle, 0, 'status'), 'all');
    expect(_queryValue(bundle, 0, 'collection_type'), 'single');
    expect(_queryValue(bundle, 0, 'sort'), 'release_date:desc');
  });

  testWidgets('desktop movies page shows empty state', (
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

  testWidgets('desktop movies page shows error state', (
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

  testWidgets('desktop movies page updates filters and reloads first page', (
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
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(
        total: 1,
        items: <Map<String, dynamic>>[
          _movieItem(movieNumber: 'ABC-010', canPlay: true),
        ],
      ),
    );

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movies-filter-trigger-label')),
      findsOneWidget,
    );
    expect(_triggerLabelText(tester), '全部');

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movies-filter-panel')), findsOneWidget);
    await tester.tap(find.text('可播放'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_triggerLabelText(tester), '可播放');
    expect(_queryValue(bundle, 1, 'status'), 'playable');
    expect(_queryValue(bundle, 1, 'collection_type'), 'single');
    expect(_queryValue(bundle, 1, 'sort'), 'release_date:desc');

    await tester.tap(find.text('最近入库'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_queryValue(bundle, 2, 'sort'), 'added_at:desc');
  });

  testWidgets('desktop movies page applies quick filter presets', (
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

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movies-filter-preset-latest-subscribed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movies-filter-preset-latest-added')),
      findsOneWidget,
    );

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

  testWidgets('desktop movies page filter panel closes when tapping outside', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: 2),
    );

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('movies-filter-panel')), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movies-filter-panel')), findsNothing);
  });

  testWidgets(
    'desktop movies page aligns header filter buttons to same height',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: _moviesJson(total: 2),
      );

      await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      final triggerHeight = _buttonHeightForLabel(tester, '全部');
      final latestSubscribedHeight = _buttonHeightForLabel(tester, '最新订阅');
      final latestAddedHeight = _buttonHeightForLabel(tester, '最新入库');

      expect(latestSubscribedHeight, triggerHeight);
      expect(latestAddedHeight, triggerHeight);
    },
  );

  testWidgets('desktop movies page uses smaller buttons inside filter panel', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: 2),
    );

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final triggerHeight = _buttonHeightForLabel(tester, '全部');

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();

    expect(_buttonHeightForLabel(tester, '可播放'), lessThan(triggerHeight));
  });

  testWidgets(
    'desktop movies page loads next page on scroll and retries failed load more',
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

  testWidgets('desktop movies page navigates to detail when tapping card', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: _moviesJson(total: 1, items: <Map<String, dynamic>>[_movieItem()]),
    );

    final router = await _pumpMoviesRouter(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/movies/ABC-001',
    );
    expect(find.text('detail: ABC-001'), findsOneWidget);
  });

  testWidgets(
    'desktop movies page toggles movie subscription without navigating',
    (WidgetTester tester) async {
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

      final router = await _pumpMoviesRouter(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('PUT', '/movies/ABC-001/subscription'), 1);
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.text('已订阅影片'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('desktop movies page adds collection feature from context menu', (
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
          'total_movies': 100,
          'matched_count': 12,
          'updated_to_collection_count': 5,
          'updated_to_single_count': 0,
          'unchanged_count': 95,
        },
      },
    );

    await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final center = tester.getCenter(
      find.byKey(const Key('movie-summary-card-OFJE-888')),
    );
    await tester.tapAt(center, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

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
    expect(find.text('已将 OFJE- 加入合集特征，并重新统计合集影片'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'desktop movies page shows media-blocked toast when unsubscribe fails',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: _moviesJson(
          total: 1,
          items: <Map<String, dynamic>>[_movieItem(movieNumber: 'ABC-001')],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/movies/ABC-001/subscription',
        statusCode: 409,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'movie_subscription_has_media',
            'message': '影片存在媒体文件，若需取消订阅请传 delete_media=true',
          },
        },
      );

      await _pumpMoviesPage(tester, sessionStore: sessionStore, bundle: bundle);
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
      expect(find.text('该影片存在媒体，默认不能取消订阅'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );
}

Future<void> _pumpMoviesPage(
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
        Provider<CollectionNumberFeaturesApi>.value(
          value: bundle.collectionNumberFeaturesApi,
        ),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: OKToast(child: const Scaffold(body: DesktopMoviesPage())),
      ),
    ),
  );
}

Future<GoRouter> _pumpMoviesRouter(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: DesktopMoviesPage()),
      ),
      GoRoute(
        path: '/desktop/library/movies/:movieNumber',
        name: 'desktop-movie-detail',
        builder:
            (context, state) => Scaffold(
              body: Text('detail: ${state.pathParameters['movieNumber']}'),
            ),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<CollectionNumberFeaturesApi>.value(
          value: bundle.collectionNumberFeaturesApi,
        ),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
      ],
      child: OKToast(
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    ),
  );

  return router;
}

String? _queryValue(TestApiBundle bundle, int requestIndex, String key) {
  final request = bundle.adapter.requests[requestIndex];
  return request.uri.queryParameters[key];
}

String _triggerLabelText(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const Key('movies-filter-trigger-label')))
      .data!;
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
