import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/discovery/presentation/mobile_overview_discover_tab.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  testWidgets(
    'mobile discover tab shows followed actress releases and recommendations',
    (tester) async {
      final sessionStore = await _buildSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      _enqueueDiscoveryResponses(bundle);
      _enqueueFollowPage(bundle);
      _enqueueSubscription(bundle, movieNumber: 'HOT-001');

      await _pumpDiscoveryWidget(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        child: const MobileOverviewDiscoverTab(),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mobile-overview-discover-tab')),
        findsWidgets,
      );
      expect(find.text('今日发现'), findsNothing);
      expect(
        find.byKey(const Key('mobile-discover-summary-card')),
        findsNothing,
      );
      expect(find.byKey(const Key('movie-summary-grid')), findsNWidgets(3));
      expect(find.text('女优上新'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-FOLLOW-001')),
        findsOneWidget,
      );
      expect(find.text('热门新片'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-HOT-001')),
        findsOneWidget,
      );
      expect(find.text('热门：女优 A'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-ABC-001')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('moment-grid')), findsOneWidget);
      expect(find.byKey(const Key('moment-card-1')), findsOneWidget);
      expect(
        find.byKey(const Key('mobile-discover-load-more-hot-actress')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mobile-discover-load-more-follow')),
        findsNothing,
      );
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
          theme: sakuraMobileThemeData,
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
    body: <String, dynamic>{
      'items': <Map<String, dynamic>>[_followMovieJson()],
      'page': 1,
      'page_size': 10,
      'total': 1,
    },
  );
}

Map<String, dynamic> _followMovieJson() => <String, dynamic>{
  'javdb_id': 'follow-id-001',
  'movie_number': 'FOLLOW-001',
  'title': 'Follow movie 001',
  'cover_image': null,
  'thin_cover_image': null,
  'release_date': '2026-05-01',
  'duration_minutes': 120,
  'heat': 0,
  'is_subscribed': true,
  'can_play': false,
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
    'hot_actress': <String, dynamic>{'name': '女优 A'},
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
