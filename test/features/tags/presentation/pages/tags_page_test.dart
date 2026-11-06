import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/tags/presentation/pages/desktop/tags_page.dart';
import 'package:sakuramedia/features/tags/presentation/pages/mobile/tags_page.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/desktop_routes.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

import '../../../../support/test_api_bundle.dart';

const _movieNumber = 'ABP-123';
const _detailText = 'movie-detail';

class _RecordingPageCache extends RiverpodPageCache {
  final List<String> keys = <String>[];

  @override
  RiverpodPageHandle obtain({
    required String key,
    required List<KeepAliveLink> Function() resolveLinks,
  }) {
    keys.add(key);
    return super.obtain(key: key, resolveLinks: resolveLinks);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mobile in <bool>[false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} tags keep selection and navigation',
      (tester) async {
        final pageCache = _RecordingPageCache();
        addTearDown(pageCache.dispose);
        final harness = await _pumpTagsPage(
          tester,
          mobile: mobile,
          pageCache: pageCache,
        );

        expect(
          pageCache.keys,
          contains(mobile ? 'mobile:tags:list' : 'desktop:tags:list'),
        );

        await _toggleTag(tester, 1);
        await _toggleTag(tester, 2);
        await tester.tap(find.byKey(const Key('tags-browse-confirm')));
        await _pumpFrames(tester);

        expect(find.byKey(const Key('tags-summary-1')), findsOneWidget);
        expect(find.byKey(const Key('tags-summary-2')), findsOneWidget);
        expect(
          harness.bundle.adapter.requests
              .firstWhere((request) => request.path == '/movies')
              .uri
              .queryParameters['tag_ids'],
          '1,2',
        );

        await tester.tap(find.byKey(const Key('tags-edit-selection')));
        await _pumpFrames(tester);
        await _toggleTag(tester, 3);
        await tester.tap(find.byKey(const Key('tags-browse-cancel')));
        await _pumpFrames(tester);

        expect(find.byKey(const Key('tags-summary-3')), findsNothing);
        expect(find.byKey(const Key('tags-summary-1')), findsOneWidget);
        expect(find.byKey(const Key('tags-summary-2')), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('movie-summary-card-$_movieNumber')),
        );
        await _pumpFrames(tester);
        expect(find.text(_detailText), findsOneWidget);

        harness.router.pop();
        await _pumpFrames(tester);

        await tester.tap(find.byKey(const Key('tags-summary-1')));
        await _pumpFrames(tester);
        expect(find.byKey(const Key('tags-summary-1')), findsNothing);
        expect(find.byKey(const Key('tags-summary-2')), findsOneWidget);

        await tester.tap(find.byKey(const Key('tags-summary-clear')));
        await _pumpFrames(tester);
        expect(find.byKey(const Key('tags-browse-confirm')), findsNothing);
        expect(find.byKey(const Key('tags-browse-search')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('mobile tag results keep the header pinned and refresh once', (
    tester,
  ) async {
    final pageCache = _RecordingPageCache();
    addTearDown(pageCache.dispose);
    final harness = await _pumpTagsPage(
      tester,
      mobile: true,
      initialTagId: 1,
      pageCache: pageCache,
    );

    expect(pageCache.keys, isEmpty);
    expect(
      harness.bundle.adapter.requests
          .firstWhere((request) => request.path == '/movies')
          .uri
          .queryParameters['tag_ids'],
      '1',
    );

    final header = find.byKey(const Key('mobile-tags-page-total'));
    final scrollView = find
        .byKey(const PageStorageKey<String>('mobile:tags:detail:1:movies'))
        .last;
    final initialTop = tester.getTopLeft(header).dy;

    await tester.drag(scrollView, const Offset(0, -260));
    await _pumpFrames(tester);
    final pinnedTop = tester.getTopLeft(header).dy;
    expect(pinnedTop, lessThan(initialTop));

    await tester.drag(scrollView, const Offset(0, -180));
    await _pumpFrames(tester);
    expect(tester.getTopLeft(header).dy, closeTo(pinnedTop, 0.1));

    await tester.fling(scrollView, const Offset(0, 1200), 2000);
    await _pumpFrames(tester);
    final refreshState = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    final refreshFuture = refreshState.show();
    await _pumpFrames(tester);
    await refreshFuture;
    await _pumpFrames(tester);

    expect(harness.bundle.adapter.hitCount('GET', '/movies'), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop tag results register one page refresh', (tester) async {
    AppPageRefreshCallback? refresh;
    var registrations = 0;
    final registrar = AppPageRefreshRegistrar(
      register: (callback) {
        registrations++;
        refresh = callback;
      },
      unregister: (callback) {
        if (identical(callback, refresh)) {
          refresh = null;
        }
      },
    );
    final harness = await _pumpTagsPage(
      tester,
      mobile: false,
      initialTagId: 1,
      pageCache: _RecordingPageCache(),
      refreshRegistrar: registrar,
    );

    expect(registrations, 1);
    expect(refresh, isNotNull);

    final refreshFuture = refresh!();
    await _pumpFrames(tester);
    await refreshFuture;
    await _pumpFrames(tester);

    expect(harness.bundle.adapter.hitCount('GET', '/movies'), 2);
    expect(tester.takeException(), isNull);
  });
}

Future<_TagsHarness> _pumpTagsPage(
  WidgetTester tester, {
  required bool mobile,
  int? initialTagId,
  required RiverpodPageCache pageCache,
  AppPageRefreshRegistrar? refreshRegistrar,
}) async {
  final session = SessionStore.inMemory();
  await session.saveBaseUrl('https://api.example.com');
  await session.saveTokens(
    accessToken: 'test',
    refreshToken: 'test',
    expiresAt: DateTime(2099),
  );
  final bundle = await createTestApiBundle(session);
  addTearDown(bundle.dispose);
  addTearDown(session.dispose);
  bundle.adapter.setFallbackJson(method: 'GET', path: '/tags', body: _tags());
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/movies',
    body: _moviePage(),
  );
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/taste-profile',
    body: const <String, dynamic>{
      'sample_movie_count': 0,
      'actresses': <dynamic>[],
      'tags': <dynamic>[],
    },
  );

  final router = _buildTagsRouter(
    mobile: mobile,
    initialTagId: initialTagId,
    refreshRegistrar: refreshRegistrar,
  );
  addTearDown(router.dispose);
  tester.view.physicalSize = mobile
      ? const Size(390, 844)
      : const Size(1100, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(pageStateCache: pageCache),
      child: MaterialApp.router(
        theme: mobile ? buildSakuraMobileThemeData() : sakuraThemeData,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        routerConfig: router,
      ),
    ),
  );
  await _pumpFrames(tester);
  return _TagsHarness(bundle: bundle, router: router);
}

GoRouter _buildTagsRouter({
  required bool mobile,
  int? initialTagId,
  AppPageRefreshRegistrar? refreshRegistrar,
}) {
  final tagsLocation = mobile ? mobileTagsPath : desktopTagsPath;
  final detailLocation = mobile
      ? MobileMovieDetailRouteData(movieNumber: _movieNumber).location
      : DesktopMovieDetailRouteData(movieNumber: _movieNumber).location;
  Widget page() {
    final content = Scaffold(
      body: mobile
          ? MobileTagsPage(initialTagId: initialTagId)
          : DesktopTagsPage(initialTagId: initialTagId),
    );
    return refreshRegistrar == null
        ? content
        : AppPageRefreshRegistrarScope(
            registrar: refreshRegistrar,
            child: content,
          );
  }

  return GoRouter(
    initialLocation: tagsLocation,
    routes: <RouteBase>[
      GoRoute(path: tagsLocation, builder: (_, _) => page()),
      GoRoute(
        path: detailLocation,
        builder: (_, _) => const Scaffold(body: Text(_detailText)),
      ),
    ],
  );
}

Future<void> _toggleTag(WidgetTester tester, int tagId) async {
  final tag = find.byKey(Key('tags-cloud-tag-$tagId'));
  await tester.ensureVisible(tag);
  await tester.tap(tag);
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

List<Map<String, dynamic>> _tags() => <Map<String, dynamic>>[
  <String, dynamic>{'tag_id': 1, 'name': '标签一', 'movie_count': 30},
  <String, dynamic>{'tag_id': 2, 'name': '标签二', 'movie_count': 20},
  <String, dynamic>{'tag_id': 3, 'name': '标签三', 'movie_count': 10},
];

Map<String, dynamic> _moviePage() => <String, dynamic>{
  'items': <Map<String, dynamic>>[
    for (var index = 0; index < 24; index++)
      <String, dynamic>{
        'id': index + 1,
        'movie_number': index == 0 ? _movieNumber : 'ABP-${index + 100}',
        'title': '影片 ${index + 1}',
        'cover_image': null,
        'release_date': null,
        'duration_minutes': 120,
        'is_subscribed': false,
        'can_play': true,
      },
  ],
  'page': 1,
  'page_size': 24,
  'total': 24,
};

class _TagsHarness {
  const _TagsHarness({required this.bundle, required this.router});

  final TestApiBundle bundle;
  final GoRouter router;
}
