import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_back_overlay.dart';
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

  group('Touch Optimized Controls', () {
    test('controls builder always resolves to adaptive controls', () {
      expect(
        resolveMoviePlayerVideoControlsBuilder(useTouchOptimizedControls: true),
        AdaptiveVideoControls,
      );
      expect(
        resolveMoviePlayerVideoControlsBuilder(
          useTouchOptimizedControls: false,
        ),
        AdaptiveVideoControls,
      );
    });

    test(
      'material controls theme keeps default seek sizing for touch flag',
      () {
        final themeData = buildMoviePlayerMaterialControlsThemeData(
          theme: ThemeData.light(),
          topControls: const <Widget>[],
          bottomControls: const <Widget>[],
          useTouchOptimizedControls: true,
        );

        expect(themeData.seekGesture, isTrue);
        expect(themeData.seekBarThumbSize, 14);
        expect(
          themeData.seekBarMargin,
          const EdgeInsets.fromLTRB(30, 0, 30, 75),
        );
        expect(themeData.volumeGesture, isTrue);
        expect(themeData.brightnessGesture, isTrue);
        expect(themeData.seekOnDoubleTap, isTrue);
      },
    );

    test('default material controls theme keeps desktop seek sizing', () {
      final themeData = buildMoviePlayerMaterialControlsThemeData(
        theme: ThemeData.light(),
        topControls: const <Widget>[],
        bottomControls: const <Widget>[],
        useTouchOptimizedControls: false,
      );

      expect(themeData.seekGesture, isTrue);
      expect(themeData.seekBarThumbSize, 14);
      expect(themeData.seekBarMargin, const EdgeInsets.fromLTRB(30, 0, 30, 75));
    });

    test('material controls theme supports top and bottom button bars', () {
      final top = MoviePlayerBackButton(onPressed: () {});
      final bottom = const MaterialPlayOrPauseButton();
      final themeData = buildMoviePlayerMaterialControlsThemeData(
        theme: ThemeData.light(),
        topControls: <Widget>[top],
        bottomControls: <Widget>[bottom],
        useTouchOptimizedControls: false,
      );

      expect(themeData.topButtonBar, hasLength(1));
      expect(themeData.topButtonBar.first, same(top));
      expect(themeData.bottomButtonBar, hasLength(1));
      expect(themeData.bottomButtonBar.first, same(bottom));
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
  });
}

class _FakeMoviePlayerSurfacePlaybackDriver
    implements MoviePlayerSurfacePlaybackDriver {
  final List<String> operations = <String>[];
  VoidCallback? onAfterOpen;
  VoidCallback? onAfterWaitUntilFirstFrameRendered;

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
}
