import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/media_player/movie_media_thumbnail_grid.dart';

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
    // 只按宽给解码提示（保宽高比、不拉伸），不给高。
    expect(maskedImage.memCacheHeight, isNull);
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
    expect(maskedImage.memCacheHeight, isNull);
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
    expect(maskedImage.memCacheHeight, isNull);
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
    'thumbnail grid loads newly visible images during active scroll',
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

      final unseenImage = find.descendant(
        of: unseenTile,
        matching: find.byType(CachedNetworkImage),
      );

      // 全程按住手指（活动滚动中）滑动；新滚入视口的缩略图应在手指离开前就加载。
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('movie-media-thumbnail-grid'))),
      );
      for (var step = 0;
          step < 30 &&
              unseenImage.evaluate().isEmpty &&
              (unseenTile.evaluate().isNotEmpty || step < 14);
          step++) {
        await gesture.moveBy(const Offset(0, -160));
        await tester.pump();
      }

      expect(unseenTile, findsOneWidget);
      expect(unseenImage, findsOneWidget); // 手指仍未离开即已加载

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(unseenImage, findsOneWidget);
    },
  );

  testWidgets(
    'thumbnail grid loads newly visible images after viewport resize',
    (WidgetTester tester) async {
      final thumbnails = _manyThumbnails(120);
      final resizedVisibleTile = find.byKey(const Key('movie-media-thumb-12'));

      await _pumpGrid(
        tester,
        thumbnails: thumbnails,
        columns: 3,
        width: 600,
        height: 60,
        isScrollLocked: false,
      );
      await tester.pumpAndSettle();

      expect(resizedVisibleTile, findsNothing);

      await _pumpGrid(
        tester,
        thumbnails: thumbnails,
        columns: 3,
        width: 240,
        height: 360,
        isScrollLocked: false,
      );
      await tester.pumpAndSettle();

      // 视口变化后，原先不在视口、未建图的瓦片进入可见范围即应加载出图片，
      // 不应停留在占位图（回归保护：缩略图面板调整尺寸后图片不自动加载）。
      expect(resizedVisibleTile, findsOneWidget);
      expect(
        find.descendant(
          of: resizedVisibleTile,
          matching: find.byType(CachedNetworkImage),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'thumbnail grid rebuilds visible images with new urls when dataset changes',
    (WidgetTester tester) async {
      await _pumpGrid(
        tester,
        thumbnails: _manyThumbnails(120, mediaId: 100, imagePrefix: 'first'),
        activeIndex: 0,
        isScrollLocked: false,
      );
      await tester.pumpAndSettle();

      final visibleTile = find.byKey(const Key('movie-media-thumb-0'));
      final firstImage = tester.widget<CachedNetworkImage>(
        find.descendant(
          of: visibleTile,
          matching: find.byType(CachedNetworkImage),
        ),
      );
      expect(firstImage.imageUrl, contains('first-0'));

      // 数据集换新（不同 id）后，可见瓦片应重建并指向新 url，不残留旧图。
      await _pumpGrid(
        tester,
        thumbnails: _manyThumbnails(120, mediaId: 200, imagePrefix: 'second'),
        activeIndex: 0,
        isScrollLocked: false,
      );
      await tester.pumpAndSettle();

      final secondImage = tester.widget<CachedNetworkImage>(
        find.descendant(
          of: visibleTile,
          matching: find.byType(CachedNetworkImage),
        ),
      );
      expect(secondImage.imageUrl, contains('second-0'));
      expect(secondImage.imageUrl, isNot(contains('first-0')));
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

  group('adaptive thumbnail fit', () {
    test('portrait / squarish (ratio < 1.5) uses contain', () {
      expect(resolveAdaptiveThumbnailFit(720 / 1280), BoxFit.contain); // 0.5625
      expect(resolveAdaptiveThumbnailFit(1.49), BoxFit.contain);
    });

    test('landscape / wide (ratio >= 1.5) uses cover', () {
      expect(resolveAdaptiveThumbnailFit(16 / 9), BoxFit.cover); // 1.777
      expect(resolveAdaptiveThumbnailFit(1.5), BoxFit.cover); // 边界含等于 → cover
    });

    test('null or non-positive ratio defaults to cover', () {
      expect(resolveAdaptiveThumbnailFit(null), BoxFit.cover);
      expect(resolveAdaptiveThumbnailFit(0), BoxFit.cover);
      expect(resolveAdaptiveThumbnailFit(-1), BoxFit.cover);
    });
  });

  testWidgets('thumbnail image defaults to cover before ratio resolves', (
    WidgetTester tester,
  ) async {
    await _pumpGrid(tester, thumbnails: _thumbnails());
    await tester.pump();

    final maskedImage = tester.widget<MaskedImage>(
      find
          .descendant(
            of: find.byKey(const Key('movie-media-thumb-0')),
            matching: find.byType(MaskedImage),
          )
          .first,
    );

    expect(maskedImage.fit, BoxFit.cover);
  });

  group('computeStaggeredLayout', () {
    test('按最短列优先放置（并列时取最左列），同 aspect 多列首行起平', () {
      // 4 个等 aspect 的 tile（1:1）+ 3 列 + tileWidth=100、spacing=0 → 前 3 个分别落 0/1/2 列；
      // 4 个 column 高度 (100,100,100)，最短列下标取最小 → 第 4 个落第 0 列。
      final result = computeStaggeredLayout(
        crossAxisCount: 3,
        availableWidth: 300,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
        items: const [
          (width: 100, height: 100),
          (width: 100, height: 100),
          (width: 100, height: 100),
          (width: 100, height: 100),
        ],
      );

      expect(result.tileWidth, 100);
      expect(result.tiles, hasLength(4));
      expect(result.tiles[0].columnIndex, 0);
      expect(result.tiles[1].columnIndex, 1);
      expect(result.tiles[2].columnIndex, 2);
      expect(result.tiles[3].columnIndex, 0);
      expect(result.tiles[3].topOffset, 100);
      expect(result.tiles[3].height, 100);
    });

    test('混合横竖图：竖图（aspect<1）tile 更高', () {
      // 3 列、availableWidth=300、无 spacing → tileWidth=100。
      // 横图 16:9 → tileHeight≈56.25；竖图 9:16 → tileHeight≈177.78。
      final result = computeStaggeredLayout(
        crossAxisCount: 3,
        availableWidth: 300,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
        items: const [
          (width: 1920, height: 1080), // 横
          (width: 1080, height: 1920), // 竖
          (width: 1920, height: 1080), // 横
          (width: 1920, height: 1080), // 横，应落到最矮的「横+横」列（不是竖图那列）
        ],
      );

      expect(result.tiles[0].height, closeTo(56.25, 0.01));
      expect(result.tiles[1].height, closeTo(177.78, 0.01));
      expect(result.tiles[2].height, closeTo(56.25, 0.01));
      // 0/2 列首行后高 ≈56.25，1 列首行后高 ≈177.78；最矮取 0 列。
      expect(result.tiles[3].columnIndex, 0);
      expect(result.tiles[3].topOffset, closeTo(56.25, 0.01));
    });

    test('缺 width/height（含部分缺、零、负）按 16:9 回退', () {
      final result = computeStaggeredLayout(
        crossAxisCount: 1,
        availableWidth: 160,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
        items: const [
          (width: null, height: null),
          (width: 100, height: null),
          (width: 0, height: 100),
          (width: 100, height: -1),
        ],
      );

      // 160 / (16/9) = 90
      for (final tile in result.tiles) {
        expect(tile.height, closeTo(90, 0.01));
      }
    });

    test('crossAxisSpacing/mainAxisSpacing 正确减去 + 累计高度不含尾部 spacing', () {
      final result = computeStaggeredLayout(
        crossAxisCount: 2,
        availableWidth: 220, // 2 列 + 1 个 20 间距 → tileWidth = (220-20)/2 = 100
        crossAxisSpacing: 20,
        mainAxisSpacing: 10,
        items: const [
          (width: 100, height: 100),
          (width: 100, height: 100),
          (width: 100, height: 100),
        ],
      );

      expect(result.tileWidth, 100);
      expect(result.tiles[0].topOffset, 0);
      expect(result.tiles[1].topOffset, 0);
      // 第 3 个落第 0 列：top = 100 + 10 = 110；列累计高度去掉尾部 spacing → 210。
      expect(result.tiles[2].columnIndex, 0);
      expect(result.tiles[2].topOffset, 110);
      expect(result.columnHeights[0], 210);
      expect(result.columnHeights[1], 100);
      expect(result.totalHeight, 210);
    });

    test('空列表 / 0 列 / 负宽返回空 layout 而非抛', () {
      expect(
        computeStaggeredLayout(
          crossAxisCount: 3,
          availableWidth: 300,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
          items: const [],
        ).tiles,
        isEmpty,
      );
      expect(
        computeStaggeredLayout(
          crossAxisCount: 0,
          availableWidth: 300,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
          items: const [(width: 1, height: 1)],
        ).tiles,
        isEmpty,
      );
      expect(
        computeStaggeredLayout(
          crossAxisCount: 3,
          availableWidth: 0,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
          items: const [(width: 1, height: 1)],
        ).tiles,
        isEmpty,
      );
    });
  });

  testWidgets('staggered layout: 渲染 CustomScrollView + SliverMasonryGrid，按 dims 切 tile 高度', (
    WidgetTester tester,
  ) async {
    await _pumpGrid(
      tester,
      layout: ThumbnailGridLayout.staggered,
      columns: 2,
      thumbnails: <MovieMediaThumbnailDto>[
        // 横版
        MovieMediaThumbnailDto(
          thumbnailId: 1,
          mediaId: 100,
          offsetSeconds: 10,
          image: const MovieImageDto(
            id: 1,
            origin: 'a.webp',
            small: 'a.webp',
            medium: 'a.webp',
            large: 'a.webp',
          ),
          width: 1920,
          height: 1080,
        ),
        // 竖版（同列宽下 tile 高度应明显大于横版）
        MovieMediaThumbnailDto(
          thumbnailId: 2,
          mediaId: 200,
          offsetSeconds: 20,
          image: const MovieImageDto(
            id: 2,
            origin: 'b.webp',
            small: 'b.webp',
            medium: 'b.webp',
            large: 'b.webp',
          ),
          width: 1080,
          height: 1920,
        ),
      ],
    );

    // staggered 分支用 CustomScrollView，uniform 分支用 GridView。
    expect(
      find.byKey(const Key('movie-media-thumbnail-grid')),
      findsOneWidget,
    );
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(GridView), findsNothing);

    // 两个 AspectRatio 分别对应横/竖 → 高度差异应大约 16/9 vs 9/16。
    final aspectRatios =
        tester
            .widgetList<AspectRatio>(find.byType(AspectRatio))
            .map((w) => w.aspectRatio)
            .toList();
    expect(aspectRatios, contains(closeTo(16 / 9, 0.0001)));
    expect(aspectRatios, contains(closeTo(1080 / 1920, 0.0001)));
  });

  testWidgets(
    'staggered layout: width/height 缺失 tile 回退 16:9 占位',
    (WidgetTester tester) async {
      await _pumpGrid(
        tester,
        layout: ThumbnailGridLayout.staggered,
        columns: 1,
        thumbnails: <MovieMediaThumbnailDto>[
          MovieMediaThumbnailDto(
            thumbnailId: 1,
            mediaId: 100,
            offsetSeconds: 10,
            image: const MovieImageDto(
              id: 1,
              origin: 'a.webp',
              small: 'a.webp',
              medium: 'a.webp',
              large: 'a.webp',
            ),
          ),
        ],
      );

      final aspectRatios =
          tester
              .widgetList<AspectRatio>(find.byType(AspectRatio))
              .map((w) => w.aspectRatio)
              .toList();
      expect(aspectRatios, contains(closeTo(16 / 9, 0.0001)));
    },
  );
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
  ThumbnailGridLayout layout = ThumbnailGridLayout.uniform16x9,
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
              layout: layout,
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
  return (extent * effectivePixelRatio).round().clamp(1, 1024);
}
