import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/config/app_image_config.dart';
import 'package:sakuramedia/core/media/app_image_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_thumbnail.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_fullscreen.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

void main() {
  late bool originalEnableBlur;
  late SessionStore sessionStore;

  setUp(() async {
    originalEnableBlur = AppImageConfig.enableBlur;
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
  });

  tearDown(() {
    AppImageConfig.enableBlur = originalEnableBlur;
    debugRemoteImageOverrides.clear();
  });

  group('MaskedImage', () {
    testWidgets('遮罩开启时不解析图片 provider', (tester) async {
      final provider = _CountingImageProvider();
      debugRemoteImageOverrides['https://api.example.com/cover.jpg'] = provider;
      AppImageConfig.enableBlur = true;

      await _pumpMaskedImage(tester, sessionStore);
      await tester.pump();

      expect(provider.loadCalls, 0);
    });

    testWidgets('遮罩关闭时照常解析图片 provider', (tester) async {
      final provider = _CountingImageProvider();
      debugRemoteImageOverrides['https://api.example.com/cover.jpg'] = provider;
      AppImageConfig.enableBlur = false;

      await _pumpMaskedImage(tester, sessionStore);
      await tester.pump();

      expect(provider.loadCalls, greaterThan(0));
    });
  });

  group('MoviePlotThumbnail', () {
    testWidgets('遮罩开启时不解析图片 provider', (tester) async {
      final provider = _CountingImageProvider();
      AppImageConfig.enableBlur = true;

      await _pumpMoviePlotThumbnail(tester, provider);
      await tester.pump();

      expect(provider.loadCalls, 0);
    });

    testWidgets('遮罩关闭时照常解析图片 provider', (tester) async {
      final provider = _CountingImageProvider();
      AppImageConfig.enableBlur = false;

      await _pumpMoviePlotThumbnail(tester, provider);
      await tester.pump();

      expect(provider.loadCalls, greaterThan(0));
    });
  });

  group('AppPinchToFullscreenImage', () {
    testWidgets('遮罩开启时不解析图片 provider', (tester) async {
      final provider = _CountingImageProvider();
      AppImageConfig.enableBlur = true;

      await _pumpPinchToFullscreenImage(tester, provider);
      await tester.pump();

      expect(provider.loadCalls, 0);
    });

    testWidgets('遮罩关闭时照常解析图片 provider', (tester) async {
      final provider = _CountingImageProvider();
      AppImageConfig.enableBlur = false;

      await _pumpPinchToFullscreenImage(tester, provider);
      await tester.pump();

      expect(provider.loadCalls, greaterThan(0));
    });
  });
}

Future<void> _pumpMaskedImage(WidgetTester tester, SessionStore sessionStore) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
      child: MaterialApp(
        theme: sakuraDesktopThemeData,
        home: const Scaffold(
          body: SizedBox(
            width: 120,
            height: 160,
            child: MaskedImage(url: '/cover.jpg'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpMoviePlotThumbnail(
  WidgetTester tester,
  ImageProvider<Object> provider,
) {
  return tester.pumpWidget(
    MaterialApp(
      theme: sakuraDesktopThemeData,
      home: Scaffold(
        body: MoviePlotThumbnail(maxHeight: 100, imageProvider: provider),
      ),
    ),
  );
}

Future<void> _pumpPinchToFullscreenImage(
  WidgetTester tester,
  ImageProvider<Object> provider,
) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: sakuraDesktopThemeData,
        home: Scaffold(
          body: AppPinchToFullscreenImage(
            imageProvider: provider,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    ),
  );
}

class _CountingImageProvider extends ImageProvider<_CountingImageProvider> {
  int loadCalls = 0;

  @override
  Future<_CountingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_CountingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _CountingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    loadCalls += 1;
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}
