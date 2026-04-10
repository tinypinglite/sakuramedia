import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_player_page.dart';
import 'package:sakuramedia/features/movies/presentation/mobile_movie_player_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_back_overlay.dart';

import '../../../support/test_api_bundle.dart';

const List<String> _portraitOrientations = <String>[
  'DeviceOrientation.portraitUp',
  'DeviceOrientation.portraitDown',
];
const List<String> _landscapeOrientations = <String>[
  'DeviceOrientation.landscapeLeft',
  'DeviceOrientation.landscapeRight',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late List<List<String>> orientationCalls;
  late List<String> systemUiModeCalls;
  late List<List<String>> systemUiOverlayCalls;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    orientationCalls = <List<String>>[];
    systemUiModeCalls = <String>[];
    systemUiOverlayCalls = <List<String>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            final arguments = (call.arguments as List<dynamic>)
                .map((dynamic item) => item.toString())
                .toList(growable: false);
            orientationCalls.add(arguments);
          }
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            systemUiModeCalls.add(call.arguments.toString());
          }
          if (call.method == 'SystemChrome.setEnabledSystemUIOverlays') {
            final arguments = (call.arguments as List<dynamic>)
                .map((dynamic item) => item.toString())
                .toList(growable: false);
            systemUiOverlayCalls.add(arguments);
          }
          return Future<dynamic>.value(null);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    bundle.dispose();
  });

  testWidgets('mobile movie player locks landscape and restores portrait', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(540, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(mediaItems: const <Map<String, dynamic>>[]),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(
      _countOrientationCalls(orientationCalls, _landscapeOrientations),
      greaterThanOrEqualTo(1),
    );
    expect(
      _countUiModeCalls(systemUiModeCalls, 'SystemUiMode.immersiveSticky'),
      greaterThanOrEqualTo(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();

    expect(
      _countOrientationCalls(orientationCalls, _portraitOrientations),
      greaterThanOrEqualTo(1),
    );
    expect(
      _countVisibleOverlayCalls(systemUiOverlayCalls),
      greaterThanOrEqualTo(2),
    );
  });

  testWidgets('mobile movie player locks landscape and restores landscape', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(mediaItems: const <Map<String, dynamic>>[]),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(
      _countOrientationCalls(orientationCalls, _landscapeOrientations),
      greaterThanOrEqualTo(1),
    );
    expect(
      _countUiModeCalls(systemUiModeCalls, 'SystemUiMode.immersiveSticky'),
      greaterThanOrEqualTo(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();

    expect(
      _countOrientationCalls(orientationCalls, _landscapeOrientations),
      greaterThanOrEqualTo(2),
    );
    expect(
      _countVisibleOverlayCalls(systemUiOverlayCalls),
      greaterThanOrEqualTo(2),
    );
  });

  testWidgets('mobile movie player back falls back to movie detail route', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(
        mediaItems: const <Map<String, dynamic>>[
          <String, dynamic>{
            'media_id': 100,
            'play_url': '/files/media/movies/ABC-001/video.mp4',
            'path': '/library/main/ABC-001/video.mp4',
            'duration_seconds': 7200,
            'progress': null,
          },
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/100/thumbnails',
      body: const <String, dynamic>{'items': <Map<String, dynamic>>[]},
    );

    final router = GoRouter(
      initialLocation: buildMobileMoviePlayerRoutePath('ABC-001', mediaId: 100),
      routes: [
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber',
          builder:
              (_, state) => Text(
                'detail:${state.pathParameters['movieNumber']}',
                textDirection: TextDirection.ltr,
              ),
        ),
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber/player',
          builder:
              (_, state) => MobileMoviePlayerPage(
                movieNumber: state.pathParameters['movieNumber']!,
                initialMediaId: int.tryParse(
                  state.uri.queryParameters['mediaId'] ?? '',
                ),
                initialPositionSeconds: int.tryParse(
                  state.uri.queryParameters['positionSeconds'] ?? '',
                ),
                surfaceBuilder: (
                  BuildContext context,
                  String resolvedUrl,
                  surfaceController,
                  Duration? initialPosition,
                  ValueChanged<Duration>? onPositionChanged,
                  ValueChanged<bool>? onPlayingChanged,
                  subtitleState,
                  onSubtitleSelectionChanged,
                  onSubtitleReloadRequested,
                  VoidCallback onBackPressed,
                  bool useTouchOptimizedControls,
                ) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: MoviePlayerBackOverlay(onPressed: onBackPressed),
                  );
                },
              ),
        ),
      ],
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

  testWidgets('mobile movie player uses default adaptive controls', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(
        mediaItems: const <Map<String, dynamic>>[
          <String, dynamic>{
            'media_id': 100,
            'play_url': '/files/media/movies/ABC-001/video.mp4',
            'path': '/library/main/ABC-001/video.mp4',
            'duration_seconds': 7200,
            'progress': null,
          },
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/100/thumbnails',
      body: const <String, dynamic>{'items': <Map<String, dynamic>>[]},
    );

    bool? capturedUseTouchOptimizedControls;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
        ],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: MobileMoviePlayerPage(
              movieNumber: 'ABC-001',
              surfaceBuilder: (
                BuildContext context,
                String resolvedUrl,
                surfaceController,
                Duration? initialPosition,
                ValueChanged<Duration>? onPositionChanged,
                ValueChanged<bool>? onPlayingChanged,
                subtitleState,
                onSubtitleSelectionChanged,
                onSubtitleReloadRequested,
                VoidCallback onBackPressed,
                bool useTouchOptimizedControls,
              ) {
                capturedUseTouchOptimizedControls = useTouchOptimizedControls;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(capturedUseTouchOptimizedControls, isFalse);
    final desktopPlayer = tester.widget<DesktopMoviePlayerPage>(
      find.byType(DesktopMoviePlayerPage),
    );
    expect(desktopPlayer.enableThumbnailActionMenu, isTrue);
    expect(desktopPlayer.imageSearchRoutePath, mobileImageSearchPath);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(body: MobileMoviePlayerPage(movieNumber: 'ABC-001')),
      ),
    ),
  );
}

Map<String, dynamic> _movieDetailJson({
  required List<Map<String, dynamic>> mediaItems,
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
    'media_items': mediaItems,
  };
}

int _countOrientationCalls(List<List<String>> calls, List<String> expected) {
  return calls.where((call) => _sameOrientations(call, expected)).length;
}

bool _sameOrientations(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

int _countUiModeCalls(List<String> calls, String keyword) {
  return calls.where((call) => call.contains(keyword)).length;
}

int _countVisibleOverlayCalls(List<List<String>> calls) {
  return calls
      .where(
        (call) =>
            call.contains('SystemUiOverlay.top') &&
            call.contains('SystemUiOverlay.bottom'),
      )
      .length;
}
