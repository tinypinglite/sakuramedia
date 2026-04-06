import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_media_point_gallery.dart';

void main() {
  testWidgets('movie media point gallery shows empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _galleryApp(
        child: const MovieMediaPointGallery(points: <MovieMediaPointDto>[]),
      ),
    );

    expect(find.text('暂无标记点'), findsOneWidget);
    expect(find.byKey(const Key('movie-media-point-empty')), findsOneWidget);
  });

  testWidgets(
    'movie media point gallery opens preview on tap and shows timecode',
    (WidgetTester tester) async {
      MovieMediaPointDto? tappedPoint;

      await tester.pumpWidget(
        _galleryApp(
          child: MovieMediaPointGallery(
            points: <MovieMediaPointDto>[_buildPoint(1, 90)],
            onOpenPreview: (point) => tappedPoint = point,
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-media-point-timecode-0')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('movie-media-point-timecode-0')))
            .data,
        '01:30',
      );
      await tester.tap(find.byKey(const Key('movie-media-point-thumb-0')));
      await tester.pumpAndSettle();

      expect(tappedPoint?.pointId, 1);
    },
  );

  testWidgets('movie media point gallery forwards secondary tap to menu', (
    WidgetTester tester,
  ) async {
    MovieMediaPointDto? menuPoint;
    Offset? menuPosition;

    await tester.pumpWidget(
      _galleryApp(
        child: MovieMediaPointGallery(
          points: <MovieMediaPointDto>[_buildPoint(2, 120)],
          onRequestPointMenu: (context, point, globalPosition) async {
            menuPoint = point;
            menuPosition = globalPosition;
          },
        ),
      ),
    );

    final center = tester.getCenter(
      find.byKey(const Key('movie-media-point-thumb-0')),
    );
    await tester.tapAt(center, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(menuPoint?.pointId, 2);
    expect(menuPosition, equals(center));
  });

  testWidgets('movie media point gallery forwards long press to menu', (
    WidgetTester tester,
  ) async {
    MovieMediaPointDto? menuPoint;

    await tester.pumpWidget(
      _galleryApp(
        child: MovieMediaPointGallery(
          points: <MovieMediaPointDto>[_buildPoint(3, 150)],
          onRequestPointMenu: (context, point, globalPosition) async {
            menuPoint = point;
          },
        ),
      ),
    );

    final center = tester.getCenter(
      find.byKey(const Key('movie-media-point-thumb-0')),
    );
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(menuPoint?.pointId, 3);
  });
}

Widget _galleryApp({required Widget child}) {
  final sessionStore = SessionStore.inMemory();
  return ChangeNotifierProvider<SessionStore>.value(
    value: sessionStore,
    child: MaterialApp(theme: sakuraThemeData, home: Scaffold(body: child)),
  );
}

MovieMediaPointDto _buildPoint(int pointId, int offsetSeconds) {
  return MovieMediaPointDto(
    pointId: pointId,
    thumbnailId: pointId * 10,
    offsetSeconds: offsetSeconds,
    image: MovieImageDto(
      id: pointId,
      origin: 'point-$pointId-origin.webp',
      small: 'point-$pointId-small.webp',
      medium: 'point-$pointId-medium.webp',
      large: 'point-$pointId-large.webp',
    ),
  );
}
