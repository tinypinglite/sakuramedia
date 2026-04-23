import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  testWidgets('preview image stage resets to fullscreen after pinch in', (
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
    final leftFinger = await tester.startGesture(
      Offset(rect.center.dx - 20, rect.center.dy),
    );
    await tester.pump();
    final rightFinger = await tester.startGesture(
      Offset(rect.center.dx + 20, rect.center.dy),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    _expectFullscreenVisible(tester);
    final overlay = tester.widget<ColoredBox>(
      find.byKey(kAppImageFullscreenOverlayKey),
    );
    expect(overlay.color, Colors.black.withValues(alpha: 0.96));
    final fullscreenImage = find.byKey(
      const Key('preview-image-stage-fullscreen-image'),
    );
    final fullscreenRect = tester.getRect(fullscreenImage);

    await leftFinger.moveTo(Offset(rect.center.dx - 5, rect.center.dy));
    await rightFinger.moveTo(Offset(rect.center.dx + 5, rect.center.dy));
    await tester.pump();
    final shrunkenRect = tester.getRect(fullscreenImage);
    expect(shrunkenRect.width, lessThan(fullscreenRect.width));
    await leftFinger.up();
    await rightFinger.up();
    await tester.pumpAndSettle();

    _expectFullscreenVisible(tester);
    _expectRectCloseTo(tester.getRect(fullscreenImage), fullscreenRect);
  });

  testWidgets('preview image stage resets to fullscreen after pinch out', (
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
    final leftFinger = await tester.startGesture(
      Offset(rect.center.dx - 20, rect.center.dy),
    );
    await tester.pump();
    final rightFinger = await tester.startGesture(
      Offset(rect.center.dx + 20, rect.center.dy),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final fullscreenImage = find.byKey(
      const Key('preview-image-stage-fullscreen-image'),
    );
    final fullscreenRect = tester.getRect(fullscreenImage);

    await leftFinger.moveTo(Offset(rect.center.dx - 45, rect.center.dy));
    await rightFinger.moveTo(Offset(rect.center.dx + 45, rect.center.dy));
    await tester.pump();
    final expandedRect = tester.getRect(fullscreenImage);
    expect(expandedRect.width, greaterThan(fullscreenRect.width));
    await leftFinger.up();
    await rightFinger.up();
    await tester.pumpAndSettle();

    _expectFullscreenVisible(tester);
    _expectRectCloseTo(tester.getRect(fullscreenImage), fullscreenRect);
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
    final leftFinger = await tester.startGesture(
      Offset(rect.center.dx - 20, rect.center.dy),
    );
    await tester.pump();
    final rightFinger = await tester.startGesture(
      Offset(rect.center.dx + 20, rect.center.dy),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await leftFinger.up();
    await rightFinger.up();
    await tester.pumpAndSettle();

    _expectFullscreenVisible(tester);
    await tester.tap(find.byKey(kAppImageFullscreenCloseButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(kAppImageFullscreenOverlayKey), findsNothing);
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
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(PreviewImageStage));
    final leftFinger = await tester.startGesture(
      Offset(rect.center.dx - 20, rect.center.dy),
    );
    await tester.pump();
    final rightFinger = await tester.startGesture(
      Offset(rect.center.dx + 20, rect.center.dy),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await leftFinger.up();
    await rightFinger.up();
    await tester.pumpAndSettle();

    _expectFullscreenVisible(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(kAppImageFullscreenOverlayKey), findsNothing);
  });
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
