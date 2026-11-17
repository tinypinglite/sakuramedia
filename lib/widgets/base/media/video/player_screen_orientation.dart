import 'package:flutter/services.dart';

/// 移动端播放器的方向统一入口（「层级二」共享实现）。
///
/// 桌面端不使用这些函数：桌面全屏是 media_kit 的原生窗口全屏（method channel），
/// 方向由窗口系统决定。播放页的沉浸系统栏由页面级
/// `landscape_player_system_ui.dart` 统一管理；这里只负责方向，避免
/// media_kit 的全屏进出重复切换系统栏。

/// 播放页锁定方向：只允许横屏。
///
/// Android 上 `[landscapeLeft, landscapeRight]` 映射为 `userLandscape`，
/// 两个横屏方向都允许，因此翻转 180° 仍会跟随传感器；竖屏被排除。
Future<void> lockPlayerPageLandscape() async {
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

/// 播放页解锁方向：交给系统传感器决定，横竖屏都可用。
///
/// Android 上空列表映射为 `unspecified`，遵循系统自动旋转开关；iOS 上放开
/// `Info.plist` 允许的全部方向。
Future<void> unlockPlayerOrientation() async {
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
}

/// 按播放页当前的方向锁状态应用系统方向。
Future<void> applyPlayerOrientationLock({required bool locked}) {
  return locked ? lockPlayerPageLandscape() : unlockPlayerOrientation();
}
