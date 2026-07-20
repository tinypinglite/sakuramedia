import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_surface_readiness.dart';

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
      expect(find.byType(VideoLoadingIndicator), findsOneWidget);
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
}
