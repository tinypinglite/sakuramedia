import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/mobile_overview_my_tab.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/mobile_overview_page.dart';
import 'package:sakuramedia/features/overview/presentation/providers/mobile_overview_tab_index_provider.dart';
import 'package:sakuramedia/features/playlists/data/playlist_order_store.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_order_store_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/logged_in_session_store.dart';
import '../../../../../support/preview_helpers.dart';
import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late InMemoryPlaylistOrderStore orderStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
    orderStore = InMemoryPlaylistOrderStore();
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('loads each overview source once and refreshes each once', (
    tester,
  ) async {
    _enqueueMyTabResponses(bundle);
    await _pumpMyTab(tester, bundle, orderStore);
    await _pumpFrames(tester);

    _expectSourceCounts(bundle, 1);

    _enqueueMyTabResponses(bundle);
    final refreshState = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    final refreshFuture = refreshState.show();
    await _pumpFrames(tester);
    await refreshFuture;
    await _pumpFrames(tester);

    _expectSourceCounts(bundle, 2);
    expect(tester.takeException(), isNull);
  });

  test('latest movie provider recovers after a failed initial load', () async {
    _enqueueMyTabResponses(bundle, latestStatusCode: 500);
    final container = ProviderContainer(
      overrides: bundle.riverpodOverrides(),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    const scope = MovieSummaryScope.latest(pageSize: 12);
    final subscription = container.listen(
      movieSummaryProvider(scope),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await expectLater(
      container.read(movieSummaryProvider(scope).future),
      throwsA(anything),
    );
    expect(container.read(movieSummaryProvider(scope)).hasError, isTrue);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/latest',
      body: _page(pageSize: 12),
    );
    await container.read(movieSummaryProvider(scope).notifier).reload();

    expect(container.read(movieSummaryProvider(scope)).hasError, isFalse);
    expect(bundle.adapter.hitCount('GET', '/movies/latest'), 2);
  });

  testWidgets('reports tab changes and opens the shell drawer', (tester) async {
    _enqueueMyTabResponses(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections',
      body: const <dynamic>[],
    );

    final scaffoldKey = GlobalKey<ScaffoldState>();
    await pumpPreviewApp(
      tester,
      home: const MobileOverviewPage(),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      extraOverrides: [
        playlistOrderStoreProvider.overrideWithValue(orderStore),
      ],
      wrap: (child) =>
          Scaffold(key: scaffoldKey, drawer: const Drawer(), body: child),
      settle: false,
    );
    await _pumpFrames(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MobileOverviewPage)),
    );
    expect(container.read(mobileOverviewTabIndexProvider), 0);

    await tester.fling(
      find.byKey(const Key('mobile-overview-tab-view')),
      const Offset(-320, 0),
      1000,
    );
    await _pumpFrames(tester);
    expect(container.read(mobileOverviewTabIndexProvider), 1);

    await tester.tap(find.byType(Tab).first);
    await _pumpFrames(tester);
    expect(container.read(mobileOverviewTabIndexProvider), 0);

    await tester.tap(find.byKey(const Key('mobile-overview-menu-button')));
    await _pumpFrames(tester);
    expect(scaffoldKey.currentState?.isDrawerOpen, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpMyTab(
  WidgetTester tester,
  TestApiBundle bundle,
  InMemoryPlaylistOrderStore orderStore,
) {
  return pumpPreviewApp(
    tester,
    home: const MobileOverviewMyTab(),
    size: const Size(390, 844),
    theme: buildSakuraMobileThemeData(),
    platform: TargetPlatform.android,
    appPlatform: AppPlatform.mobile,
    bundle: bundle,
    extraOverrides: [playlistOrderStoreProvider.overrideWithValue(orderStore)],
    settle: false,
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _enqueueMyTabResponses(
  TestApiBundle bundle, {
  int latestStatusCode = 200,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/latest',
    statusCode: latestStatusCode,
    body: latestStatusCode == 200
        ? _page(pageSize: 12)
        : <String, dynamic>{'detail': 'failed'},
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies',
    body: _page(pageSize: 24),
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/playlists',
    body: const <dynamic>[],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/view-history',
    body: <String, dynamic>{'items': <dynamic>[]},
  );
}

Map<String, dynamic> _page({required int pageSize}) {
  return <String, dynamic>{
    'items': <dynamic>[],
    'page': 1,
    'page_size': pageSize,
    'total': 0,
  };
}

void _expectSourceCounts(TestApiBundle bundle, int count) {
  expect(bundle.adapter.hitCount('GET', '/movies/latest'), count);
  expect(bundle.adapter.hitCount('GET', '/movies'), count);
  expect(bundle.adapter.hitCount('GET', '/playlists'), count);
  expect(bundle.adapter.hitCount('GET', '/view-history'), count);
}
