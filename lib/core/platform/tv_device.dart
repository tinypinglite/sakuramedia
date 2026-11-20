import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sakuramedia/app/app_platform.dart';

const bool _forceTvLayout = bool.fromEnvironment('SAKURAMEDIA_TV');

/// Android TV 设备探测。
///
/// Pico 等 Android 设备没有 Leanback 特性，不能依赖系统自动判断；
/// 这类设备通过 `--dart-define=SAKURAMEDIA_TV=true` 使用同一套 TV 布局。
abstract final class TvDevice {
  static const MethodChannel _channel = MethodChannel('sakuramedia/tv_device');

  static Future<bool> isTelevision() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

Future<AppPlatform?> detectAppPlatformOverride() async {
  if (_forceTvLayout || await TvDevice.isTelevision()) {
    return AppPlatform.tv;
  }
  return null;
}
