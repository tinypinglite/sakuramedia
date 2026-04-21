import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_number_bar.dart';

void main() {
  testWidgets('movie detail number bar renders interaction stats and summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: MovieDetailNumberBar(
            movieNumber: ' ABC-001 ',
            summary: ' 这是影片简介 ',
            wantWatchCount: 23,
            watchedCount: 12,
            score: 4.50,
            commentCount: 34,
            heat: 56,
            scoreNumber: 45,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('movie-detail-number')), findsOneWidget);
    expect(
      find.byKey(const Key('movie-detail-interaction-row')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('movie-detail-summary')), findsOneWidget);

    expect(find.text('想看人数 23'), findsOneWidget);
    expect(find.text('看过人数 12'), findsOneWidget);
    expect(find.text('评分人数 45'), findsOneWidget);
    expect(find.text('56'), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);

    final numberBottom =
        tester.getBottomLeft(find.byKey(const Key('movie-detail-number'))).dy;
    final interactionTop =
        tester
            .getTopLeft(find.byKey(const Key('movie-detail-interaction-row')))
            .dy;
    final summaryTop =
        tester.getTopLeft(find.byKey(const Key('movie-detail-summary'))).dy;

    expect(numberBottom, lessThan(interactionTop));
    expect(interactionTop, lessThan(summaryTop));

    final numberText = tester.widget<Text>(
      find.byKey(const Key('movie-detail-number')),
    );
    final summaryText = tester.widget<Text>(
      find.byKey(const Key('movie-detail-summary')),
    );
    final wantWatchText = tester.widget<Text>(
      find.byKey(const Key('movie-detail-interaction-want-watch-text')),
    );

    expect(numberText.style?.fontSize, sakuraThemeData.appTextScale.s16);
    expect(wantWatchText.style?.fontSize, sakuraThemeData.appTextScale.s12);
    expect(summaryText.style?.fontSize, sakuraThemeData.appTextScale.s14);
  });

  testWidgets('movie detail number bar keeps zero values visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: MovieDetailNumberBar(
            movieNumber: 'ABC-001',
            summary: '',
            wantWatchCount: 0,
            watchedCount: 0,
            score: 0,
            commentCount: 0,
            heat: 0,
            scoreNumber: 0,
          ),
        ),
      ),
    );

    expect(find.text('想看人数 0'), findsOneWidget);
    expect(find.text('看过人数 0'), findsOneWidget);
    expect(find.text('评分人数 0'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-detail-interaction-heat-text')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-detail-interaction-score-text')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-detail-interaction-comment-text')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('movie-detail-summary')), findsNothing);
  });

  testWidgets('movie detail number bar wraps interaction row on narrow width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: SizedBox(
            width: 180,
            child: MovieDetailNumberBar(
              movieNumber: 'ABC-001',
              summary: '简介',
              wantWatchCount: 9956,
              watchedCount: 3185,
              score: 4.51,
              commentCount: 96,
              heat: 131,
              scoreNumber: 13141,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('movie-detail-interaction-row')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
