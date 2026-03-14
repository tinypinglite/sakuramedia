import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
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
        home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
      ),
    );
  }
}
