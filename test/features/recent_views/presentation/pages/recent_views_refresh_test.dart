import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/recent_views/presentation/pages/mobile/recent_views_page.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_provider.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('refresh failure keeps stale grid and shows one inline error', (
    tester,
  ) async {
    _enqueueRecentViews(bundle, movieNumber: 'ABC-001');
    await pumpPreviewApp(
      tester,
      home: const MobileRecentViewsPage(),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      settle: false,
    );
    await _pumpFrames(tester);
    expect(find.byKey(const Key('recent-views-grid')), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/view-history',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'failed'},
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MobileRecentViewsPage)),
    );
    container.invalidate(recentViewsProvider);
    await _pumpFrames(tester);

    expect(find.byKey(const Key('recent-views-refresh-error')), findsOneWidget);
    expect(find.byKey(const Key('recent-views-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _enqueueRecentViews(TestApiBundle bundle, {required String movieNumber}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/view-history',
    body: <String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'entity_type': 'movie',
          'viewed_at': '2026-05-08T10:00:00',
          'movie': <String, dynamic>{
            'id': 11,
            'movie_number': movieNumber,
            'title': 'Movie 1',
            'cover_image': null,
            'thin_cover_image': null,
            'release_date': '2026-05-01',
            'duration_minutes': 120,
            'heat': 88,
            'is_subscribed': true,
            'can_play': true,
            'media_items': <dynamic>[],
          },
          'actor': null,
        },
      ],
    },
  );
}
