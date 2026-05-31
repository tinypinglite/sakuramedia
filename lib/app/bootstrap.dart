import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/config/app_image_config.dart';
import 'package:sakuramedia/app/window_bootstrap_stub.dart'
    if (dart.library.io) 'package:sakuramedia/app/window_bootstrap_desktop.dart'
    as window_bootstrap;

Future<void> bootstrapApplication() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureImageCacheBudget();
  MediaKit.ensureInitialized();

  if (kIsWeb) {
    // 禁用浏览器默认右键菜单，让应用内的 onSecondaryTapDown 自定义菜单生效。
    await BrowserContextMenu.disableContextMenu();
  }

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
