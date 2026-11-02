import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/rated_movies_page.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
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

  testWidgets('移动端评分页展示列表，排序抽屉可切维度', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final pageBody = <String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'movie_number': 'ABC-001',
          'title': 'Rated Movie',
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'heat': 1,
          'is_subscribed': false,
          'can_play': true,
          'my_score': 4.0,
          'my_rating_values': <String, dynamic>{'1': 4},
        },
      ],
      'page': 1,
      'page_size': 24,
      'total': 1,
    };
    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': '颜值',
          'min_value': 1,
          'max_value': 5,
          'weight': 1.0,
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: OKToast(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
            theme: sakuraThemeData,
            home: const Scaffold(body: MobileRatedMoviesPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-rated-movies-page')), findsOneWidget);
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(find.text('总分 4.0'), findsOneWidget);
    expect(find.byKey(const Key('rated-movies-sort-trigger')), findsOneWidget);
    expect(
      bundle.adapter.requests
          .lastWhere((request) => request.uri.path == '/movies')
          .uri
          .queryParameters['sort'],
      'my_score:desc',
    );
    final initialRequest = bundle.adapter.requests.lastWhere(
      (request) => request.uri.path == '/movies',
    );
    expect(initialRequest.uri.queryParameters['status'], 'all');
    expect(initialRequest.uri.queryParameters['collection_type'], 'all');

    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    await tester.tap(find.byKey(const Key('rated-movies-sort-trigger')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-rated-movies-sort-drawer')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('rated-movies-sort-dimension-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      bundle.adapter.requests
          .lastWhere((request) => request.uri.path == '/movies')
          .uri
          .queryParameters['sort'],
      'dimension_1:desc',
    );
  });

  testWidgets('移动端筛选抽屉切换状态和合集类型', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final pageBody = <String, dynamic>{
      'items': const <Map<String, dynamic>>[],
      'page': 1,
      'page_size': 24,
      'total': 0,
    };
    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: OKToast(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
            theme: sakuraThemeData,
            home: const Scaffold(body: MobileRatedMoviesPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rated-movies-filter-trigger')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-rated-movies-filter-drawer')),
      findsOneWidget,
    );

    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    await tester.tap(
      find.byKey(const Key('rated-movies-filter-status-unsubscribed')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      bundle.adapter.requests
          .lastWhere((request) => request.uri.path == '/movies')
          .uri
          .queryParameters['status'],
      'unsubscribed',
    );

    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    await tester.tap(
      find.byKey(const Key('rated-movies-filter-collection-single')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final request = bundle.adapter.requests.lastWhere(
      (request) => request.uri.path == '/movies',
    );
    expect(request.uri.queryParameters['status'], 'unsubscribed');
    expect(request.uri.queryParameters['collection_type'], 'single');
  });
}
