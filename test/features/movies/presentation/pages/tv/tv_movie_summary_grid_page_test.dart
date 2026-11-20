import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_movie_summary_grid_page.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_http_client_adapter.dart';
import '../../../../../support/logged_in_session_store.dart';
import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('TV 影片库排序切换字段与方向后按新 sort 重拉第一页', (tester) async {
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/movies',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[_movie('ABC-001')],
        'page': 1,
        'page_size': 36,
        'total': 1,
      },
    );

    await _pumpPage(
      tester,
      bundle,
      scope: const MovieSummaryScope.movies(
        cacheKey: 'tv-test:movies:list',
        pageSize: 36,
      ),
    );

    expect(find.byKey(const Key('tv-movie-grid')), findsOneWidget);
    expect(find.byKey(const Key('tv-sort-trigger')), findsOneWidget);
    expect(find.byKey(const Key('tv-sort-field-releaseDate')), findsNothing);
    expect(
      _movieRequests(bundle).single.uri.queryParameters['sort'],
      'release_date:desc',
    );

    await _openSortDialog(tester);
    expect(find.byKey(const Key('tv-sort-field-releaseDate')), findsOneWidget);
    expect(find.byKey(const Key('tv-sort-field-heat')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tv-sort-field-addedAt')));
    await _applySort(tester);
    expect(
      _movieRequests(bundle).last.uri.queryParameters['sort'],
      'added_at:desc',
    );
    expect(_movieRequests(bundle).last.uri.queryParameters['page'], '1');

    await _openSortDialog(tester);
    await tester.tap(find.byKey(const Key('tv-sort-direction-asc')));
    await _applySort(tester);
    expect(
      _movieRequests(bundle).last.uri.queryParameters['sort'],
      'added_at:asc',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV 播放列表排序写播放列表筛选并可回到默认顺序', (tester) async {
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/playlists/7/movies',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[_movie('ABC-001')],
        'page': 1,
        'page_size': 36,
        'total': 1,
      },
    );

    await _pumpPage(
      tester,
      bundle,
      scope: const MovieSummaryScope.playlist(playlistId: 7, pageSize: 36),
    );

    expect(find.byKey(const Key('tv-sort-trigger')), findsOneWidget);
    expect(
      _playlistRequests(bundle).single.uri.queryParameters.containsKey('sort'),
      isFalse,
    );

    await _openSortDialog(tester);
    expect(find.byKey(const Key('tv-sort-default')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tv-sort-field-releaseDate')));
    await _applySort(tester);
    expect(
      _playlistRequests(bundle).last.uri.queryParameters['sort'],
      'release_date:desc',
    );

    await _openSortDialog(tester);
    await tester.tap(find.byKey(const Key('tv-sort-direction-asc')));
    await _applySort(tester);
    expect(
      _playlistRequests(bundle).last.uri.queryParameters['sort'],
      'release_date:asc',
    );

    await _openSortDialog(tester);
    await tester.tap(find.byKey(const Key('tv-sort-default')));
    await _applySort(tester);
    expect(
      _playlistRequests(bundle).last.uri.queryParameters.containsKey('sort'),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV 影片库页头和排序入口随整页滚动离开视口', (tester) async {
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/movies',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          for (var index = 0; index < 30; index++)
            _movie('ABC-${index.toString().padLeft(3, '0')}'),
        ],
        'page': 1,
        'page_size': 36,
        'total': 30,
      },
    );

    await _pumpPage(
      tester,
      bundle,
      scope: const MovieSummaryScope.movies(
        cacheKey: 'tv-test:movies:scroll',
        pageSize: 36,
      ),
    );

    final trigger = find.byKey(const Key('tv-sort-trigger'));
    expect(trigger.hitTestable(), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    expect(trigger.hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openSortDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tv-sort-trigger')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('tv-sort-dialog')), findsOneWidget);
}

Future<void> _applySort(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tv-sort-apply')));
  await _pumpFrames(tester);
}

Future<void> _pumpPage(
  WidgetTester tester,
  TestApiBundle bundle, {
  required MovieSummaryScope scope,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      // 关闭 Riverpod 3 的全局自动重试，避免失败路径掩盖真实行为。
      retry: (_, _) => null,
      overrides: <Override>[
        ...bundle.riverpodOverrides(),
        statsFeaturesEnabledProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        builder: (context, child) =>
            OKToast(child: child ?? const SizedBox.shrink()),
        theme: buildSakuraTvThemeData(),
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        home: Scaffold(
          body: TvMovieSummaryGridPage(
            scope: scope,
            title: '影片',
            pageKey: const Key('tv-sort-test-page'),
          ),
        ),
      ),
    ),
  );
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

List<RecordedRequest> _movieRequests(TestApiBundle bundle) {
  return bundle.adapter.requests
      .where((request) => request.uri.path == '/movies')
      .toList(growable: false);
}

List<RecordedRequest> _playlistRequests(TestApiBundle bundle) {
  return bundle.adapter.requests
      .where((request) => request.uri.path == '/playlists/7/movies')
      .toList(growable: false);
}

Map<String, dynamic> _movie(String movieNumber) {
  return <String, dynamic>{
    'movie_number': movieNumber,
    'title': 'Movie $movieNumber',
    'cover_image': null,
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'heat': 1,
    'is_subscribed': false,
    'can_play': true,
  };
}
