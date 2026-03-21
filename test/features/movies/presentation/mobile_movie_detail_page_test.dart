import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/mobile_movie_detail_page.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_hero_card.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('mobile movie detail page shows loading skeleton on first load', (
    WidgetTester tester,
  ) async {
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

    final loadingSurface = tester.widget<ColoredBox>(
      find.byKey(const Key('mobile-movie-detail-page-surface')),
    );
    expect(loadingSurface.color, sakuraThemeData.appColors.surfaceCard);
    expect(
      find.byKey(const Key('movie-detail-loading-skeleton')),
      findsOneWidget,
    );

    if (!completer.isCompleted) {
      completer.complete();
    }
    await tester.pumpAndSettle();
  });

  testWidgets(
    'mobile movie detail loading skeleton does not overflow on narrow widths',
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

      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        physicalSize: const Size(320, 720),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('movie-detail-loading-skeleton')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      completer.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('mobile movie detail page shows error state and can retry', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('影片详情暂时无法加载，请稍后重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-detail-page')), findsOneWidget);
    expect(find.text('ABC-001'), findsWidgets);
  });

  testWidgets('mobile movie detail page renders sections and opens inspector', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(
        mediaItems: <Map<String, dynamic>>[
          _mediaItemJson(mediaId: 100, specialTags: '普通'),
          _mediaItemJson(mediaId: 101, specialTags: '预告'),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/101/thumbnails',
      body: _mediaThumbnailsJson(mediaId: 101),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/reviews',
      body: _movieReviewsJson(prefix: 'hot', count: 2),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final loadedSurface = tester.widget<ColoredBox>(
      find.byKey(const Key('mobile-movie-detail-page-surface')),
    );
    expect(loadedSurface.color, sakuraThemeData.appColors.surfaceCard);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('演员'), findsOneWidget);
    expect(find.text('媒体源'), findsOneWidget);

    await tester.ensureVisible(find.text('预告 1.0 GB'));
    await tester.tap(find.text('预告 1.0 GB'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-detail-inspector-bottom-sheet')),
      findsOneWidget,
    );
    final drawerContentTopLeft = tester.getTopLeft(
      find.byKey(const Key('app-bottom-drawer-content')),
    );
    final panelTopLeft = tester.getTopLeft(
      find.byKey(const Key('movie-detail-inspector-panel')),
    );
    expect(panelTopLeft.dx - drawerContentTopLeft.dx, 0);
    expect(find.text('评论'), findsOneWidget);
    expect(find.text('磁力搜索'), findsOneWidget);
    expect(find.text('缩略图'), findsWidgets);
    expect(find.text('hot-review-1'), findsOneWidget);
    expect(bundle.adapter.hitCount('GET', '/media/101/thumbnails'), 1);
    expect(bundle.adapter.hitCount('GET', '/movies/ABC-001/reviews'), 1);
  });

  testWidgets(
    'mobile movie detail opens playlist picker and creator as bottom sheets',
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
          _playlistJson(
            id: 1,
            name: '最近播放',
            kind: 'recently_played',
            isSystem: true,
            movieCount: 1,
          ),
          _playlistJson(id: 2, name: '我的收藏', description: 'Favorite'),
        ],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('movie-detail-playlist-trigger')),
      );
      await tester.tap(find.byKey(const Key('movie-detail-playlist-trigger')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-playlist-picker-bottom-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-playlist-picker-dialog')),
        findsNothing,
      );
      expect(find.text('我的收藏'), findsOneWidget);
      expect(find.text('最近播放'), findsNothing);

      await tester.tap(find.byKey(const Key('movie-playlist-create-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('create-playlist-bottom-sheet')),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'mobile movie detail playlist picker height adapts with small content',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(540, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[_playlistJson(id: 2, name: '我的收藏')],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('movie-detail-playlist-trigger')),
      );
      await tester.tap(find.byKey(const Key('movie-detail-playlist-trigger')));
      await tester.pumpAndSettle();

      final viewportHeight =
          tester.getSize(find.byType(MobileMovieDetailPage)).height;
      final drawerHeight =
          tester
              .getSize(
                find.byKey(const Key('movie-playlist-picker-bottom-sheet')),
              )
              .height;

      expect(drawerHeight, lessThanOrEqualTo(viewportHeight * 0.4));
    },
  );

  testWidgets(
    'mobile movie detail playlist picker caps height at 40% and keeps list scrollable',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(540, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final customPlaylists = List<Map<String, dynamic>>.generate(
        24,
        (index) => _playlistJson(
          id: 100 + index,
          name: '自定义列表 ${index + 1}',
          movieCount: index,
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[
          _playlistJson(
            id: 1,
            name: '最近播放',
            kind: 'recently_played',
            isSystem: true,
            movieCount: 10,
          ),
          ...customPlaylists,
        ],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('movie-detail-playlist-trigger')),
      );
      await tester.tap(find.byKey(const Key('movie-detail-playlist-trigger')));
      await tester.pumpAndSettle();

      final viewportHeight =
          tester.getSize(find.byType(MobileMovieDetailPage)).height;
      final drawerHeight =
          tester
              .getSize(
                find.byKey(const Key('movie-playlist-picker-bottom-sheet')),
              )
              .height;
      final maxAllowedHeight = viewportHeight * 0.4;

      expect(drawerHeight, lessThanOrEqualTo(maxAllowedHeight + 0.1));

      final listFinder = find.byKey(const Key('movie-playlist-list'));
      final lastOptionFinder = find.byKey(
        const Key('movie-playlist-option-123'),
      );

      expect(listFinder, findsOneWidget);
      expect(lastOptionFinder, findsNothing);
      await tester.dragUntilVisible(
        lastOptionFinder,
        listFinder,
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      expect(lastOptionFinder, findsOneWidget);
    },
  );

  testWidgets(
    'mobile movie detail plot thumbnail opens bottom drawer preview',
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

      expect(
        find.byKey(const Key('movie-plot-preview-bottom-drawer')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('movie-plot-preview-dialog')), findsNothing);
    },
  );

  testWidgets(
    'mobile movie detail plot preview main image opens action menu on long press',
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

      final center = tester.getCenter(
        find.byKey(const Key('movie-plot-preview-main-image-0')),
      );
      final gesture = await tester.startGesture(center);
      await tester.pump(kLongPressTimeout);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('相似图片'), findsOneWidget);
      expect(find.text('保存到本地'), findsOneWidget);
    },
  );

  testWidgets('mobile movie detail hero height follows 30% viewport rule', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(540, 1080);
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
        tester.getSize(find.byType(MobileMovieDetailPage)).height;
    final heroHeight = tester.getSize(find.byType(MovieDetailHeroCard)).height;

    expect(heroHeight, closeTo(viewportHeight * 0.3, 0.1));
  });

  testWidgets(
    'mobile movie detail inspector supports manual magnet search and thumbnail columns',
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
        body: <Map<String, dynamic>>[
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
        ],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('磁力搜索'));
      await tester.pumpAndSettle();
      expect(bundle.adapter.hitCount('GET', '/download-candidates'), 0);

      await tester.tap(
        find.byKey(const Key('movie-detail-magnet-search-button')),
      );
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/download-candidates'), 1);
      expect(find.text('ABC-001 4K 中文字幕'), findsOneWidget);

      await tester.tap(find.text('缩略图'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('movie-media-thumb-0')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('movie-detail-thumbnail-columns-5')),
      );
      await tester.pumpAndSettle();

      final columnButton = tester.widget<AppButton>(
        find.byKey(const Key('movie-detail-thumbnail-columns-5')),
      );
      expect(columnButton.isSelected, isTrue);
    },
  );

  testWidgets('mobile movie detail play entries navigate to mobile player', (
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
      path: '/media/100/points',
      body: const <Map<String, dynamic>>[],
    );

    final visitedPlayerUris = <String>[];
    final router = GoRouter(
      initialLocation: buildMobileMovieDetailRoutePath('ABC-001'),
      routes: [
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber',
          builder:
              (_, state) => MobileMovieDetailPage(
                movieNumber: state.pathParameters['movieNumber']!,
              ),
        ),
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber/player',
          builder: (_, state) {
            visitedPlayerUris.add(state.uri.toString());
            return Text(
              'player:${state.uri}',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouterPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      router: router,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-detail-hero-play-button')));
    await tester.pumpAndSettle();
    expect(
      visitedPlayerUris,
      contains('/mobile/library/movies/ABC-001/player?mediaId=100'),
    );

    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('缩略图'));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('movie-media-thumb-0'))),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放'));
    await tester.pumpAndSettle();
    expect(
      visitedPlayerUris,
      contains(
        '/mobile/library/movies/ABC-001/player?mediaId=100&positionSeconds=10',
      ),
    );
  });

  testWidgets('mobile movie detail actor tap navigates to actor detail route', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );
    Object? actorRouteExtra;
    final router = GoRouter(
      initialLocation: buildMobileMovieDetailRoutePath('ABC-001'),
      routes: [
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber',
          builder:
              (_, state) => MobileMovieDetailPage(
                movieNumber: state.pathParameters['movieNumber']!,
              ),
        ),
        GoRoute(
          path: '$mobileActorsPath/:actorId',
          builder: (_, state) {
            actorRouteExtra = state.extra;
            return Text(
              'actor:${state.pathParameters['actorId']}',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouterPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      router: router,
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('movie-actor-1')));
    await tester.tap(find.byKey(const Key('movie-actor-1')));
    await tester.pumpAndSettle();

    expect(find.text('actor:1'), findsOneWidget);
    expect(actorRouteExtra, buildMobileMovieDetailRoutePath('ABC-001'));
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  Size physicalSize = const Size(430, 900),
}) async {
  tester.view.physicalSize = physicalSize;
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
          child: Scaffold(body: MobileMovieDetailPage(movieNumber: 'ABC-001')),
        ),
      ),
    ),
  );
}

Future<void> _pumpRouterPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  required GoRouter router,
}) async {
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
      child: OKToast(
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    ),
  );
}

Map<String, dynamic> _movieDetailJson({
  List<Map<String, dynamic>>? mediaItems,
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
    'actors': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'javdb_id': 'ActorA1',
        'name': '三上悠亚',
        'alias_name': '三上悠亚 / 鬼头桃菜',
        'is_subscribed': false,
        'profile_image': null,
      },
    ],
    'tags': <Map<String, dynamic>>[
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
    'plot_images': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 12,
        'origin': '/files/images/movies/ABC-001/plots/0.jpg',
        'small': '/files/images/movies/ABC-001/plots/0-small.jpg',
        'medium': '/files/images/movies/ABC-001/plots/0-medium.jpg',
        'large': '/files/images/movies/ABC-001/plots/0-large.jpg',
      },
    ],
    'media_items': mediaItems ?? <Map<String, dynamic>>[_mediaItemJson()],
    'playlists': const <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _playlistJson({
  required int id,
  required String name,
  String kind = 'custom',
  bool isSystem = false,
  bool isMutable = true,
  bool isDeletable = true,
  int movieCount = 0,
  String description = '',
}) {
  final mutable = isSystem ? false : isMutable;
  final deletable = isSystem ? false : isDeletable;
  return <String, dynamic>{
    'id': id,
    'name': name,
    'kind': kind,
    'description': description,
    'is_system': isSystem,
    'is_mutable': mutable,
    'is_deletable': deletable,
    'movie_count': movieCount,
    'created_at': '2026-03-12T10:10:00Z',
    'updated_at': '2026-03-12T10:10:00Z',
  };
}

Map<String, dynamic> _mediaItemJson({
  int mediaId = 100,
  String specialTags = '普通',
}) {
  return <String, dynamic>{
    'media_id': mediaId,
    'library_id': 1,
    'play_url':
        '/files/media/movies/ABC-001/video.mp4?expires=1700000900&signature=abc',
    'path': '/library/main/ABC-001/video.mp4',
    'storage_mode': 'hardlink',
    'resolution': '1920x1080',
    'file_size_bytes': 1073741824,
    'duration_seconds': 7200,
    'special_tags': specialTags,
    'valid': true,
    'progress': <String, dynamic>{
      'last_position_seconds': 600,
      'last_watched_at': '2026-03-08T09:30:00',
    },
    'points': const <Map<String, dynamic>>[],
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
  ];
}
