import 'dart:io';

bool runtimeIsDesktopPlatform() {
  return Platform.isWindows || Platform.isMacOS;
}

bool runtimeIsMobilePlatform() {
  return Platform.isAndroid || Platform.isIOS;
}

bool runtimeIsAndroidPlatform() {
  return Platform.isAndroid;
}

bool runtimeIsIosPlatform() {
  return Platform.isIOS;
}
