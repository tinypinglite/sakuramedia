import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_subtitle_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_subtitle_button.dart';

void main() {
  testWidgets('subtitle button shows off item and available subtitles', (
    WidgetTester tester,
  ) async {
    int? selectedSubtitleId;
    final subtitleStateNotifier = ValueNotifier<MoviePlayerSubtitleState>(
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
      ),
    );
    final isApplyingNotifier = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: MoviePlayerSubtitleButton(
            subtitleStateListenable: subtitleStateNotifier,
            isApplyingListenable: isApplyingNotifier,
            onSubtitleSelected: (subtitleId) async {
              selectedSubtitleId = subtitleId;
            },
            onReloadRequested: () async {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-player-subtitle-menu-off')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-player-subtitle-menu-item-501')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('movie-player-subtitle-menu-item-501')).last,
    );
    await tester.pumpAndSettle();

    expect(selectedSubtitleId, 501);

    subtitleStateNotifier.dispose();
    isApplyingNotifier.dispose();
  });

  testWidgets('subtitle button shows retry entry when subtitle fetch failed', (
    WidgetTester tester,
  ) async {
    var reloadCount = 0;
    final subtitleStateNotifier = ValueNotifier<MoviePlayerSubtitleState>(
      const MoviePlayerSubtitleState(
        options: <MoviePlayerSubtitleOption>[],
        selectedSubtitleId: null,
        isLoading: false,
        fetchStatus: 'failed',
        errorMessage: '字幕抓取失败',
      ),
    );
    final isApplyingNotifier = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: MoviePlayerSubtitleButton(
            subtitleStateListenable: subtitleStateNotifier,
            isApplyingListenable: isApplyingNotifier,
            onSubtitleSelected: (_) async {},
            onReloadRequested: () async {
              reloadCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-player-subtitle-menu-status')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-player-subtitle-menu-retry')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('movie-player-subtitle-menu-retry')).last,
    );
    await tester.pumpAndSettle();

    expect(reloadCount, 1);

    subtitleStateNotifier.dispose();
    isApplyingNotifier.dispose();
  });

  testWidgets('subtitle button reflects updated selected state from notifier', (
    WidgetTester tester,
  ) async {
    final subtitleStateNotifier = ValueNotifier<MoviePlayerSubtitleState>(
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
      ),
    );
    final isApplyingNotifier = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: MoviePlayerSubtitleButton(
            subtitleStateListenable: subtitleStateNotifier,
            isApplyingListenable: isApplyingNotifier,
            onSubtitleSelected: (_) async {},
            onReloadRequested: () async {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.subtitles_outlined), findsOneWidget);
    expect(find.byIcon(Icons.subtitles_rounded), findsNothing);

    subtitleStateNotifier.value = const MoviePlayerSubtitleState(
      options: <MoviePlayerSubtitleOption>[
        MoviePlayerSubtitleOption(
          subtitleId: 501,
          label: 'ABC-001.zh.srt',
          resolvedUrl: 'https://example.com/subtitles/501.srt',
        ),
      ],
      selectedSubtitleId: 501,
      isLoading: false,
      fetchStatus: 'succeeded',
      errorMessage: null,
    );
    await tester.pump();

    expect(find.byIcon(Icons.subtitles_outlined), findsNothing);
    expect(find.byIcon(Icons.subtitles_rounded), findsOneWidget);

    subtitleStateNotifier.dispose();
    isApplyingNotifier.dispose();
  });
}
