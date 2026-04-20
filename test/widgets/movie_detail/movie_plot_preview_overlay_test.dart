import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/preview_dialog_surface.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_preview_overlay.dart';

void main() {
  test('plot preview overlay defaults to adaptive thumbnail strip layout', () {
    final source =
        File(
          'lib/widgets/movie_detail/movie_plot_preview_overlay.dart',
        ).readAsStringSync();

    expect(source, contains('MoviePlotPreviewThumbnailStripLayout.adaptive'));
  });

  testWidgets('plot preview dialog opens at the requested index', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      awaitableOverlayApp(
        child: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: _plotImages,
                      initialIndex: 1,
                    ),
                child: const Text('open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-plot-preview-dialog')), findsOneWidget);
    expect(find.byType(PreviewDialogSurface), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('plot preview supports bottom drawer presentation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      awaitableOverlayApp(
        child: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: _plotImages,
                      initialIndex: 1,
                      presentation: MoviePlotPreviewPresentation.bottomDrawer,
                    ),
                child: const Text('open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-plot-preview-bottom-drawer')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('movie-plot-preview-dialog')), findsNothing);
    expect(find.byType(PreviewDialogSurface), findsNothing);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets(
    'plot preview bottom drawer ignores top safe area and keeps bottom inset',
    (WidgetTester tester) async {
      tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 40, bottom: 24);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      await tester.pumpWidget(
        awaitableOverlayApp(
          child: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showMoviePlotPreviewOverlay(
                        context: context,
                        plotImages: _plotImages,
                        initialIndex: 1,
                        presentation: MoviePlotPreviewPresentation.bottomDrawer,
                      ),
                  child: const Text('open'),
                ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final drawerRect = tester.getRect(
        find.byKey(const Key('movie-plot-preview-bottom-drawer')),
      );
      final counterRect = tester.getRect(
        find.byKey(const Key('movie-plot-preview-counter')),
      );

      expect(counterRect.top - drawerRect.top, 16);
    },
  );

  testWidgets('plot preview on mobile hides close button', (
    WidgetTester tester,
  ) async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        awaitableOverlayApp(
          child: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showMoviePlotPreviewOverlay(
                        context: context,
                        plotImages: _plotImages,
                        initialIndex: 1,
                        presentation: MoviePlotPreviewPresentation.bottomDrawer,
                      ),
                  child: const Text('open'),
                ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-plot-preview-close')), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });

  testWidgets('plot preview dialog switches page when tapping thumbnail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      awaitableOverlayApp(
        child: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: _plotImages,
                      initialIndex: 0,
                    ),
                child: const Text('open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-plot-preview-thumb-1')));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('plot preview dialog forwards thumbnail secondary tap to menu', (
    WidgetTester tester,
  ) async {
    int? menuIndex;
    Offset? menuPosition;

    await tester.pumpWidget(
      awaitableOverlayApp(
        child: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: _plotImages,
                      initialIndex: 0,
                      onRequestImageMenu: (
                        context,
                        index,
                        globalPosition,
                      ) async {
                        menuIndex = index;
                        menuPosition = globalPosition;
                      },
                    ),
                child: const Text('open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final center = tester.getCenter(
      find.byKey(const Key('movie-plot-preview-thumb-1')),
    );
    await tester.tapAt(center, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(menuIndex, 1);
    expect(menuPosition, equals(center));
  });

  testWidgets('plot preview dialog forwards main image secondary tap to menu', (
    WidgetTester tester,
  ) async {
    int? menuIndex;
    Offset? menuPosition;

    await tester.pumpWidget(
      awaitableOverlayApp(
        child: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: _plotImages,
                      initialIndex: 0,
                      onRequestImageMenu: (
                        context,
                        index,
                        globalPosition,
                      ) async {
                        menuIndex = index;
                        menuPosition = globalPosition;
                      },
                    ),
                child: const Text('open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final center = tester.getCenter(
      find.byKey(const Key('movie-plot-preview-main-image-0')),
    );
    await tester.tapAt(center, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(menuIndex, 0);
    expect(menuPosition, equals(center));
  });

  testWidgets('plot preview dialog forwards main image long press to menu', (
    WidgetTester tester,
  ) async {
    int? menuIndex;
    Offset? menuPosition;

    await tester.pumpWidget(
      awaitableOverlayApp(
        child: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: _plotImages,
                      initialIndex: 0,
                      onRequestImageMenu: (
                        context,
                        index,
                        globalPosition,
                      ) async {
                        menuIndex = index;
                        menuPosition = globalPosition;
                      },
                    ),
                child: const Text('open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final center = tester.getCenter(
      find.byKey(const Key('movie-plot-preview-main-image-0')),
    );
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(menuIndex, 0);
    expect(menuPosition, equals(center));
  });

  testWidgets('plot preview dialog ignores main image gutter menu request', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? menuIndex;
    Offset? menuPosition;

    await tester.pumpWidget(
      awaitableOverlayApp(
        child: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: _plotImages,
                      initialIndex: 0,
                      onRequestImageMenu: (
                        context,
                        index,
                        globalPosition,
                      ) async {
                        menuIndex = index;
                        menuPosition = globalPosition;
                      },
                    ),
                child: const Text('open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final mainImageRect = tester.getRect(
      find.byKey(const Key('movie-plot-preview-main-image-0')),
    );
    final fallbackAspectRatio =
        sakuraThemeData
            .extension<AppComponentTokens>()!
            .movieDetailPlotThumbnailWidth /
        sakuraThemeData
            .extension<AppComponentTokens>()!
            .movieDetailPlotThumbnailHeight;
    final viewportAspectRatio = mainImageRect.width / mainImageRect.height;

    final outsidePoint =
        viewportAspectRatio > fallbackAspectRatio
            ? Offset(mainImageRect.left + 4, mainImageRect.center.dy)
            : Offset(mainImageRect.center.dx, mainImageRect.top + 4);

    await tester.tapAt(outsidePoint, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(menuIndex, isNull);
    expect(menuPosition, isNull);
  });

  testWidgets('plot preview dialog switches page with arrow keys', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      awaitableOverlayApp(
        child: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: _plotImages,
                      initialIndex: 0,
                    ),
                child: const Text('open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('plot preview dialog uses fixed thumbnail width in fixed mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      awaitableOverlayApp(
        child: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: _plotImages,
                      initialIndex: 1,
                      thumbnailStripLayout:
                          MoviePlotPreviewThumbnailStripLayout.fixed,
                    ),
                child: const Text('open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('movie-plot-preview-thumb-1'))).width,
      sakuraThemeData
          .extension<AppComponentTokens>()!
          .movieDetailPlotPreviewThumbnailWidth,
    );
  });

  testWidgets(
    'plot preview dialog scrolls fixed thumbnail strip to a large initial index',
    (WidgetTester tester) async {
      final plotImages = List<MovieImageDto>.generate(
        60,
        (index) => MovieImageDto(
          id: index + 1,
          origin: 'plot-$index.jpg',
          small: 'plot-$index-small.jpg',
          medium: 'plot-$index-medium.jpg',
          large: 'plot-$index-large.jpg',
        ),
      );

      await tester.pumpWidget(
        awaitableOverlayApp(
          child: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showMoviePlotPreviewOverlay(
                        context: context,
                        plotImages: plotImages,
                        initialIndex: 36,
                        thumbnailStripLayout:
                            MoviePlotPreviewThumbnailStripLayout.fixed,
                      ),
                  child: const Text('open'),
                ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('37 / 60'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-plot-preview-thumb-36')),
        findsOneWidget,
      );

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('movie-plot-preview-thumbnail-list')),
          matching: find.byType(Scrollable),
        ),
      );

      expect(scrollable.position.pixels, greaterThan(0));
    },
  );
}

Widget awaitableOverlayApp({required Widget child}) {
  final sessionStore = SessionStore.inMemory();
  return ChangeNotifierProvider<SessionStore>.value(
    value: sessionStore,
    child: MaterialApp(theme: sakuraThemeData, home: Scaffold(body: child)),
  );
}

const List<MovieImageDto> _plotImages = <MovieImageDto>[
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
];
