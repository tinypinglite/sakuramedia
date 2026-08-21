import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/config/app_image_config.dart';
import 'package:sakuramedia/app/window_bootstrap_desktop.dart'
    as window_bootstrap;

Future<void> bootstrapApplication() async {
  // marionette 需要在所有其他 binding 之前初始化（binding 是单例，第一个生效）。
  // 仅 debug 模式启用，让 AI agent 通过 VM Service 截图/检查 widget 树；release 不受影响。
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  configureImageCacheBudget();
  MediaKit.ensureInitialized();

  if (resolveAppPlatform() != AppPlatform.desktop) {
    return;
  }

  await window_bootstrap.bootstrapDesktopWindow();
}

@visibleForTesting
void configureImageCacheBudget() {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = AppImageConfig.imageCacheMaximumSize;
  imageCache.maximumSizeBytes = AppImageConfig.imageCacheMaximumSizeBytes;
}
