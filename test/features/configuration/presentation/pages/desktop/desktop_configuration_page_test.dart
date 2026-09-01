import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show AsyncData, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/config_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/configuration_page.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_provider.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_desktop_shell.dart';

import '../../../../../support/logged_in_session_store.dart';
import '../../../../../support/test_api_bundle.dart';

void main() {
  group('DesktopConfigurationPage', () {
    late SessionStore sessionStore;
    late TestApiBundle bundle;

    setUp(() async {
      sessionStore = await buildLoggedInSessionStore();
      bundle = await createTestApiBundle(sessionStore);
    });

    tearDown(() {
      bundle.dispose();
    });

    testWidgets(
      'renders configuration category entries in the requested order',
      (WidgetTester tester) async {
        _enqueueMediaLibraries(bundle);

        await _pumpPage(tester, bundle, sessionStore: sessionStore);

        // 媒体维护 / 媒体管理已迁到侧边栏「管理 > 媒体管理」独立页，不再是设置分类。
        const categoryKeys = <String>[
          'configuration-tab-account-security',
          'configuration-tab-media-libraries',
          'configuration-tab-downloads',
          'configuration-tab-indexers',
          'configuration-tab-playlists',
          'configuration-tab-blacklisted-movies',
          'configuration-tab-advanced',
          'configuration-tab-plugins',
          'configuration-tab-system-maintenance',
        ];
        var previousTop = double.negativeInfinity;
        for (final key in categoryKeys) {
          final finder = find.byKey(Key(key));
          expect(finder, findsOneWidget, reason: key);
          final top = tester.getTopLeft(finder).dy;
          expect(top, greaterThan(previousTop), reason: key);
          previousTop = top;
        }
        expect(
          find.byKey(const Key('configuration-tab-media-maintenance')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('configuration-tab-media-management')),
          findsNothing,
        );
      },
    );

    testWidgets('top-bar refresh follows the selected configuration section', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle, libraries: const []);
      _enqueueMediaLibraries(bundle, libraries: const []);
      _enqueueDownloadClientsList(bundle, clients: const []);
      _enqueueDownloadClientsList(bundle, clients: const []);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        useDesktopShell: true,
        useReloadingMediaProviderCatalog: true,
      );

      final refreshButton = find.byKey(const Key('topbar-refresh-button'));
      expect(refreshButton, findsOneWidget);

      await tester.tap(find.byKey(const Key('configuration-tab-downloads')));
      await tester.pumpAndSettle();
      expect(refreshButton, findsOneWidget);

      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/download-clients'), 2);
      expect(bundle.adapter.hitCount('GET', '/media-libraries'), 2);
      expect(bundle.adapter.hitCount('GET', '/indexer-settings'), 0);
      expect(bundle.adapter.hitCount('GET', '/playlists'), 0);
    });

    testWidgets('rebuilds the image-search index from system maintenance', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/status/image-search',
        body: <String, dynamic>{
          'index_space': <String, dynamic>{
            'state': 'rebuild_required',
            'indexed_space_id': 'siglip2-old',
            'current_space_id': 'siglip2-new',
          },
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(
        find.byKey(const Key('configuration-tab-system-maintenance')),
      );
      await tester.pumpAndSettle();

      final resetButton = find.byKey(
        const Key('configuration-system-maintenance-image-search-reset'),
      );
      expect(
        find.byKey(
          const Key('configuration-system-maintenance-image-search-card'),
        ),
        findsOneWidget,
      );
      expect(find.text('立即重建'), findsOneWidget);

      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/reset',
        statusCode: 202,
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/status/image-search',
        body: <String, dynamic>{
          'index_space': <String, dynamic>{
            'state': 'rebuild_required',
            'indexed_space_id': 'siglip2-old',
            'current_space_id': 'siglip2-new',
            'is_rebuilding': true,
          },
        },
      );

      await tester.tap(resetButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-image-search-reset-confirm')),
      );
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('POST', '/image-search/reset'), 1);
      expect(find.text('重建中'), findsOneWidget);
      expect(tester.widget<AppButton>(resetButton).onPressed, isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('loads download clients lazily when switching tabs', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle, libraries: const []);
      _enqueueDownloadClientsList(bundle, clients: const []);
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      expect(bundle.adapter.hitCount('GET', '/download-clients'), 0);
      expect(bundle.adapter.hitCount('GET', '/media-libraries'), 1);
      expect(bundle.adapter.hitCount('GET', '/config'), 0);
      expect(bundle.adapter.hitCount('GET', '/indexer-settings'), 0);
      expect(bundle.adapter.hitCount('GET', '/playlists'), 0);
      expect(find.text('还没有媒体库'), findsOneWidget);

      await tester.tap(find.byKey(const Key('configuration-tab-downloads')));
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/download-clients'), 1);
      expect(bundle.adapter.hitCount('GET', '/media-libraries'), 1);
    });

    testWidgets('refreshes the Provider catalog when returning to media tab', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle, libraries: const []);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        useReloadingMediaProviderCatalog: true,
      );

      expect(find.textContaining('暂无可用 Provider'), findsOneWidget);

      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await _openMediaLibrariesTab(tester);

      expect(find.textContaining('暂无可用 Provider'), findsNothing);
    });

    testWidgets('loads blacklisted movies lazily when switching tabs', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle, libraries: const []);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: <String, dynamic>{
          'items': const <Map<String, dynamic>>[],
          'page': 1,
          'page_size': 24,
          'total': 0,
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      expect(bundle.adapter.hitCount('GET', '/movies'), 0);

      await tester.tap(
        find.byKey(const Key('configuration-tab-blacklisted-movies')),
      );
      await tester.pumpAndSettle();

      final request = bundle.adapter.requests.firstWhere(
        (request) => request.method == 'GET' && request.path == '/movies',
      );
      expect(request.uri.queryParameters['blacklisted'], 'true');
      expect(find.text('还没有屏蔽任何影片'), findsOneWidget);
    });

    testWidgets('unblacklists a movie from its context menu', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle, libraries: const []);
      bundle.adapter
        ..enqueueJson(
          method: 'GET',
          path: '/movies',
          body: <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'javdb_id': 'javdb-BL-001',
                'movie_number': 'BL-001',
                'title': 'Blocked Movie',
                'cover_image': null,
                'release_date': '2026-01-01',
                'duration_minutes': 120,
                'heat': 10,
                'is_subscribed': false,
                'can_play': false,
              },
            ],
            'page': 1,
            'page_size': 24,
            'total': 1,
          },
        )
        ..enqueueJson(
          method: 'DELETE',
          path: '/movies/blacklist',
          statusCode: 204,
        );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(
        find.byKey(const Key('configuration-tab-blacklisted-movies')),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('movie-summary-card-BL-001'));
      await tester.ensureVisible(card);
      await tester.tapAt(
        tester.getCenter(card),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消屏蔽'));
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('DELETE', '/movies/blacklist'), 1);
      final request = bundle.adapter.requests.last;
      expect(request.body, <String, dynamic>{
        'movie_numbers': <String>['BL-001'],
      });
      expect(card, findsNothing);
      expect(find.text('还没有屏蔽任何影片'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('confirms before leaving dirty advanced settings tab', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueAdvancedConfig(bundle);
      _enqueuePlaylists(bundle, playlists: const []);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-advanced'),
      );

      await tester.enterText(
        find.byKey(const Key('configuration-advanced-min-video-size-field')),
        '257',
      );
      await tester.tap(find.byKey(const Key('configuration-tab-playlists')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('configuration-advanced-leave-confirm-dialog')),
        findsOneWidget,
      );
      expect(bundle.adapter.hitCount('GET', '/playlists'), 0);

      await tester.tap(
        find.byKey(const Key('configuration-advanced-leave-cancel-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('高级设置'), findsWidgets);
      expect(bundle.adapter.hitCount('GET', '/playlists'), 0);

      await tester.tap(find.byKey(const Key('configuration-tab-playlists')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-advanced-leave-confirm-button')),
      );
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/playlists'), 1);
      expect(find.text('还没有自定义播放列表'), findsOneWidget);
    });

    testWidgets('loads playlists lazily and hides system playlists', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueuePlaylists(
        bundle,
        playlists: const [
          {
            'id': 1,
            'name': '最近播放',
            'kind': 'recently_played',
            'description': '系统自动维护的最近播放影片列表',
            'is_system': true,
            'is_mutable': false,
            'is_deletable': false,
            'movie_count': 1,
            'created_at': '2026-03-12T10:00:00Z',
            'updated_at': '2026-03-12T10:00:00Z',
          },
          {
            'id': 2,
            'name': '我的收藏',
            'kind': 'custom',
            'description': 'Favorite movies',
            'is_system': false,
            'is_mutable': true,
            'is_deletable': true,
            'movie_count': 2,
            'created_at': '2026-03-12T10:10:00Z',
            'updated_at': '2026-03-12T11:20:00Z',
          },
        ],
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      expect(bundle.adapter.hitCount('GET', '/playlists'), 0);

      await tester.tap(find.byKey(const Key('configuration-tab-playlists')));
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/playlists'), 1);
      final request = bundle.adapter.requests.firstWhere(
        (item) => item.method == 'GET' && item.path == '/playlists',
      );
      expect(request.uri.queryParameters['include_system'], 'false');
      expect(
        find.byKey(const Key('desktop-playlist-management-card-2')),
        findsOneWidget,
      );
      expect(find.text('最近播放'), findsNothing);
    });

    testWidgets('creates playlist from configuration playlists tab', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueuePlaylists(bundle, playlists: const []);
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/playlists',
        statusCode: 201,
        body: {
          'id': 3,
          'name': '稍后再看',
          'kind': 'custom',
          'description': 'Need watch later',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 0,
          'created_at': '2026-03-12T10:10:00Z',
          'updated_at': '2026-03-12T10:10:00Z',
        },
      );
      _enqueuePlaylists(
        bundle,
        playlists: const [
          {
            'id': 3,
            'name': '稍后再看',
            'kind': 'custom',
            'description': 'Need watch later',
            'is_system': false,
            'is_mutable': true,
            'is_deletable': true,
            'movie_count': 0,
            'created_at': '2026-03-12T10:10:00Z',
            'updated_at': '2026-03-12T10:10:00Z',
          },
        ],
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      await tester.tap(find.byKey(const Key('configuration-tab-playlists')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-playlist-create-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('create-playlist-name-field')),
        '稍后再看',
      );
      await tester.enterText(
        find.byKey(const Key('create-playlist-description-field')),
        'Need watch later',
      );
      await tester.tap(find.byKey(const Key('create-playlist-submit-button')));
      await tester.pumpAndSettle();

      final request = bundle.adapter.requests.firstWhere(
        (item) => item.method == 'POST' && item.path == '/playlists',
      );
      expect(request.body['name'], '稍后再看');
      expect(request.body['description'], 'Need watch later');
      expect(
        find.byKey(const Key('desktop-playlist-management-card-3')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('edits playlist from configuration playlists tab', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueuePlaylists(
        bundle,
        playlists: const [
          {
            'id': 2,
            'name': '我的收藏',
            'kind': 'custom',
            'description': 'Favorite movies',
            'is_system': false,
            'is_mutable': true,
            'is_deletable': true,
            'movie_count': 2,
            'created_at': '2026-03-12T10:10:00Z',
            'updated_at': '2026-03-12T11:20:00Z',
          },
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/playlists/2',
        body: {
          'id': 2,
          'name': '收藏补完',
          'kind': 'custom',
          'description': 'Updated',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 2,
          'created_at': '2026-03-12T10:10:00Z',
          'updated_at': '2026-03-12T11:30:00Z',
        },
      );
      _enqueuePlaylists(
        bundle,
        playlists: const [
          {
            'id': 2,
            'name': '收藏补完',
            'kind': 'custom',
            'description': 'Updated',
            'is_system': false,
            'is_mutable': true,
            'is_deletable': true,
            'movie_count': 2,
            'created_at': '2026-03-12T10:10:00Z',
            'updated_at': '2026-03-12T11:30:00Z',
          },
        ],
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      await tester.tap(find.byKey(const Key('configuration-tab-playlists')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('desktop-playlist-edit-2')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('configuration-playlist-name-field')),
        '收藏补完',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-playlist-description-field')),
        'Updated',
      );
      await tester.ensureVisible(find.text('保存').last);
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final request = bundle.adapter.requests.firstWhere(
        (item) => item.method == 'PATCH' && item.path == '/playlists/2',
      );
      expect(request.body['name'], '收藏补完');
      expect(request.body['description'], 'Updated');
      expect(
        find.byKey(const Key('desktop-playlist-management-card-2')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('deletes playlist from configuration playlists tab', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueuePlaylists(
        bundle,
        playlists: const [
          {
            'id': 2,
            'name': '我的收藏',
            'kind': 'custom',
            'description': 'Favorite movies',
            'is_system': false,
            'is_mutable': true,
            'is_deletable': true,
            'movie_count': 2,
            'created_at': '2026-03-12T10:10:00Z',
            'updated_at': '2026-03-12T11:20:00Z',
          },
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/playlists/2',
        statusCode: 204,
      );
      _enqueuePlaylists(bundle, playlists: const []);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      await tester.tap(find.byKey(const Key('configuration-tab-playlists')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('desktop-playlist-delete-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('DELETE', '/playlists/2'), 1);
      expect(find.text('我的收藏'), findsNothing);
      expect(find.text('还没有自定义播放列表'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'shows media library name and provider on configuration cells',
      (WidgetTester tester) async {
        _enqueueMediaLibraries(bundle);

        await _pumpPage(tester, bundle, sessionStore: sessionStore);
        await _openMediaLibrariesTab(tester);

        expect(find.byKey(const Key('media-library-card-1')), findsOneWidget);
        expect(find.text('Main Library'), findsOneWidget);
        expect(find.text('Provider A'), findsOneWidget);
        expect(find.text('ID 1'), findsOneWidget);
      },
    );

    testWidgets('deletes a media library and refreshes the list', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/media-libraries/1',
        statusCode: 204,
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media-libraries',
        body: const <Map<String, Object?>>[],
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openMediaLibrariesTab(tester);
      await tester.tap(find.byKey(const Key('media-library-delete-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('DELETE', '/media-libraries/1'), 1);
      expect(find.text('Main Library'), findsNothing);
      expect(find.text('还没有媒体库'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'does not call delete api when media library deletion canceled',
      (WidgetTester tester) async {
        _enqueueMediaLibraries(bundle);

        await _pumpPage(tester, bundle, sessionStore: sessionStore);
        await _openMediaLibrariesTab(tester);
        await tester.tap(find.byKey(const Key('media-library-delete-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消').last);
        await tester.pumpAndSettle();

        expect(bundle.adapter.hitCount('DELETE', '/media-libraries/1'), 0);
        expect(find.byKey(const Key('media-library-card-1')), findsOneWidget);
        expect(find.text('Main Library'), findsOneWidget);
      },
    );

    testWidgets('shows backend error when deleting a media library fails', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueResponder(
        method: 'DELETE',
        path: '/media-libraries/1',
        responder: (options, requestBody) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 'media_library_in_use',
                'message': '媒体库仍被业务数据引用，无法删除',
              },
            }),
            409,
            headers: const {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openMediaLibrariesTab(tester);
      await tester.tap(find.byKey(const Key('media-library-delete-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('DELETE', '/media-libraries/1'), 1);
      expect(find.byKey(const Key('media-library-card-1')), findsOneWidget);
      expect(find.text('媒体库仍被业务数据引用，无法删除'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('renders account security form in account tab', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueAccount(bundle, username: 'account');

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );

      expect(find.text('账号安全'), findsWidgets);
      expect(find.text('账号资料'), findsOneWidget);
      expect(find.text('修改密码'), findsWidgets);
      expect(
        find.byKey(const Key('configuration-username-field')),
        findsOneWidget,
      );
      expect(find.text('account'), findsWidgets);
      expect(
        find.byKey(const Key('configuration-password-current-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('configuration-password-new-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('configuration-password-confirm-field')),
        findsOneWidget,
      );
    });

    testWidgets('validates required password fields before submit', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueAccount(bundle, username: 'account');

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('请输入当前密码'), findsOneWidget);
      expect(find.text('请输入新密码'), findsOneWidget);
      expect(find.text('请再次输入新密码'), findsOneWidget);
      expect(bundle.adapter.hitCount('POST', '/account/password'), 0);
    });

    testWidgets('prevents reusing current password as new password', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueAccount(bundle, username: 'account');

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'same-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'same-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'same-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('新密码不能与当前密码相同'), findsOneWidget);
      expect(bundle.adapter.hitCount('POST', '/account/password'), 0);
    });

    testWidgets('prevents submit when password confirmation mismatches', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueAccount(bundle, username: 'account');

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'old-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'other-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('两次输入的新密码不一致'), findsOneWidget);
      expect(bundle.adapter.hitCount('POST', '/account/password'), 0);
    });

    testWidgets('updates username without clearing session', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueAccount(bundle, username: 'account');
      _enqueueAccount(bundle, method: 'PATCH', username: 'renamed-account');

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-username-field')),
        '  renamed-account  ',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('configuration-username-submit-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        bundle.adapter.requests
            .firstWhere(
              (request) =>
                  request.method == 'PATCH' && request.path == '/account',
            )
            .body,
        <String, dynamic>{'username': 'renamed-account'},
      );
      expect(sessionStore.hasSession, isTrue);
      expect(find.text('用户名已更新'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows username conflict in account profile card', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueAccount(bundle, username: 'account');
      bundle.adapter.enqueueResponder(
        method: 'PATCH',
        path: '/account',
        responder: (options, requestBody) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 'username_conflict',
                'message': 'Username already exists',
                'details': null,
              },
            }),
            409,
            headers: const {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-username-field')),
        'taken',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('configuration-username-submit-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('用户名已存在，请换一个名称'), findsWidgets);
      expect(sessionStore.hasSession, isTrue);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('submits password change request and clears fields on reset', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueAccount(bundle, username: 'account');
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/account/password',
        statusCode: 204,
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/auth/tokens',
        body: {
          'access_token': 'verified-access-token',
          'refresh_token': 'verified-refresh-token',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'expires_at': '2026-03-10T13:00:00Z',
          'refresh_expires_at': '2026-03-17T13:00:00Z',
          'user': {'username': 'account'},
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'old-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'new-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final postRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'POST' && request.path == '/account/password',
      );
      expect(postRequest.body, <String, dynamic>{
        'current_password': 'old-password',
        'new_password': 'new-password',
      });
      final verifyRequest = bundle.adapter.requests.firstWhere(
        (request) => request.method == 'POST' && request.path == '/auth/tokens',
      );
      expect(verifyRequest.body, <String, dynamic>{
        'username': 'account',
        'password': 'new-password',
      });
      expect(sessionStore.hasSession, isFalse);

      await sessionStore.saveTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'stale-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'reset-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'reset-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-reset-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-reset-button')),
      );
      await tester.pump();

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('configuration-password-current-field')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('configuration-password-new-field')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('configuration-password-confirm-field')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows backend error when password change fails', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueAccount(bundle, username: 'account');
      await sessionStore.saveTokens(
        accessToken: 'access-token',
        refreshToken: '',
        expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
      );
      bundle.adapter.enqueueResponder(
        method: 'POST',
        path: '/account/password',
        responder: (options, requestBody) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 'invalid_credentials',
                'message': 'Current password is incorrect',
                'details': null,
              },
            }),
            401,
            headers: const {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'wrong-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'new-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Current password is incorrect'), findsOneWidget);
      expect(find.byKey(const Key('configuration-page')), findsOneWidget);
      expect(sessionStore.accessToken, 'access-token');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('keeps session when new password verification fails', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueAccount(bundle, username: 'account');
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/account/password',
        statusCode: 204,
      );
      bundle.adapter.enqueueResponder(
        method: 'POST',
        path: '/auth/tokens',
        responder: (options, requestBody) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {'code': 'invalid_credentials', 'message': '用户名或密码错误'},
            }),
            401,
            headers: const {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'old-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'new-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('密码已修改，但新密码登录校验失败，请重新登录确认'), findsOneWidget);
      expect(sessionStore.hasSession, isTrue);
      expect(find.byKey(const Key('configuration-page')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows backend error when deleting a client fails', (
      WidgetTester tester,
    ) async {
      _enqueueDownloadClientsList(
        bundle,
        clients: [
          const {
            'id': 1,
            'name': 'client-a',
            'provider_config': {'endpoint': 'http://localhost:8080'},
            'library_id': 1,
            'created_at': '2026-03-10T08:00:00Z',
            'updated_at': '2026-03-10T08:00:00Z',
          },
        ],
      );
      _enqueueMediaLibraries(bundle);
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueResponder(
        method: 'DELETE',
        path: '/download-clients/1',
        responder: (options, requestBody) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 'download_client_in_use',
                'message': '下载器仍被任务引用',
              },
            }),
            409,
            headers: const {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-downloads')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download-client-delete-1')));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(find.text('下载器仍被任务引用'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'loads indexer settings and download clients when switching tabs',
      (WidgetTester tester) async {
        _enqueueMediaLibraries(bundle);
        _enqueueIndexerSettings(bundle, indexers: const []);
        _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);

        await _pumpPage(tester, bundle, sessionStore: sessionStore);

        expect(bundle.adapter.hitCount('GET', '/indexer-settings'), 0);
        expect(bundle.adapter.hitCount('GET', '/download-clients'), 0);

        await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
        await tester.pumpAndSettle();

        expect(bundle.adapter.hitCount('GET', '/indexer-settings'), 1);
        expect(bundle.adapter.hitCount('GET', '/download-clients'), 1);
      },
    );

    testWidgets('refreshes indexer settings without a save confirmation', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(bundle, indexers: const []);
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);
      _enqueueIndexerSettings(bundle, indexers: const []);
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        useDesktopShell: true,
      );
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();

      final refreshButton = find.byKey(const Key('topbar-refresh-button'));
      await tester.tap(refreshButton);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('configuration-indexers-refresh-confirm-dialog')),
        findsNothing,
      );
      expect(bundle.adapter.hitCount('GET', '/indexer-settings'), 2);
      expect(bundle.adapter.hitCount('GET', '/download-clients'), 2);
    });

    testWidgets(
      'updates indexer download clients when the shared list changes',
      (WidgetTester tester) async {
        _enqueueMediaLibraries(bundle);
        _enqueueIndexerSettings(bundle, indexers: const []);
        _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);

        await _pumpPage(tester, bundle, sessionStore: sessionStore);
        await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const Key('configuration-page'))),
          listen: false,
        );
        container
            .read(downloadClientsProvider.notifier)
            .upsert(
              const DownloadClientDto(
                id: 3,
                name: 'client-c',
                libraryId: 1,
                providerConfig: {'endpoint': 'http://localhost:8082'},
                createdAt: null,
                updatedAt: null,
              ),
            );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('configuration-indexer-create-button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('indexer-download-client-3')),
          findsOneWidget,
        );
      },
    );

    testWidgets('tests saved Torznab settings and shows the result', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(bundle, indexers: const []);
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/indexer-settings/test',
        body: <String, dynamic>{
          'healthy': true,
          'checked_at': '2026-07-11T08:00:00Z',
          'query': 'SSNI-888',
          'indexers_checked': 2,
          'result_count': 5,
          'elapsed_ms': 342,
          'error': null,
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-indexer-connection-test-button')),
      );
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/indexer-settings/test'), 1);
      expect(
        find.byKey(const Key('configuration-indexer-connection-test-result')),
        findsOneWidget,
      );
      expect(find.text('Torznab 已连通，真实搜索已完成。'), findsOneWidget);
      expect(find.text('索引器：2 个'), findsOneWidget);
      expect(find.text('候选：5 条'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('disables creating indexer when no download clients exist', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(bundle, indexers: const []);
      _enqueueDownloadClientsList(bundle, clients: const []);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();

      final createButton = tester.widget<AppButton>(
        find.byKey(const Key('configuration-indexer-create-button')),
      );
      expect(createButton.onPressed, isNull);
      expect(find.text('请先在下载器 Tab 创建下载器'), findsOneWidget);
    });

    testWidgets('requires selecting a download client when creating indexer', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(bundle, indexers: const []);
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-indexer-create-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('indexer-entry-name-field')),
        'mteam',
      );
      await tester.enterText(
        find.byKey(const Key('indexer-entry-url-field')),
        'https://mirror.example.com/torznab',
      );
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      expect(find.text('请至少选择一个下载器'), findsWidgets);
    });

    testWidgets(
      'creates an indexer immediately with its download client binding',
      (WidgetTester tester) async {
        _enqueueMediaLibraries(bundle);
        _enqueueIndexerSettings(bundle, indexers: const []);
        _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);
        bundle.adapter.enqueueJson(
          method: 'PATCH',
          path: '/indexer-settings',
          body: {
            'indexers': [
              {
                'id': 1,
                'name': 'mteam',
                'url': 'https://mirror.example.com/torznab',
                'kind': 'pt',
                'api_key': 'secret-key',
                'download_clients': [
                  {'id': 1, 'name': 'client-a'},
                ],
              },
            ],
          },
        );

        await _pumpPage(tester, bundle, sessionStore: sessionStore);
        await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('configuration-indexer-save-button')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const Key('configuration-indexer-create-button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('indexer-entry-name-field')),
          'mteam',
        );
        await tester.enterText(
          find.byKey(const Key('indexer-entry-url-field')),
          'https://mirror.example.com/torznab',
        );
        await tester.enterText(
          find.byKey(const Key('indexer-entry-api-key-field')),
          'secret-key',
        );
        await tester.tap(
          find.byKey(const Key('indexer-download-client-add-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存').last);
        await tester.pumpAndSettle();

        final patchRequest = bundle.adapter.requests.firstWhere(
          (request) =>
              request.method == 'PATCH' && request.path == '/indexer-settings',
        );
        expect(patchRequest.body['indexers'][0]['download_client_ids'], <int>[
          1,
        ]);
        expect(patchRequest.body['indexers'][0]['api_key'], 'secret-key');
        expect(find.textContaining('下载器: client-a'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets('saves reordered download client priorities for an indexer', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(
        bundle,
        indexers: const [
          {
            'id': 1,
            'name': 'mteam',
            'url': 'https://mirror.example.com/torznab',
            'kind': 'pt',
            'download_clients': [
              {'id': 1, 'name': 'client-a'},
              {'id': 2, 'name': 'client-b'},
            ],
          },
        ],
      );
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/indexer-settings',
        body: {
          'indexers': [
            {
              'id': 1,
              'name': 'mteam',
              'url': 'https://mirror.example.com/torznab',
              'kind': 'pt',
              'api_key': 'secret-key',
              'download_clients': [
                {'id': 2, 'name': 'client-b'},
                {'id': 1, 'name': 'client-a'},
              ],
            },
          ],
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('indexer-entry-edit-0')));
      await tester.pumpAndSettle();

      expect(find.text('下载器优先级'), findsOneWidget);
      expect(find.text('默认下载器'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const Key('indexer-download-client-move-up-2')),
      );
      await tester.tap(
        find.byKey(const Key('indexer-download-client-move-up-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final patchRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' && request.path == '/indexer-settings',
      );
      expect(patchRequest.body['indexers'][0]['download_client_ids'], <int>[
        2,
        1,
      ]);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('deletes an indexer immediately', (WidgetTester tester) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(
        bundle,
        indexers: const [
          {
            'id': 1,
            'name': 'mteam',
            'url': 'https://mirror.example.com/torznab',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'client-a',
          },
        ],
      );
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/indexer-settings',
        body: const {'indexers': []},
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('indexer-entry-delete-0')));
      await tester.pumpAndSettle();

      final patchRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' && request.path == '/indexer-settings',
      );
      expect(patchRequest.body['indexers'], isEmpty);
      expect(find.text('还没有配置索引站'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('searches indexers by bound download client name', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(
        bundle,
        indexers: const [
          {
            'id': 1,
            'name': 'mteam',
            'url': 'https://mirror.example.com/torznab',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'client-a',
          },
          {
            'id': 2,
            'name': 'dmhy',
            'url': 'https://public.example.com/torznab',
            'kind': 'bt',
            'download_client_id': 2,
            'download_client_name': 'client-b',
          },
        ],
      );
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'client-b');
      await tester.pumpAndSettle();

      expect(find.text('dmhy'), findsOneWidget);
      expect(find.text('mteam'), findsNothing);
    });

    testWidgets('edits indexer with prefilled download client binding', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(
        bundle,
        indexers: const [
          {
            'id': 1,
            'name': 'mteam',
            'url': 'https://mirror.example.com/torznab',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'client-a',
          },
        ],
      );
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/indexer-settings',
        body: {
          'indexers': [
            {
              'id': 1,
              'name': 'mteam',
              'url': 'https://mirror.example.com/torznab',
              'kind': 'pt',
              'api_key': 'secret-key',
              'download_clients': [
                {'id': 2, 'name': 'client-b'},
              ],
            },
          ],
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('indexer-entry-edit-0')));
      await tester.pumpAndSettle();

      expect(find.text('client-a'), findsWidgets);
      await tester.tap(
        find.byKey(const Key('indexer-download-client-remove-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('indexer-download-client-add-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final patchRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' && request.path == '/indexer-settings',
      );
      expect(patchRequest.body['indexers'][0]['download_client_ids'], <int>[2]);
      expect(patchRequest.body['indexers'][0]['api_key'], 'secret-key');
      expect(find.textContaining('下载器: client-b'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('prevents duplicate indexer names before saving', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(
        bundle,
        indexers: const [
          {
            'id': 1,
            'name': 'mteam',
            'url': 'https://example.com/torznab',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'client-a',
          },
        ],
      );
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('configuration-indexer-create-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-indexer-create-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('indexer-entry-name-field')),
        'mteam',
      );
      await tester.enterText(
        find.byKey(const Key('indexer-entry-url-field')),
        'https://mirror.example.com/torznab',
      );
      await tester.tap(find.byKey(const Key('indexer-download-client-add-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('PATCH', '/indexer-settings'), 0);
      expect(find.text('索引器名称重复: mteam'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  testWidgets('successful password change returns to login through router', (
    WidgetTester tester,
  ) async {
    final sessionStore = await buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);
    _enqueueMediaLibraries(bundle);
    _enqueueAccount(bundle, username: 'account');
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/account/password',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/auth/tokens',
      body: {
        'access_token': 'verified-access-token',
        'refresh_token': 'verified-refresh-token',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'expires_at': '2026-03-10T13:00:00Z',
        'refresh_expires_at': '2026-03-17T13:00:00Z',
        'user': {'username': 'account'},
      },
    );

    final router = buildDesktopRouter(sessionStore: sessionStore);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...bundle.riverpodOverrides(),
          mediaProviderCatalogProvider.overrideWith(
            _TestMediaProviderCatalog.new,
          ),
        ],
        child: OKToast(
          child: MaterialApp.router(
            theme: sakuraThemeData,
            routerConfig: router,
          ),
        ),
      ),
    );
    addTearDown(tester.view.reset);

    router.go(desktopConfigurationPath);
    await tester.pumpAndSettle();
    await _openConfigurationTab(
      tester,
      const Key('configuration-tab-account-security'),
    );

    await tester.enterText(
      find.byKey(const Key('configuration-password-current-field')),
      'old-password',
    );
    await tester.enterText(
      find.byKey(const Key('configuration-password-new-field')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('configuration-password-confirm-field')),
      'new-password',
    );
    await tester.ensureVisible(
      find.byKey(const Key('configuration-password-submit-button')),
    );
    await tester.tap(
      find.byKey(const Key('configuration-password-submit-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(sessionStore.hasSession, isFalse);
    expect(find.byKey(const Key('login-form-base-url')), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, loginPath);
    await tester.pump(const Duration(seconds: 3));
  });
}

const _testProvider = MediaProviderDto(
  providerKey: 'demo',
  displayName: 'Provider A',
  libraryConfigFields: <ProviderConfigFieldDto>[],
  downloadConfigFields: <ProviderConfigFieldDto>[],
);

class _TestMediaProviderCatalog extends MediaProviderCatalog {
  @override
  Future<List<MediaProviderDto>> build() async => const <MediaProviderDto>[
    _testProvider,
  ];
}

class _ReloadingMediaProviderCatalog extends MediaProviderCatalog {
  @override
  Future<List<MediaProviderDto>> build() async => const <MediaProviderDto>[];

  @override
  Future<void> reload() async {
    state = const AsyncData<List<MediaProviderDto>>(<MediaProviderDto>[
      _testProvider,
    ]);
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  TestApiBundle bundle, {
  required SessionStore sessionStore,
  bool useReloadingMediaProviderCatalog = false,
  bool useDesktopShell = false,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;

  final page = const DesktopConfigurationPage();
  final Widget home = useDesktopShell
      ? AppDesktopShell(
          currentPath: desktopConfigurationPath,
          layout: AppShellLayout.standard,
          topBarConfig: const DesktopTopBarConfig(
            title: '系统设置',
            fallbackPath: null,
            isBackEnabled: false,
          ),
          shellNavigatorKey: GlobalKey<NavigatorState>(),
          navGroups: const [],
          child: page,
        )
      : Scaffold(body: page);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...bundle.riverpodOverrides(),
        if (useReloadingMediaProviderCatalog)
          mediaProviderCatalogProvider.overrideWith(
            _ReloadingMediaProviderCatalog.new,
          )
        else
          mediaProviderCatalogProvider.overrideWith(
            _TestMediaProviderCatalog.new,
          ),
      ],
      child: OKToast(
        child: MaterialApp(theme: sakuraThemeData, home: home),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(tester.view.reset);
}

Future<void> _openConfigurationTab(WidgetTester tester, Key tabKey) async {
  await tester.tap(find.byKey(tabKey));
  await tester.pumpAndSettle();
}

Future<void> _openMediaLibrariesTab(WidgetTester tester) async {
  await _openConfigurationTab(
    tester,
    const Key('configuration-tab-media-libraries'),
  );
}

void _enqueueDownloadClientsList(
  TestApiBundle bundle, {
  required List<Map<String, Object?>> clients,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: clients,
  );
}

void _enqueueAccount(
  TestApiBundle bundle, {
  String method = 'GET',
  required String username,
}) {
  bundle.adapter.enqueueJson(
    method: method,
    path: '/account',
    body: {
      'username': username,
      'created_at': '2026-03-08T09:00:00Z',
      'last_login_at': '2026-03-08T10:00:00Z',
    },
  );
}

const List<Map<String, Object?>> _defaultDownloadClients = [
  {
    'id': 1,
    'name': 'client-a',
    'provider_config': {'endpoint': 'http://localhost:8080'},
    'library_id': 1,
    'created_at': '2026-03-10T08:00:00Z',
    'updated_at': '2026-03-10T08:00:00Z',
  },
  {
    'id': 2,
    'name': 'client-b',
    'provider_config': {'endpoint': 'http://localhost:8081'},
    'library_id': 1,
    'created_at': '2026-03-10T09:00:00Z',
    'updated_at': '2026-03-10T09:00:00Z',
  },
];

void _enqueueIndexerSettings(
  TestApiBundle bundle, {
  List<Map<String, Object?>> indexers = const [],
}) {
  Map<String, Object?> withApiKey(Map<String, Object?> entry) {
    return <String, Object?>{
      ...entry,
      'api_key': entry.containsKey('api_key') ? entry['api_key'] : 'secret-key',
    };
  }

  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/indexer-settings',
    body: {
      'indexers': indexers
          .map((entry) {
            if (entry.containsKey('download_clients')) return withApiKey(entry);
            return <String, Object?>{
              ...withApiKey(entry),
              'download_clients': <Map<String, Object?>>[
                <String, Object?>{
                  'id': entry['download_client_id'],
                  'name': entry['download_client_name'],
                },
              ],
            };
          })
          .toList(growable: false),
    },
  );
}

void _enqueuePlaylists(
  TestApiBundle bundle, {
  required List<Map<String, Object?>> playlists,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/playlists',
    body: playlists,
  );
  // 桌面 playlists section 用 PlaylistsOverviewController 时会为每个
  // movieCount>0 的 playlist 拉取首张影片作封面预览。
  for (final playlist in playlists) {
    final id = playlist['id'];
    final movieCount = playlist['movie_count'];
    if (id is int && movieCount is int && movieCount > 0) {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/$id/movies',
        body: <String, dynamic>{
          'items': const <Map<String, dynamic>>[],
          'page': 1,
          'page_size': 1,
          'total': 0,
        },
      );
    }
  }
}

void _enqueueAdvancedConfig(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/config',
    body: _buildAdvancedConfigResponseJson(),
  );
}

void _enqueueMediaLibraries(
  TestApiBundle bundle, {
  List<Map<String, Object?>> libraries = const [
    {
      'id': 1,
      'name': 'Main Library',
      'provider_key': 'demo',
      'provider_config': {'root': '/media/library/main'},
      'created_at': '2026-03-08T09:30:00Z',
      'updated_at': '2026-03-08T09:30:00Z',
    },
  ],
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: libraries,
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries/providers',
    body: const <Map<String, dynamic>>[
      <String, dynamic>{
        'provider_key': 'demo',
        'display_name': 'Provider A',
        'library_config_fields': <Map<String, dynamic>>[],
        'download_config_fields': <Map<String, dynamic>>[],
      },
    ],
  );
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/media-libraries/providers',
    body: const <Map<String, dynamic>>[
      <String, dynamic>{
        'provider_key': 'demo',
        'display_name': 'Provider A',
        'library_config_fields': <Map<String, dynamic>>[],
        'download_config_fields': <Map<String, dynamic>>[],
      },
    ],
  );
}

Map<String, dynamic> _buildAdvancedConfigResponseJson() {
  return <String, dynamic>{
    'values': <String, dynamic>{
      'media': <String, dynamic>{'allowed_min_video_file_size': 268435456},
      'metadata': <String, dynamic>{'javdb_host': 'jdforrepam.com'},
      'scheduler': <String, dynamic>{
        for (final key in AdvancedSchedulerConfigDto.cronKeys)
          '${key}_cron': '0 2 * * *',
      },
      'downloads': <String, dynamic>{
        'subscription_search_fresh_days': 7,
        'subscription_search_stale_attempt_limit': 3,
      },
      'logging': <String, dynamic>{'level': 'INFO'},
    },
    'restart_required': const <String>[],
  };
}

void _enqueueOverviewResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status',
    body: <String, dynamic>{
      'actors': <String, dynamic>{'female_total': 12, 'female_subscribed': 8},
      'movies': <String, dynamic>{
        'total': 120,
        'subscribed': 35,
        'playable': 88,
      },
      'media_files': <String, dynamic>{
        'total': 156,
        'total_size_bytes': 987654321,
      },
      'media_libraries': <String, dynamic>{'total': 3},
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    body: <String, dynamic>{
      'healthy': true,
      'embedding_service': <String, dynamic>{
        'healthy': true,
        'space_id': 'clip-vit-l-14',
        'dimension': 768,
        'modalities': <String>['image', 'text'],
      },
      'indexing': <String, dynamic>{
        'pending_thumbnails': 23,
        'failed_thumbnails': 2,
      },
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/latest',
    body: <String, dynamic>{
      'items': List<Map<String, dynamic>>.generate(
        8,
        (index) => <String, dynamic>{
          'javdb_id': 'MovieA${index + 1}',
          'movie_number': 'ABC-${(index + 1).toString().padLeft(3, '0')}',
          'title': 'Movie ${index + 1}',
          'cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'is_subscribed': index.isEven,
          'can_play': true,
        },
      ),
      'page': 1,
      'page_size': 8,
      'total': 8,
    },
  );
}
