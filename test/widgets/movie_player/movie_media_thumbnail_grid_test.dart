import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/movie_player/movie_media_thumbnail_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('thumbnail grid uses fixed 16:9 aspect ratio for grid items', (
    WidgetTester tester,
  ) async {
    await _pumpGrid(
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
    );

    final gridView = tester.widget<GridView>(
      find.byKey(const Key('movie-media-thumbnail-grid')),
    );
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.childAspectRatio, closeTo(16 / 9, 0.0001));
  });

  testWidgets('thumbnail grid marks active thumbnail with selected style', (
    WidgetTester tester,
  ) async {
    await _pumpGrid(tester, thumbnails: _thumbnails(), activeIndex: 1);

    final decoratedBox = tester.widget<DecoratedBox>(
      find.byKey(const Key('movie-media-thumbnail-tile-1-decoration')),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;

    expect(decoration.border, isA<Border>());
  });

  testWidgets('thumbnail grid provides decode size hints for masked images', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpGrid(tester, thumbnails: _thumbnails());
    await tester.pump();

    final maskedImageFinder = find.descendant(
      of: find.byKey(const Key('movie-media-thumb-0')),
      matching: find.byType(MaskedImage),
    );
    final maskedImage = tester.widget<MaskedImage>(maskedImageFinder);
    final renderedSize = tester.getSize(maskedImageFinder);

    expect(
      maskedImage.memCacheWidth,
      _expectedDecodeDimension(extent: renderedSize.width, devicePixelRatio: 2),
    );
    expect(
      maskedImage.memCacheHeight,
      _expectedDecodeDimension(
        extent: renderedSize.height,
        devicePixelRatio: 2,
      ),
    );
  });

  testWidgets('thumbnail grid caps decode hints at 2x device pixel ratio', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpGrid(tester, thumbnails: _thumbnails());
    await tester.pump();

    final maskedImageFinder = find.descendant(
      of: find.byKey(const Key('movie-media-thumb-0')),
      matching: find.byType(MaskedImage),
    );
    final maskedImage = tester.widget<MaskedImage>(maskedImageFinder);
    final renderedSize = tester.getSize(maskedImageFinder);

    expect(
      maskedImage.memCacheWidth,
      _expectedDecodeDimension(
        extent: renderedSize.width,
        devicePixelRatio: 3.5,
      ),
    );
    expect(
      maskedImage.memCacheHeight,
      _expectedDecodeDimension(
        extent: renderedSize.height,
        devicePixelRatio: 3.5,
      ),
    );
  });

  testWidgets('thumbnail grid caps decode hints to 1024 upper bound', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpGrid(
      tester,
      thumbnails: _thumbnails(),
      columns: 1,
      width: 2200,
      height: 1400,
    );
    await tester.pump();

    final maskedImage = tester.widget<MaskedImage>(
      find.descendant(
        of: find.byKey(const Key('movie-media-thumb-0')),
        matching: find.byType(MaskedImage),
      ),
    );

    expect(maskedImage.memCacheWidth, 1024);
    expect(maskedImage.memCacheHeight, 1024);
  });

  testWidgets('thumbnail grid shows retry action when loading fails', (
    WidgetTester tester,
  ) async {
    var retried = false;

    await _pumpGrid(
      tester,
      thumbnails: const <MovieMediaThumbnailDto>[],
      errorMessage: '请稍后重试。',
      onRetry: () => retried = true,
    );

    expect(find.text('缩略图加载失败'), findsOneWidget);

    await tester.tap(find.byKey(const Key('movie-media-thumbnail-retry')));
    await tester.pump();

    expect(retried, isTrue);
  });

  testWidgets('thumbnail grid uses vertical scroll grid', (
    WidgetTester tester,
  ) async {
    await _pumpGrid(
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
    );

    final scrollable = tester.widget<Scrollable>(
      find.descendant(
        of: find.byKey(const Key('movie-media-thumbnail-grid')),
        matching: find.byType(Scrollable),
      ),
    );

    expect(scrollable.axisDirection, AxisDirection.down);
  });

  testWidgets('thumbnail grid uses lazy child delegate for loaded thumbnails', (
    WidgetTester tester,
  ) async {
    await _pumpGrid(
      tester,
      thumbnails: _manyThumbnails(60),
      activeIndex: 0,
      isScrollLocked: false,
    );

    final gridView = tester.widget<GridView>(
      find.byKey(const Key('movie-media-thumbnail-grid')),
    );

    expect(gridView.childrenDelegate, isA<SliverChildBuilderDelegate>());
  });

  testWidgets('thumbnail grid disables manual scrolling while locked', (
    WidgetTester tester,
  ) async {
    await _pumpGrid(
      tester,
      thumbnails: _manyThumbnails(24),
      isScrollLocked: true,
    );

    final scrollable = tester.widget<Scrollable>(
      find.descendant(
        of: find.byKey(const Key('movie-media-thumbnail-grid')),
        matching: find.byType(Scrollable),
      ),
    );

    expect(scrollable.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('thumbnail grid keeps user scroll position while unlocked', (
    WidgetTester tester,
  ) async {
    await _pumpGrid(
      tester,
      thumbnails: _manyThumbnails(60),
      activeIndex: 0,
      isScrollLocked: false,
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('movie-media-thumbnail-grid')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    final state = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('movie-media-thumbnail-grid')),
        matching: find.byType(Scrollable),
      ),
    );
    final offsetBefore = state.position.pixels;

    await _pumpGrid(
      tester,
      thumbnails: _manyThumbnails(60),
      activeIndex: 50,
      isScrollLocked: false,
    );
    await tester.pumpAndSettle();

    expect(offsetBefore, greaterThan(0));
    expect(state.position.pixels, offsetBefore);
  });

  testWidgets(
    'thumbnail grid keeps already-rendered image widgets while user scrolling',
    (WidgetTester tester) async {
      await _pumpGrid(
        tester,
        thumbnails: _manyThumbnails(60),
        activeIndex: 0,
        isScrollLocked: false,
      );
      await tester.pumpAndSettle();

      expect(find.byType(CachedNetworkImage), findsWidgets);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('movie-media-thumbnail-grid'))),
      );
      await gesture.moveBy(const Offset(0, -220));
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsWidgets);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CachedNetworkImage), findsWidgets);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CachedNetworkImage), findsWidgets);
    },
  );

  testWidgets(
    'thumbnail grid only renders previously loaded images during active scroll',
    (WidgetTester tester) async {
      await _pumpGrid(
        tester,
        thumbnails: _manyThumbnails(120),
        activeIndex: 0,
        isScrollLocked: false,
      );
      await tester.pumpAndSettle();

      final unseenTile = find.byKey(const Key('movie-media-thumb-80'));
      expect(unseenTile, findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('movie-media-thumbnail-grid'))),
      );
      for (var step = 0; step < 10 && unseenTile.evaluate().isEmpty; step++) {
        await gesture.moveBy(const Offset(0, -260));
        await tester.pump();
      }

      expect(unseenTile, findsOneWidget);
      expect(
        find.descendant(
          of: unseenTile,
          matching: find.byType(CachedNetworkImage),
        ),
        findsNothing,
      );

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.descendant(
          of: unseenTile,
          matching: find.byType(CachedNetworkImage),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'thumbnail grid resets rendered cache when thumbnail dataset changes',
    (WidgetTester tester) async {
      await _pumpGrid(
        tester,
        thumbnails: _manyThumbnails(120, mediaId: 100, imagePrefix: 'first'),
        activeIndex: 0,
        isScrollLocked: false,
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('movie-media-thumbnail-grid'))),
      );
      await gesture.moveBy(const Offset(0, -220));
      await tester.pump();
      final cachedTile = find.byKey(const Key('movie-media-thumb-5'));
      expect(cachedTile, findsOneWidget);
      expect(
        find.descendant(
          of: cachedTile,
          matching: find.byType(CachedNetworkImage),
        ),
        findsOneWidget,
      );

      await _pumpGrid(
        tester,
        thumbnails: _manyThumbnails(120, mediaId: 200, imagePrefix: 'second'),
        activeIndex: 0,
        isScrollLocked: false,
      );
      await tester.pump();

      expect(cachedTile, findsOneWidget);
      expect(
        find.descendant(
          of: cachedTile,
          matching: find.byType(CachedNetworkImage),
        ),
        findsNothing,
      );

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.descendant(
          of: cachedTile,
          matching: find.byType(CachedNetworkImage),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('thumbnail grid re-centers active item when relocked', (
    WidgetTester tester,
  ) async {
    await _pumpGrid(
      tester,
      thumbnails: _manyThumbnails(60),
      activeIndex: 50,
      isScrollLocked: false,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-media-thumb-50')), findsNothing);

    await _pumpGrid(
      tester,
      thumbnails: _manyThumbnails(60),
      activeIndex: 50,
      isScrollLocked: true,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-media-thumb-50')), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsWidgets);
  });

  testWidgets(
    'thumbnail grid re-centers active item after column change while locked',
    (WidgetTester tester) async {
      await _pumpGrid(
        tester,
        thumbnails: _manyThumbnails(60),
        columns: 4,
        activeIndex: 50,
        isScrollLocked: true,
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byKey(const Key('movie-media-thumbnail-grid')),
        matching: find.byType(Scrollable),
      );
      final state = tester.state<ScrollableState>(scrollableFinder);
      final offsetBefore = state.position.pixels;

      await _pumpGrid(
        tester,
        thumbnails: _manyThumbnails(60),
        columns: 2,
        activeIndex: 50,
        isScrollLocked: true,
      );
      await tester.pumpAndSettle();

      expect(offsetBefore, greaterThan(0));
      expect(find.byKey(const Key('movie-media-thumb-50')), findsOneWidget);
    },
  );

  testWidgets(
    'thumbnail grid throttles locked auto scroll and settles on latest active item',
    (WidgetTester tester) async {
      await _pumpGrid(
        tester,
        thumbnails: _manyThumbnails(90),
        activeIndex: 0,
        isScrollLocked: true,
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byKey(const Key('movie-media-thumbnail-grid')),
        matching: find.byType(Scrollable),
      );

      await _pumpGrid(
        tester,
        thumbnails: _manyThumbnails(90),
        activeIndex: 48,
        isScrollLocked: true,
      );
      await tester.pump();

      final offsetAfterLeading = _scrollOffset(tester, scrollableFinder);
      expect(offsetAfterLeading, greaterThan(0));

      await _pumpGrid(
        tester,
        thumbnails: _manyThumbnails(90),
        activeIndex: 72,
        isScrollLocked: true,
      );
      await tester.pump();

      expect(_scrollOffset(tester, scrollableFinder), offsetAfterLeading);
      expect(find.byKey(const Key('movie-media-thumb-72')), findsNothing);

      await tester.pump(const Duration(milliseconds: 179));
      expect(_scrollOffset(tester, scrollableFinder), offsetAfterLeading);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(
        _scrollOffset(tester, scrollableFinder),
        greaterThan(offsetAfterLeading),
      );
      expect(find.byKey(const Key('movie-media-thumb-72')), findsOneWidget);
    },
  );

  testWidgets('thumbnail grid forwards thumbnail menu requests', (
    WidgetTester tester,
  ) async {
    int? requestedIndex;
    Offset? requestedPosition;

    await _pumpGrid(
      tester,
      thumbnails: _thumbnails(),
      onThumbnailMenuRequested: (index, position) {
        requestedIndex = index;
        requestedPosition = position;
      },
    );

    final target = find.byKey(const Key('movie-media-thumb-1'));
    final center = tester.getCenter(target);

    await tester.tapAt(center, buttons: kSecondaryMouseButton);
    await tester.pump();

    expect(requestedIndex, 1);
    expect(requestedPosition, equals(center));
  });
}

Future<void> _pumpGrid(
  WidgetTester tester, {
  required List<MovieMediaThumbnailDto> thumbnails,
  int columns = 3,
  int? activeIndex = 0,
  double width = 360,
  double height = 720,
  bool isScrollLocked = true,
  String? errorMessage,
  VoidCallback? onRetry,
  void Function(int index, Offset globalPosition)? onThumbnailMenuRequested,
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
            height: height,
            child: MovieMediaThumbnailGrid(
              thumbnails: thumbnails,
              isLoading: false,
              errorMessage: errorMessage,
              columns: columns,
              activeIndex: activeIndex,
              isScrollLocked: isScrollLocked,
              onThumbnailTap: (_) {},
              onRetry: onRetry ?? () {},
              onThumbnailMenuRequested: onThumbnailMenuRequested,
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

List<MovieMediaThumbnailDto> _manyThumbnails(
  int count, {
  int mediaId = 100,
  String imagePrefix = 'thumb',
}) {
  return List<MovieMediaThumbnailDto>.generate(
    count,
    (index) => MovieMediaThumbnailDto(
      thumbnailId: index + 1,
      mediaId: mediaId,
      offsetSeconds: (index + 1) * 10,
      image: MovieImageDto(
        id: index + 1,
        origin: 'relative/$imagePrefix-$index.webp',
        small: 'relative/$imagePrefix-$index.webp',
        medium: 'relative/$imagePrefix-$index.webp',
        large: 'relative/$imagePrefix-$index.webp',
      ),
    ),
  );
}

double _scrollOffset(WidgetTester tester, Finder scrollableFinder) {
  final state = tester.state<ScrollableState>(scrollableFinder);
  return state.position.pixels;
}

int _expectedDecodeDimension({
  required double extent,
  required double devicePixelRatio,
}) {
  final effectivePixelRatio = devicePixelRatio > 2 ? 2.0 : devicePixelRatio;
  return (extent * effectivePixelRatio).round().clamp(1, 1024) as int;
}
