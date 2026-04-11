import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_back_overlay.dart';

void main() {
  group('MoviePlayerCurrentNumberBadge', () {
    testWidgets('renders trimmed movie number with a stable key', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MoviePlayerCurrentNumberBadge(movieNumber: '  ABP-123  '),
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-player-current-number')),
        findsOneWidget,
      );
      expect(find.text('ABP-123'), findsOneWidget);
    });

    testWidgets('keeps single-line ellipsis text behavior', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MoviePlayerCurrentNumberBadge(
              movieNumber: 'ABP-123-VERY-LONG-CURRENT-PLAYING-NUMBER',
            ),
          ),
        ),
      );

      final numberText = tester.widget<Text>(find.textContaining('ABP-123'));
      expect(numberText.maxLines, 1);
      expect(numberText.overflow, TextOverflow.ellipsis);
      expect(numberText.softWrap, isFalse);
    });
  });

  group('MoviePlayerBackWithNumberControl', () {
    testWidgets('keeps number badge immediately after back button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: MoviePlayerBackWithNumberControl(
              onPressed: () {},
              movieNumber: 'SNOS-148',
            ),
          ),
        ),
      );

      final backRect = tester.getRect(
        find.byKey(const Key('movie-player-back-button')),
      );
      final numberRect = tester.getRect(
        find.byKey(const Key('movie-player-current-number')),
      );

      expect(numberRect.left - backRect.right, closeTo(2, 0.01));
      expect(backRect.left, lessThan(numberRect.left));
    });
  });
}
