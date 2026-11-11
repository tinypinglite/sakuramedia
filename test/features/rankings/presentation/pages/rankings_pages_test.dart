import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/desktop/rankings_page.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/mobile/rankings_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/fake_http_client_adapter.dart';
import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
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

  testWidgets('桌面榜单沿用 scope、分页与批量选择契约', (tester) async {
    _enqueueRankingsPage(bundle);

    final pageCache = _RecordingPageCache();
    await pumpPreviewApp(
      tester,
      home: const DesktopRankingsPage(),
      size: const Size(1100, 760),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      pageStateCache: pageCache,
      wrap: (child) => AppPageRefreshRegistrarScope(
        registrar: AppPageRefreshRegistrar(
          register: (_) {},
          unregister: (_) {},
        ),
        child: Scaffold(body: child),
      ),
    );

    expect(pageCache.lastKey, 'desktop:rankings:list');
    expect(_itemRequests(bundle), hasLength(1));
    expect(_itemRequests(bundle).single.uri.queryParameters['page_size'], '24');
    expect(_itemRequests(bundle).single.uri.queryParameters['period'], 'daily');
    expect(find.byKey(const Key('desktop-rankings-page')), findsOneWidget);
    expect(
      find.byKey(const Key('desktop-rankings-page-total')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('desktop-rankings-enter-selection-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('desktop-rankings-exit-selection-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('desktop-rankings-batch-subscribe-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('移动榜单沿用 scope、分页与下拉刷新契约', (tester) async {
    _enqueueRankingsPage(bundle);

    final pageCache = _RecordingPageCache();
    await pumpPreviewApp(
      tester,
      home: const MobileRankingsPage(),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.iOS,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      pageStateCache: pageCache,
    );

    expect(pageCache.lastKey, 'mobile:rankings:list');
    expect(_itemRequests(bundle), hasLength(1));
    expect(_itemRequests(bundle).single.uri.queryParameters['page_size'], '24');
    expect(
      find.byKey(const Key('mobile-rankings-large-title')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-rankings-filter-button')),
      findsOneWidget,
    );

    _enqueueRankingItems(bundle);
    final refreshView = tester.widget<AppAdaptiveRefreshScrollView>(
      find.byType(AppAdaptiveRefreshScrollView),
    );
    final refreshFuture = refreshView.onRefresh!();
    await tester.pump(const Duration(seconds: 1));
    await refreshFuture;
    await tester.pumpAndSettle();
    expect(_itemRequests(bundle), hasLength(2));
    expect(tester.takeException(), isNull);
  });
}

class _RecordingPageCache extends RiverpodPageCache {
  String? lastKey;

  @override
  RiverpodPageHandle obtain({
    required String key,
    required List<KeepAliveLink> Function() resolveLinks,
  }) {
    lastKey = key;
    return super.obtain(key: key, resolveLinks: resolveLinks);
  }
}

List<RecordedRequest> _itemRequests(TestApiBundle bundle) {
  return bundle.adapter.requests
      .where(
        (request) =>
            request.path == '/ranking-sources/javdb/boards/censored/items',
      )
      .toList(growable: false);
}

void _enqueueRankingsPage(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/ranking-sources',
    body: <Map<String, dynamic>>[
      <String, dynamic>{'source_key': 'javdb', 'name': 'JavDB'},
    ],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/ranking-sources/javdb/boards',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'source_key': 'javdb',
        'board_key': 'censored',
        'name': '有码',
        'supported_periods': <String>['daily', 'weekly'],
        'default_period': 'daily',
      },
    ],
  );
  _enqueueRankingItems(bundle);
}

void _enqueueRankingItems(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/ranking-sources/javdb/boards/censored/items',
    body: <String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'rank': 1,
          'movie_number': 'ABC-001',
          'title': 'Movie 1',
          'cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'heat': 1,
          'is_subscribed': false,
          'can_play': true,
        },
      ],
      'page': 1,
      'page_size': 24,
      'total': 1,
    },
  );
}
