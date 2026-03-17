import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/window_bootstrap_stub.dart'
    if (dart.library.io) 'package:sakuramedia/app/window_bootstrap_desktop.dart'
    as window_bootstrap;

Future<void> bootstrapApplication() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (resolveAppPlatform() != AppPlatform.desktop) {
    return;
  }

  await window_bootstrap.bootstrapDesktopWindow();
}
