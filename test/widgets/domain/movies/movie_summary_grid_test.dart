import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

const MovieListItemDto _movie = MovieListItemDto(
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

void main() {
  testWidgets('movie summary grid uses spacing token for grid gaps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: SizedBox(
            width: 960,
            child: MovieSummaryGrid(items: [_movie]),
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
            child: MovieSummaryGrid(items: [_movie]),
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

  testWidgets('movie summary grid caps columns at the unified card grid spec', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: MovieSummaryGrid(items: [_movie])),
      ),
    );

    final gridView = tester.widget<GridView>(
      find.byKey(const Key('movie-summary-grid')),
    );
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(
      delegate.crossAxisCount,
      AppComponentTokens.defaults().cardGridMaxColumns,
    );
  });

  testWidgets('movie summary grid derives columns from the unified target width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: MovieSummaryGrid(items: [_movie])),
      ),
    );

    final gridView = tester.widget<GridView>(
      find.byKey(const Key('movie-summary-grid')),
    );
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    // (1200 + 12) / (220 + 12) = 5.2 → 5 列。
    expect(delegate.crossAxisCount, 5);
  });

  testWidgets('movie summary card uses component token aspect ratio', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: MovieSummaryCard(movie: _movie)),
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
