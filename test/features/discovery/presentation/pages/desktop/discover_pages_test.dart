import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/discovery/presentation/desktop_discover_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/desktop/discover_moments_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/desktop/discover_movies_page.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/desktop/hot_actress_releases_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  testWidgets(
    'desktop discover page keeps followed actresses and adds hot releases',
    (tester) async {
      final sessionStore = await _buildSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueDiscoveryResponses(bundle);
      _enqueueSubscription(bundle, movieNumber: 'HOT-001');

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
      // 女优上新、热门女优新片、今日推荐各一个影片网格。
      expect(find.byKey(const Key('movie-summary-grid')), findsNWidgets(3));
      expect(find.text('女优上新'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-FOL-001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('desktop-discover-load-more-follow')),
        findsOneWidget,
      );
      expect(find.text('热门女优新片'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-HOT-001')),
        findsOneWidget,
      );
      expect(find.text('热门：女优 1'), findsOneWidget);
      expect(
        find.byKey(const Key('desktop-discover-load-more-hot-actress')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-summary-card-ABC-001')),
        findsOneWidget,
      );
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
      final requestsByPath = {
        for (final request in bundle.adapter.requests) request.path: request,
      };
      expect(
        requestsByPath['/hot-actress-releases']!
            .uri
            .queryParameters['page_size'],
        '24',
      );
      expect(
        requestsByPath['/movies/subscribed-actors/latest']!
            .uri
            .queryParameters['page_size'],
        '24',
      );
      expect(
        requestsByPath['/daily-recommendations']!
            .uri
            .queryParameters['page_size'],
        '24',
      );
      expect(
        requestsByPath['/moment-recommendations']!
            .uri
            .queryParameters['page_size'],
        '24',
      );
      expect(find.text('近期热度较高'), findsNothing);
      expect(find.text('与你收藏的时刻画面相似'), findsNothing);

      await tester.tap(
        find.byKey(const Key('movie-summary-card-subscription-HOT-001')),
      );
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('PUT', '/movies/HOT-001/subscription'), 1);
      expect(
        tester
            .widget<SubscriptionHeartBadge>(
              find.byKey(const Key('movie-summary-card-subscription-HOT-001')),
            )
            .isSubscribed,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 3));
    },
  );

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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-summary-card-ABC-025')), findsOneWidget);
  });

  testWidgets('desktop hot actress releases page loads more on scroll', (
    tester,
  ) async {
    final sessionStore = await _buildSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueHotActressPage(bundle, page: 1, start: 1, count: 24, total: 25);
    _enqueueHotActressPage(bundle, page: 2, start: 25, count: 1, total: 25);
    _enqueueSubscription(bundle, movieNumber: 'HOT-001');

    await _pumpDiscoveryWidget(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      child: const DesktopHotActressReleasesPage(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('desktop-hot-actress-releases-page')),
      findsOneWidget,
    );
    expect(find.text('热门：女优 1'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('movie-summary-card-subscription-HOT-001')),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('PUT', '/movies/HOT-001/subscription'), 1);
    expect(
      tester
          .widget<SubscriptionHeartBadge>(
            find.byKey(const Key('movie-summary-card-subscription-HOT-001')),
          )
          .isSubscribed,
      isTrue,
    );
    await tester.pump(const Duration(seconds: 3));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-summary-card-HOT-025')), findsOneWidget);
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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
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
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsNothing);
      expect(
        find.byKey(const Key('movie-summary-card-ABC-024')),
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
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
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
  _enqueueFollowPage(bundle);
  _enqueueHotActressPage(bundle, page: 1, start: 1, count: 1, total: 1);
  _enqueueDailyPage(bundle, page: 1, start: 1, count: 1, total: 1);
  _enqueueMomentPage(bundle, page: 1, start: 1, count: 1, total: 1);
}

void _enqueueSubscription(TestApiBundle bundle, {required String movieNumber}) {
  bundle.adapter.enqueueJson(
    method: 'PUT',
    path: '/movies/$movieNumber/subscription',
    statusCode: 204,
  );
}

void _enqueueFollowPage(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/subscribed-actors/latest',
    body: {
      'items': [_followMovieJson()],
      'page': 1,
      'page_size': 24,
      'total': 1,
    },
  );
}

Map<String, dynamic> _followMovieJson() => {
  'javdb_id': 'MovieFOL-001',
  'movie_number': 'FOL-001',
  'title': 'Movie FOL-001',
  'cover_image': null,
  'release_date': '2026-05-01',
  'duration_minutes': 120,
  'is_subscribed': true,
  'can_play': true,
};

void _enqueueHotActressPage(
  TestApiBundle bundle, {
  required int page,
  required int start,
  required int count,
  required int total,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/hot-actress-releases',
    body: <String, dynamic>{
      'items': List<Map<String, dynamic>>.generate(
        count,
        (index) => _hotActressMovieJson(start + index),
      ),
      'page': page,
      'page_size': count,
      'total': total,
    },
  );
}

Map<String, dynamic> _hotActressMovieJson(int index) {
  final number = index.toString().padLeft(3, '0');
  return <String, dynamic>{
    'javdb_id': 'hot-id-$number',
    'movie_number': 'HOT-$number',
    'title': 'Hot movie $number',
    'cover_image': null,
    'thin_cover_image': null,
    'release_date': '2026-05-01',
    'duration_minutes': 120,
    'heat': 0,
    'is_subscribed': false,
    'can_play': false,
    'hot_actress': <String, dynamic>{'name': '女优 $index'},
  };
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
