import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('preview image stage enters and exits fullscreen on pinch', (
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

    expect(find.byKey(kAppImageFullscreenOverlayKey), findsOneWidget);
    expect(
      find.byKey(const Key('preview-image-stage-fullscreen-image')),
      findsOneWidget,
    );

    await leftFinger.moveTo(Offset(rect.center.dx - 5, rect.center.dy));
    await rightFinger.moveTo(Offset(rect.center.dx + 5, rect.center.dy));
    await tester.pump();
    await leftFinger.up();
    await rightFinger.up();
    await tester.pumpAndSettle();

    expect(find.byKey(kAppImageFullscreenOverlayKey), findsNothing);
  });
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
