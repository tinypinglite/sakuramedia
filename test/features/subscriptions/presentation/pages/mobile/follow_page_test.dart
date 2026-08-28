import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/subscriptions/presentation/pages/mobile/follow_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  testWidgets('mobile follow page renders all pages on scroll', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueFollowPage(bundle, page: 1, start: 1, count: 18, total: 19);
    _enqueueFollowPage(bundle, page: 2, start: 19, count: 1, total: 19);

    await _pumpFollowPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-follow-page')), findsOneWidget);
    expect(find.byKey(const Key('mobile-follow-page-total')), findsOneWidget);
    expect(find.text('19 部'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-summary-card-FOLLOW-001')),
      findsOneWidget,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-summary-card-FOLLOW-019')),
      findsOneWidget,
    );
    expect(
      bundle.adapter.hitCount('GET', '/movies/subscribed-actors/latest'),
      2,
    );
  });
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

Future<void> _pumpFollowPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: OKToast(
        child: MaterialApp(
          theme: sakuraMobileThemeData,
          home: const Scaffold(body: MobileFollowPage()),
        ),
      ),
    ),
  );
}

void _enqueueFollowPage(
  TestApiBundle bundle, {
  required int page,
  required int start,
  required int count,
  required int total,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/subscribed-actors/latest',
    body: <String, dynamic>{
      'items': List<Map<String, dynamic>>.generate(
        count,
        (index) => _followMovieJson(start + index),
      ),
      'page': page,
      'page_size': 18,
      'total': total,
    },
  );
}

Map<String, dynamic> _followMovieJson(int index) {
  final number = index.toString().padLeft(3, '0');
  return <String, dynamic>{
    'javdb_id': 'follow-id-$number',
    'movie_number': 'FOLLOW-$number',
    'title': 'Follow movie $number',
    'cover_image': null,
    'thin_cover_image': null,
    'release_date': '2026-05-01',
    'duration_minutes': 120,
    'heat': index,
    'is_subscribed': true,
    'can_play': false,
  };
}
