import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/media/app_image_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';

import 'test_api_bundle.dart';

/// Widget 预览验证的共享基建。用法与坑位说明见 `docs/widget-preview-testing.md`。
///
/// 预览脚本（`*_preview.dart`，临时、不入库）只写 fixture 和场景：
///
/// ```dart
/// void main() {
///   setUpAll(loadPreviewFonts);
///   // ... setUp 里 createTestApiBundle
///
///   testWidgets('desktop light', (tester) async {
///     final cover = await makePreviewImage(width: 800, height: 1200);
///     registerPreviewImage(coverUrl, cover);
///     await pumpPreviewApp(
///       tester,
///       home: const MovieDetailPage(movieNumber: 'ABC-001', mobile: false),
///       size: const Size(1100, 760),
///       theme: buildSakuraDesktopThemeData(),
///       platform: TargetPlatform.macOS,
///       bundle: bundle,
///       outputPath: '${previewOutputDirectory('movie-detail')}/desktop.png',
///     );
///   });
/// }
/// ```

// ==================== 字体与主题 ====================

/// 加载预览用字体：探测本机中文字体 + 当前 Flutter SDK 的 MaterialIcons。
///
/// 在 `main()` 顶部 `setUpAll(loadPreviewFonts);` 调用。不加载则中文全是
/// 方框（flutter_test 默认 FlutterTest 字体），截图不能作为视觉验收依据。
Future<void> loadPreviewFonts() async {
  const candidates = <String>[
    '/System/Library/Fonts/Hiragino Sans GB.ttc',
    '/System/Library/Fonts/STHeiti Light.ttc',
    '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
  ];
  final cjkFile = candidates
      .map(File.new)
      .firstWhere(
        (file) => file.existsSync(),
        orElse: () => throw StateError('找不到可用的中文字体，请检查本机字体路径'),
      );
  final cjk = FontLoader('PreviewCjk');
  cjk.addFont(cjkFile.readAsBytes().then(ByteData.sublistView));
  await cjk.load();

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    throw StateError('FLUTTER_ROOT 未设置：请用 flutter test 运行预览脚本');
  }
  final icons = FontLoader('MaterialIcons');
  icons.addFont(
    File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes().then(ByteData.sublistView),
  );
  await icons.load();
}

/// 把真实中文字体挂到主题上（业务 Text 大量走 textTheme / DefaultTextStyle）。
ThemeData previewTheme(ThemeData theme, TargetPlatform platform) {
  return theme.copyWith(
    platform: platform,
    textTheme: theme.textTheme.apply(fontFamily: 'PreviewCjk'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'PreviewCjk'),
  );
}

// ==================== 可控图片 ====================

/// 生成一张可辨识的测试图：斜向渐变 + 高光圆 + 底部深色标题带。
///
/// [colors] 必须恰好两个（ui.Gradient.linear 不带 stops 的约束）。
/// 封面/头像等比例与裁切验证都用它，不要用失败占位图当验收依据。
Future<ui.Image> makePreviewImage({
  required int width,
  required int height,
  List<Color> colors = const <Color>[Color(0xFF7B2FF7), Color(0xFFF107A3)],
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final w = width.toDouble();
  final h = height.toDouble();
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(w, h), colors),
  );
  canvas.drawCircle(
    Offset(w * 0.5, h * 0.32),
    w * 0.2,
    Paint()..color = const Color(0xCCFFFFFF),
  );
  canvas.drawCircle(
    Offset(w * 0.5, h * 0.32),
    w * 0.1,
    Paint()..color = const Color(0xFF1B1035),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, h * 0.78, w, h * 0.22),
    Paint()..color = const Color(0xCC0B0B12),
  );
  return recorder.endRecording().toImage(width, height);
}

/// 从本地 PNG 文件读成已解码图片（用仓库真实素材做封面/头像）。
Future<ui.Image> loadPreviewImageFromFile(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// 给预览注册可控图片：`url` 的远程图直接渲染为 [image]（已解码，同步可用）。
///
/// 必须在 `pumpWidget` 之前注册；注册表按原始 URL 精确匹配
/// （即 DTO 里 `cover_image.origin` 经 `resolveMediaUrl` 后的完整地址）。
/// 同一 URL 重复注册会覆盖；`setUp` 里调 [clearPreviewImages] 防串场。
void registerPreviewImage(String url, ui.Image image) {
  debugRemoteImageOverrides[url] = _PreviewImageProvider(image);
}

/// 批量注册，见 [registerPreviewImage]。
void registerPreviewImages(Map<String, ui.Image> images) {
  for (final entry in images.entries) {
    registerPreviewImage(entry.key, entry.value);
  }
}

/// 清空图片注册表。
void clearPreviewImages() {
  debugRemoteImageOverrides.clear();
}

/// 已解码图片的同步 provider：绕开 `CachedNetworkImageProvider`（测试环境
/// 没有 path_provider / sqflite）与解码等待，首帧即出图；`ResizeImage`
/// 包装、比例/裁切/羽化逻辑照常工作。
class _PreviewImageProvider extends ImageProvider<_PreviewImageProvider> {
  _PreviewImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_PreviewImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_PreviewImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _PreviewImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: image)),
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

// ==================== 截图与装配 ====================

/// 本轮预览的唯一输出目录（系统临时目录下，自动创建）。
///
/// [taskName] 带任务与日期标识，例如 `movie-detail-20261011`；
/// 不要复用上一轮会话的目录，截图在验证结束后保留供查看。
String previewOutputDirectory(String taskName) {
  final dir = Directory(
    '${Directory.systemTemp.path}/sakuramedia-preview-$taskName',
  )..createSync(recursive: true);
  return dir.path;
}

/// `RepaintBoundary` → PNG。必须在目标已 paint 之后调用。
Future<void> capturePreview(
  WidgetTester tester,
  GlobalKey key,
  String outputPath, {
  double pixelRatio = 1,
}) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(outputPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
  expect(tester.takeException(), isNull);
}

/// 一次性装配预览页面并（可选）截图：
/// `ProviderScope + AppPlatformScope + OKToast + RepaintBoundary + MaterialApp`。
///
/// - 默认 `Scaffold(body: home)`；需要外壳（shell / 顶栏）时用 [wrap] 自定义。
/// - [size] 为逻辑尺寸（DPR 恒 1），结束自动复位。
/// - [settle] 为 false 时只 `pump` 两帧（加载态/持续动画场景），
///   调用方可自行 `pump(Duration(...))` 后手动 [capturePreview]。
/// - [locale] 决定 widget 层文案语言（`AppLocalizations.of(context)`）；
///   provider 层文案由 `appLocalizationsProvider` 决定，需要时用
///   [extraOverrides] 覆盖 `appLanguageStoreProvider`。
/// - 返回 RepaintBoundary 的 key，便于分阶段多次截图。
Future<GlobalKey> pumpPreviewApp(
  WidgetTester tester, {
  required Widget home,
  required Size size,
  required ThemeData theme,
  required TargetPlatform platform,
  required TestApiBundle bundle,
  AppPlatform appPlatform = AppPlatform.desktop,
  Widget Function(Widget child)? wrap,
  RiverpodPageCache? pageStateCache,
  Locale locale = const Locale('zh'),
  List<Override> extraOverrides = const <Override>[],
  bool settle = true,
  String? outputPath,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    AppSurfaceRuntime.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: ProviderScope(
        overrides: <Override>[
          ...bundle.riverpodOverrides(pageStateCache: pageStateCache),
          ...extraOverrides,
        ],
        child: AppPlatformScope(
          platform: appPlatform,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: locale,
              localizationsDelegates: <LocalizationsDelegate<dynamic>>[
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
              theme: previewTheme(theme, platform),
              builder: (context, child) =>
                  OKToast(child: child ?? const SizedBox.shrink()),
              home: wrap?.call(home) ?? Scaffold(body: home),
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(tester.takeException(), isNull);
  if (outputPath != null) {
    await capturePreview(tester, boundaryKey, outputPath);
  }
  return boundaryKey;
}
