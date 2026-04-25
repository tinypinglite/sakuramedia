import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/app_image_fullscreen.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/media/preview_image_stage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preview image stage uses contain fit by default', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: PreviewImageStage(
          imageUrl: '/preview.jpg',
          height: 240,
          onClose: () {},
        ),
      ),
    );

    final image = tester.widget<MaskedImage>(find.byType(MaskedImage));
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('preview image stage closes via action button', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    var closeTapCount = 0;

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: PreviewImageStage(
          imageUrl: '/preview.jpg',
          height: 240,
          closeButtonKey: const Key('preview-image-stage-close'),
          onClose: () => closeTapCount += 1,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('preview-image-stage-close')));
    await tester.pump();

    expect(closeTapCount, 1);
  });

  testWidgets('preview image stage renders black background stage', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: PreviewImageStage(
          imageUrl: '/preview.jpg',
          height: 240,
          onClose: () {},
        ),
      ),
    );

    final background = tester.widget<ColoredBox>(find.byType(ColoredBox).first);
    expect(background.color, Colors.black);
  });

  testWidgets('preview image stage opens fullscreen on tap', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: PreviewImageStage(
          imageUrl: '/preview.jpg',
          height: 240,
          onClose: () {},
          enablePinchToFullscreen: true,
          fullscreenImageKey: const Key('preview-image-stage-fullscreen-image'),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(PreviewImageStage));
    await tester.tapAt(rect.center);
    await _pumpAnimations(tester);

    _expectFullscreenVisible(tester);
    final overlay = tester.widget<ColoredBox>(
      find.byKey(kAppImageFullscreenOverlayKey),
    );
    expect(overlay.color, Colors.black);
    expect(
      tester.getSize(find.byKey(kAppImageFullscreenOverlayKey)),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
    expect(find.byType(PhotoViewGallery), findsOneWidget);
    final fullscreenImage = find.byKey(
      const Key('preview-image-stage-fullscreen-image'),
    );
    final fullscreenRect = tester.getRect(fullscreenImage);
    final overlayRect = tester.getRect(
      find.byKey(kAppImageFullscreenOverlayKey),
    );
    expect(fullscreenRect.width, lessThanOrEqualTo(overlayRect.width));
    expect(fullscreenRect.height, lessThanOrEqualTo(overlayRect.height));

    _expectFullscreenVisible(tester);
    expect(find.byType(PhotoViewGallery), findsOneWidget);
  });

  testWidgets('preview image stage fades fullscreen overlay in', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: PreviewImageStage(
          imageUrl: '/preview.jpg',
          height: 240,
          onClose: () {},
          enablePinchToFullscreen: true,
          fullscreenImageKey: const Key('preview-image-stage-fullscreen-image'),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(PreviewImageStage));
    await tester.tapAt(rect.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    _expectFullscreenVisible(tester);
    final overlay = tester.widget<ColoredBox>(
      find.byKey(kAppImageFullscreenOverlayKey),
    );
    expect(overlay.color, isNot(Colors.transparent));
    expect(overlay.color, isNot(Colors.black));
    final fullscreenImageOpacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const Key('preview-image-stage-fullscreen-image')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(fullscreenImageOpacity.opacity, greaterThan(0));
    expect(fullscreenImageOpacity.opacity, lessThan(1));

    await _pumpAnimations(tester);
    final settledOverlay = tester.widget<ColoredBox>(
      find.byKey(kAppImageFullscreenOverlayKey),
    );
    expect(settledOverlay.color, Colors.black);
  });

  testWidgets('preview image stage keeps fullscreen gallery after tap', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: PreviewImageStage(
          imageUrl: '/preview.jpg',
          height: 240,
          onClose: () {},
          enablePinchToFullscreen: true,
          fullscreenImageKey: const Key('preview-image-stage-fullscreen-image'),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(PreviewImageStage));
    await tester.tapAt(rect.center);
    await _pumpAnimations(tester);

    expect(find.byType(PhotoViewGallery), findsOneWidget);

    _expectFullscreenVisible(tester);
    expect(find.byType(PhotoViewGallery), findsOneWidget);
  });

  testWidgets('preview image stage closes fullscreen via close button', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: PreviewImageStage(
          imageUrl: '/preview.jpg',
          height: 240,
          onClose: () {},
          enablePinchToFullscreen: true,
          fullscreenImageKey: const Key('preview-image-stage-fullscreen-image'),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(PreviewImageStage));
    await tester.tapAt(rect.center);
    await _pumpAnimations(tester);

    _expectFullscreenVisible(tester);
    await tester.tap(find.byKey(kAppImageFullscreenCloseButtonKey));
    await _pumpAnimations(tester);

    expect(find.byKey(kAppImageFullscreenOverlayKey), findsNothing);
  });

  testWidgets('preview image stage dismisses fullscreen on tap', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: PreviewImageStage(
          imageUrl: '/preview.jpg',
          height: 240,
          onClose: () {},
          enablePinchToFullscreen: true,
          fullscreenImageKey: const Key('preview-image-stage-fullscreen-image'),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(PreviewImageStage));
    await tester.tapAt(rect.center);
    await _pumpAnimations(tester);

    _expectFullscreenVisible(tester);
    final tap = await tester.startGesture(rect.center);
    await tester.pump();
    await tap.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    _expectFullscreenVisible(tester);
    final exitingOverlay = tester.widget<ColoredBox>(
      find.byKey(kAppImageFullscreenOverlayKey),
    );
    expect(exitingOverlay.color, isNot(Colors.black));

    await _pumpAnimations(tester);
    expect(find.byKey(kAppImageFullscreenOverlayKey), findsNothing);
  });

  testWidgets('preview image stage dismisses fullscreen on swipe down', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: PreviewImageStage(
          imageUrl: '/preview.jpg',
          height: 240,
          onClose: () {},
          enablePinchToFullscreen: true,
          fullscreenImageKey: const Key('preview-image-stage-fullscreen-image'),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(PreviewImageStage));
    await tester.tapAt(rect.center);
    await _pumpAnimations(tester);

    _expectFullscreenVisible(tester);
    final fullscreenImage = find.byKey(
      const Key('preview-image-stage-fullscreen-image'),
    );
    final fullscreenRect = tester.getRect(fullscreenImage);
    final swipe = await tester.startGesture(rect.center);
    await tester.pump();
    await swipe.moveBy(const Offset(0, 120));
    await tester.pump();
    expect(
      tester.getRect(fullscreenImage).top,
      greaterThan(fullscreenRect.top),
    );
    await swipe.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    _expectFullscreenVisible(tester);
    final exitingOverlay = tester.widget<ColoredBox>(
      find.byKey(kAppImageFullscreenOverlayKey),
    );
    expect(exitingOverlay.color, isNot(Colors.black));

    await _pumpAnimations(tester);
    expect(find.byKey(kAppImageFullscreenOverlayKey), findsNothing);
  });

  testWidgets('preview image stage keeps fullscreen after short swipe down', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: PreviewImageStage(
          imageUrl: '/preview.jpg',
          height: 240,
          onClose: () {},
          enablePinchToFullscreen: true,
          fullscreenImageKey: const Key('preview-image-stage-fullscreen-image'),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(PreviewImageStage));
    await tester.tapAt(rect.center);
    await _pumpAnimations(tester);

    final fullscreenImage = find.byKey(
      const Key('preview-image-stage-fullscreen-image'),
    );
    final fullscreenRect = tester.getRect(fullscreenImage);
    final swipe = await tester.startGesture(rect.center);
    await tester.pump();
    await swipe.moveBy(const Offset(0, 40));
    await tester.pump();
    await swipe.up();
    await _pumpAnimations(tester);

    _expectFullscreenVisible(tester);
    _expectRectCloseTo(tester.getRect(fullscreenImage), fullscreenRect);
  });

  testWidgets('preview image stage dismisses fullscreen on system back', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder:
              (_, __) => Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: PreviewImageStage(
                      imageUrl: '/preview.jpg',
                      height: 240,
                      onClose: () {},
                      enablePinchToFullscreen: true,
                      fullscreenImageKey: const Key(
                        'preview-image-stage-fullscreen-image',
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        ],
        child: MaterialApp.router(
          theme: sakuraThemeData,
          routerConfig: router,
          builder:
              (context, content) =>
                  AppImageFullscreenHost(child: content ?? const SizedBox()),
        ),
      ),
    );
    await _pumpAnimations(tester);

    final rect = tester.getRect(find.byType(PreviewImageStage));
    await tester.tapAt(rect.center);
    await _pumpAnimations(tester);

    _expectFullscreenVisible(tester);
    await tester.binding.handlePopRoute();
    await _pumpAnimations(tester);

    expect(find.byKey(kAppImageFullscreenOverlayKey), findsNothing);
  });
}

Future<void> _pumpAnimations(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _expectFullscreenVisible(WidgetTester tester) {
  expect(find.byKey(kAppImageFullscreenOverlayKey), findsOneWidget);
  expect(
    find.byKey(const Key('preview-image-stage-fullscreen-image')),
    findsOneWidget,
  );
}

void _expectRectCloseTo(Rect actual, Rect expected, {double tolerance = 0.01}) {
  expect(actual.left, closeTo(expected.left, tolerance));
  expect(actual.top, closeTo(expected.top, tolerance));
  expect(actual.width, closeTo(expected.width, tolerance));
  expect(actual.height, closeTo(expected.height, tolerance));
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.sessionStore, required this.child});

  final SessionStore sessionStore;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        builder:
            (context, content) =>
                AppImageFullscreenHost(child: content ?? const SizedBox()),
        home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
      ),
    );
  }
}
