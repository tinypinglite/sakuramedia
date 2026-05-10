import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';
import 'package:sakuramedia/features/discovery/presentation/desktop_discover_page.dart';
import 'package:sakuramedia/features/discovery/presentation/discovery_recommendation_list_pages.dart';
import 'package:sakuramedia/features/discovery/presentation/mobile_overview_discover_tab.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/theme.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  testWidgets('mobile discover tab uses simple movie and moment grids', (
    tester,
  ) async {
    final sessionStore = await _buildSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDiscoveryResponses(bundle);

    await _pumpDiscoveryWidget(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      child: const MobileOverviewDiscoverTab(),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-overview-discover-tab')), findsWidgets);
    expect(find.text('今日发现'), findsNothing);
    expect(find.byKey(const Key('mobile-discover-summary-card')), findsNothing);
    expect(find.byKey(const Key('movie-summary-grid')), findsOneWidget);
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(find.byKey(const Key('moment-grid')), findsOneWidget);
    expect(find.byKey(const Key('moment-card-1')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-discover-load-more-daily')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-discover-load-more-moments')),
      findsOneWidget,
    );
    expect(find.text('近期热度较高'), findsNothing);
    expect(find.text('与你收藏的时刻画面相似'), findsNothing);
  });

  testWidgets('desktop discover page uses simple movie and moment grids', (
    tester,
  ) async {
    final sessionStore = await _buildSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDiscoveryResponses(bundle);

    await _pumpDiscoveryWidget(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      child: const DesktopDiscoverPage(),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-discover-page')), findsOneWidget);
    expect(find.text('DISCOVERY'), findsNothing);
    expect(find.text('读取后端最新推荐快照，集中展示今日推荐影片和推荐时刻。'), findsNothing);
    expect(
      find.byKey(const Key('desktop-discover-summary-card')),
      findsNothing,
    );
    expect(find.byKey(const Key('movie-summary-grid')), findsOneWidget);
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(find.byKey(const Key('moment-grid')), findsOneWidget);
    expect(find.byKey(const Key('moment-card-1')), findsOneWidget);
    expect(
      find.byKey(const Key('desktop-discover-load-more-daily')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('desktop-discover-load-more-moments')),
      findsOneWidget,
    );
    expect(find.text('近期热度较高'), findsNothing);
    expect(find.text('与你收藏的时刻画面相似'), findsNothing);
  });

  testWidgets('desktop discover movies page loads more on scroll', (
    tester,
  ) async {
    final sessionStore = await _buildSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueDailyPage(bundle, page: 1, start: 1, count: 24, total: 25);
    _enqueueDailyPage(bundle, page: 2, start: 25, count: 1, total: 25);

    await _pumpDiscoveryWidget(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      child: const DesktopDiscoverMoviesPage(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('desktop-discover-movies-page')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-summary-card-ABC-025')), findsOneWidget);
  });

  testWidgets('desktop discover moments page loads more on scroll', (
    tester,
  ) async {
    final sessionStore = await _buildSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueMomentPage(bundle, page: 1, start: 1, count: 24, total: 25);
    _enqueueMomentPage(bundle, page: 2, start: 25, count: 1, total: 25);

    await _pumpDiscoveryWidget(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      child: const DesktopDiscoverMomentsPage(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('desktop-discover-moments-page')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('moment-card-1')), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moment-card-25')), findsOneWidget);
  });

  testWidgets(
    'desktop discover movies page keeps items after load more error',
    (tester) async {
      final sessionStore = await _buildSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueDailyPage(bundle, page: 1, start: 1, count: 24, total: 25);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/daily-recommendations',
        statusCode: 500,
        body: <String, dynamic>{'detail': 'failed'},
      );

      await _pumpDiscoveryWidget(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        child: const DesktopDiscoverMoviesPage(),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-summary-card-ABC-001')),
        findsOneWidget,
      );
      expect(find.text('加载更多推荐影片失败，请点击重试'), findsOneWidget);
    },
  );
}

Future<SessionStore> _buildSessionStore() async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-05-08T12:00:00Z'),
  );
  return sessionStore;
}

Future<void> _pumpDiscoveryWidget(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  required Widget child,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ApiClient>.value(value: bundle.apiClient),
        Provider<DiscoveryApi>.value(value: bundle.discoveryApi),
        Provider<MediaApi>(
          create: (_) => MediaApi(apiClient: bundle.apiClient),
        ),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<ImageSearchApi>(
          create: (_) => ImageSearchApi(apiClient: bundle.apiClient),
        ),
        Provider<ImageSearchDraftStore>(create: (_) => ImageSearchDraftStore()),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraMobileThemeData,
          onGenerateRoute:
              (settings) => MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => child,
              ),
          home: child,
        ),
      ),
    ),
  );
}

void _enqueueDiscoveryResponses(TestApiBundle bundle) {
  _enqueueDailyPage(bundle, page: 1, start: 1, count: 1, total: 1);
  _enqueueMomentPage(bundle, page: 1, start: 1, count: 1, total: 1);
}

void _enqueueDailyPage(
  TestApiBundle bundle, {
  required int page,
  required int start,
  required int count,
  required int total,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/daily-recommendations',
    body: <String, dynamic>{
      'items': List<Map<String, dynamic>>.generate(
        count,
        (index) => _dailyMovieJson(start + index),
      ),
      'page': page,
      'page_size': count,
      'total': total,
    },
  );
}

void _enqueueMomentPage(
  TestApiBundle bundle, {
  required int page,
  required int start,
  required int count,
  required int total,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/moment-recommendations',
    body: <String, dynamic>{
      'items': List<Map<String, dynamic>>.generate(
        count,
        (index) => _momentJson(start + index),
      ),
      'page': page,
      'page_size': count,
      'total': total,
      'generated_at': '2026-05-08T04:00:00',
    },
  );
}

Map<String, dynamic> _dailyMovieJson(int index) {
  final number = index.toString().padLeft(3, '0');
  return <String, dynamic>{
    'javdb_id': 'abc-id-$number',
    'movie_number': 'ABC-$number',
    'title': 'Movie title $number',
    'title_zh': '中文标题 $number',
    'cover_image': null,
    'thin_cover_image': null,
    'release_date': '2026-05-01',
    'duration_minutes': 120,
    'heat': 88 + index,
    'is_subscribed': false,
    'can_play': true,
    'snapshot_date': '2026-05-08',
    'generated_at': '2026-05-08T04:00:00',
    'rank': index,
    'recommendation_score': 0.91,
    'reason_codes': ['popular'],
    'reason_texts': ['近期热度较高'],
    'signal_scores': <String, dynamic>{'heat': 0.8},
    'is_stale': index == 1,
  };
}

Map<String, dynamic> _momentJson(int index) {
  final number = index.toString().padLeft(3, '0');
  return <String, dynamic>{
    'recommendation_id': index,
    'rank': index,
    'score': 0.88,
    'strategy': 'visual',
    'reason': '与你收藏的时刻画面相似',
    'media_id': 100 + index,
    'thumbnail_id': 500 + index,
    'offset_seconds': 360,
    'image': null,
    'movie': <String, dynamic>{
      'javdb_id': 'abc-id-$number',
      'movie_number': 'ABC-$number',
      'title': 'Movie title $number',
      'title_zh': '',
      'cover_image': null,
      'thin_cover_image': null,
      'release_date': null,
      'duration_minutes': 120,
      'heat': 10 + index,
      'is_subscribed': false,
      'can_play': true,
    },
  };
}
