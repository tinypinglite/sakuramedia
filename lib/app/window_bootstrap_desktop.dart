import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:window_manager/window_manager.dart';

Future<void> bootstrapDesktopWindow() async {
  await windowManager.ensureInitialized();
  final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
  final windowOptions = WindowOptions(
    size: const Size(1440, 800),
    minimumSize: const Size(1440, 800),
    center: true,
    backgroundColor:
        isMacOS ? Colors.transparent : const AppColors.defaults().surfaceCard,
    skipTaskbar: false,
    titleBarStyle: isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
    windowButtonVisibility: true,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
