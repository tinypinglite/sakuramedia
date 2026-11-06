import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_speed_button.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_subtitle_button.dart';

void main() {
  Widget app(Widget child) {
    return MaterialApp(
      theme: sakuraThemeData,
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: SizedBox(width: 160, height: 40, child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('倍速按钮打开菜单并回传选择的速率', (tester) async {
    double? selectedRate;
    await tester.pumpWidget(
      app(
        MoviePlayerSpeedButton(
          currentRate: 1.0,
          hasExplicitSelection: false,
          onRateSelected: (rate) async => selectedRate = rate,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('movie-player-speed-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('movie-player-speed-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('movie-player-speed-menu-item-1_5')));
    await tester.pumpAndSettle();

    expect(selectedRate, 1.5);
    expect(find.byKey(const Key('movie-player-speed-menu')), findsNothing);
  });

  testWidgets('字幕按钮打开菜单并回传选择的字幕', (tester) async {
    final subtitleState = ValueNotifier<MoviePlayerSubtitleState>(
      const MoviePlayerSubtitleState(
        options: <MoviePlayerSubtitleOption>[
          MoviePlayerSubtitleOption(
            subtitleId: 7,
            label: '中文',
            resolvedUrl: 'https://example.com/subtitle.vtt',
          ),
        ],
        selectedSubtitleId: null,
        isLoading: false,
        fetchStatus: 'ready',
        errorMessage: null,
      ),
    );
    final isApplying = ValueNotifier<bool>(false);
    addTearDown(subtitleState.dispose);
    addTearDown(isApplying.dispose);
    int? selectedSubtitleId;

    await tester.pumpWidget(
      app(
        MoviePlayerSubtitleButton(
          subtitleStateListenable: subtitleState,
          isApplyingListenable: isApplying,
          onSubtitleSelected: (subtitleId) async =>
              selectedSubtitleId = subtitleId,
          onReloadRequested: () async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('movie-player-subtitle-menu')), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('movie-player-subtitle-menu-item-7')),
    );
    await tester.pumpAndSettle();

    expect(selectedSubtitleId, 7);
    expect(find.byKey(const Key('movie-player-subtitle-menu')), findsNothing);
  });
}
