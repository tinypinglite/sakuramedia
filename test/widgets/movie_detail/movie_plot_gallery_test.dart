import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_gallery.dart';

void main() {
  test('movie plot gallery does not force fixed thumbnail width', () {
    final source =
        File(
          'lib/widgets/movie_detail/movie_plot_gallery.dart',
        ).readAsStringSync();

    expect(
      source,
      isNot(contains('width: tokens.movieDetailPlotThumbnailWidth')),
    );
  });

  testWidgets(
    'movie plot gallery shows empty state when there are no plot images',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        awaitableGalleryApp(
          child: const MoviePlotGallery(plotImages: <MovieImageDto>[]),
        ),
      );

      expect(find.text('暂无剧情图'), findsOneWidget);
    },
  );

  testWidgets('movie plot gallery notifies the selected plot thumbnail', (
    WidgetTester tester,
  ) async {
    int? tappedIndex;
    int? menuIndex;
    Offset? menuPosition;

    await tester.pumpWidget(
      awaitableGalleryApp(
        child: MoviePlotGallery(
          plotImages: const <MovieImageDto>[
            MovieImageDto(
              id: 1,
              origin: 'plot-0.jpg',
              small: 'plot-0-small.jpg',
              medium: 'plot-0-medium.jpg',
              large: 'plot-0-large.jpg',
            ),
            MovieImageDto(
              id: 2,
              origin: 'plot-1.jpg',
              small: 'plot-1-small.jpg',
              medium: 'plot-1-medium.jpg',
              large: 'plot-1-large.jpg',
            ),
          ],
          onOpenPreview: (index) => tappedIndex = index,
          onRequestImageMenu: (context, index, globalPosition) async {
            menuIndex = index;
            menuPosition = globalPosition;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('movie-plot-thumb-1')));
    await tester.pumpAndSettle();

    expect(tappedIndex, 1);
    expect(menuIndex, isNull);
    expect(menuPosition, isNull);
  });

  testWidgets('movie plot gallery forwards secondary tap to image menu', (
    WidgetTester tester,
  ) async {
    int? menuIndex;
    Offset? menuPosition;

    await tester.pumpWidget(
      awaitableGalleryApp(
        child: MoviePlotGallery(
          plotImages: const <MovieImageDto>[
            MovieImageDto(
              id: 1,
              origin: 'plot-0.jpg',
              small: 'plot-0-small.jpg',
              medium: 'plot-0-medium.jpg',
              large: 'plot-0-large.jpg',
            ),
            MovieImageDto(
              id: 2,
              origin: 'plot-1.jpg',
              small: 'plot-1-small.jpg',
              medium: 'plot-1-medium.jpg',
              large: 'plot-1-large.jpg',
            ),
          ],
          onRequestImageMenu: (context, index, globalPosition) async {
            menuIndex = index;
            menuPosition = globalPosition;
          },
        ),
      ),
    );

    final center = tester.getCenter(
      find.byKey(const Key('movie-plot-thumb-1')),
    );
    await tester.tapAt(center, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(menuIndex, 1);
    expect(menuPosition, equals(center));
  });

  testWidgets('movie plot gallery forwards long press to image menu', (
    WidgetTester tester,
  ) async {
    int? menuIndex;
    Offset? menuPosition;

    await tester.pumpWidget(
      awaitableGalleryApp(
        child: MoviePlotGallery(
          plotImages: const <MovieImageDto>[
            MovieImageDto(
              id: 1,
              origin: 'plot-0.jpg',
              small: 'plot-0-small.jpg',
              medium: 'plot-0-medium.jpg',
              large: 'plot-0-large.jpg',
            ),
            MovieImageDto(
              id: 2,
              origin: 'plot-1.jpg',
              small: 'plot-1-small.jpg',
              medium: 'plot-1-medium.jpg',
              large: 'plot-1-large.jpg',
            ),
          ],
          onRequestImageMenu: (context, index, globalPosition) async {
            menuIndex = index;
            menuPosition = globalPosition;
          },
        ),
      ),
    );

    final center = tester.getCenter(
      find.byKey(const Key('movie-plot-thumb-1')),
    );
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(menuIndex, 1);
    expect(menuPosition, equals(center));
  });
}

Widget awaitableGalleryApp({required Widget child}) {
  final sessionStore = SessionStore.inMemory();
  return ChangeNotifierProvider<SessionStore>.value(
    value: sessionStore,
    child: MaterialApp(theme: sakuraThemeData, home: Scaffold(body: child)),
  );
}
