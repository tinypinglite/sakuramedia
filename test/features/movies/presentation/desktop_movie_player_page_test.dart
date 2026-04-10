import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_player_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface_controller.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface_readiness.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late List<Duration> seekRequests;
  late List<Duration?> initialPositions;
  late ValueNotifier<bool> surfaceReady;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    seekRequests = <Duration>[];
    initialPositions = <Duration?>[];
    surfaceReady = ValueNotifier<bool>(true);
  });

  tearDown(() {
    surfaceReady.dispose();
    bundle.dispose();
  });

  testWidgets('movie player page shows left blackout before detail resolves', (
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

    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      surfaceBuilder: _testSurfaceBuilder(seekRequests, initialPositions),
    );
    await tester.pump();

    expect(find.byKey(const Key('movie-player-left-blackout')), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'movie player page keeps left panel black until surface reports ready',
    (WidgetTester tester) async {
      surfaceReady.value = false;
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

      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        surfaceBuilder: _testSurfaceBuilder(
          seekRequests,
          initialPositions,
          readiness: surfaceReady,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-player-left-blackout')), findsNothing);
      expect(
        find.byKey(const Key('movie-player-surface-ready-mask')),
        findsOneWidget,
      );

      surfaceReady.value = true;
      await tester.pump();

      expect(
        find.byKey(const Key('movie-player-surface-ready-mask')),
        findsNothing,
      );
      expect(
        find.text(
          'surface:https://api.example.com/files/media/movies/ABC-001/video.mp4?expires=1700000900&signature=abc',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'movie player page uses requested media id and resolves playback url',
    (WidgetTester tester) async {
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
            <String, dynamic>{
              'media_id': 101,
              'library_id': 1,
              'play_url':
                  '/files/media/movies/ABC-001/video-alt.mp4?expires=1700000900&signature=abc',
              'path': '/library/main/ABC-001/video-alt.mp4',
              'storage_mode': 'hardlink',
              'resolution': '1280x720',
              'file_size_bytes': 524288000,
              'duration_seconds': 5400,
              'special_tags': '导演剪辑版',
              'valid': true,
              'progress': null,
              'points': const <Map<String, dynamic>>[],
            },
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/101/thumbnails',
        body: _mediaThumbnailsJson(mediaId: 101),
      );

      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        initialMediaId: 101,
        surfaceBuilder: _testSurfaceBuilder(seekRequests, initialPositions),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'surface:https://api.example.com/files/media/movies/ABC-001/video-alt.mp4?expires=1700000900&signature=abc',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-player-thumbnail-panel')),
        findsOneWidget,
      );
    },
  );

  testWidgets('movie player page falls back to first playable media', (
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

    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      initialMediaId: 999,
      surfaceBuilder: _testSurfaceBuilder(seekRequests, initialPositions),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'surface:https://api.example.com/files/media/movies/ABC-001/video.mp4?expires=1700000900&signature=abc',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'movie player page shows empty state when no playable media exists',
    (WidgetTester tester) async {
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

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('暂无可播放媒体'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-player-thumbnail-panel')),
        findsOneWidget,
      );
      expect(find.text('还没有可用缩略图'), findsNothing);
    },
  );

  testWidgets('movie player page back overlay returns to movie detail', (
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

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/desktop/library/movies/:movieNumber',
          builder:
              (context, state) =>
                  Text('detail:${state.pathParameters['movieNumber']}'),
          routes: [
            GoRoute(
              path: 'player',
              builder:
                  (context, state) => DesktopMoviePlayerPage(
                    movieNumber: state.pathParameters['movieNumber']!,
                    initialMediaId: int.tryParse(
                      state.uri.queryParameters['mediaId'] ?? '',
                    ),
                    surfaceBuilder: _testSurfaceBuilder(
                      seekRequests,
                      initialPositions,
                    ),
                  ),
            ),
          ],
        ),
      ],
      initialLocation: '/desktop/library/movies/ABC-001/player?mediaId=100',
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

    await tester.tap(find.byKey(const Key('movie-player-back-button')));
    await tester.pumpAndSettle();

    expect(find.text('detail:ABC-001'), findsOneWidget);
  });

  testWidgets('movie player page keeps back overlay in top-left corner', (
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
      method: 'PUT',
      path: '/media/100/progress',
      body: <String, dynamic>{
        'media_id': 100,
        'last_position_seconds': 20,
        'last_watched_at': '2026-03-12T14:00:00',
      },
    );

    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      surfaceBuilder: _testSurfaceBuilder(seekRequests, initialPositions),
    );
    await tester.pumpAndSettle();

    final backTopLeft = tester.getTopLeft(
      find.byKey(const Key('movie-player-back-button')),
    );
    final frameTopLeft = tester.getTopLeft(
      find.byKey(const Key('movie-player-page-frame')),
    );

    expect(backTopLeft.dx - frameTopLeft.dx, closeTo(12, 0.1));
    expect(backTopLeft.dy - frameTopLeft.dy, closeTo(24, 0.1));
  });

  testWidgets(
    'movie player page shows thumbnail empty state when list is empty',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: const <Map<String, dynamic>>[],
      );

      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        surfaceBuilder: _testSurfaceBuilder(seekRequests, initialPositions),
      );
      await tester.pumpAndSettle();

      expect(find.text('还没有可用缩略图'), findsOneWidget);
    },
  );

  testWidgets('movie player page shows thumbnail error state and retries', (
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
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/100/thumbnails',
      body: _mediaThumbnailsJson(),
    );

    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      surfaceBuilder: _testSurfaceBuilder(seekRequests, initialPositions),
    );
    await tester.pumpAndSettle();

    expect(find.text('缩略图加载失败'), findsOneWidget);

    await tester.tap(find.byKey(const Key('movie-player-thumbnail-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-player-thumb-0')), findsOneWidget);
    expect(bundle.adapter.hitCount('GET', '/media/100/thumbnails'), 2);
  });

  testWidgets('movie player page changes thumbnail columns and seeks on tap', (
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

    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      surfaceBuilder: _testSurfaceBuilder(seekRequests, initialPositions),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-player-columns-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-player-thumb-1')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(seekRequests, contains(const Duration(seconds: 20)));
  });

  testWidgets(
    'movie player page keeps player surface stable during position updates',
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

      ValueChanged<Duration>? emitPosition;
      var surfaceBuildCount = 0;
      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        surfaceBuilder: (
          context,
          resolvedUrl,
          surfaceController,
          initialPosition,
          onPositionChanged,
          onPlayingChanged,
          onBackPressed,
          useTouchOptimizedControls,
        ) {
          surfaceBuildCount += 1;
          emitPosition = onPositionChanged;
          return Text('surface:$resolvedUrl');
        },
      );
      await tester.pumpAndSettle();

      final baselineBuildCount = surfaceBuildCount;
      expect(emitPosition, isNotNull);

      emitPosition!(const Duration(seconds: 12));
      await tester.pump();
      emitPosition!(const Duration(seconds: 20));
      await tester.pump();
      emitPosition!(const Duration(seconds: 35));
      await tester.pump();

      expect(surfaceBuildCount, baselineBuildCount);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'movie player page updates thumbnail highlight as playback moves',
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

      ValueChanged<Duration>? emitPosition;
      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        surfaceBuilder: (
          context,
          resolvedUrl,
          surfaceController,
          initialPosition,
          onPositionChanged,
          onPlayingChanged,
          onBackPressed,
          useTouchOptimizedControls,
        ) {
          emitPosition = onPositionChanged;
          return Text('surface:$resolvedUrl');
        },
      );
      await tester.pumpAndSettle();

      expect(_thumbnailBorderWidth(tester, 0), 1.5);
      expect(_thumbnailBorderWidth(tester, 1), 1.0);

      emitPosition!(const Duration(seconds: 20));
      await tester.pump();

      expect(_thumbnailBorderWidth(tester, 0), 1.0);
      expect(_thumbnailBorderWidth(tester, 1), 1.5);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'movie player page throttles locked thumbnail auto scroll during rapid playback updates',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _manyMediaThumbnailsJson(90),
      );

      ValueChanged<Duration>? emitPosition;
      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        surfaceBuilder: (
          context,
          resolvedUrl,
          surfaceController,
          initialPosition,
          onPositionChanged,
          onPlayingChanged,
          onBackPressed,
          useTouchOptimizedControls,
        ) {
          emitPosition = onPositionChanged;
          return Text('surface:$resolvedUrl');
        },
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byKey(const Key('movie-player-thumbnail-grid')),
        matching: find.byType(Scrollable),
      );

      emitPosition!(const Duration(seconds: 850));
      await tester.pump();
      await tester.pump();

      final offsetAfterLeading = _thumbnailScrollOffset(
        tester,
        scrollableFinder,
      );
      expect(find.byKey(const Key('movie-player-thumb-84')), findsOneWidget);
      expect(_thumbnailBorderWidth(tester, 84), 1.5);

      emitPosition!(const Duration(seconds: 890));
      await tester.pump();
      await tester.pump();
      emitPosition!(const Duration(seconds: 900));
      await tester.pump();
      await tester.pump();

      expect(
        _thumbnailScrollOffset(tester, scrollableFinder),
        offsetAfterLeading,
      );
      expect(_thumbnailBorderWidth(tester, 89), 1.5);

      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();

      expect(
        _thumbnailScrollOffset(tester, scrollableFinder),
        greaterThanOrEqualTo(offsetAfterLeading),
      );
      expect(find.byKey(const Key('movie-player-thumb-89')), findsOneWidget);
      expect(_thumbnailBorderWidth(tester, 89), 1.5);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'movie player page passes stored progress as initial seek position',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          mediaItems: <Map<String, dynamic>>[
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
                'last_position_seconds': 120,
                'last_watched_at': '2026-03-12T14:00:00',
              },
              'points': const <Map<String, dynamic>>[],
            },
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );

      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        surfaceBuilder: _testSurfaceBuilder(seekRequests, initialPositions),
      );
      await tester.pumpAndSettle();

      expect(initialPositions, contains(const Duration(seconds: 120)));
    },
  );

  testWidgets(
    'movie player page prefers requested initial position over stored progress',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          mediaItems: <Map<String, dynamic>>[
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
                'last_position_seconds': 120,
                'last_watched_at': '2026-03-12T14:00:00',
              },
              'points': const <Map<String, dynamic>>[],
            },
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );

      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        initialPositionSeconds: 61,
        surfaceBuilder: _testSurfaceBuilder(seekRequests, initialPositions),
      );
      await tester.pumpAndSettle();

      expect(initialPositions, contains(const Duration(seconds: 61)));
    },
  );

  testWidgets('movie player page flushes final playback progress on dispose', (
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
      method: 'PUT',
      path: '/media/100/progress',
      body: <String, dynamic>{
        'media_id': 100,
        'last_position_seconds': 25,
        'last_watched_at': '2026-03-12T14:00:00',
      },
    );

    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      surfaceBuilder:
          (
            context,
            resolvedUrl,
            surfaceController,
            initialPosition,
            onPositionChanged,
            onPlayingChanged,
            onBackPressed,
            useTouchOptimizedControls,
          ) => _TestMoviePlayerSurface(
            resolvedUrl: resolvedUrl,
            surfaceController: surfaceController,
            initialPosition: initialPosition,
            seekRequests: seekRequests,
            initialPositions: initialPositions,
            onPositionChanged: onPositionChanged,
            onPlayingChanged: onPlayingChanged,
            onBackPressed: onBackPressed,
            emitPositionOnBuild: const Duration(seconds: 25),
          ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('PUT', '/media/100/progress'), 1);
  });

  testWidgets('movie player page toggles thumbnail scroll lock state', (
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

    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      surfaceBuilder: _testSurfaceBuilder(seekRequests, initialPositions),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_open_rounded), findsNothing);

    await tester.tap(find.byKey(const Key('movie-player-scroll-lock-toggle')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_rounded), findsNothing);
    expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
  });

  testWidgets(
    'movie player page opens thumbnail action menu on secondary tap',
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

      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        surfaceBuilder: _testSurfaceBuilder(seekRequests, initialPositions),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('movie-player-thumb-1'))),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('相似图片'), findsOneWidget);
      expect(find.text('保存到本地'), findsOneWidget);
      expect(find.text('添加标记'), findsOneWidget);
      expect(find.text('播放'), findsOneWidget);
    },
  );
}

MoviePlayerSurfaceBuilder _testSurfaceBuilder(
  List<Duration> seekRequests,
  List<Duration?> initialPositions, {
  ValueNotifier<bool>? readiness,
}) {
  return (
    BuildContext context,
    String resolvedUrl,
    MoviePlayerSurfaceController surfaceController,
    Duration? initialPosition,
    ValueChanged<Duration>? onPositionChanged,
    ValueChanged<bool>? onPlayingChanged,
    VoidCallback onBackPressed,
    bool useTouchOptimizedControls,
  ) {
    return _TestMoviePlayerSurface(
      resolvedUrl: resolvedUrl,
      surfaceController: surfaceController,
      initialPosition: initialPosition,
      seekRequests: seekRequests,
      initialPositions: initialPositions,
      onPositionChanged: onPositionChanged,
      onPlayingChanged: onPlayingChanged,
      onBackPressed: onBackPressed,
      readiness: readiness,
    );
  };
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  int? initialMediaId,
  int? initialPositionSeconds,
  Widget Function(
    BuildContext context,
    String resolvedUrl,
    MoviePlayerSurfaceController surfaceController,
    Duration? initialPosition,
    ValueChanged<Duration>? onPositionChanged,
    ValueChanged<bool>? onPlayingChanged,
    VoidCallback onBackPressed,
    bool useTouchOptimizedControls,
  )?
  surfaceBuilder,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
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
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: DesktopMoviePlayerPage(
            movieNumber: 'ABC-001',
            initialMediaId: initialMediaId,
            initialPositionSeconds: initialPositionSeconds,
            surfaceBuilder: surfaceBuilder,
          ),
        ),
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
    'cover_image': null,
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
    'summary': '',
    'actors': const <Map<String, dynamic>>[],
    'tags': const <Map<String, dynamic>>[],
    'thin_cover_image': null,
    'plot_images': const <Map<String, dynamic>>[],
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
            'progress': null,
            'points': const <Map<String, dynamic>>[],
          },
        ],
  };
}

List<Map<String, dynamic>> _mediaThumbnailsJson({int mediaId = 100}) {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'thumbnail_id': 1,
      'media_id': mediaId,
      'offset_seconds': 10,
      'image': <String, dynamic>{
        'id': 11,
        'origin': '/files/images/thumb-10.webp',
        'small': '/files/images/thumb-10.webp',
        'medium': '/files/images/thumb-10.webp',
        'large': '/files/images/thumb-10.webp',
      },
    },
    <String, dynamic>{
      'thumbnail_id': 2,
      'media_id': mediaId,
      'offset_seconds': 20,
      'image': <String, dynamic>{
        'id': 12,
        'origin': '/files/images/thumb-20.webp',
        'small': '/files/images/thumb-20.webp',
        'medium': '/files/images/thumb-20.webp',
        'large': '/files/images/thumb-20.webp',
      },
    },
  ];
}

List<Map<String, dynamic>> _manyMediaThumbnailsJson(
  int count, {
  int mediaId = 100,
}) {
  return List<Map<String, dynamic>>.generate(count, (index) {
    final seconds = (index + 1) * 10;
    return <String, dynamic>{
      'thumbnail_id': index + 1,
      'media_id': mediaId,
      'offset_seconds': seconds,
      'image': <String, dynamic>{
        'id': index + 11,
        'origin': '/files/images/thumb-$seconds.webp',
        'small': '/files/images/thumb-$seconds.webp',
        'medium': '/files/images/thumb-$seconds.webp',
        'large': '/files/images/thumb-$seconds.webp',
      },
    };
  });
}

class _TestMoviePlayerSurface extends StatefulWidget {
  const _TestMoviePlayerSurface({
    required this.resolvedUrl,
    required this.surfaceController,
    required this.initialPosition,
    required this.seekRequests,
    required this.initialPositions,
    required this.onPositionChanged,
    required this.onPlayingChanged,
    required this.onBackPressed,
    this.readiness,
    this.emitPositionOnBuild,
  });

  final String resolvedUrl;
  final MoviePlayerSurfaceController surfaceController;
  final Duration? initialPosition;
  final List<Duration> seekRequests;
  final List<Duration?> initialPositions;
  final ValueChanged<Duration>? onPositionChanged;
  final ValueChanged<bool>? onPlayingChanged;
  final VoidCallback onBackPressed;
  final ValueNotifier<bool>? readiness;
  final Duration? emitPositionOnBuild;

  @override
  State<_TestMoviePlayerSurface> createState() =>
      _TestMoviePlayerSurfaceState();
}

class _TestMoviePlayerSurfaceState extends State<_TestMoviePlayerSurface> {
  StreamSubscription<Duration>? _subscription;

  @override
  void initState() {
    super.initState();
    widget.initialPositions.add(widget.initialPosition);
    _subscription = widget.surfaceController.seekStream.listen(
      widget.seekRequests.add,
    );
    widget.onPlayingChanged?.call(true);
    if (widget.emitPositionOnBuild != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.onPositionChanged?.call(widget.emitPositionOnBuild!);
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Text('surface:${widget.resolvedUrl}');
    final readiness = widget.readiness;
    final surface =
        readiness == null
            ? content
            : ValueListenableBuilder<bool>(
              valueListenable: readiness,
              builder: (context, isReady, child) {
                return MoviePlayerSurfaceFrame(isReady: isReady, child: child!);
              },
              child: content,
            );
    return Stack(
      children: [
        surface,
        Positioned(
          left: 0,
          top: 0,
          child: MoviePlayerBackOverlay(onPressed: widget.onBackPressed),
        ),
      ],
    );
  }
}

double _thumbnailBorderWidth(WidgetTester tester, int index) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.byKey(Key('movie-player-thumbnail-tile-$index-decoration')),
  );
  final decoration = decoratedBox.decoration as BoxDecoration;
  final border = decoration.border as Border;
  return border.top.width;
}

double _thumbnailScrollOffset(WidgetTester tester, Finder scrollableFinder) {
  final state = tester.state<ScrollableState>(scrollableFinder);
  return state.position.pixels;
}
