import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/mobile_actor_detail_page.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
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

  testWidgets('mobile actor detail page shows loading skeleton before load', (
    WidgetTester tester,
  ) async {
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
      find.byKey(const Key('mobile-actor-detail-loading-skeleton')),
      findsOneWidget,
    );

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('mobile actor detail page shows 404 error state', (
    WidgetTester tester,
  ) async {
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
  });

  testWidgets(
    'mobile actor detail page can retry actor load after server error',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors/1',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: _moviesJson(total: 0, items: const <Map<String, dynamic>>[]),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors/1',
        body: _actorDetailJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('女优详情暂时无法加载，请稍后重试'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '重试'));
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/actors/1'), 2);
      expect(find.byKey(const Key('mobile-actor-detail-page')), findsOneWidget);
      expect(find.text('三上悠亚 / 鬼头桃菜'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile actor detail page renders header and default movie query',
    (WidgetTester tester) async {
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

      expect(
        find.byKey(const Key('mobile-actor-detail-header')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mobile-actor-detail-name')), findsOneWidget);
      expect(find.text('三上悠亚 / 鬼头桃菜'), findsOneWidget);
      expect(
        find.byKey(const Key('mobile-actor-detail-total')),
        findsOneWidget,
      );
      final nameText = tester.widget<Text>(
        find.byKey(const Key('mobile-actor-detail-name')),
      );
      expect(nameText.style?.fontSize, sakuraMobileThemeData.appTextScale.s14);
      expect(find.text('2 部'), findsOneWidget);
      expect(
        find.byKey(const Key('mobile-actor-detail-subscription-1')),
        findsOneWidget,
      );
      expect(find.byType(MovieSummaryCard), findsNWidgets(2));

      expect(_queryValue(bundle, 1, 'actor_id'), '1');
      expect(_queryValue(bundle, 1, 'status'), 'all');
      expect(_queryValue(bundle, 1, 'collection_type'), 'single');
      expect(_queryValue(bundle, 1, 'sort'), 'release_date:desc');
    },
  );

  testWidgets('mobile actor detail page updates movie filters', (
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

    expect(
      tester
          .widget<AppTextButton>(
            find.ancestor(
              of: find.byKey(const Key('movies-filter-trigger-label')),
              matching: find.byType(AppTextButton),
            ),
          )
          .isSelected,
      isTrue,
    );

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
    expect(
      tester
          .widget<AppTextButton>(
            find.ancestor(
              of: find.byKey(const Key('movies-filter-trigger-label')),
              matching: find.byType(AppTextButton),
            ),
          )
          .isSelected,
      isTrue,
    );
    expect(
      _buttonBackgroundColor(
        tester,
        find.byKey(const Key('movies-filter-trigger-label')),
      ),
      sakuraMobileThemeData.colorScheme.primary.withValues(alpha: 0.08),
    );
  });

  testWidgets('mobile actor detail page applies quick filter presets', (
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

    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      physicalSize: const Size(360, 900),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<AppTextButton>(
            find.ancestor(
              of: find.byKey(const Key('movies-filter-trigger-label')),
              matching: find.byType(AppTextButton),
            ),
          )
          .isSelected,
      isTrue,
    );
    expect(
      _buttonBackgroundColor(
        tester,
        find.byKey(const Key('movies-filter-trigger-label')),
      ),
      sakuraMobileThemeData.colorScheme.primary.withValues(alpha: 0.08),
    );

    await tester.tap(
      find.byKey(const Key('movies-filter-preset-latest-subscribed')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_queryValue(bundle, 2, 'actor_id'), '1');
    expect(_queryValue(bundle, 2, 'status'), 'subscribed');
    expect(_queryValue(bundle, 2, 'collection_type'), 'single');
    expect(_queryValue(bundle, 2, 'sort'), 'subscribed_at:desc');
    expect(
      tester
          .widget<AppTextButton>(
            find.byKey(const Key('movies-filter-preset-latest-subscribed')),
          )
          .isSelected,
      isTrue,
    );
    expect(
      tester
          .widget<AppTextButton>(
            find.ancestor(
              of: find.byKey(const Key('movies-filter-trigger-label')),
              matching: find.byType(AppTextButton),
            ),
          )
          .isSelected,
      isFalse,
    );
    expect(
      _buttonBackgroundColor(
        tester,
        find.byKey(const Key('movies-filter-preset-latest-subscribed')),
      ),
      sakuraMobileThemeData.colorScheme.primary.withValues(alpha: 0.08),
    );

    await tester.tap(
      find.byKey(const Key('movies-filter-preset-latest-added')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_queryValue(bundle, 3, 'actor_id'), '1');
    expect(_queryValue(bundle, 3, 'status'), 'playable');
    expect(_queryValue(bundle, 3, 'collection_type'), 'single');
    expect(_queryValue(bundle, 3, 'sort'), 'added_at:desc');
    expect(
      tester
          .widget<AppTextButton>(
            find.byKey(const Key('movies-filter-preset-latest-added')),
          )
          .isSelected,
      isTrue,
    );
    expect(
      tester
          .widget<AppTextButton>(
            find.ancestor(
              of: find.byKey(const Key('movies-filter-trigger-label')),
              matching: find.byType(AppTextButton),
            ),
          )
          .isSelected,
      isFalse,
    );
    expect(
      _buttonBackgroundColor(
        tester,
        find.byKey(const Key('movies-filter-preset-latest-added')),
      ),
      sakuraMobileThemeData.colorScheme.primary.withValues(alpha: 0.08),
    );
  });

  testWidgets(
    'mobile actor detail page shows actor and movie subscription feedback',
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
        path: '/actors/1/subscription',
        statusCode: 204,
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/movies/ABC-001/subscription',
        statusCode: 204,
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('mobile-actor-detail-subscription-1')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('DELETE', '/actors/1/subscription'), 1);
      expect(find.text('已取消订阅女优'), findsOneWidget);

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

  testWidgets(
    'mobile actor detail page loads next page and retries load more failure',
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

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2800));
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

  testWidgets('mobile actor detail movie tap pushes movie detail route', (
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
      body: _moviesJson(
        total: 1,
        items: <Map<String, dynamic>>[
          _movieItem(movieNumber: 'ABC-001', isSubscribed: false),
        ],
      ),
    );

    final router = GoRouter(
      initialLocation: buildMobileActorDetailRoutePath(1),
      routes: [
        GoRoute(
          path: '$mobileActorsPath/:actorId',
          builder: (_, state) {
            return MobileActorDetailPage(
              actorId: int.parse(state.pathParameters['actorId']!),
            );
          },
        ),
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber',
          builder:
              (_, state) => Text(
                'movie:${state.pathParameters['movieNumber']}',
                textDirection: TextDirection.ltr,
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouterPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      router: router,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
    await tester.pumpAndSettle();

    expect(find.text('movie:ABC-001'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  Size physicalSize = const Size(430, 900),
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ActorsApi>.value(value: bundle.actorsApi),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        ChangeNotifierProvider(
          create: (_) => MovieCollectionTypeChangeNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
      ],
      child: MaterialApp(
        theme: sakuraMobileThemeData,
        home: OKToast(
          child: const Scaffold(body: MobileActorDetailPage(actorId: 1)),
        ),
      ),
    ),
  );
}

Future<void> _pumpRouterPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ActorsApi>.value(value: bundle.actorsApi),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        ChangeNotifierProvider(
          create: (_) => MovieCollectionTypeChangeNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
      ],
      child: OKToast(
        child: MaterialApp.router(
          theme: sakuraMobileThemeData,
          routerConfig: router,
        ),
      ),
    ),
  );
}

String? _queryValue(TestApiBundle bundle, int requestIndex, String key) {
  final request = bundle.adapter.requests[requestIndex];
  return request.uri.queryParameters[key];
}

Color? _buttonBackgroundColor(WidgetTester tester, Finder finder) {
  final buttonFinder = find.ancestor(
    of: finder,
    matching: find.byType(AppTextButton),
  );
  final resolvedFinder =
      buttonFinder.evaluate().isNotEmpty ? buttonFinder : finder;
  final button = tester.widget<AppTextButton>(resolvedFinder);
  final context = tester.element(resolvedFinder);
  if (button.onPressed == null) {
    return context.appColors.borderSubtle.withValues(alpha: 0.32);
  }
  if (button.isSelected) {
    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
  }
  return switch (button.backgroundStyle) {
    AppTextButtonBackgroundStyle.transparent => Colors.transparent,
    AppTextButtonBackgroundStyle.muted => context.appColors.surfaceMuted,
  };
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
