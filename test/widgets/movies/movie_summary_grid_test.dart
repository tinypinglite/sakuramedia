import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_card.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';

void main() {
  test('movie summary grid does not hardcode spacing constants', () {
    final source =
        File('lib/widgets/movies/movie_summary_grid.dart').readAsStringSync();

    expect(source, contains('context.appSpacing.md'));
    expect(source, isNot(contains('const spacing = 12.0')));
  });

  test('movie summary layout does not hardcode card sizing constants', () {
    final gridSource =
        File('lib/widgets/movies/movie_summary_grid.dart').readAsStringSync();
    final cardSource =
        File('lib/widgets/movies/movie_summary_card.dart').readAsStringSync();

    expect(gridSource, contains('context.appComponentTokens'));
    expect(gridSource, isNot(contains('const targetWidth = 210.0')));
    expect(gridSource, isNot(contains('childAspectRatio: 0.7')));
    expect(cardSource, contains('context.appComponentTokens'));
    expect(cardSource, isNot(contains('aspectRatio: 0.7')));
  });

  testWidgets('movie summary grid uses spacing token for grid gaps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: SizedBox(
            width: 960,
            child: MovieSummaryGrid(items: [], isLoading: true),
          ),
        ),
      ),
    );

    final gridView = tester.widget<GridView>(
      find.byKey(const Key('movie-summary-grid')),
    );
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.crossAxisSpacing, AppSpacing.defaults().md);
    expect(delegate.mainAxisSpacing, AppSpacing.defaults().md);
  });

  testWidgets('movie summary grid uses component tokens for card sizing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: SizedBox(
            width: 960,
            child: MovieSummaryGrid(items: [], isLoading: true),
          ),
        ),
      ),
    );

    final gridView = tester.widget<GridView>(
      find.byKey(const Key('movie-summary-grid')),
    );
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(
      delegate.childAspectRatio,
      AppComponentTokens.defaults().movieCardAspectRatio,
    );
  });

  testWidgets('movie summary card uses component token aspect ratio', (
    WidgetTester tester,
  ) async {
    const movie = MovieListItemDto(
      javdbId: 'test-javdb-id',
      movieNumber: 'ABP-123',
      title: 'Test Movie',
      coverImage: null,
      releaseDate: null,
      durationMinutes: 0,
      heat: 0,
      canPlay: false,
      isSubscribed: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: MovieSummaryCard(movie: movie)),
      ),
    );

    final aspectRatio = tester.widget<AspectRatio>(
      find.byType(AspectRatio).first,
    );
    expect(
      aspectRatio.aspectRatio,
      AppComponentTokens.defaults().movieCardAspectRatio,
    );
  });
}
