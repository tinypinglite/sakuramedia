import 'dart:async';

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

    test('mobile bottom controls omit subtitle and speed buttons', () {
      final controls = buildMoviePlayerMobileBottomControls();

      expect(controls, hasLength(5));
      expect(controls.whereType<MoviePlayerSpeedButton>(), isEmpty);
      expect(controls.whereType<MoviePlayerSubtitleButton>(), isEmpty);
      expect(controls.last, isA<MaterialFullscreenButton>());
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
