import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/config/app_image_config.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 从 MaskedImage 渲染出的 `Image` widget 里取回 network 层的 URL。
/// 内部结构：`Image.image` 是 `ResizeImage(CachedNetworkImageProvider)`
/// 或直接就是 `CachedNetworkImageProvider`（未传 memCacheWidth/Height 时）。
String? _extractImageUrl(Image image) {
  final provider = image.image;
  if (provider is ResizeImage) {
    final inner = provider.imageProvider;
    if (inner is CachedNetworkImageProvider) {
      return inner.url;
    }
  }
  if (provider is CachedNetworkImageProvider) {
    return provider.url;
  }
  return null;
}

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

    final image = tester.widget<Image>(find.byType(Image));

    expect(_extractImageUrl(image), 'https://api.example.com/covers/a.jpg');
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

      final imageSize = tester.getSize(find.byType(Image));
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
      final imageSize = tester.getSize(find.byType(Image));
      final overflowBox = tester.widget<OverflowBox>(find.byType(OverflowBox));
      final expectedWidth = 160 / 0.47;

      expect(find.byType(ClipRect), findsOneWidget);
      expect(find.byType(OverflowBox), findsOneWidget);
      expect(clipRectSize.width, 160);
      expect(imageSize.width, moreOrLessEquals(expectedWidth, epsilon: 0.01));
      expect(overflowBox.alignment, Alignment.centerRight);
    },
  );

  testWidgets('masked image forwards alignment to underlying Image', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      _TestApp(
        sessionStore: sessionStore,
        child: const MaskedImage(
          url: '/covers/a.jpg',
          alignment: Alignment.topCenter,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.alignment, Alignment.topCenter);
  });

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
    expect(find.byType(Image), findsOneWidget);
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

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'masked image keeps ImageProvider identity stable across rebuilds',
    (WidgetTester tester) async {
      // 根治「SSE 每秒 tick → 卡片 rebuild → CachedNetworkImage/OctoImage 内部
      // 新 ResizeImage 实例 → Image element 被 ValueKey(image) 强制替换 → fade 重放」
      // 这条闪烁链路。断言：反复 setState 触发 MaskedImage 的 parent 重建后，
      // Image widget 的 `image` provider **identity 稳定**（== 且 identical）。
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      final rebuildTrigger = ValueNotifier<int>(0);
      addTearDown(rebuildTrigger.dispose);

      await tester.pumpWidget(
        _TestApp(
          sessionStore: sessionStore,
          child: ValueListenableBuilder<int>(
            valueListenable: rebuildTrigger,
            builder: (context, tick, _) {
              return MaskedImage(url: '/covers/a.jpg');
            },
          ),
        ),
      );

      final providerBefore = tester.widget<Image>(find.byType(Image)).image;

      for (var i = 0; i < 5; i++) {
        rebuildTrigger.value = i + 1;
        await tester.pump();
      }

      final providerAfter = tester.widget<Image>(find.byType(Image)).image;
      expect(
        identical(providerBefore, providerAfter),
        isTrue,
        reason:
            'MaskedImage 内部应该缓存 ImageProvider identity，避免高频 rebuild '
            '触发 Image element 重建 / fade 动画重放。',
      );
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
