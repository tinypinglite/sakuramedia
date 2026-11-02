import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/rated_movies_page.dart';
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

  testWidgets('已评分影片使用标准网格，卡片显示总分，可切换维度排序', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
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
            home: const Scaffold(body: DesktopRatedMoviesPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.lastWhere(
      (request) => request.uri.path == '/movies',
    );
    expect(request.uri.queryParameters['rated'], 'true');
    expect(request.uri.queryParameters['status'], 'all');
    expect(request.uri.queryParameters['collection_type'], 'all');
    expect(request.uri.queryParameters['sort'], 'my_score:desc');

    expect(find.text('已评分 1 部'), findsOneWidget);
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(
      find.byKey(const Key('movie-summary-card-number-ABC-001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-summary-card-trailing-ABC-001')),
      findsOneWidget,
    );
    expect(find.text('总分 4.0'), findsOneWidget);
    expect(
      find.byKey(const Key('rated-movies-dimension-manage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('rated-movies-filter-trigger')),
      findsOneWidget,
    );

    // 排序收进标准筛选入口：默认摘要「总分 ↓」。
    expect(find.text('总分 ↓'), findsOneWidget);

    // 切换到单维度排序后重新请求，并带上 dimension_<id> sort。
    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    await tester.tap(find.byKey(const Key('rated-movies-sort-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rated-movies-sort-dimension-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final dimensionRequest = bundle.adapter.requests.lastWhere(
      (request) => request.uri.path == '/movies',
    );
    expect(dimensionRequest.uri.queryParameters['rated'], 'true');
    expect(dimensionRequest.uri.queryParameters['sort'], 'dimension_1:desc');

    // 选中字段后浮层关闭；重新打开再切升降序。
    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    await tester.tap(find.byKey(const Key('rated-movies-sort-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rated-movies-sort-asc')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final ascRequest = bundle.adapter.requests.lastWhere(
      (request) => request.uri.path == '/movies',
    );
    expect(ascRequest.uri.queryParameters['sort'], 'dimension_1:asc');
  });

  testWidgets('首屏加载失败时切升降序仍按总分排序', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'boom'},
    );
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
            home: const Scaffold(body: DesktopRatedMoviesPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('我的评分加载失败，请稍后重试'), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 24,
        'total': 0,
      },
    );
    await tester.tap(find.byKey(const Key('rated-movies-sort-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rated-movies-sort-asc')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final request = bundle.adapter.requests.lastWhere(
      (request) => request.uri.path == '/movies',
    );
    expect(request.uri.queryParameters['sort'], 'my_score:asc');
  });

  testWidgets('删除当前排序维度后自动回到总分排序', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
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
            home: const Scaffold(body: DesktopRatedMoviesPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 先切到维度排序。
    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    await tester.tap(find.byKey(const Key('rated-movies-sort-trigger')));
    await tester.pumpAndSettle();
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

    // 选中字段后排序面板已关闭，直接打开维度管理。
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
          'has_scores': false,
        },
      ],
    );
    await tester.tap(find.byKey(const Key('rated-movies-dimension-manage')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rating-dimension-1')), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/movie-rating-dimensions/1',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: const <Map<String, dynamic>>[],
    );
    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('rating-dimension-1')),
        matching: find.byIcon(Icons.delete_outline_rounded),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    final sortRequests = bundle.adapter.requests
        .where((request) => request.uri.path == '/movies')
        .map((request) => request.uri.queryParameters['sort'])
        .toList();
    expect(sortRequests.last, 'my_score:desc');
    expect(sortRequests.where((sort) => sort == 'dimension_1:desc').length, 1);
  });

  testWidgets('打开维度管理时刷新已有评分状态', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 24,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': '颜值',
          'min_value': 1,
          'max_value': 10,
          'weight': 1.0,
          'has_scores': false,
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
            home: const Scaffold(body: DesktopRatedMoviesPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': '颜值',
          'min_value': 1,
          'max_value': 10,
          'weight': 1.0,
          'has_scores': true,
        },
      ],
    );
    await tester.tap(find.byKey(const Key('rated-movies-dimension-manage')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('rating-dimension-1')),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已有评分，分数范围不可修改'), findsOneWidget);
  });

  testWidgets('筛选订阅状态、合集类型与番号来源，并重置为全部', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
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
            home: const Scaffold(body: DesktopRatedMoviesPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rated-movies-filter-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rated-movies-filter-panel')), findsOneWidget);

    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    await tester.tap(
      find.byKey(const Key('rated-movies-filter-status-subscribed')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      bundle.adapter.requests
          .lastWhere((request) => request.uri.path == '/movies')
          .uri
          .queryParameters['status'],
      'subscribed',
    );

    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    await tester.tap(
      find.byKey(const Key('rated-movies-filter-collection-single')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    var request = bundle.adapter.requests.lastWhere(
      (request) => request.uri.path == '/movies',
    );
    expect(request.uri.queryParameters['status'], 'subscribed');
    expect(request.uri.queryParameters['collection_type'], 'single');
    expect(request.uri.queryParameters['number_source'], 'all');
    expect(request.uri.queryParameters['sort'], 'my_score:desc');

    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    await tester.tap(
      find.byKey(const Key('rated-movies-filter-number-source-fc2')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    request = bundle.adapter.requests.lastWhere(
      (request) => request.uri.path == '/movies',
    );
    expect(request.uri.queryParameters['status'], 'subscribed');
    expect(request.uri.queryParameters['collection_type'], 'single');
    expect(request.uri.queryParameters['number_source'], 'fc2');
    expect(
      find.descendant(
        of: find.byKey(const Key('rated-movies-filter-trigger')),
        matching: find.text('已订阅 · 单体 · FC2'),
      ),
      findsOneWidget,
    );

    bundle.adapter.enqueueJson(method: 'GET', path: '/movies', body: pageBody);
    await tester.tap(find.text('重置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    request = bundle.adapter.requests.lastWhere(
      (request) => request.uri.path == '/movies',
    );
    expect(request.uri.queryParameters['status'], 'all');
    expect(request.uri.queryParameters['collection_type'], 'all');
    expect(request.uri.queryParameters['number_source'], 'all');
    expect(request.uri.queryParameters['sort'], 'my_score:desc');
    expect(
      find.descendant(
        of: find.byKey(const Key('rated-movies-filter-trigger')),
        matching: find.text('全部'),
      ),
      findsOneWidget,
    );
  });
}
