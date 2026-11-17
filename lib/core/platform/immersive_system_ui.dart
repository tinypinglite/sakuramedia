import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('sakuramedia/immersive_system_ui');

/// 移动端全屏沉浸系统栏控制。
///
/// Android 使用原生 `WindowInsetsControllerCompat`：targetSdk 36 下 Flutter 的
/// `SystemUiMode.immersiveSticky` 会被系统忽略，不能再作为隐藏系统栏的实现。
/// 原生通道不可用时回退到 Flutter 的默认行为，避免测试环境或热重载期间抛错。
/// iOS 继续使用 `SystemChrome`。
Future<void> setImmersiveSystemUi({required bool enabled}) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      await _channel.invokeMethod<void>('setImmersive', <String, bool>{
        'enabled': enabled,
      });
      return;
    } catch (error) {
      debugPrint('[immersive-system-ui] native call failed: $error');
    }
  }

  if (enabled) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    return;
  }
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
}
