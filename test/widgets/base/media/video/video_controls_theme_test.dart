import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/video/video_controls_theme.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';

void main() {
  group('Movie player controls theme', () {
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

    test('mobile controls theme keeps progress visible while seek is disabled',
        () {
      final themeData = buildMoviePlayerMobileControlsThemeData(
        theme: ThemeData.light(),
        topControls: const <Widget>[],
        bottomControls: const <Widget>[],
        seekEnabled: false,
      );

      expect(themeData.displaySeekBar, isTrue);
      expect(themeData.seekGesture, isFalse);
      expect(themeData.seekOnDoubleTap, isFalse);
    });

    test('desktop controls theme keeps the built-in progress bar visible', () {
      final themeData = buildMoviePlayerDesktopControlsThemeData(
        theme: ThemeData.light(),
        topControls: const <Widget>[],
        bottomControls: const <Widget>[],
      );

      expect(themeData.displaySeekBar, isTrue);
    });

    testWidgets('mobile and desktop controls share the buffering indicator', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Builder(
            builder: (context) => Column(
              children: [
                buildMoviePlayerMobileControlsThemeData(
                  theme: Theme.of(context),
                  topControls: const <Widget>[],
                  bottomControls: const <Widget>[],
                ).bufferingIndicatorBuilder!(context),
                buildMoviePlayerDesktopControlsThemeData(
                  theme: Theme.of(context),
                  topControls: const <Widget>[],
                  bottomControls: const <Widget>[],
                ).bufferingIndicatorBuilder!(context),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(VideoLoadingIndicator), findsNWidgets(2));
      expect(find.text('正在缓冲…'), findsNWidgets(2));
    });

    test('mobile controls theme supports top and bottom button bars', () {
      const top = SizedBox(key: Key('top-control'));
      const bottom = MaterialPlayOrPauseButton();
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

    test('desktop controls theme supports top and bottom button bars', () {
      const top = SizedBox(key: Key('top-control'));
      const bottom = MaterialDesktopFullscreenButton();
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
