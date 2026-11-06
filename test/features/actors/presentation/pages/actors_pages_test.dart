import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/pages/desktop/actors_page.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actors_page.dart';
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
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/taste-profile',
      body: <String, dynamic>{
        'sample_movie_count': 0,
        'actresses': <Map<String, dynamic>>[],
        'unsubscribed_actresses': <Map<String, dynamic>>[],
        'tags': <Map<String, dynamic>>[],
      },
    );
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('桌面演员列表沿用缓存、搜索与双路刷新契约', (tester) async {
    _enqueueActorsPage(bundle, actorId: 1);
    _enqueueActorsPage(bundle, actorId: 2);
    _enqueueActorsPage(bundle, actorId: 3);
    _enqueueActorsPage(bundle, actorId: 4);

    final pageCache = _RecordingPageCache();
    final refreshCallbacks = <Future<void> Function()>[];
    await pumpPreviewApp(
      tester,
      home: const DesktopActorsPage(),
      size: const Size(1100, 760),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      pageStateCache: pageCache,
      wrap: (child) => AppPageRefreshRegistrarScope(
        registrar: AppPageRefreshRegistrar(
          register: refreshCallbacks.add,
          unregister: refreshCallbacks.remove,
        ),
        child: Scaffold(body: child),
      ),
    );

    expect(pageCache.lastKey, 'desktop:actors:list');
    expect(_actorRequests(bundle), hasLength(1));
    expect(
      _actorRequests(bundle).single.uri.queryParameters['page_size'],
      '24',
    );

    await tester.tap(find.byKey(const Key('actors-search-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('actors-search-field')), '三上');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final searchRequest = _actorRequests(bundle).last;
    expect(searchRequest.uri.queryParameters['query'], '三上');
    expect(searchRequest.uri.queryParameters.containsKey('sort'), isFalse);

    await tester.tap(find.byKey(const Key('actors-search-clear')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(
      _actorRequests(bundle).last.uri.queryParameters.containsKey('query'),
      isFalse,
    );

    expect(refreshCallbacks, hasLength(1));
    final refreshFuture = refreshCallbacks.single();
    await tester.pump(const Duration(seconds: 1));
    await refreshFuture;
    await tester.pumpAndSettle();

    expect(_actorRequests(bundle), hasLength(4));
    expect(bundle.adapter.hitCount('GET', '/taste-profile'), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('移动演员列表沿用缓存、搜索与串行刷新契约', (tester) async {
    _enqueueActorsPage(bundle, actorId: 1);
    _enqueueActorsPage(bundle, actorId: 2);
    _enqueueActorsPage(bundle, actorId: 3);

    final pageCache = _RecordingPageCache();
    await pumpPreviewApp(
      tester,
      home: const MobileActorsPage(),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.iOS,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      pageStateCache: pageCache,
      wrap: (child) => Scaffold(body: child),
    );

    expect(pageCache.lastKey, 'mobile:actors:list');
    expect(_actorRequests(bundle), hasLength(1));
    expect(
      _actorRequests(bundle).single.uri.queryParameters['page_size'],
      '24',
    );

    await tester.tap(find.byKey(const Key('mobile-actors-search-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('mobile-actors-search-field')),
      '三上',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final searchRequest = _actorRequests(bundle).last;
    expect(searchRequest.uri.queryParameters['query'], '三上');
    expect(searchRequest.uri.queryParameters.containsKey('sort'), isFalse);

    final refreshView = tester.widget<AppAdaptiveRefreshScrollView>(
      find.byType(AppAdaptiveRefreshScrollView),
    );
    final refreshFuture = refreshView.onRefresh();
    await tester.pump(const Duration(seconds: 1));
    await refreshFuture;
    await tester.pumpAndSettle();

    expect(_actorRequests(bundle), hasLength(3));
    expect(bundle.adapter.hitCount('GET', '/taste-profile'), 2);
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

List<RecordedRequest> _actorRequests(TestApiBundle bundle) {
  return bundle.adapter.requests
      .where((request) => request.path == '/actors')
      .toList(growable: false);
}

void _enqueueActorsPage(TestApiBundle bundle, {required int actorId}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/actors',
    body: <String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': actorId,
          'javdb_id': 'actor-$actorId',
          'name': '演员$actorId',
          'alias_name': '演员$actorId',
          'profile_image': null,
          'is_subscribed': true,
          'movie_count': 3,
        },
      ],
      'page': 1,
      'page_size': 24,
      'total': 1,
    },
  );
}
