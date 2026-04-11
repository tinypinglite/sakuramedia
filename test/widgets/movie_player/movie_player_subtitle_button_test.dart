import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_subtitle_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_subtitle_button.dart';

void main() {
  group('MoviePlayerSubtitleButton', () {
    testWidgets('shows available subtitles only on tap', (
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
      addTearDown(subtitleStateNotifier.dispose);
      addTearDown(isApplyingNotifier.dispose);

      await _pumpHarness(
        tester,
        subtitleStateListenable: subtitleStateNotifier,
        isApplyingListenable: isApplyingNotifier,
        onSubtitleSelected: (subtitleId) async {
          selectedSubtitleId = subtitleId;
        },
      );

      await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-player-subtitle-menu')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-player-subtitle-menu-item-501')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-player-subtitle-menu-off')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('movie-player-subtitle-menu-status')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('movie-player-subtitle-menu-retry')),
        findsNothing,
      );

      final itemGestureDetector = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.byKey(const Key('movie-player-subtitle-menu-item-501')),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      itemGestureDetector.onTap?.call();
      await tester.pumpAndSettle();

      expect(selectedSubtitleId, 501);
    });

    testWidgets('shows menu on hover', (WidgetTester tester) async {
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
      addTearDown(subtitleStateNotifier.dispose);
      addTearDown(isApplyingNotifier.dispose);

      await _pumpHarness(
        tester,
        subtitleStateListenable: subtitleStateNotifier,
        isApplyingListenable: isApplyingNotifier,
        onSubtitleSelected: (_) async {},
      );
      final gesture = await _createMouseGesture(tester);

      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-subtitle-button')),
      );

      expect(
        find.byKey(const Key('movie-player-subtitle-menu')),
        findsOneWidget,
      );
    });

    testWidgets('closes menu when tapping outside', (
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
      addTearDown(subtitleStateNotifier.dispose);
      addTearDown(isApplyingNotifier.dispose);

      await _pumpHarness(
        tester,
        subtitleStateListenable: subtitleStateNotifier,
        isApplyingListenable: isApplyingNotifier,
        onSubtitleSelected: (_) async {},
      );

      await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-subtitle-menu')),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-player-subtitle-menu')), findsNothing);
    });

    testWidgets('keeps menu open when pointer moves from button to menu', (
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
      addTearDown(subtitleStateNotifier.dispose);
      addTearDown(isApplyingNotifier.dispose);

      await _pumpHarness(
        tester,
        subtitleStateListenable: subtitleStateNotifier,
        isApplyingListenable: isApplyingNotifier,
        onSubtitleSelected: (_) async {},
      );
      final gesture = await _createMouseGesture(tester);

      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-subtitle-button')),
      );
      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-subtitle-menu')),
      );
      await tester.pump(const Duration(milliseconds: 40));

      expect(
        find.byKey(const Key('movie-player-subtitle-menu')),
        findsOneWidget,
      );
    });

    testWidgets(
      'keeps menu open when pointer moves slightly above single-item menu',
      (WidgetTester tester) async {
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
        addTearDown(subtitleStateNotifier.dispose);
        addTearDown(isApplyingNotifier.dispose);

        await _pumpHarness(
          tester,
          subtitleStateListenable: subtitleStateNotifier,
          isApplyingListenable: isApplyingNotifier,
          onSubtitleSelected: (_) async {},
        );
        final gesture = await _createMouseGesture(tester);

        await _moveMouseToFinder(
          tester,
          gesture,
          find.byKey(const Key('movie-player-subtitle-button')),
        );
        final menuRect = tester.getRect(
          find.byKey(const Key('movie-player-subtitle-menu')),
        );
        await gesture.moveTo(Offset(menuRect.center.dx, menuRect.top - 20));
        await tester.pump();

        expect(
          find.byKey(const Key('movie-player-subtitle-menu')),
          findsOneWidget,
        );
      },
    );

    testWidgets('menu sits above the button with a fixed 6px gap', (
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
      addTearDown(subtitleStateNotifier.dispose);
      addTearDown(isApplyingNotifier.dispose);

      await _pumpHarness(
        tester,
        subtitleStateListenable: subtitleStateNotifier,
        isApplyingListenable: isApplyingNotifier,
        onSubtitleSelected: (_) async {},
      );

      await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
      await tester.pumpAndSettle();

      final menuRect = tester.getRect(
        find.byKey(const Key('movie-player-subtitle-menu')),
      );
      final buttonRect = tester.getRect(
        find.byKey(const Key('movie-player-subtitle-button')),
      );
      expect(buttonRect.top - menuRect.bottom, inInclusiveRange(0.0, 8.0));
    });

    testWidgets('closes menu when pointer moves beyond hover tolerance area', (
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
      addTearDown(subtitleStateNotifier.dispose);
      addTearDown(isApplyingNotifier.dispose);

      await _pumpHarness(
        tester,
        subtitleStateListenable: subtitleStateNotifier,
        isApplyingListenable: isApplyingNotifier,
        onSubtitleSelected: (_) async {},
      );
      final gesture = await _createMouseGesture(tester);

      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-subtitle-button')),
      );
      final menuRect = tester.getRect(
        find.byKey(const Key('movie-player-subtitle-menu')),
      );
      await gesture.moveTo(Offset(menuRect.center.dx, menuRect.top - 120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byKey(const Key('movie-player-subtitle-menu')), findsNothing);
    });

    testWidgets('closes menu after pointer leaves button and menu region', (
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
      addTearDown(subtitleStateNotifier.dispose);
      addTearDown(isApplyingNotifier.dispose);

      await _pumpHarness(
        tester,
        subtitleStateListenable: subtitleStateNotifier,
        isApplyingListenable: isApplyingNotifier,
        onSubtitleSelected: (_) async {},
      );
      final gesture = await _createMouseGesture(tester);

      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-subtitle-button')),
      );
      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-subtitle-menu')),
      );
      final buttonRegion = tester.widget<MouseRegion>(
        find
            .ancestor(
              of: find.byKey(const Key('movie-player-subtitle-button')),
              matching: find.byType(MouseRegion),
            )
            .first,
      );
      final menuRegion = tester.widget<MouseRegion>(
        find
            .ancestor(
              of: find.byKey(const Key('movie-player-subtitle-menu')),
              matching: find.byType(MouseRegion),
            )
            .first,
      );
      buttonRegion.onExit?.call(const PointerExitEvent(position: Offset.zero));
      menuRegion.onExit?.call(const PointerExitEvent(position: Offset.zero));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('movie-player-subtitle-menu')), findsNothing);
    });

    testWidgets('shows empty menu when no subtitles are available', (
      WidgetTester tester,
    ) async {
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
      addTearDown(subtitleStateNotifier.dispose);
      addTearDown(isApplyingNotifier.dispose);

      await _pumpHarness(
        tester,
        subtitleStateListenable: subtitleStateNotifier,
        isApplyingListenable: isApplyingNotifier,
        onSubtitleSelected: (_) async {},
      );

      await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-player-subtitle-menu')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-player-subtitle-menu-item-501')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('movie-player-subtitle-menu-status')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('movie-player-subtitle-menu-retry')),
        findsNothing,
      );
    });

    testWidgets('subtitle button uses text label without tooltip', (
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
      addTearDown(subtitleStateNotifier.dispose);
      addTearDown(isApplyingNotifier.dispose);

      await _pumpHarness(
        tester,
        subtitleStateListenable: subtitleStateNotifier,
        isApplyingListenable: isApplyingNotifier,
        onSubtitleSelected: (_) async {},
      );

      expect(find.text('字幕'), findsOneWidget);
      expect(find.byIcon(Icons.subtitles_outlined), findsNothing);
      expect(find.byIcon(Icons.subtitles_rounded), findsNothing);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets(
      'menu checkmark reflects updated selected state from notifier',
      (WidgetTester tester) async {
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
        addTearDown(subtitleStateNotifier.dispose);
        addTearDown(isApplyingNotifier.dispose);

        await _pumpHarness(
          tester,
          subtitleStateListenable: subtitleStateNotifier,
          isApplyingListenable: isApplyingNotifier,
          onSubtitleSelected: (_) async {},
        );
        await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('movie-player-subtitle-menu-item-check-501')),
          findsNothing,
        );
        expect(
          find.byKey(
            const Key('movie-player-subtitle-menu-item-check-slot-501'),
          ),
          findsOneWidget,
        );

        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();

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
        await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('movie-player-subtitle-menu-item-check-501')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('movie-player-subtitle-menu-item-check-slot-501'),
          ),
          findsNothing,
        );
      },
    );
  });
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required ValueListenable<MoviePlayerSubtitleState> subtitleStateListenable,
  required ValueListenable<bool> isApplyingListenable,
  required Future<void> Function(int? subtitleId) onSubtitleSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 96),
            child: MoviePlayerSubtitleButton(
              subtitleStateListenable: subtitleStateListenable,
              isApplyingListenable: isApplyingListenable,
              onSubtitleSelected: onSubtitleSelected,
              onReloadRequested: () async {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<TestGesture> _createMouseGesture(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  return gesture;
}

Future<void> _moveMouseToFinder(
  WidgetTester tester,
  TestGesture gesture,
  Finder finder,
) async {
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pump();
}
