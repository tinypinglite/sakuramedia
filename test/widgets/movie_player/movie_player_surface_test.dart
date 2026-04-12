import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_subtitle_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_speed_button.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_subtitle_button.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface_readiness.dart';

void main() {
  group('MoviePlayerSurfaceReadiness', () {
    test('starts as not ready', () {
      final readiness = MoviePlayerSurfaceReadiness();

      expect(readiness.isReady, isFalse);
    });

    test('markReady flips readiness to true', () {
      final readiness = MoviePlayerSurfaceReadiness();

      readiness.markReady();

      expect(readiness.isReady, isTrue);
    });

    test('reset returns readiness to false', () {
      final readiness = MoviePlayerSurfaceReadiness();
      readiness.markReady();

      readiness.reset();

      expect(readiness.isReady, isFalse);
    });
  });

  group('MoviePlayerSurfaceFrame', () {
    testWidgets('shows a black readiness mask while surface is not ready', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MoviePlayerSurfaceFrame(
              isReady: false,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final mask = tester.widget<ColoredBox>(
        find.byKey(const Key('movie-player-surface-ready-mask')),
      );

      expect(
        mask.color,
        sakuraThemeData.appColors.movieDetailHeroBackgroundStart,
      );
    });

    testWidgets('hides readiness mask once the surface is ready', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MoviePlayerSurfaceFrame(
              isReady: true,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-player-surface-ready-mask')),
        findsNothing,
      );
    });
  });

  group('MoviePlayerSurfaceOpenCoordinator', () {
    test(
      'opens paused with requested start position, then starts playback',
      () async {
        final driver = _FakeMoviePlayerSurfacePlaybackDriver();
        var markedReady = false;

        await const MoviePlayerSurfaceOpenCoordinator().open(
          driver: driver,
          resolvedUrl: 'https://example.com/video.mp4',
          initialPosition: const Duration(seconds: 61),
          shouldContinue: () => true,
          markReady: () => markedReady = true,
        );

        expect(driver.operations, <String>[
          'open:https://example.com/video.mp4:start=0:01:01.000000:play=false',
          'play',
          'waitUntilFirstFrameRendered',
          'seek:0:01:01.000000',
        ]);
        expect(markedReady, isTrue);
      },
    );

    test(
      'starts playback without seek when no initial position is provided',
      () async {
        final driver = _FakeMoviePlayerSurfacePlaybackDriver();

        await const MoviePlayerSurfaceOpenCoordinator().open(
          driver: driver,
          resolvedUrl: 'https://example.com/video.mp4',
          initialPosition: null,
          shouldContinue: () => true,
          markReady: () {},
        );

        expect(driver.operations, <String>[
          'open:https://example.com/video.mp4:start=null:play=false',
          'play',
          'waitUntilFirstFrameRendered',
        ]);
      },
    );

    test(
      'stops before follow-up actions when request is no longer current',
      () async {
        final driver = _FakeMoviePlayerSurfacePlaybackDriver();
        var shouldContinue = true;
        var markedReady = false;
        driver.onAfterOpen = () {
          shouldContinue = false;
        };

        await const MoviePlayerSurfaceOpenCoordinator().open(
          driver: driver,
          resolvedUrl: 'https://example.com/video.mp4',
          initialPosition: const Duration(seconds: 12),
          shouldContinue: () => shouldContinue,
          markReady: () => markedReady = true,
        );

        expect(driver.operations, <String>[
          'open:https://example.com/video.mp4:start=0:00:12.000000:play=false',
        ]);
        expect(markedReady, isFalse);
      },
    );

    test(
      'stops before readiness when request becomes stale after first frame',
      () async {
        final driver = _FakeMoviePlayerSurfacePlaybackDriver();
        var shouldContinue = true;
        var markedReady = false;
        driver.onAfterWaitUntilFirstFrameRendered = () {
          shouldContinue = false;
        };

        await const MoviePlayerSurfaceOpenCoordinator().open(
          driver: driver,
          resolvedUrl: 'https://example.com/video.mp4',
          initialPosition: const Duration(seconds: 12),
          shouldContinue: () => shouldContinue,
          markReady: () => markedReady = true,
        );

        expect(driver.operations, <String>[
          'open:https://example.com/video.mp4:start=0:00:12.000000:play=false',
          'play',
          'waitUntilFirstFrameRendered',
        ]);
        expect(markedReady, isFalse);
      },
    );
  });

  group('MoviePlayerSurfaceSubtitleCoordinator', () {
    test('applies external subtitle data and returns the selected id', () async {
      final driver = _FakeMoviePlayerSurfacePlaybackDriver();
      const subtitleText = '1\n00:00:01,000 --> 00:00:02,000\nhello\n';

      final result = await const MoviePlayerSurfaceSubtitleCoordinator()
          .applySelection(
            driver: driver,
            selectedOption: const MoviePlayerSubtitleOption(
              subtitleId: 501,
              label: 'ABC-001.zh.srt',
              resolvedUrl: 'https://example.com/subtitles/501.srt',
              title: 'ABC-001.zh.srt',
            ),
            loadSubtitleText: (_) async => subtitleText,
            onError: () {},
          );

      expect(result, 501);
      expect(
        driver.operations,
        contains(
          'subtitle:$subtitleText:title=ABC-001.zh.srt:language=null:uri=false:data=true',
        ),
      );
    });

    test('disables subtitles when null is selected', () async {
      final driver = _FakeMoviePlayerSurfacePlaybackDriver();

      final result = await const MoviePlayerSurfaceSubtitleCoordinator()
          .applySelection(
            driver: driver,
            selectedOption: null,
            loadSubtitleText: (_) async => throw UnimplementedError(),
            onError: () {},
          );

      expect(result, isNull);
      expect(driver.operations, <String>[
        'subtitle:no:title=null:language=null:uri=false:data=false',
      ]);
    });

    test(
      'falls back to no subtitle and emits error when subtitle load fails',
      () async {
        final driver =
            _FakeMoviePlayerSurfacePlaybackDriver()
              ..failNextSubtitleSelection = true;
        var didError = false;

        final result = await const MoviePlayerSurfaceSubtitleCoordinator()
            .applySelection(
              driver: driver,
              selectedOption: const MoviePlayerSubtitleOption(
                subtitleId: 501,
                label: 'ABC-001.zh.srt',
                resolvedUrl: 'https://example.com/subtitles/501.srt',
              ),
              loadSubtitleText:
                  (_) async => '1\n00:00:01,000 --> 00:00:02,000\nhello\n',
              onError: () => didError = true,
            );

        expect(result, isNull);
        expect(didError, isTrue);
        expect(driver.operations, <String>[
          'subtitle:1\n00:00:01,000 --> 00:00:02,000\nhello\n:title=null:language=null:uri=false:data=true',
          'subtitle:no:title=null:language=null:uri=false:data=false',
        ]);
      },
    );

    test(
      'falls back to no subtitle and emits error when subtitle text load fails',
      () async {
        final driver = _FakeMoviePlayerSurfacePlaybackDriver();
        var didError = false;

        final result = await const MoviePlayerSurfaceSubtitleCoordinator()
            .applySelection(
              driver: driver,
              selectedOption: const MoviePlayerSubtitleOption(
                subtitleId: 501,
                label: 'ABC-001.zh.srt',
                resolvedUrl: 'https://example.com/subtitles/501.srt',
              ),
              loadSubtitleText: (_) async => throw const FormatException('bad'),
              onError: () => didError = true,
            );

        expect(result, isNull);
        expect(didError, isTrue);
        expect(driver.operations, <String>[
          'subtitle:no:title=null:language=null:uri=false:data=false',
        ]);
      },
    );
  });

  group('Touch Optimized Controls', () {
    test(
      'controls builder resolves to mobile or desktop media_kit controls',
      () {
        expect(
          resolveMoviePlayerVideoControlsBuilder(
            useTouchOptimizedControls: true,
          ),
          buildMoviePlayerMobileVideoControls,
        );
        expect(
          resolveMoviePlayerVideoControlsBuilder(
            useTouchOptimizedControls: false,
          ),
          buildMoviePlayerDesktopVideoControls,
        );
      },
    );

    test('mobile controls theme keeps expected seek sizing and gestures', () {
      final themeData = buildMoviePlayerMobileControlsThemeData(
        theme: ThemeData.light(),
        topControls: const <Widget>[],
        bottomControls: const <Widget>[],
      );

      expect(themeData.seekGesture, isTrue);
      expect(themeData.seekBarThumbSize, 14);
      expect(themeData.seekBarMargin, const EdgeInsets.fromLTRB(30, 0, 30, 75));
      expect(themeData.volumeGesture, isTrue);
      expect(themeData.brightnessGesture, isTrue);
      expect(themeData.seekOnDoubleTap, isTrue);
    });

    test('top controls render back button then current movie number', () {
      final controls = buildMoviePlayerTopControls(
        movieNumber: 'ABP-123',
        onBackPressed: () {},
      );

      expect(controls, hasLength(1));
      expect(controls[0], isA<MoviePlayerBackWithNumberControl>());
      expect(
        (controls[0] as MoviePlayerBackWithNumberControl).movieNumber,
        'ABP-123',
      );
    });

    test('top controls stay empty without a back callback', () {
      final controls = buildMoviePlayerTopControls(
        movieNumber: 'ABP-123',
        onBackPressed: null,
      );

      expect(controls, isEmpty);
    });

    test('mobile controls theme supports top and bottom button bars', () {
      final top = MoviePlayerBackButton(onPressed: () {});
      final bottom = const MaterialPlayOrPauseButton();
      final themeData = buildMoviePlayerMobileControlsThemeData(
        theme: ThemeData.light(),
        topControls: <Widget>[top],
        bottomControls: <Widget>[bottom],
      );

      expect(themeData.topButtonBar, hasLength(1));
      expect(themeData.topButtonBar.first, same(top));
      expect(themeData.bottomButtonBar, hasLength(1));
      expect(themeData.bottomButtonBar.first, same(bottom));
    });

    test(
      'mobile bottom controls place speed and subtitle before fullscreen',
      () {
        final speedDisplay = ValueNotifier<MoviePlayerMobileSpeedDisplayState>(
          const MoviePlayerMobileSpeedDisplayState(
            rate: 1.0,
            hasExplicitSelection: false,
          ),
        );
        addTearDown(speedDisplay.dispose);
        final controls = buildMoviePlayerMobileBottomControls(
          activeDrawer: null,
          speedDisplayListenable: speedDisplay,
          onSpeedButtonPressed: () {},
          onSubtitleButtonPressed: () {},
        );

        expect(controls, hasLength(7));
        expect(controls[4].key, isNull);
        expect(
          controls[5].key,
          const Key('movie-player-mobile-subtitle-button'),
        );
        expect(controls[6], isA<MaterialFullscreenButton>());
      },
    );

    testWidgets(
      'mobile speed button updates label from notifier without parent rebuild',
      (WidgetTester tester) async {
        final speedDisplay = ValueNotifier<MoviePlayerMobileSpeedDisplayState>(
          const MoviePlayerMobileSpeedDisplayState(
            rate: 1.0,
            hasExplicitSelection: false,
          ),
        );
        addTearDown(speedDisplay.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: Row(
                children: buildMoviePlayerMobileDrawerToggleButtons(
                  activeDrawer: null,
                  speedDisplayListenable: speedDisplay,
                  onSpeedButtonPressed: () {},
                  onSubtitleButtonPressed: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('倍速'), findsOneWidget);
        speedDisplay.value = const MoviePlayerMobileSpeedDisplayState(
          rate: 1.5,
          hasExplicitSelection: true,
        );
        await tester.pump();
        expect(find.text('1.5x'), findsOneWidget);
        expect(find.text('倍速'), findsNothing);
      },
    );

    testWidgets('mobile speed button keeps 1.0x after explicit selection', (
      WidgetTester tester,
    ) async {
      final speedDisplay = ValueNotifier<MoviePlayerMobileSpeedDisplayState>(
        const MoviePlayerMobileSpeedDisplayState(
          rate: 1.0,
          hasExplicitSelection: true,
        ),
      );
      addTearDown(speedDisplay.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Row(
              children: buildMoviePlayerMobileDrawerToggleButtons(
                activeDrawer: null,
                speedDisplayListenable: speedDisplay,
                onSpeedButtonPressed: () {},
                onSubtitleButtonPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('倍速'), findsNothing);
    });

    testWidgets('mobile drawer opens speed panel and toggles closed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _MoviePlayerMobileDrawerHarness());

      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('movie-player-mobile-speed-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('movie-player-mobile-speed-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsNothing,
      );
    });

    testWidgets('mobile drawer switches from speed to subtitle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _MoviePlayerMobileDrawerHarness());

      await tester.tap(
        find.byKey(const Key('movie-player-mobile-speed-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('movie-player-mobile-subtitle-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('movie-player-mobile-subtitle-drawer')),
        findsOneWidget,
      );
    });

    testWidgets('mobile drawer closes when tapping outside panel area', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _MoviePlayerMobileDrawerHarness());

      await tester.tap(
        find.byKey(const Key('movie-player-mobile-speed-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsNothing,
      );
    });

    testWidgets('mobile drawer is anchored to player area right edge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                key: const Key('movie-player-mobile-anchor-area'),
                width: 240,
                height: 420,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Colors.black),
                    buildMoviePlayerMobileDrawerOverlay(
                      activeDrawer: MoviePlayerMobileDrawerType.speed,
                      subtitleState: MoviePlayerSubtitleState.empty,
                      currentRate: 1.0,
                      isApplyingSubtitle: false,
                      onDismiss: () {},
                      onRateSelected: (_) async {},
                      onSubtitleSelected: (_) async {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final anchorRect = tester.getRect(
        find.byKey(const Key('movie-player-mobile-anchor-area')),
      );
      final drawerRect = tester.getRect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
      );

      expect(drawerRect.right, lessThanOrEqualTo(anchorRect.right));
      expect(drawerRect.left, greaterThan(anchorRect.left));
      expect(drawerRect.top, equals(anchorRect.top));
      expect(drawerRect.bottom, equals(anchorRect.bottom));
    });

    test('desktop controls theme supports top and bottom button bars', () {
      final top = MoviePlayerBackButton(onPressed: () {});
      final bottom = const MaterialDesktopFullscreenButton();
      final themeData = buildMoviePlayerDesktopControlsThemeData(
        theme: ThemeData.light(),
        topControls: <Widget>[top],
        bottomControls: <Widget>[bottom],
      );

      expect(themeData.topButtonBar, hasLength(1));
      expect(themeData.topButtonBar.first, same(top));
      expect(themeData.bottomButtonBar, hasLength(1));
      expect(themeData.bottomButtonBar.first, same(bottom));
    });

    test('desktop bottom controls place speed before subtitle button', () {
      final subtitleState = ValueNotifier<MoviePlayerSubtitleState>(
        MoviePlayerSubtitleState.empty,
      );
      final isApplying = ValueNotifier<bool>(false);
      addTearDown(subtitleState.dispose);
      addTearDown(isApplying.dispose);

      final controls = buildMoviePlayerDesktopBottomControls(
        currentRate: 1.0,
        hasExplicitSelection: false,
        onRateSelected: (_) async {},
        subtitleStateListenable: subtitleState,
        isApplyingListenable: isApplying,
        onSubtitleSelected: (_) async {},
        onSubtitleReloadRequested: () async {},
      );

      expect(controls, hasLength(7));
      final speedButton = controls[4] as MoviePlayerSpeedButton;
      expect(speedButton, isA<MoviePlayerSpeedButton>());
      expect(speedButton.hasExplicitSelection, isFalse);
      expect(controls[5], isA<MoviePlayerSubtitleButton>());
      expect(controls[6], isA<MaterialFullscreenButton>());
    });
  });

  group('Movie player configuration', () {
    test('desktop configuration enables libass subtitles', () {
      expect(
        buildMoviePlayerConfiguration(
          isWeb: false,
          platform: TargetPlatform.macOS,
        ).libass,
        isTrue,
      );
      expect(
        buildMoviePlayerConfiguration(
          isWeb: false,
          platform: TargetPlatform.windows,
        ).libass,
        isTrue,
      );
      expect(
        buildMoviePlayerConfiguration(
          isWeb: false,
          platform: TargetPlatform.linux,
        ).libass,
        isTrue,
      );
    });

    test('mobile and web configuration keep libass disabled', () {
      expect(
        buildMoviePlayerConfiguration(
          isWeb: false,
          platform: TargetPlatform.android,
        ).libass,
        isFalse,
      );
      expect(
        buildMoviePlayerConfiguration(
          isWeb: false,
          platform: TargetPlatform.iOS,
        ).libass,
        isFalse,
      );
      expect(
        buildMoviePlayerConfiguration(
          isWeb: true,
          platform: TargetPlatform.macOS,
        ).libass,
        isFalse,
      );
    });
  });
}

class _MoviePlayerMobileDrawerHarness extends StatefulWidget {
  const _MoviePlayerMobileDrawerHarness();

  @override
  State<_MoviePlayerMobileDrawerHarness> createState() =>
      _MoviePlayerMobileDrawerHarnessState();
}

class _MoviePlayerMobileDrawerHarnessState
    extends State<_MoviePlayerMobileDrawerHarness> {
  MoviePlayerMobileDrawerType? _activeDrawer;
  int? _selectedSubtitleId;
  final ValueNotifier<MoviePlayerMobileSpeedDisplayState>
  _speedDisplayNotifier = ValueNotifier<MoviePlayerMobileSpeedDisplayState>(
    const MoviePlayerMobileSpeedDisplayState(
      rate: 1.0,
      hasExplicitSelection: false,
    ),
  );

  final MoviePlayerSubtitleState _subtitleState =
      const MoviePlayerSubtitleState(
        options: <MoviePlayerSubtitleOption>[
          MoviePlayerSubtitleOption(
            subtitleId: 501,
            label: 'ABC-001.zh.srt',
            resolvedUrl: 'https://example.com/subtitles/501.srt',
          ),
        ],
        selectedSubtitleId: null,
        isLoading: false,
        fetchStatus: 'succeeded',
        errorMessage: null,
      );

  @override
  void dispose() {
    _speedDisplayNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitleState = MoviePlayerSubtitleState(
      options: _subtitleState.options,
      selectedSubtitleId: _selectedSubtitleId,
      isLoading: false,
      fetchStatus: 'succeeded',
      errorMessage: null,
    );
    return MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              buildMoviePlayerMobileDrawerOverlay(
                activeDrawer: _activeDrawer,
                subtitleState: subtitleState,
                currentRate: _speedDisplayNotifier.value.rate,
                isApplyingSubtitle: false,
                onDismiss: () => setState(() => _activeDrawer = null),
                onRateSelected: (rate) async {
                  setState(() {
                    _activeDrawer = null;
                  });
                  _speedDisplayNotifier
                      .value = MoviePlayerMobileSpeedDisplayState(
                    rate: rate,
                    hasExplicitSelection: true,
                  );
                },
                onSubtitleSelected: (subtitleId) async {
                  setState(() {
                    _selectedSubtitleId = subtitleId;
                    _activeDrawer = null;
                  });
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: 420,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: buildMoviePlayerMobileDrawerToggleButtons(
                        activeDrawer: _activeDrawer,
                        speedDisplayListenable: _speedDisplayNotifier,
                        onSpeedButtonPressed:
                            () => setState(() {
                              _activeDrawer =
                                  _activeDrawer ==
                                          MoviePlayerMobileDrawerType.speed
                                      ? null
                                      : MoviePlayerMobileDrawerType.speed;
                            }),
                        onSubtitleButtonPressed:
                            () => setState(() {
                              _activeDrawer =
                                  _activeDrawer ==
                                          MoviePlayerMobileDrawerType.subtitle
                                      ? null
                                      : MoviePlayerMobileDrawerType.subtitle;
                            }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FakeMoviePlayerSurfacePlaybackDriver
    implements MoviePlayerSurfacePlaybackDriver {
  final List<String> operations = <String>[];
  VoidCallback? onAfterOpen;
  VoidCallback? onAfterWaitUntilFirstFrameRendered;
  bool failNextSubtitleSelection = false;

  @override
  Future<void> open(
    String resolvedUrl, {
    required Duration? startPosition,
    required bool play,
  }) async {
    operations.add('open:$resolvedUrl:start=$startPosition:play=$play');
    onAfterOpen?.call();
  }

  @override
  Future<void> play() async {
    operations.add('play');
  }

  @override
  Future<void> seek(Duration position) async {
    operations.add('seek:$position');
  }

  @override
  Future<void> waitUntilFirstFrameRendered() async {
    operations.add('waitUntilFirstFrameRendered');
    onAfterWaitUntilFirstFrameRendered?.call();
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    operations.add(
      'subtitle:${track.id}:title=${track.title}:language=${track.language}:uri=${track.uri}:data=${track.data}',
    );
    if (failNextSubtitleSelection && (track.uri || track.data)) {
      failNextSubtitleSelection = false;
      throw StateError('subtitle failure');
    }
  }
}
