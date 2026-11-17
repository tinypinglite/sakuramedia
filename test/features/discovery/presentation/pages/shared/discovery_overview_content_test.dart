import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/discovery/presentation/desktop_discover_page.dart';
import 'package:sakuramedia/features/discovery/presentation/mobile_overview_discover_tab.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/logged_in_session_store.dart';
import '../../../../../support/preview_helpers.dart';
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

  testWidgets('mobile overview uses the shared 10-item discovery feeds', (
    tester,
  ) async {
    _enqueueOverview(bundle, pageSize: 10);

    await pumpPreviewApp(
      tester,
      home: const MobileOverviewDiscoverTab(),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      settle: false,
    );
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('mobile-overview-discover-tab')),
      findsWidgets,
    );
    _expectFeedPageSize(bundle, '10');
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop discover uses the shared 12-item discovery feeds', (
    tester,
  ) async {
    _enqueueOverview(bundle, pageSize: 12);

    await pumpPreviewApp(
      tester,
      home: const DesktopDiscoverPage(),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      settle: false,
    );
    await _pumpFrames(tester);

    expect(find.byKey(const Key('desktop-discover-page')), findsOneWidget);
    _expectFeedPageSize(bundle, '12');
    expect(tester.takeException(), isNull);
  });
}

void _enqueueOverview(TestApiBundle bundle, {required int pageSize}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/taste-profile',
    body: <String, dynamic>{
      'sample_movie_count': 0,
      'actresses': <dynamic>[],
      'unsubscribed_actresses': <dynamic>[],
      'tags': <dynamic>[],
    },
  );
  for (final path in <String>[
    '/movies/subscribed-actors/latest',
    '/hot-actress-releases',
    '/daily-recommendations',
    '/moment-recommendations',
  ]) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: path,
      body: <String, dynamic>{
        'items': <dynamic>[],
        'page': 1,
        'page_size': pageSize,
        'total': 0,
        if (path == '/moment-recommendations')
          'generated_at': '2026-08-04T04:00:00',
      },
    );
  }
}

void _expectFeedPageSize(TestApiBundle bundle, String pageSize) {
  for (final path in <String>[
    '/movies/subscribed-actors/latest',
    '/hot-actress-releases',
    '/daily-recommendations',
    '/moment-recommendations',
  ]) {
    final request = bundle.adapter.requests.firstWhere(
      (request) => request.path == path,
    );
    expect(request.uri.queryParameters['page_size'], pageSize);
  }
  expect(bundle.adapter.hitCount('GET', '/taste-profile'), 1);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
