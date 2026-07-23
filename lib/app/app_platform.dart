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
      return AppPlatform.desktop;
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return AppPlatform.mobile;
    default:
      throw UnsupportedError(
        'SakuraMedia does not support ${defaultTargetPlatform.name}.',
      );
  }
}

bool isMobileAppPlatform({AppPlatform? override}) {
  return resolveAppPlatform(override: override) == AppPlatform.mobile;
}
