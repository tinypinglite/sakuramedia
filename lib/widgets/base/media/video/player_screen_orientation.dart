import 'package:flutter/services.dart';

/// 移动端播放器的方向统一入口（「层级二」共享实现）。
///
/// 桌面端不使用这些函数：桌面全屏是 media_kit 的原生窗口全屏（method channel），
/// 方向由窗口系统决定。播放页的沉浸系统栏由页面级
/// `landscape_player_system_ui.dart` 统一管理；这里只负责方向，避免
/// media_kit 的全屏进出重复切换系统栏。

/// 进入 media_kit 全屏：跟随系统传感器。
///
/// Android 上该组合映射为 `user`（尊重系统自动旋转开关）；iOS 上放开
/// 竖屏 + 两个横屏，由系统旋转锁决定实际朝向。
Future<void> enterPlayerFullscreenOrientation() async {
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

/// 播放页默认方向：锁横屏。
///
/// Android 上 `[landscapeLeft, landscapeRight]` 映射为 `userLandscape`，
/// 不受系统自动旋转开关影响，保证分栏布局始终横屏可用。
Future<void> lockPlayerPageLandscape() async {
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

/// 播放页竖屏方向：仅锁正向竖屏。
///
/// 移动端播放器默认横屏；用户点旋转按钮后切到竖屏。倒置竖屏不在支持范围，
/// 避免手机平放时被系统判成上下颠倒。
Future<void> lockPlayerPagePortrait() async {
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
}
