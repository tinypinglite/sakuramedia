import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_page.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_detail_page.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('movie detail page avoids page-level card decoration', () {
    final source =
        File(
          'lib/features/movies/presentation/desktop_movie_detail_page.dart',
        ).readAsStringSync();

    expect(source, isNot(contains('boxShadow: context.appShadows.card')));
    expect(
      source,
      isNot(
        contains('border: Border.all(color: context.appColors.borderSubtle)'),
      ),
    );
  });

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

  testWidgets(
    'movie detail page shows loading skeleton before request completes',
    (WidgetTester tester) async {
      final completer = Completer<void>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/movies/ABC-001',
        responder: (options, requestBody) async {
          await completer.future;
          return ResponseBody.fromString(
            jsonEncode(_movieDetailJson()),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pump();

      expect(
        find.byKey(const Key('movie-detail-loading-skeleton')),
        findsOneWidget,
      );

      if (!completer.isCompleted) {
        completer.complete();
      }
      await tester.pumpAndSettle();
    },
  );

  testWidgets('movie detail page renders sections and fixed info bar', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('ABC-001'), findsWidgets);
    expect(find.text('26/03/08'), findsOneWidget);
    expect(find.text('120 分钟'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('系列'), findsOneWidget);
    expect(find.text('Attackers'), findsOneWidget);
    expect(find.text('演员'), findsOneWidget);
    expect(find.text('媒体源'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-detail-fixed-info-bar')),
      findsOneWidget,
    );
  });

  testWidgets(
    'movie detail page shows playlist picker trigger near movie number',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
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
          <String, dynamic>{
            'id': 2,
            'name': '我的收藏',
            'kind': 'custom',
            'description': 'Favorite',
            'is_system': false,
            'is_mutable': true,
            'is_deletable': true,
            'movie_count': 0,
            'created_at': '2026-03-12T10:10:00Z',
            'updated_at': '2026-03-12T10:10:00Z',
          },
        ],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-playlist-trigger')),
        findsOneWidget,
      );
      final playlistIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('movie-detail-playlist-trigger')),
          matching: find.byIcon(Icons.playlist_add_rounded),
        ),
      );
      expect(playlistIcon.size, AppComponentTokens.defaults().iconSizeLg);

      await tester.tap(find.byKey(const Key('movie-detail-playlist-trigger')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-playlist-picker-dialog')),
        findsOneWidget,
      );
      expect(find.text('我的收藏'), findsOneWidget);
      expect(find.text('最近播放'), findsNothing);
    },
  );

  testWidgets('movie detail playlist picker toggles membership immediately', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(
        playlists: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 2,
            'name': '我的收藏',
            'kind': 'custom',
            'is_system': false,
          },
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 2,
          'name': '我的收藏',
          'kind': 'custom',
          'description': 'Favorite',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 1,
          'created_at': '2026-03-12T10:10:00Z',
          'updated_at': '2026-03-12T10:10:00Z',
        },
        <String, dynamic>{
          'id': 3,
          'name': '稍后再看',
          'kind': 'custom',
          'description': 'Later',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 0,
          'created_at': '2026-03-12T10:10:00Z',
          'updated_at': '2026-03-12T10:10:00Z',
        },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/playlists/2/movies/ABC-001',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/playlists/3/movies/ABC-001',
      statusCode: 204,
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-detail-playlist-trigger')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Checkbox>(find.byKey(const Key('movie-playlist-checkbox-2')))
          .value,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('movie-playlist-option-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-playlist-option-3')));
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('DELETE', '/playlists/2/movies/ABC-001'), 1);
    expect(bundle.adapter.hitCount('PUT', '/playlists/3/movies/ABC-001'), 1);
  });

  testWidgets('movie detail playlist picker toggles when tapping checkbox', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(playlists: const <Map<String, dynamic>>[]),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 3,
          'name': '稍后再看',
          'kind': 'custom',
          'description': 'Later',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 0,
          'created_at': '2026-03-12T10:10:00Z',
          'updated_at': '2026-03-12T10:10:00Z',
        },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/playlists/3/movies/ABC-001',
      statusCode: 204,
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-detail-playlist-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-playlist-checkbox-3')));
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('PUT', '/playlists/3/movies/ABC-001'), 1);
  });

  testWidgets('movie detail playlist picker creates playlist and adds movie', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(playlists: const <Map<String, dynamic>>[]),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[],
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/playlists',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 4,
        'name': '新列表',
        'kind': 'custom',
        'description': 'New list',
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'movie_count': 0,
        'created_at': '2026-03-12T10:10:00Z',
        'updated_at': '2026-03-12T10:10:00Z',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/playlists/4/movies/ABC-001',
      statusCode: 204,
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-detail-playlist-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-playlist-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create-playlist-name-field')),
      '新列表',
    );
    await tester.enterText(
      find.byKey(const Key('create-playlist-description-field')),
      'New list',
    );
    await tester.tap(find.byKey(const Key('create-playlist-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('新列表'), findsOneWidget);
    expect(bundle.adapter.hitCount('POST', '/playlists'), 1);
    expect(bundle.adapter.hitCount('PUT', '/playlists/4/movies/ABC-001'), 1);
  });

  testWidgets(
    'movie detail page keeps fixed info bar position while scrolling',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      final infoBarFinder = find.byKey(
        const Key('movie-detail-fixed-info-bar'),
      );
      final beforeScroll = tester.getTopLeft(infoBarFinder).dy;

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      final afterScroll = tester.getTopLeft(infoBarFinder).dy;

      expect(afterScroll, closeTo(beforeScroll, 1));
    },
  );

  testWidgets('movie detail page opens inspector dialog from fixed info bar', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/100/thumbnails',
      body: _mediaThumbnailsJson(),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-detail-inspector-dialog')),
      findsOneWidget,
    );
    expect(find.text('磁力搜索'), findsOneWidget);
    expect(find.text('缩略图'), findsWidgets);
    expect(find.byTooltip('关闭'), findsOneWidget);
  });

  testWidgets(
    'movie detail page inspector thumbnail tab uses auto columns and exposes 5-column toggle',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();

      final gridView = tester.widget<GridView>(
        find.byKey(const Key('movie-media-thumbnail-grid')),
      );
      final delegate =
          gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(delegate.crossAxisCount, 5);
      expect(
        find.byKey(const Key('movie-detail-thumbnail-columns-5')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'movie detail page inspector magnet tab stays idle until search button is tapped',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/media/100/thumbnails'), 0);

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/media/100/thumbnails'), 1);

      await tester.tap(find.text('磁力搜索'));
      await tester.pumpAndSettle();

      expect(find.text('搜索依赖配置管理中的下载器与索引器。'), findsOneWidget);
      expect(bundle.adapter.hitCount('GET', '/download-candidates'), 0);
      expect(bundle.adapter.hitCount('GET', '/media/100/thumbnails'), 1);
    },
  );

  testWidgets('movie detail page inspector magnet tab searches on demand', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/100/thumbnails',
      body: _mediaThumbnailsJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-candidates',
      body: _downloadCandidatesJson(),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('磁力搜索'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-detail-magnet-search-button')),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('GET', '/download-candidates'), 1);
    expect(find.text('ABC-001 4K 中文字幕'), findsOneWidget);
    expect(find.text('下载器: qb-main'), findsWidgets);
    expect(find.text('做种: 18'), findsOneWidget);
    expect(find.text('体积: 12.0 GB'), findsOneWidget);
  });

  testWidgets(
    'movie detail page inspector magnet tab reapplies filter only after manual search',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-candidates',
        body: _downloadCandidatesJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-candidates',
        body: _downloadCandidatesJson(indexerKind: 'pt'),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('磁力搜索'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('movie-detail-magnet-search-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('ABC-001 4K 中文字幕'), findsOneWidget);

      await tester.tap(find.byKey(const Key('movie-detail-magnet-filter-pt')));
      await tester.pumpAndSettle();

      expect(find.text('搜索依赖配置管理中的下载器与索引器。'), findsOneWidget);
      expect(find.text('ABC-001 4K 中文字幕'), findsNothing);
      expect(bundle.adapter.hitCount('GET', '/download-candidates'), 1);

      await tester.tap(
        find.byKey(const Key('movie-detail-magnet-search-button')),
      );
      await tester.pumpAndSettle();

      final request = bundle.adapter.requests.last;
      expect(request.uri.queryParameters['indexer_kind'], 'pt');
      expect(bundle.adapter.hitCount('GET', '/download-candidates'), 2);
      expect(find.text('ABC-001 PT 1080P'), findsOneWidget);
    },
  );

  testWidgets('movie detail page inspector magnet tab shows empty state', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/100/thumbnails',
      body: _mediaThumbnailsJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-candidates',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('磁力搜索'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-detail-magnet-search-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('没有找到可用资源'), findsOneWidget);
  });

  testWidgets(
    'movie detail page inspector magnet tab retries failed search and can submit download',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-candidates',
        statusCode: 502,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'download_candidate_search_failed',
            'message': 'boom',
          },
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-candidates',
        body: _downloadCandidatesJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-requests',
        statusCode: 201,
        body: {
          'task': {
            'id': 100,
            'client_id': 2,
            'movie_number': 'ABC-001',
            'name': 'ABC-001 4K 中文字幕',
            'info_hash': '95a37f09c6d5aac200752f4c334dc9dff91e8cfc',
            'save_path': '/mnt/qb/downloads/a/ABC-001',
            'progress': 0.0,
            'download_state': 'queued',
            'import_status': 'pending',
            'created_at': '2026-03-10T08:10:00Z',
            'updated_at': '2026-03-10T08:10:00Z',
          },
          'created': true,
        },
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('磁力搜索'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('movie-detail-magnet-search-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('搜索资源失败，请稍后重试。'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('movie-detail-magnet-retry-button')),
      );
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/download-candidates'), 2);
      expect(find.text('ABC-001 4K 中文字幕'), findsOneWidget);

      await tester.tap(find.byKey(const Key('movie-detail-magnet-submit-0')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('POST', '/download-requests'), 1);
      expect(find.text('已提交到 qb-main'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'movie detail page inspector magnet tab shows duplicate toast on existing task',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-candidates',
        body: _downloadCandidatesJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-requests',
        body: {
          'task': {
            'id': 100,
            'client_id': 2,
            'movie_number': 'ABC-001',
            'name': 'ABC-001 4K 中文字幕',
            'info_hash': '95a37f09c6d5aac200752f4c334dc9dff91e8cfc',
            'save_path': '/mnt/qb/downloads/a/ABC-001',
            'progress': 0.0,
            'download_state': 'queued',
            'import_status': 'pending',
            'created_at': '2026-03-10T08:10:00Z',
            'updated_at': '2026-03-10T08:10:00Z',
          },
          'created': false,
        },
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('磁力搜索'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('movie-detail-magnet-search-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('movie-detail-magnet-submit-0')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('下载任务已存在'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'movie detail page inspector magnet tab shows configuration guidance',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('磁力搜索'));
      await tester.pumpAndSettle();

      expect(find.text('搜索依赖配置管理中的下载器与索引器。'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-detail-magnet-open-configuration')),
        findsNothing,
      );
      expect(find.byKey(const Key('movie-detail-inspector-dialog')), findsOneWidget);
    },
  );

  testWidgets(
    'movie detail page inspector thumbnail tab retries failed thumbnail load',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        statusCode: 500,
        body: <String, dynamic>{'detail': 'boom'},
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();

      expect(find.text('缩略图加载失败'), findsOneWidget);
      expect(bundle.adapter.hitCount('GET', '/media/100/thumbnails'), 1);

      await tester.tap(find.byKey(const Key('movie-media-thumbnail-retry')));
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/media/100/thumbnails'), 2);
      expect(
        find.byKey(const Key('movie-media-thumbnail-grid')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'movie detail page inspector thumbnail tile opens preview dialog',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-media-thumb-1')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-plot-preview-dialog')),
        findsOneWidget,
      );
      expect(find.text('2 / 2'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const Key('movie-plot-preview-thumb-1')))
            .width,
        sakuraThemeData
            .extension<AppComponentTokens>()!
            .movieDetailPlotPreviewThumbnailWidth,
      );

      final selectedThumbOpacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byKey(const Key('movie-plot-preview-thumb-1')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      final unselectedThumbOpacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byKey(const Key('movie-plot-preview-thumb-0')),
          matching: find.byType(AnimatedOpacity),
        ),
      );

      expect(selectedThumbOpacity.opacity, 1);
      expect(unselectedThumbOpacity.opacity, closeTo(0.58, 0.001));
    },
  );

  testWidgets(
    'movie detail page inspector thumbnail opens action menu on secondary tap',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/points',
        body: const <Map<String, dynamic>>[],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('movie-media-thumb-1'))),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('相似图片'), findsOneWidget);
      expect(find.text('保存到本地'), findsOneWidget);
      expect(find.text('添加标记'), findsOneWidget);
      expect(find.text('播放'), findsOneWidget);
    },
  );

  testWidgets(
    'movie detail page inspector thumbnail play action opens player route',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/points',
        body: const <Map<String, dynamic>>[],
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/desktop/library/movies/:movieNumber/player',
            builder:
                (context, state) => Text(
                  'player:${state.uri.toString()}',
                  textDirection: TextDirection.ltr,
                ),
          ),
          GoRoute(
            path: '/desktop/library/movies/:movieNumber',
            builder:
                (context, state) => DesktopMovieDetailPage(
                  movieNumber: state.pathParameters['movieNumber']!,
                ),
          ),
        ],
        initialLocation: '/desktop/library/movies/ABC-001',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
            Provider<ApiClient>.value(value: bundle.apiClient),
            Provider<MediaApi>.value(
              value: MediaApi(apiClient: bundle.apiClient),
            ),
            Provider<MoviesApi>.value(value: bundle.moviesApi),
            Provider<DownloadsApi>.value(value: bundle.downloadsApi),
          ],
          child: MaterialApp.router(
            theme: sakuraThemeData,
            routerConfig: router,
            builder: (context, child) => OKToast(child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('movie-media-thumb-1'))),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('播放'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-inspector-dialog')),
        findsNothing,
      );
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/desktop/library/movies/ABC-001/player?mediaId=100&positionSeconds=20',
      );
    },
  );

  testWidgets(
    'movie detail page inspector thumbnail similar-image action opens image search route',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/points',
        body: const <Map<String, dynamic>>[],
      );
      bundle.adapter.enqueueBytes(
        method: 'GET',
        path: '/files/thumbs/100/2.webp',
        body: Uint8List.fromList(const <int>[1, 2, 3]),
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: desktopImageSearchPath,
            builder:
                (context, state) => const Text(
                  'image-search',
                  textDirection: TextDirection.ltr,
                ),
          ),
          GoRoute(
            path: '/desktop/library/movies/:movieNumber',
            builder:
                (context, state) => DesktopMovieDetailPage(
                  movieNumber: state.pathParameters['movieNumber']!,
                ),
          ),
        ],
        initialLocation: '/desktop/library/movies/ABC-001',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
            Provider<ApiClient>.value(value: bundle.apiClient),
            Provider<MediaApi>.value(
              value: MediaApi(apiClient: bundle.apiClient),
            ),
            Provider<MoviesApi>.value(value: bundle.moviesApi),
            Provider<DownloadsApi>.value(value: bundle.downloadsApi),
          ],
          child: MaterialApp.router(
            theme: sakuraThemeData,
            routerConfig: router,
            builder: (context, child) => OKToast(child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('movie-media-thumb-1'))),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('相似图片'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-inspector-dialog')),
        findsNothing,
      );
      expect(
        router.routeInformationProvider.value.uri.toString(),
        desktopImageSearchPath,
      );
      expect(find.text('image-search'), findsOneWidget);
    },
  );

  testWidgets('movie detail page renders series with smaller text style', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final seriesText = tester.widget<Text>(find.text('Attackers'));
    final expectedStyle = sakuraThemeData.textTheme.bodySmall;

    expect(seriesText.style?.fontSize, expectedStyle?.fontSize);
    expect(seriesText.style?.height, expectedStyle?.height);
  });

  testWidgets('movie detail page stat icons show tooltip labels on hover', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(
      tester.getCenter(find.byIcon(Icons.calendar_today_outlined)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('发行日期'), findsOneWidget);
  });

  testWidgets(
    'movie detail page opens plot preview dialog when tapping plot image',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-main-image-cover')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('movie-plot-thumb-1')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-plot-preview-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-detail-main-image-cover')),
        findsOneWidget,
      );
      expect(find.text('2 / 2'), findsOneWidget);
    },
  );

  testWidgets(
    'movie detail page plot thumbnail opens action menu on secondary tap',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('movie-plot-thumb-1'))),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('相似图片'), findsOneWidget);
      expect(find.text('保存到本地'), findsOneWidget);
    },
  );

  testWidgets(
    'movie detail page plot preview thumbnail opens action menu on secondary tap',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-plot-thumb-0')));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('movie-plot-preview-thumb-1'))),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('相似图片'), findsOneWidget);
      expect(find.text('保存到本地'), findsOneWidget);
    },
  );

  testWidgets(
    'movie detail page plot similar-image action opens image search route',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueBytes(
        method: 'GET',
        path: '/files/images/movies/ABC-001/plots/1.jpg',
        body: Uint8List.fromList(const <int>[1, 2, 3]),
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: desktopImageSearchPath,
            builder:
                (context, state) => const Text(
                  'image-search',
                  textDirection: TextDirection.ltr,
                ),
          ),
          GoRoute(
            path: '/desktop/library/movies/:movieNumber',
            builder:
                (context, state) => DesktopMovieDetailPage(
                  movieNumber: state.pathParameters['movieNumber']!,
                ),
          ),
        ],
        initialLocation: '/desktop/library/movies/ABC-001',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
            Provider<ApiClient>.value(value: bundle.apiClient),
            Provider<MediaApi>.value(
              value: MediaApi(apiClient: bundle.apiClient),
            ),
            Provider<MoviesApi>.value(value: bundle.moviesApi),
            Provider<DownloadsApi>.value(value: bundle.downloadsApi),
          ],
          child: MaterialApp.router(
            theme: sakuraThemeData,
            routerConfig: router,
            builder: (context, child) => OKToast(child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('movie-plot-thumb-1'))),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('相似图片'));
      await tester.pumpAndSettle();

      expect(find.text('image-search'), findsOneWidget);
      expect(
        bundle.adapter.hitCount(
          'GET',
          '/files/images/movies/ABC-001/plots/1.jpg',
        ),
        1,
      );
    },
  );

  testWidgets(
    'movie detail page plot similar-image search exposes current movie scope filter',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueBytes(
        method: 'GET',
        path: '/files/images/movies/ABC-001/plots/1.jpg',
        body: Uint8List.fromList(const <int>[1, 2, 3]),
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          'session_id': 'session-1',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': null,
          'expires_at': '2026-03-08T10:10:00Z',
          'items': const <Map<String, dynamic>>[],
        },
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: desktopImageSearchPath,
            builder: (context, state) {
              final routeState = DesktopImageSearchRouteState.maybeFromExtra(
                state.extra,
              );
              return DesktopImageSearchPage(
                fallbackPath: routeState.fallbackPath,
                initialFileName: routeState.initialFileName,
                initialFileBytes: routeState.initialFileBytes,
                initialMimeType: routeState.initialMimeType,
                currentMovieNumber: routeState.currentMovieNumber,
                initialCurrentMovieScope: routeState.initialCurrentMovieScope,
              );
            },
          ),
          GoRoute(
            path: '/desktop/library/movies/:movieNumber',
            builder:
                (context, state) => DesktopMovieDetailPage(
                  movieNumber: state.pathParameters['movieNumber']!,
                ),
          ),
        ],
        initialLocation: '/desktop/library/movies/ABC-001',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
            Provider<ApiClient>.value(value: bundle.apiClient),
            Provider<ActorsApi>.value(value: bundle.actorsApi),
            Provider<ImageSearchApi>.value(
              value: ImageSearchApi(apiClient: bundle.apiClient),
            ),
            Provider<MediaApi>.value(
              value: MediaApi(apiClient: bundle.apiClient),
            ),
            Provider<MoviesApi>.value(value: bundle.moviesApi),
            Provider<DownloadsApi>.value(value: bundle.downloadsApi),
          ],
          child: MaterialApp.router(
            theme: sakuraThemeData,
            routerConfig: router,
            builder: (context, child) => OKToast(child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('movie-plot-thumb-1'))),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('相似图片'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('desktop-image-search-toggle-filter')),
      );
      await tester.pumpAndSettle();

      expect(find.text('当前影片范围'), findsOneWidget);
      expect(find.widgetWithText(AppButton, '全部'), findsOneWidget);
      expect(find.widgetWithText(AppButton, '仅当前影片'), findsOneWidget);
      expect(find.widgetWithText(AppButton, '排除当前影片'), findsOneWidget);
    },
  );

  testWidgets('movie detail page keeps thin cover hero when cover is absent', (
    WidgetTester tester,
  ) async {
    final detail = _movieDetailJson();
    detail['cover_image'] = null;

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: detail,
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-detail-main-image-thin-cover')),
      findsOneWidget,
    );
  });

  testWidgets(
    'movie detail page hides media section when there are no media items',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          tags: const <Map<String, dynamic>>[],
          actors: const <Map<String, dynamic>>[],
          plotImages: const <Map<String, dynamic>>[],
          mediaItems: const <Map<String, dynamic>>[],
        ),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('暂无剧情图'), findsOneWidget);
      expect(find.text('暂无标签'), findsOneWidget);
      expect(find.text('暂无演员信息'), findsOneWidget);
      expect(find.text('媒体源'), findsNothing);
      expect(find.text('暂无媒体源'), findsNothing);
    },
  );

  testWidgets('movie detail page taps hero play icon and opens player route', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/desktop/library/movies/:movieNumber/player',
          name: 'desktop-movie-player',
          builder:
              (context, state) => Scaffold(
                body: Column(
                  children: [
                    Text('player:${state.pathParameters['movieNumber']}'),
                    Text('media:${state.uri.queryParameters['mediaId']}'),
                  ],
                ),
              ),
        ),
        GoRoute(
          path: '/desktop/library/movies/:movieNumber',
          name: 'desktop-movie-detail',
          builder:
              (context, state) => DesktopMovieDetailPage(
                movieNumber: state.pathParameters['movieNumber']!,
              ),
        ),
      ],
      initialLocation: '/desktop/library/movies/ABC-001',
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-detail-hero-play-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('movie-detail-hero-play-button')));
    await tester.pumpAndSettle();

    expect(find.text('player:ABC-001'), findsOneWidget);
    expect(find.text('media:100'), findsOneWidget);
  });

  testWidgets(
    'movie detail page subscribes from hero subscription icon when unsubscribed',
    (WidgetTester tester) async {
      final detail = _movieDetailJson();
      detail['is_subscribed'] = false;

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: detail,
      );
      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/movies/ABC-001/subscription',
        statusCode: 204,
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('movie-detail-hero-subscription-icon')),
          matching: find.byIcon(Icons.favorite_border_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('movie-detail-hero-subscription-icon')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('PUT', '/movies/ABC-001/subscription'), 1);
      expect(
        find.descendant(
          of: find.byKey(const Key('movie-detail-hero-subscription-icon')),
          matching: find.byIcon(Icons.favorite_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text('已订阅影片'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'movie detail page hides hero play icon when media has no play url',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          mediaItems: <Map<String, dynamic>>[
            <String, dynamic>{
              'media_id': 100,
              'library_id': 1,
              'play_url': '',
              'path': '/library/main/ABC-001/video.mp4',
              'storage_mode': 'hardlink',
              'resolution': '1920x1080',
              'file_size_bytes': 1073741824,
              'duration_seconds': 7200,
              'special_tags': '普通',
              'valid': true,
              'progress': null,
              'points': const <Map<String, dynamic>>[],
            },
          ],
        ),
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/desktop/library/movies/:movieNumber',
            name: 'desktop-movie-detail',
            builder:
                (context, state) => DesktopMovieDetailPage(
                  movieNumber: state.pathParameters['movieNumber']!,
                ),
          ),
          GoRoute(
            path: '/desktop/library/movies/:movieNumber/player',
            name: 'desktop-movie-player',
            builder:
                (context, state) =>
                    Text('player:${state.pathParameters['movieNumber']}'),
          ),
        ],
        initialLocation: '/desktop/library/movies/ABC-001',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
            Provider<MoviesApi>.value(value: bundle.moviesApi),
          ],
          child: MaterialApp.router(
            theme: sakuraThemeData,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-hero-play-button')),
        findsNothing,
      );

      expect(find.text('player:ABC-001'), findsNothing);
    },
  );

  testWidgets('movie detail page opens actor detail from actor avatar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/desktop/library/movies/:movieNumber',
          name: 'desktop-movie-detail',
          builder:
              (context, state) => DesktopMovieDetailPage(
                movieNumber: state.pathParameters['movieNumber']!,
              ),
        ),
        GoRoute(
          path: '/desktop/library/actors/:actorId',
          name: 'desktop-actor-detail',
          builder:
              (context, state) => Scaffold(
                body: Column(
                  children: [
                    Text('actor:${state.pathParameters['actorId']}'),
                    Text('extra:${state.extra as String?}'),
                  ],
                ),
              ),
        ),
      ],
      initialLocation: '/desktop/library/movies/ABC-001',
    );

    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-actor-1')));
    await tester.pumpAndSettle();

    expect(find.text('actor:1'), findsOneWidget);
    expect(find.text('extra:/desktop/library/movies/ABC-001'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ApiClient>.value(value: bundle.apiClient),
        Provider<MediaApi>.value(value: MediaApi(apiClient: bundle.apiClient)),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
        Provider<DownloadsApi>.value(value: bundle.downloadsApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: const OKToast(
          child: Scaffold(body: DesktopMovieDetailPage(movieNumber: 'ABC-001')),
        ),
      ),
    ),
  );
}

List<Map<String, dynamic>> _downloadCandidatesJson({
  String indexerKind = 'bt',
}) {
  if (indexerKind == 'pt') {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'source': 'jackett',
        'indexer_name': 'mteam',
        'indexer_kind': 'pt',
        'resolved_client_id': 2,
        'resolved_client_name': 'qb-main',
        'movie_number': 'ABC-001',
        'title': 'ABC-001 PT 1080P',
        'size_bytes': 4294967296,
        'seeders': 8,
        'magnet_url': 'magnet:?xt=urn:btih:pt123',
        'torrent_url': '',
        'tags': <String>['PT', '1080P'],
      },
    ];
  }

  return <Map<String, dynamic>>[
    <String, dynamic>{
      'source': 'jackett',
      'indexer_name': 'mteam',
      'indexer_kind': 'bt',
      'resolved_client_id': 2,
      'resolved_client_name': 'qb-main',
      'movie_number': 'ABC-001',
      'title': 'ABC-001 4K 中文字幕',
      'size_bytes': 12884901888,
      'seeders': 18,
      'magnet_url': 'magnet:?xt=urn:btih:abcdef',
      'torrent_url': '',
      'tags': <String>['4K', '中字'],
    },
  ];
}

Map<String, dynamic> _movieDetailJson({
  List<Map<String, dynamic>>? tags,
  List<Map<String, dynamic>>? actors,
  List<Map<String, dynamic>>? plotImages,
  List<Map<String, dynamic>>? mediaItems,
  List<Map<String, dynamic>>? playlists,
}) {
  return <String, dynamic>{
    'javdb_id': 'MovieA1',
    'movie_number': 'ABC-001',
    'title': 'Movie 1',
    'cover_image': <String, dynamic>{
      'id': 10,
      'origin': '/files/images/movies/ABC-001/cover.jpg',
      'small': '/files/images/movies/ABC-001/cover-small.jpg',
      'medium': '/files/images/movies/ABC-001/cover-medium.jpg',
      'large': '/files/images/movies/ABC-001/cover-large.jpg',
    },
    'release_date': '2026-03-08',
    'duration_minutes': 120,
    'score': 4.5,
    'watched_count': 12,
    'want_watch_count': 23,
    'comment_count': 34,
    'score_number': 45,
    'is_collection': false,
    'is_subscribed': true,
    'can_play': true,
    'series_name': 'Attackers',
    'summary': '',
    'actors':
        actors ??
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'javdb_id': 'ActorA1',
            'name': '三上悠亚',
            'alias_name': '三上悠亚 / 鬼头桃菜',
            'is_subscribed': false,
            'profile_image': null,
          },
        ],
    'tags':
        tags ??
        <Map<String, dynamic>>[
          <String, dynamic>{'tag_id': 1, 'name': '剧情'},
          <String, dynamic>{'tag_id': 2, 'name': '偶像'},
        ],
    'thin_cover_image': <String, dynamic>{
      'id': 11,
      'origin': '/files/images/movies/ABC-001/thin.jpg',
      'small': '/files/images/movies/ABC-001/thin-small.jpg',
      'medium': '/files/images/movies/ABC-001/thin-medium.jpg',
      'large': '/files/images/movies/ABC-001/thin-large.jpg',
    },
    'plot_images':
        plotImages ??
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 12,
            'origin': '/files/images/movies/ABC-001/plots/0.jpg',
            'small': '/files/images/movies/ABC-001/plots/0-small.jpg',
            'medium': '/files/images/movies/ABC-001/plots/0-medium.jpg',
            'large': '/files/images/movies/ABC-001/plots/0-large.jpg',
          },
          <String, dynamic>{
            'id': 13,
            'origin': '/files/images/movies/ABC-001/plots/1.jpg',
            'small': '/files/images/movies/ABC-001/plots/1-small.jpg',
            'medium': '/files/images/movies/ABC-001/plots/1-medium.jpg',
            'large': '/files/images/movies/ABC-001/plots/1-large.jpg',
          },
        ],
    'media_items':
        mediaItems ??
        <Map<String, dynamic>>[
          <String, dynamic>{
            'media_id': 100,
            'library_id': 1,
            'play_url':
                '/files/media/movies/ABC-001/video.mp4?expires=1700000900&signature=abc',
            'path': '/library/main/ABC-001/video.mp4',
            'storage_mode': 'hardlink',
            'resolution': '1920x1080',
            'file_size_bytes': 1073741824,
            'duration_seconds': 7200,
            'special_tags': '普通',
            'valid': true,
            'progress': <String, dynamic>{
              'last_position_seconds': 600,
              'last_watched_at': '2026-03-08T09:30:00',
            },
            'points': const <Map<String, dynamic>>[],
          },
        ],
    'playlists': playlists ?? const <Map<String, dynamic>>[],
  };
}

List<Map<String, dynamic>> _mediaThumbnailsJson({int mediaId = 100}) {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'thumbnail_id': 1,
      'media_id': mediaId,
      'offset_seconds': 10,
      'image': <String, dynamic>{
        'id': 101,
        'origin': '/files/thumbs/$mediaId/1.webp',
        'small': '/files/thumbs/$mediaId/1-small.webp',
        'medium': '/files/thumbs/$mediaId/1-medium.webp',
        'large': '/files/thumbs/$mediaId/1-large.webp',
      },
    },
    <String, dynamic>{
      'thumbnail_id': 2,
      'media_id': mediaId,
      'offset_seconds': 20,
      'image': <String, dynamic>{
        'id': 102,
        'origin': '/files/thumbs/$mediaId/2.webp',
        'small': '/files/thumbs/$mediaId/2-small.webp',
        'medium': '/files/thumbs/$mediaId/2-medium.webp',
        'large': '/files/thumbs/$mediaId/2-large.webp',
      },
    },
  ];
}
