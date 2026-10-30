import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/video/video_controls_theme.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';

/// 测试树的本地化 delegate：ARB 文案 + material_ui 的 Material/Cupertino 文案。
const List<LocalizationsDelegate<dynamic>> _testLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ];

void main() {
  group('Movie player controls theme', () {
    test(
      'controls builder resolves to the expected mobile or desktop controls',
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

    test(
      'mobile controls theme keeps progress visible while seek is disabled',
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
      },
    );

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
          locale: const Locale('zh'),
          localizationsDelegates: _testLocalizationsDelegates,
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
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

    testWidgets('buffering indicator can be hidden before the first frame', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: _testLocalizationsDelegates,
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: Builder(
            builder: (context) => Column(
              children: [
                buildMoviePlayerMobileControlsThemeData(
                  theme: Theme.of(context),
                  topControls: const <Widget>[],
                  bottomControls: const <Widget>[],
                  showBufferingIndicator: false,
                ).bufferingIndicatorBuilder!(context),
                buildMoviePlayerDesktopControlsThemeData(
                  theme: Theme.of(context),
                  topControls: const <Widget>[],
                  bottomControls: const <Widget>[],
                  showBufferingIndicator: false,
                ).bufferingIndicatorBuilder!(context),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(VideoLoadingIndicator), findsNothing);
      expect(find.text('正在缓冲…'), findsNothing);
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

    test('desktop controls theme replaces built-in seek bar with cluster', () {
      const top = SizedBox(key: Key('top-control'));
      const bottom = MaterialDesktopFullscreenButton();
      const seekBar = SizedBox(key: Key('bottom-seek-bar'));
      final themeData = buildMoviePlayerDesktopControlsThemeData(
        theme: ThemeData.light(),
        topControls: <Widget>[top],
        bottomControls: <Widget>[bottom],
        bottomSeekBar: seekBar,
      );

      expect(themeData.displaySeekBar, isFalse);
      expect(themeData.seekBarMargin, EdgeInsets.zero);
      expect(themeData.buttonBarHeight, 92);
      expect(themeData.topButtonBar, hasLength(1));
      expect(themeData.topButtonBar.first, isA<Expanded>());
      expect(themeData.bottomButtonBar, hasLength(1));
      final cluster =
          (themeData.bottomButtonBar.first as Expanded).child as Column;
      expect(cluster.children.first, same(seekBar));
      final buttonRow = cluster.children.last as SizedBox;
      expect((buttonRow.child! as Row).children.first, same(bottom));
    });

    test('reserveTopRightToggle 为右上角面板开关让位，避免与信息按钮重叠', () {
      final overlay = sakuraThemeData.appOverlayTokens;
      final spacing = sakuraThemeData.appSpacing;
      final reserve = overlay.playerBackBadgeMinHeight + spacing.sm;

      final mobile = buildMoviePlayerMobileControlsThemeData(
        theme: sakuraThemeData,
        topControls: const <Widget>[],
        bottomControls: const <Widget>[],
        reserveTopRightToggle: true,
      );
      expect(
        mobile.topButtonBarMargin.right,
        overlay.playerControlBarHorizontalInset + reserve,
      );

      final desktop = buildMoviePlayerDesktopControlsThemeData(
        theme: sakuraThemeData,
        topControls: const <Widget>[],
        bottomControls: const <Widget>[],
        reserveTopRightToggle: true,
      );
      expect(
        desktop.topButtonBarMargin.right,
        overlay.playerControlBarHorizontalInset + reserve,
      );
    });
  });
}
