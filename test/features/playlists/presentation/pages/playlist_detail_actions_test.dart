import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/desktop/playlist_detail_page.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/mobile/playlist_detail_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  late TestApiBundle bundle;

  setUp(() async {
    final sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
  });

  testWidgets('桌面详情页「···」编辑播放列表并就地更新横幅', (WidgetTester tester) async {
    _enqueueDetail(bundle);
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/playlists/7',
      body: _playlistJson(name: '收藏补完'),
    );

    await _pumpDetail(tester, bundle: bundle, mobile: false);

    expect(find.text('我的收藏'), findsOneWidget);
    expect(
      find.byKey(const Key('playlist-detail-more-actions-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('playlist-detail-more-actions-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('playlist-detail-action-edit')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('playlist-detail-action-delete')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('playlist-detail-action-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('playlist-edit-name-field')),
      '收藏补完',
    );
    await tester.tap(find.byKey(const Key('playlist-edit-submit-button')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.firstWhere(
      (item) => item.method == 'PATCH' && item.path == '/playlists/7',
    );
    expect(request.body['name'], '收藏补完');
    expect(find.text('收藏补完'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('桌面详情页「···」删除播放列表并返回列表', (WidgetTester tester) async {
    _enqueueDetail(bundle);
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/playlists/7',
      statusCode: 204,
    );

    await _pumpDetail(tester, bundle: bundle, mobile: false);

    await tester.tap(
      find.byKey(const Key('playlist-detail-more-actions-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('playlist-detail-action-delete')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('playlist-detail-delete-confirm')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('playlist-detail-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('DELETE', '/playlists/7'), 1);
    expect(find.text('播放列表列表'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('系统播放列表不显示管理入口', (WidgetTester tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/7',
      body: _playlistJson(isSystem: true, isMutable: false, isDeletable: false),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/7/movies',
      body: _emptyMoviesPage(),
    );

    await _pumpDetail(tester, bundle: bundle, mobile: false);

    expect(
      find.byKey(const Key('playlist-detail-more-actions-button')),
      findsNothing,
    );

    await _rightClickBanner(tester);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('playlist-detail-action-edit')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('playlist-detail-action-delete')),
      findsNothing,
    );
  });

  testWidgets('桌面右键横幅不再弹菜单', (WidgetTester tester) async {
    _enqueueDetail(bundle);

    await _pumpDetail(tester, bundle: bundle, mobile: false);

    await _rightClickBanner(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('playlist-detail-action-edit')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('playlist-detail-action-delete')),
      findsNothing,
    );
  });

  testWidgets('移动长按横幅不再弹菜单', (WidgetTester tester) async {
    _enqueueDetail(bundle);

    await _pumpDetail(tester, bundle: bundle, mobile: true);

    await tester.longPress(find.byKey(const Key('playlist-banner-card-7')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('playlist-detail-actions-drawer')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('playlist-detail-action-edit')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('playlist-detail-action-delete')),
      findsNothing,
    );
  });

  testWidgets('深链详情删除后回到播放列表列表', (WidgetTester tester) async {
    _enqueueDetail(bundle);
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/playlists/7',
      statusCode: 204,
    );

    await _pumpDetail(tester, bundle: bundle, mobile: false, deepLink: true);

    await tester.tap(
      find.byKey(const Key('playlist-detail-more-actions-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('playlist-detail-action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('playlist-detail-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('DELETE', '/playlists/7'), 1);
    expect(find.text('播放列表列表'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('移动详情页「···」弹底部操作表，编辑走底部抽屉', (WidgetTester tester) async {
    _enqueueDetail(bundle);
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/playlists/7',
      body: _playlistJson(name: '收藏补完'),
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/playlists/7',
      statusCode: 204,
    );

    await _pumpDetail(tester, bundle: bundle, mobile: true);

    expect(
      find.byKey(const Key('playlist-detail-more-actions-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('playlist-detail-more-actions-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('playlist-detail-actions-drawer')),
      findsOneWidget,
    );
    expect(find.text('播放列表操作'), findsOneWidget);
    expect(
      find.byKey(const Key('playlist-detail-action-edit')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('playlist-detail-action-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('playlist-edit-drawer')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('playlist-edit-name-field')),
      '收藏补完',
    );
    await tester.tap(find.byKey(const Key('playlist-edit-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('收藏补完'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('playlist-detail-more-actions-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('playlist-detail-action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('playlist-detail-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('DELETE', '/playlists/7'), 1);
    expect(find.text('播放列表列表'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required bool mobile,
  bool deepLink = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = mobile
      ? const Size(390, 844)
      : const Size(1100, 760);
  addTearDown(tester.view.reset);

  final detailPage = mobile
      ? const MobilePlaylistDetailPage(playlistId: 7)
      : const DesktopPlaylistDetailPage(playlistId: 7);
  final fallbackPath = mobile
      ? '/mobile/overview'
      : '/desktop/library/playlists';
  final router = deepLink
      ? GoRouter(
          initialLocation: '/playlist/7',
          routes: [
            GoRoute(path: '/playlist/7', builder: (_, _) => detailPage),
            GoRoute(
              path: fallbackPath,
              builder: (_, _) => const Scaffold(body: Text('播放列表列表')),
            ),
          ],
        )
      : GoRouter(
          initialLocation: '/playlist/7',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('播放列表列表')),
              routes: [
                GoRoute(path: 'playlist/7', builder: (_, _) => detailPage),
              ],
            ),
          ],
        );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: AppPlatformScope(
        platform: mobile ? AppPlatform.mobile : AppPlatform.desktop,
        child: OKToast(
          child: MaterialApp.router(
            theme: mobile ? sakuraMobileThemeData : sakuraThemeData,
            routerConfig: router,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _enqueueDetail(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/playlists/7',
    body: _playlistJson(),
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/playlists/7/movies',
    body: _emptyMoviesPage(),
  );
}

Finder get _bannerFinder =>
    find.byKey(const Key('playlist-banner-card-7'));

/// 右键横幅：验证右键不再是管理入口。
Future<void> _rightClickBanner(WidgetTester tester) async {
  final mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await mouse.down(tester.getCenter(_bannerFinder));
  await mouse.up();
  await mouse.removePointer();
}

Map<String, dynamic> _playlistJson({
  String name = '我的收藏',
  bool isSystem = false,
  bool isMutable = true,
  bool isDeletable = true,
}) => <String, dynamic>{
  'id': 7,
  'name': name,
  'kind': isSystem ? 'recently_played' : 'custom',
  'description': 'Favorite movies',
  'is_system': isSystem,
  'is_mutable': isMutable,
  'is_deletable': isDeletable,
  'movie_count': 0,
  'created_at': '2026-03-12T10:10:00Z',
  'updated_at': '2026-03-12T11:20:00Z',
};

Map<String, dynamic> _emptyMoviesPage() => <String, dynamic>{
  'items': const <Map<String, dynamic>>[],
  'page': 1,
  'page_size': 24,
  'total': 0,
};
