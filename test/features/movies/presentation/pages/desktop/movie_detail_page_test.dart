import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/movie_detail_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

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

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: OKToast(
          child: MaterialApp(
            theme: sakuraThemeData,
            home: const Scaffold(
              body: DesktopMovieDetailPage(movieNumber: 'ABC-001'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop movie detail page loads and renders movie info', (
    WidgetTester tester,
  ) async {
    _enqueueMovieDetailResponses(bundle);

    await pumpPage(tester);

    expect(find.text('Movie 1'), findsOneWidget);
    expect(find.text('ABC-001'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

void _enqueueMovieDetailResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/ABC-001',
    body: <String, dynamic>{
      'javdb_id': 'MovieA1',
      'movie_number': 'ABC-001',
      'title': 'Movie 1',
      'cover_image': null,
      'release_date': '2024-01-02',
      'duration_minutes': 120,
      'score': 4.5,
      'watched_count': 12,
      'want_watch_count': 23,
      'comment_count': 34,
      'score_number': 45,
      'is_collection': false,
      'is_subscribed': true,
      'can_play': true,
      'series_id': 7,
      'series_name': 'Attackers',
      'summary': '',
      'actors': const <Map<String, dynamic>>[],
      'tags': const <Map<String, dynamic>>[],
      'thin_cover_image': null,
      'plot_images': const <Map<String, dynamic>>[],
      'media_items': const <Map<String, dynamic>>[],
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: const <Map<String, dynamic>>[],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/ABC-001/similar',
    body: const <String, dynamic>{'items': <dynamic>[]},
  );
}
