import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/media/playback_interleave.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_native_stats_sampler.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';

void main() {
  testWidgets('音视频交错行使用错误色强调', (tester) async {
    final sampler = MoviePlayerNativeStatsSampler(
      readNativeProperty: (_) async => null,
      originalUrl: 'https://api.example/media/1/play/',
    );
    addTearDown(sampler.dispose);
    sampler.updateInterleaveSignal(
      const PlaybackInterleaveSignal(
        cacheKey: 'media-1',
        source: PlaybackInterleaveSource.mp4Layout,
        maxDistanceBytes: 5 * 1024 * 1024 * 1024,
        spanBytes: 4 * 1024 * 1024 * 1024,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: sakuraDesktopThemeData,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: MoviePlayerPlaybackInfoPanel(
              infoListenable: sampler.snapshot,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final valueFinder = find.byKey(
      const Key('movie-player-info-value-interleave'),
    );
    expect(valueFinder, findsOneWidget);
    final text = tester.widget<Text>(valueFinder);
    final theme = Theme.of(tester.element(valueFinder));
    expect(text.style?.color, theme.appTextPalette.error);
    expect(
      text.style?.fontWeight,
      theme.appTextWeights.weightFor(AppTextWeight.semibold),
    );
  });
}
