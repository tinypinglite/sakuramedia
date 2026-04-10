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
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_page.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_detail_page.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_actor_wrap.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_hero_card.dart';

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
      body: _movieDetailJson(heat: 31),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('ABC-001'), findsWidgets);
    expect(find.text('26/03/08'), findsOneWidget);
    expect(find.text('120 分钟'), findsOneWidget);
    expect(find.text('系列 · Attackers'), findsOneWidget);
    expect(find.text('厂商 · S1 NO.1 STYLE'), findsOneWidget);
    expect(find.text('导演 · 紋℃'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-detail-interaction-row')),
      findsOneWidget,
    );
    expect(find.text('想看人数 23'), findsOneWidget);
    expect(find.text('看过人数 12'), findsOneWidget);
    expect(find.text('评分人数 45'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-detail-hero-heat-text')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-detail-interaction-heat-text')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('movie-detail-hero-heat-text')))
          .data,
      '31',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('movie-detail-interaction-heat-text')),
          )
          .data,
      '31',
    );
    expect(find.byIcon(Icons.star_outline_rounded), findsWidgets);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsWidgets);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);
    expect(find.text('演员'), findsOneWidget);
    expect(find.text('媒体源'), findsOneWidget);
    expect(find.text('H.264 · 22.8 Mbps · 29.97 fps'), findsOneWidget);
    final seriesTop = tester.getTopLeft(find.text('系列 · Attackers')).dy;
    final tagTop = tester.getTopLeft(find.text('标签')).dy;
    expect(seriesTop, lessThan(tagTop));
    expect(
      find.byKey(const Key('movie-detail-fixed-info-bar')),
      findsOneWidget,
    );
  });

  testWidgets(
    'movie detail page shows selected media points and updates when switching media',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          mediaItems: <Map<String, dynamic>>[
            _mediaItemJson(
              mediaId: 100,
              specialTags: '普通',
              points: <Map<String, dynamic>>[
                _mediaPointJson(
                  pointId: 1,
                  thumbnailId: 66,
                  offsetSeconds: 120,
                ),
              ],
            ),
            _mediaItemJson(
              mediaId: 101,
              specialTags: '预告',
              points: <Map<String, dynamic>>[
                _mediaPointJson(
                  pointId: 2,
                  thumbnailId: 77,
                  offsetSeconds: 240,
                ),
              ],
            ),
          ],
        ),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-media-point-timecode-0')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('movie-media-point-timecode-0')))
            .data,
        '02:00',
      );

      await tester.tap(find.text('预告 500.0 MB'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('movie-media-point-timecode-0')))
            .data,
        '04:00',
      );
    },
  );

  testWidgets(
    'movie detail page opens point preview dialog without movie detail action',
    (WidgetTester tester) async {
      final pointJson = _mediaPointJson(
        pointId: 1,
        thumbnailId: 66,
        offsetSeconds: 120,
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          mediaItems: <Map<String, dynamic>>[
            _mediaItemJson(points: <Map<String, dynamic>>[pointJson]),
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/points',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
            'point_id': 1,
            'media_id': 100,
            'thumbnail_id': 66,
            'offset_seconds': 120,
            'image': pointJson['image'],
            'created_at': '2026-03-12T10:00:00Z',
          },
        ],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-media-point-thumb-0')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('image-search-result-preview-dialog')),
        findsOneWidget,
      );
      expect(find.text('影片详情'), findsNothing);
      expect(find.text('删除标记'), findsOneWidget);
    },
  );

  testWidgets('movie detail page point action menu appears on secondary tap', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(
        mediaItems: <Map<String, dynamic>>[
          _mediaItemJson(
            points: <Map<String, dynamic>>[
              _mediaPointJson(pointId: 1, thumbnailId: 66, offsetSeconds: 120),
            ],
          ),
        ],
      ),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('movie-media-point-thumb-0')),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('movie-media-point-thumb-0'))),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('相似图片'), findsOneWidget);
    expect(find.text('保存到本地'), findsOneWidget);
    expect(find.text('删除标记'), findsOneWidget);
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('影片详情'), findsNothing);
  });

  testWidgets('movie detail page point play action opens player route', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(
        mediaItems: <Map<String, dynamic>>[
          _mediaItemJson(
            points: <Map<String, dynamic>>[
              _mediaPointJson(pointId: 1, thumbnailId: 66, offsetSeconds: 120),
            ],
          ),
        ],
      ),
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
          Provider<ImageSearchDraftStore>(
            create: (_) => ImageSearchDraftStore(),
          ),
        ],
        child: MaterialApp.router(
          theme: sakuraThemeData,
          routerConfig: router,
          builder: (context, child) => OKToast(child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('movie-media-point-thumb-0')),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('movie-media-point-thumb-0'))),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/desktop/library/movies/ABC-001/player?mediaId=100&positionSeconds=120',
    );
  });

  testWidgets(
    'movie detail page point similar-image action opens image search route',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          mediaItems: <Map<String, dynamic>>[
            _mediaItemJson(
              points: <Map<String, dynamic>>[
                _mediaPointJson(
                  pointId: 1,
                  thumbnailId: 66,
                  offsetSeconds: 120,
                ),
              ],
            ),
          ],
        ),
      );
      bundle.adapter.enqueueBytes(
        method: 'GET',
        path: '/files/points/66.webp',
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
            Provider<ImageSearchDraftStore>(
              create: (_) => ImageSearchDraftStore(),
            ),
          ],
          child: MaterialApp.router(
            theme: sakuraThemeData,
            routerConfig: router,
            builder: (context, child) => OKToast(child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('movie-media-point-thumb-0')),
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('movie-media-point-thumb-0'))),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('相似图片'));
      await tester.pumpAndSettle();

      expect(find.text('image-search'), findsOneWidget);
      expect(bundle.adapter.hitCount('GET', '/files/points/66.webp'), 1);
    },
  );

  testWidgets('movie detail page point delete action updates visible gallery', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(
        mediaItems: <Map<String, dynamic>>[
          _mediaItemJson(
            points: <Map<String, dynamic>>[
              _mediaPointJson(pointId: 1, thumbnailId: 66, offsetSeconds: 120),
            ],
          ),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media/100/points/1',
      statusCode: 204,
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-media-point-thumb-0')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('movie-media-point-thumb-0')),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('movie-media-point-thumb-0'))),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除标记'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('DELETE', '/media/100/points/1'), 1);
    expect(find.byKey(const Key('movie-media-point-thumb-0')), findsNothing);
  });

  testWidgets(
    'movie detail page hides maker and director sections when empty',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(makerName: '', directorName: ''),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('厂商 · S1 NO.1 STYLE'), findsNothing);
      expect(find.text('导演 · 紋℃'), findsNothing);
    },
  );

  testWidgets(
    'movie detail page shows title above hero and summary below movie number',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(title: 'ABC-001 4K 中文字幕', summary: '这是影片简介'),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-detail-title')), findsOneWidget);
      expect(find.byKey(const Key('movie-detail-summary')), findsOneWidget);
      expect(find.text('ABC-001 4K 中文字幕'), findsOneWidget);
      expect(find.text('这是影片简介'), findsOneWidget);

      final titleBottom =
          tester.getBottomLeft(find.byKey(const Key('movie-detail-title'))).dy;
      final heroTop = tester.getTopLeft(find.byType(MovieDetailHeroCard)).dy;
      final movieNumberBottom =
          tester.getBottomLeft(find.byKey(const Key('movie-detail-number'))).dy;
      final interactionTop =
          tester
              .getTopLeft(find.byKey(const Key('movie-detail-interaction-row')))
              .dy;
      final summaryTop =
          tester.getTopLeft(find.byKey(const Key('movie-detail-summary'))).dy;

      expect(titleBottom, lessThan(heroTop));
      expect(movieNumberBottom, lessThan(interactionTop));
      expect(interactionTop, lessThan(summaryTop));
    },
  );

  testWidgets('movie detail page hides duplicate title and empty summary', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(title: 'ABC-001', summary: ''),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-detail-title')), findsNothing);
    expect(find.byKey(const Key('movie-detail-summary')), findsNothing);
    expect(find.byKey(const Key('movie-detail-number')), findsOneWidget);
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
      expect(find.text('关闭'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('movie-playlist-picker-dialog')),
          matching: find.byTooltip('关闭'),
        ),
        findsOneWidget,
      );
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
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/reviews',
      body: _movieReviewsJson(prefix: 'hot', count: 2),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-detail-inspector-dialog')),
      findsOneWidget,
    );
    expect(find.text('评论'), findsOneWidget);
    expect(find.text('磁力搜索'), findsOneWidget);
    expect(find.text('缩略图'), findsOneWidget);
    expect(find.text('Missav缩略图'), findsOneWidget);
    expect(find.text('hot-user-1'), findsOneWidget);
    expect(find.text('hot-review-1'), findsOneWidget);
    final reviewContent = tester.widget<Text>(find.text('hot-review-1'));
    expect(
      reviewContent.style?.fontSize,
      sakuraThemeData.textTheme.bodyMedium?.fontSize,
    );
    expect(bundle.adapter.hitCount('GET', '/movies/ABC-001/reviews'), 1);
    expect(
      bundle.adapter.hitCount(
        'GET',
        '/movies/ABC-001/thumbnails/missav/stream',
      ),
      0,
    );
    final hotSortButton = tester.widget<AppButton>(
      find.byKey(const Key('movie-detail-review-sort-hotly')),
    );
    expect(hotSortButton.isSelected, isTrue);
    expect(find.byTooltip('关闭'), findsOneWidget);
  });

  testWidgets(
    'movie detail page inspector review skeleton fills dialog height while loading',
    (WidgetTester tester) async {
      final reviewsCompleter = Completer<void>();
      addTearDown(() {
        if (!reviewsCompleter.isCompleted) {
          reviewsCompleter.complete();
        }
      });

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/movies/ABC-001/reviews',
        responder: (options, requestBody) async {
          await reviewsCompleter.future;
          return ResponseBody.fromString(
            jsonEncode(_movieReviewsJson(prefix: 'hot', count: 2)),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pump();

      expect(
        find.byKey(const Key('movie-detail-inspector-dialog')),
        findsOneWidget,
      );
      expect(_reviewSkeletonFinder(), findsWidgets);
      expect(_reviewSkeletonFinder().evaluate().length, greaterThan(3));

      if (!reviewsCompleter.isCompleted) {
        reviewsCompleter.complete();
      }
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'movie detail page inspector review tab supports sort switch and load more retry',
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
        path: '/movies/ABC-001/reviews',
        body: _movieReviewsJson(prefix: 'hot', count: 20),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/reviews',
        body: _movieReviewsJson(prefix: 'recent', count: 20),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/reviews',
        statusCode: 502,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'movie_review_fetch_failed',
            'message': 'boom',
          },
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/reviews',
        body: _movieReviewsJson(prefix: 'recent-page2', count: 2),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();

      expect(find.text('hot-review-1'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('movie-detail-review-sort-recently')),
      );
      await tester.pumpAndSettle();

      final recentSortButton = tester.widget<AppButton>(
        find.byKey(const Key('movie-detail-review-sort-recently')),
      );
      expect(recentSortButton.isSelected, isTrue);

      final reviewListFinder = find.byKey(
        const Key('movie-detail-review-list'),
      );
      expect(
        find.byKey(const Key('movie-detail-review-load-more-button')),
        findsNothing,
      );
      await tester.drag(reviewListFinder, const Offset(0, -1200));
      await tester.pumpAndSettle();

      var reviewRequests = bundle.adapter.requests
          .where((request) => request.path == '/movies/ABC-001/reviews')
          .toList(growable: false);
      if (reviewRequests.length < 3) {
        await tester.drag(reviewListFinder, const Offset(0, -1200));
        await tester.pumpAndSettle();
        reviewRequests = bundle.adapter.requests
            .where((request) => request.path == '/movies/ABC-001/reviews')
            .toList(growable: false);
      }
      expect(reviewRequests.length, greaterThanOrEqualTo(3));
      expect(reviewRequests[2].uri.queryParameters['sort'], 'recently');
      expect(reviewRequests[2].uri.queryParameters['page'], '2');

      await tester.dragUntilVisible(
        find.byKey(const Key('movie-detail-review-load-more-retry-button')),
        reviewListFinder,
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('movie-detail-review-load-more-retry-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-review-load-more-error')),
        findsNothing,
      );

      reviewRequests = bundle.adapter.requests
          .where((request) => request.path == '/movies/ABC-001/reviews')
          .toList(growable: false);
      expect(reviewRequests, hasLength(4));
      expect(reviewRequests[0].uri.queryParameters['sort'], 'hotly');
      expect(reviewRequests[0].uri.queryParameters['page'], '1');
      expect(reviewRequests[1].uri.queryParameters['sort'], 'recently');
      expect(reviewRequests[1].uri.queryParameters['page'], '1');
      expect(reviewRequests[2].uri.queryParameters['sort'], 'recently');
      expect(reviewRequests[2].uri.queryParameters['page'], '2');
      expect(reviewRequests[3].uri.queryParameters['sort'], 'recently');
      expect(reviewRequests[3].uri.queryParameters['page'], '2');
    },
  );

  testWidgets(
    'movie detail page inspector thumbnail tab uses auto columns and exposes compact interval selector',
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
      await tester.tap(find.text('缩略图'));
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
      expect(
        find.byKey(const Key('movie-detail-thumbnail-interval-icon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-detail-thumbnail-interval-10')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-detail-thumbnail-columns-icon')),
        findsOneWidget,
      );

      final toolbarLeft = tester.getTopLeft(
        find.byKey(const Key('movie-detail-thumbnail-toolbar')),
      );
      final intervalGroupLeft = tester.getTopLeft(
        find.byKey(const Key('movie-detail-thumbnail-interval-group')),
      );
      expect(intervalGroupLeft.dx, toolbarLeft.dx);
    },
  );

  testWidgets(
    'movie detail page inspector thumbnail interval filters visible thumbnails',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(offsets: <int>[10, 20, 30, 40]),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('缩略图'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-media-thumb-3')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('movie-detail-thumbnail-interval-20')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-media-thumb-0')), findsOneWidget);
      expect(find.byKey(const Key('movie-media-thumb-1')), findsOneWidget);
      expect(find.byKey(const Key('movie-media-thumb-2')), findsNothing);
      expect(find.byKey(const Key('movie-media-thumb-3')), findsNothing);
    },
  );

  testWidgets(
    'movie detail page inspector missav interval filters visible thumbnails',
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
      bundle.adapter.enqueueSse(
        method: 'GET',
        path: '/movies/ABC-001/thumbnails/missav/stream',
        chunks: <String>[
          'event: completed\n'
              'data: {"success":true,"result":{"movie_number":"ABC-001","source":"missav","total":12,"items":[{"index":0,"url":"/missav-0.jpg"},{"index":1,"url":"/missav-1.jpg"},{"index":2,"url":"/missav-2.jpg"},{"index":3,"url":"/missav-3.jpg"},{"index":4,"url":"/missav-4.jpg"},{"index":5,"url":"/missav-5.jpg"},{"index":6,"url":"/missav-6.jpg"},{"index":7,"url":"/missav-7.jpg"},{"index":8,"url":"/missav-8.jpg"},{"index":9,"url":"/missav-9.jpg"},{"index":10,"url":"/missav-10.jpg"},{"index":11,"url":"/missav-11.jpg"}]}}\n\n',
        ],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Missav缩略图'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('movie-detail-missav-start-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-missav-columns-icon')),
        findsOneWidget,
      );
      final toolbarLeft = tester.getTopLeft(
        find.byKey(const Key('movie-detail-missav-toolbar')),
      );
      final intervalGroupLeft = tester.getTopLeft(
        find.byKey(const Key('movie-detail-missav-interval-group')),
      );
      expect(intervalGroupLeft.dx, toolbarLeft.dx);

      expect(
        find.byKey(const Key('movie-detail-missav-thumb-2')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('movie-detail-missav-interval-20')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-missav-thumb-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-detail-missav-thumb-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-detail-missav-thumb-2')),
        findsNothing,
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
      expect(
        find.byKey(const Key('movie-detail-inspector-dialog')),
        findsOneWidget,
      );
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
      await tester.tap(find.text('缩略图'));
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
      await tester.tap(find.text('缩略图'));
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
    'movie detail page inspector preview main image opens action menu on secondary tap',
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
      await tester.tap(find.text('缩略图'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('movie-media-thumb-0')));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(
          find.byKey(const Key('movie-plot-preview-main-image-0')),
        ),
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
      await tester.tap(find.text('缩略图'));
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
            Provider<ImageSearchDraftStore>(
              create: (_) => ImageSearchDraftStore(),
            ),
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
      await tester.tap(find.text('缩略图'));
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
            Provider<ImageSearchDraftStore>(
              create: (_) => ImageSearchDraftStore(),
            ),
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
      await tester.tap(find.text('缩略图'));
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
        router.routeInformationProvider.value.uri.path,
        desktopImageSearchPath,
      );
      expect(find.text('image-search'), findsOneWidget);
    },
  );

  testWidgets('movie detail page renders inline series text with bodySmall', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final seriesText = tester.widget<Text>(find.text('系列 · Attackers'));
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

  testWidgets('movie detail page hero height follows 30% viewport rule', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final viewportHeight =
        tester.getSize(find.byType(DesktopMovieDetailPage)).height;
    final heroHeight = tester.getSize(find.byType(MovieDetailHeroCard)).height;

    expect(heroHeight, closeTo(viewportHeight * 0.3, 0.1));
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
    'movie detail page plot preview main image opens action menu on secondary tap',
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
        tester.getCenter(
          find.byKey(const Key('movie-plot-preview-main-image-0')),
        ),
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
            Provider<ImageSearchDraftStore>(
              create: (_) => ImageSearchDraftStore(),
            ),
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
      final draftStore = ImageSearchDraftStore();

      final router = GoRouter(
        routes: [
          GoRoute(
            path: desktopImageSearchPath,
            builder: (context, state) {
              final draftId =
                  state.uri.queryParameters['draftId'] ??
                  state.uri.queryParameters['draft-id'];
              final draft = draftStore.get(draftId);
              final currentMovieNumber =
                  state.uri.queryParameters['currentMovieNumber'] ??
                  state.uri.queryParameters['current-movie-number'];
              final currentMovieScopeRaw =
                  state.uri.queryParameters['currentMovieScope'] ??
                  state.uri.queryParameters['current-movie-scope'] ??
                  ImageSearchCurrentMovieScope.all.name;
              final currentMovieScope = ImageSearchCurrentMovieScope.values
                  .firstWhere(
                    (scope) => scope.name == currentMovieScopeRaw,
                    orElse: () => ImageSearchCurrentMovieScope.all,
                  );
              return DesktopImageSearchPage(
                initialFileName: draft?.fileName,
                initialFileBytes: draft?.bytes,
                initialMimeType: draft?.mimeType,
                currentMovieNumber: currentMovieNumber,
                initialCurrentMovieScope: currentMovieScope,
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
            Provider<ImageSearchDraftStore>.value(value: draftStore),
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

  testWidgets(
    'movie detail page prioritizes female actors and keeps intra-group order',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          actors: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'javdb_id': 'ActorA1',
              'name': '非女优A',
              'alias_name': '非女优A',
              'gender': 0,
              'is_subscribed': false,
              'profile_image': null,
            },
            <String, dynamic>{
              'id': 2,
              'javdb_id': 'ActorA2',
              'name': '女优A',
              'alias_name': '女优A',
              'gender': 1,
              'is_subscribed': false,
              'profile_image': null,
            },
            <String, dynamic>{
              'id': 3,
              'javdb_id': 'ActorA3',
              'name': '女优B',
              'alias_name': '女优B',
              'gender': 1,
              'is_subscribed': false,
              'profile_image': null,
            },
            <String, dynamic>{
              'id': 4,
              'javdb_id': 'ActorA4',
              'name': '非女优B',
              'alias_name': '非女优B',
              'gender': 2,
              'is_subscribed': false,
              'profile_image': null,
            },
          ],
        ),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      final actorElements = find
          .descendant(
            of: find.byType(MovieActorWrap),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'movie-actor-',
                  ),
            ),
          )
          .evaluate()
          .toList(growable: false);
      final actorKeys = actorElements
          .map((element) => (element.widget.key! as ValueKey<String>).value)
          .toList(growable: false);

      expect(
        actorKeys,
        equals(const <String>[
          'movie-actor-2',
          'movie-actor-3',
          'movie-actor-1',
          'movie-actor-4',
        ]),
      );
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
    expect(find.text('extra:null'), findsOneWidget);
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
  String title = 'Movie 1',
  String summary = '',
  String makerName = 'S1 NO.1 STYLE',
  String directorName = '紋℃',
  int heat = 0,
  List<Map<String, dynamic>>? tags,
  List<Map<String, dynamic>>? actors,
  List<Map<String, dynamic>>? plotImages,
  List<Map<String, dynamic>>? mediaItems,
  List<Map<String, dynamic>>? playlists,
}) {
  return <String, dynamic>{
    'javdb_id': 'MovieA1',
    'movie_number': 'ABC-001',
    'title': title,
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
    'heat': heat,
    'watched_count': 12,
    'want_watch_count': 23,
    'comment_count': 34,
    'score_number': 45,
    'is_collection': false,
    'is_subscribed': true,
    'can_play': true,
    'series_name': 'Attackers',
    'maker_name': makerName,
    'director_name': directorName,
    'summary': summary,
    'actors':
        actors ??
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'javdb_id': 'ActorA1',
            'name': '三上悠亚',
            'alias_name': '三上悠亚 / 鬼头桃菜',
            'gender': 1,
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
    'media_items': mediaItems ?? <Map<String, dynamic>>[_mediaItemJson()],
    'playlists': playlists ?? const <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _mediaItemJson({
  int mediaId = 100,
  String specialTags = '普通',
  List<Map<String, dynamic>>? points,
}) {
  final isPreview = mediaId == 101;
  return <String, dynamic>{
    'media_id': mediaId,
    'library_id': 1,
    'play_url':
        '/files/media/movies/ABC-001/video.mp4?expires=1700000900&signature=abc',
    'path': '/library/main/ABC-001/video.mp4',
    'storage_mode': 'hardlink',
    'resolution': isPreview ? '1280x720' : '1920x1080',
    'file_size_bytes': isPreview ? 524288000 : 1073741824,
    'duration_seconds': 7200,
    'special_tags': specialTags,
    'valid': true,
    'progress': <String, dynamic>{
      'last_position_seconds': 600,
      'last_watched_at': '2026-03-08T09:30:00',
    },
    'video_info': <String, dynamic>{
      'container': <String, dynamic>{
        'format_name': isPreview ? 'mp4' : 'mpegts',
        'duration_seconds': 7200,
        'bit_rate': isPreview ? 8000000 : 22793091,
        'size_bytes': isPreview ? 524288000 : 1073741824,
      },
      'video': <String, dynamic>{
        'codec_name': isPreview ? 'hevc' : 'h264',
        'codec_long_name': isPreview ? 'H.265 / HEVC' : 'H.264 / AVC',
        'profile': isPreview ? 'Main' : 'High',
        'bit_rate': isPreview ? 6500000 : null,
        'width': isPreview ? 1280 : 1920,
        'height': isPreview ? 720 : 1080,
        'frame_rate': isPreview ? 24.0 : 29.97,
        'pixel_format': 'yuv420p',
      },
      'audio': <String, dynamic>{
        'codec_name': 'aac',
        'codec_long_name': 'AAC',
        'profile': 'LC',
        'bit_rate': 192000,
        'sample_rate': 48000,
        'channels': 2,
        'channel_layout': 'stereo',
      },
      'subtitles': const <Map<String, dynamic>>[],
    },
    'points': points ?? const <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _mediaPointJson({
  required int pointId,
  required int thumbnailId,
  required int offsetSeconds,
}) {
  return <String, dynamic>{
    'point_id': pointId,
    'thumbnail_id': thumbnailId,
    'offset_seconds': offsetSeconds,
    'image': <String, dynamic>{
      'id': 300 + pointId,
      'origin': '/files/points/$thumbnailId.webp',
      'small': '/files/points/$thumbnailId-small.webp',
      'medium': '/files/points/$thumbnailId-medium.webp',
      'large': '/files/points/$thumbnailId-large.webp',
    },
  };
}

List<Map<String, dynamic>> _movieReviewsJson({
  required String prefix,
  required int count,
}) {
  return List<Map<String, dynamic>>.generate(count, (index) {
    final seed = index + 1;
    return <String, dynamic>{
      'id': seed,
      'score': 5,
      'content': '$prefix-review-$seed',
      'created_at': '2026-03-10T08:00:00Z',
      'username': '$prefix-user-$seed',
      'like_count': 10 + seed,
      'watch_count': 20 + seed,
    };
  });
}

Finder _reviewSkeletonFinder() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('movie-detail-review-skeleton-');
  });
}

List<Map<String, dynamic>> _mediaThumbnailsJson({
  int mediaId = 100,
  List<int> offsets = const <int>[10, 20],
}) {
  return List<Map<String, dynamic>>.generate(offsets.length, (index) {
    final thumbnailId = index + 1;
    return <String, dynamic>{
      'thumbnail_id': thumbnailId,
      'media_id': mediaId,
      'offset_seconds': offsets[index],
      'image': <String, dynamic>{
        'id': 100 + thumbnailId,
        'origin': '/files/thumbs/$mediaId/$thumbnailId.webp',
        'small': '/files/thumbs/$mediaId/$thumbnailId-small.webp',
        'medium': '/files/thumbs/$mediaId/$thumbnailId-medium.webp',
        'large': '/files/thumbs/$mediaId/$thumbnailId-large.webp',
      },
    };
  }, growable: false);
}
