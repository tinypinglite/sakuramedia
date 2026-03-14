import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_thumbnail_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('thumbnail panel uses fixed 16:9 aspect ratio for grid items', (
    WidgetTester tester,
  ) async {
    await _pumpPanel(
      tester,
      thumbnails: <MovieMediaThumbnailDto>[
        MovieMediaThumbnailDto(
          thumbnailId: 1,
          mediaId: 100,
          offsetSeconds: 10,
          image: const MovieImageDto(
            id: 10,
            origin: 'relative/thumb-10.webp',
            small: 'relative/thumb-10.webp',
            medium: 'relative/thumb-10.webp',
            large: 'relative/thumb-10.webp',
          ),
        ),
      ],
      columns: 3,
      usesAutoColumns: false,
    );

    final gridView = tester.widget<GridView>(
      find.byKey(const Key('movie-player-thumbnail-grid')),
    );
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.childAspectRatio, closeTo(16 / 9, 0.0001));
  });

  testWidgets('thumbnail panel marks active thumbnail with selected style', (
    WidgetTester tester,
  ) async {
    await _pumpPanel(
      tester,
      thumbnails: _thumbnails(),
      columns: 3,
      activeIndex: 1,
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.byKey(const Key('movie-player-thumbnail-tile-1-decoration')),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;

    expect(decoration.border, isA<Border>());
  });

  testWidgets('thumbnail panel toggles highlighted column pill', (
    WidgetTester tester,
  ) async {
    int? selectedColumns;

    await _pumpPanel(
      tester,
      thumbnails: _thumbnails(),
      columns: 3,
      usesAutoColumns: false,
      onColumnsChanged: (value) => selectedColumns = value,
    );

    await tester.tap(find.byKey(const Key('movie-player-columns-5')));
    await tester.pump();

    expect(selectedColumns, 5);
  });

  testWidgets('thumbnail panel resolves 3 columns at standard panel width', (
    WidgetTester tester,
  ) async {
    await _pumpPanel(
      tester,
      thumbnails: _thumbnails(),
      columns: null,
      usesAutoColumns: true,
      width: 420,
    );

    final gridView = tester.widget<GridView>(
      find.byKey(const Key('movie-player-thumbnail-grid')),
    );
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.crossAxisCount, 3);
  });

  testWidgets('thumbnail panel resolves 5 columns at wide panel width', (
    WidgetTester tester,
  ) async {
    await _pumpPanel(
      tester,
      thumbnails: _thumbnails(),
      columns: null,
      usesAutoColumns: true,
      width: 760,
    );

    final gridView = tester.widget<GridView>(
      find.byKey(const Key('movie-player-thumbnail-grid')),
    );
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.crossAxisCount, 5);
    expect(find.byKey(const Key('movie-player-columns-5')), findsOneWidget);
  });

  testWidgets('thumbnail panel renders locked scroll toggle state', (
    WidgetTester tester,
  ) async {
    await _pumpPanel(
      tester,
      thumbnails: _thumbnails(),
      columns: 3,
      usesAutoColumns: false,
      isScrollLocked: true,
    );

    expect(
      find.byKey(const Key('movie-player-scroll-lock-toggle')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
  });

  testWidgets('thumbnail panel forwards scroll lock toggle', (
    WidgetTester tester,
  ) async {
    var toggled = false;

    await _pumpPanel(
      tester,
      thumbnails: _thumbnails(),
      columns: 3,
      usesAutoColumns: false,
      isScrollLocked: false,
      onToggleScrollLock: () => toggled = true,
    );

    await tester.tap(find.byKey(const Key('movie-player-scroll-lock-toggle')));
    await tester.pump();

    expect(toggled, isTrue);
    expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
  });

  testWidgets('thumbnail panel uses vertical scroll grid', (
    WidgetTester tester,
  ) async {
    await _pumpPanel(
      tester,
      thumbnails: List<MovieMediaThumbnailDto>.generate(
        12,
        (index) => MovieMediaThumbnailDto(
          thumbnailId: index + 1,
          mediaId: 100,
          offsetSeconds: index * 10,
          image: MovieImageDto(
            id: index + 1,
            origin: 'relative/thumb-$index.webp',
            small: 'relative/thumb-$index.webp',
            medium: 'relative/thumb-$index.webp',
            large: 'relative/thumb-$index.webp',
          ),
        ),
      ),
      columns: 3,
      usesAutoColumns: false,
    );

    final scrollable = tester.widget<Scrollable>(
      find.descendant(
        of: find.byKey(const Key('movie-player-thumbnail-grid')),
        matching: find.byType(Scrollable),
      ),
    );

    expect(scrollable.axisDirection, AxisDirection.down);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required List<MovieMediaThumbnailDto> thumbnails,
  required int? columns,
  int activeIndex = 0,
  bool isScrollLocked = true,
  bool usesAutoColumns = false,
  double width = 360,
  ValueChanged<int>? onColumnsChanged,
  VoidCallback? onToggleScrollLock,
}) async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');

  await tester.pumpWidget(
    ChangeNotifierProvider<SessionStore>.value(
      value: sessionStore,
      child: MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 720,
            child: MoviePlayerThumbnailPanel(
              thumbnails: thumbnails,
              isLoading: false,
              errorMessage: null,
              columns: columns,
              activeIndex: activeIndex,
              isScrollLocked: isScrollLocked,
              usesAutoColumns: usesAutoColumns,
              onAutoColumnsResolved: (_) {},
              onColumnsChanged: onColumnsChanged ?? (_) {},
              onToggleScrollLock: onToggleScrollLock ?? () {},
              onThumbnailTap: (_) {},
              onRetry: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

List<MovieMediaThumbnailDto> _thumbnails() {
  return <MovieMediaThumbnailDto>[
    MovieMediaThumbnailDto(
      thumbnailId: 1,
      mediaId: 100,
      offsetSeconds: 10,
      image: const MovieImageDto(
        id: 10,
        origin: 'relative/thumb-10.webp',
        small: 'relative/thumb-10.webp',
        medium: 'relative/thumb-10.webp',
        large: 'relative/thumb-10.webp',
      ),
    ),
    MovieMediaThumbnailDto(
      thumbnailId: 2,
      mediaId: 100,
      offsetSeconds: 20,
      image: const MovieImageDto(
        id: 11,
        origin: 'relative/thumb-20.webp',
        small: 'relative/thumb-20.webp',
        medium: 'relative/thumb-20.webp',
        large: 'relative/thumb-20.webp',
      ),
    ),
  ];
}
