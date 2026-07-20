import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_controls.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawers.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_speed_button.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_subtitle_button.dart';

void main() {
  group('Movie player controls', () {
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

    test(
      'top controls include right info button when callback is provided',
      () {
        final controls = buildMoviePlayerTopControls(
          movieNumber: 'ABP-123',
          onBackPressed: () {},
          onInfoPressed: () {},
        );

        expect(controls, hasLength(3));
        expect(controls[0], isA<MoviePlayerBackWithNumberControl>());
        expect(controls[1], isA<Spacer>());
        expect(controls[2], isA<MoviePlayerInfoButton>());
      },
    );

    test('top controls can render info button without back callback', () {
      final controls = buildMoviePlayerTopControls(
        movieNumber: 'ABP-123',
        onBackPressed: null,
        onInfoPressed: () {},
      );

      expect(controls, hasLength(1));
      expect(controls[0], isA<MoviePlayerInfoButton>());
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
}
