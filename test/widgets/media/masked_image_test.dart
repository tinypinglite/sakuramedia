import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/config/app_image_config.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppImageConfig.enableMask = true;
  });

  testWidgets('masked image prefixes relative url with session base url', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: const MaskedImage(url: '/covers/a.jpg'),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.imageUrl, 'https://api.example.com/covers/a.jpg');
  });

 

  testWidgets(
    'masked image does not wrap image when visible width factor unset',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        _TestApp(
          sessionStore: sessionStore,
          child: const MaskedImage(url: '/covers/a.jpg'),
        ),
      );

      expect(find.byType(ClipRect), findsNothing);

      final imageSize = tester.getSize(find.byType(CachedNetworkImage));
      expect(imageSize.width, 160);
    },
  );

  testWidgets(
    'masked image crops to visible width factor using provided alignment',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        _TestApp(
          sessionStore: sessionStore,
          child: const MaskedImage(
            url: '/covers/a.jpg',
            visibleWidthFactor: 0.47,
            visibleAlignment: Alignment.centerRight,
          ),
        ),
      );

      final clipRectSize = tester.getSize(find.byType(ClipRect));
      final imageSize = tester.getSize(find.byType(CachedNetworkImage));
      final overflowBox = tester.widget<OverflowBox>(find.byType(OverflowBox));
      final expectedWidth = 160 / 0.47;

      expect(find.byType(ClipRect), findsOneWidget);
      expect(find.byType(OverflowBox), findsOneWidget);
      expect(clipRectSize.width, 160);
      expect(imageSize.width, moreOrLessEquals(expectedWidth, epsilon: 0.01));
      expect(overflowBox.alignment, Alignment.centerRight);
    },
  );

  testWidgets('masked image skips color filter when mask is disabled', (
    WidgetTester tester,
  ) async {
    AppImageConfig.enableMask = false;
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: const MaskedImage(url: '/covers/a.jpg'),
      ),
    );

    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets(
    'masked image shows placeholder instead of network image when base url missing',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();

      await tester.pumpWidget(
        _TestApp(
          sessionStore: sessionStore,
          child: const MaskedImage(url: '/covers/a.jpg'),
        ),
      );

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    },
  );

  test('masked image rejects invalid visible width factor values', () {
    expect(
      () => MaskedImage(url: '/covers/a.jpg', visibleWidthFactor: 0),
      throwsAssertionError,
    );
    expect(
      () => MaskedImage(url: '/covers/a.jpg', visibleWidthFactor: 1.1),
      throwsAssertionError,
    );
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
        home: Scaffold(body: Center(child: SizedBox(width: 160, child: child))),
      ),
    );
  }
}
