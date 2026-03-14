import 'package:flutter/foundation.dart';

enum AppPlatform { desktop, mobile, web }

enum AppShellLayout { standard, fullscreen }

AppPlatform resolveAppPlatform({AppPlatform? override}) {
  if (override != null) {
    return override;
  }
  if (kIsWeb) {
    return AppPlatform.web;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return AppPlatform.desktop;
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return AppPlatform.mobile;
    case TargetPlatform.fuchsia:
      return AppPlatform.desktop;
  }
}
