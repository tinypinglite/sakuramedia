import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sakuramedia/core/platform/immersive_system_ui.dart';
import 'package:sakuramedia/widgets/base/media/video/player_screen_orientation.dart';

/// 播放页横屏沉浸式的页面级 SystemUI 生命周期：进入锁横屏并隐藏系统栏，
/// 退出恢复系统栏并解除方向锁定。
///
/// 由影片播放页（`MobileMoviePlayerPage`）、单切片播放页（`MobileClipPlayerPage`）、
/// 切片合集连播页、单视频播放页与视频合集连播页共用，保证各处进出播放页的行为
/// 一致，避免各自维护一份逻辑造成漂移。
///
/// 移动端底栏不提供全屏入口；若 media_kit 全屏路由由其它方式触发，
/// `ThemedVideoPlayer` / `MoviePlayerSurface` 只接管方向，系统栏仍由本页
/// 生命周期持有，避免重复切换。

/// 进入播放页：锁横屏并隐藏系统栏。
Future<void> enterLandscapePlayerSystemUi() async {
  await setImmersiveSystemUi(enabled: true);
  await lockPlayerPageLandscape();
}

/// 退出播放页：恢复系统栏并解除方向锁定，交给系统默认。
Future<void> restoreSystemUiAfterLandscapePlayer() async {
  await setImmersiveSystemUi(enabled: false);
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(setImmersiveSystemUi(enabled: false));
  });
}
