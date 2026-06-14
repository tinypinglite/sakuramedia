import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 横屏全屏沉浸式播放的系统 UI 控制：进入隐藏系统栏并锁定横屏，退出恢复系统栏并
/// 解除方向锁定。
///
/// 由影片播放页（`MobileMoviePlayerPage`）、单切片播放页（`MobileClipPlayerPage`）
/// 与切片合集连播页（`MobileClipCollectionPlayPage`）共用，保证三处进出沉浸式横屏的
/// 行为完全一致，避免各自维护一份逻辑造成漂移。

/// 进入横屏全屏沉浸式：隐藏系统栏并锁定横屏。
Future<void> enterLandscapePlayerSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

/// 退出播放：恢复系统栏并解除方向锁定，回到进入前的方向。
Future<void> restoreSystemUiAfterLandscapePlayer() async {
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      ),
    );
  });
}
