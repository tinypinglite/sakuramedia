import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface.dart';

/// 「层级二」播放器统一入口：把裸 [Video] 外面的三层控制主题嵌套
/// （[MaterialVideoControlsTheme] + [MaterialDesktopVideoControlsTheme] + 控件 builder）
/// 收敛成一个无业务状态的展示组件，供所有「无字幕/无进度上报」的轻量播放场景复用
/// （快播弹窗、单切片/单视频全屏、切片/视频合集连播）。
///
/// 直接复用 [movie_player_surface] 里已有的主题构建函数，不重写主题逻辑：
/// - [buildMoviePlayerMobileControlsThemeData] / [buildMoviePlayerDesktopControlsThemeData]
/// - [resolveMoviePlayerVideoControlsBuilder]（`useTouchOptimizedControls` 决定
///   点击唤出 vs 鼠标 hover 唤出控制条）。
///
/// 顶/底控制条由调用方按场景传入（合集有上一首/下一首、单片/弹窗没有），
/// 本组件只负责把它们装进统一主题并渲染 [Video]。
class ThemedVideoPlayer extends StatelessWidget {
  const ThemedVideoPlayer({
    super.key,
    required this.videoController,
    required this.useTouchOptimizedControls,
    this.topControls = const <Widget>[],
    this.bottomControls = const <Widget>[],
    this.fullscreenBottomControls,
    this.videoKey,
    this.fit = BoxFit.contain,
    this.fill = Colors.black,
  });

  final VideoController videoController;

  /// `true` → [MaterialVideoControls]（点击屏幕唤出，为触摸而设计）；
  /// `false` → [MaterialDesktopVideoControls]（鼠标 hover 唤出）。
  final bool useTouchOptimizedControls;

  final List<Widget> topControls;
  final List<Widget> bottomControls;

  /// 全屏态底栏控制条；为 `null` 时沿用 [bottomControls]。
  ///
  /// media_kit 进全屏会 push 一个独立路由，页面级浮层（如合集连播的「选集」面板）
  /// 不在该路由内、点了也看不到。需要「仅窗口态可用」的按钮时，传一份去掉该按钮的
  /// 列表给本参数，避免全屏里出现点了没反应的死按钮。
  final List<Widget>? fullscreenBottomControls;

  /// 透传给内部 [Video] 的 Key，用于保留现有测试锚点（如 `clip-player-video`）。
  final Key? videoKey;

  final BoxFit fit;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullscreenBottom = fullscreenBottomControls ?? bottomControls;
    final desktopThemeData = buildMoviePlayerDesktopControlsThemeData(
      theme: theme,
      topControls: topControls,
      bottomControls: bottomControls,
    );
    final desktopFullscreenThemeData = buildMoviePlayerDesktopControlsThemeData(
      theme: theme,
      topControls: topControls,
      bottomControls: fullscreenBottom,
    );
    final mobileThemeData = buildMoviePlayerMobileControlsThemeData(
      theme: theme,
      topControls: topControls,
      bottomControls: bottomControls,
    );
    final mobileFullscreenThemeData = buildMoviePlayerMobileControlsThemeData(
      theme: theme,
      topControls: topControls,
      bottomControls: fullscreenBottom,
    );
    return MaterialVideoControlsTheme(
      normal: mobileThemeData,
      fullscreen: mobileFullscreenThemeData,
      child: MaterialDesktopVideoControlsTheme(
        normal: desktopThemeData,
        fullscreen: desktopFullscreenThemeData,
        child: Video(
          key: videoKey,
          controller: videoController,
          fit: fit,
          fill: fill,
          controls: resolveMoviePlayerVideoControlsBuilder(
            useTouchOptimizedControls: useTouchOptimizedControls,
          ),
        ),
      ),
    );
  }
}
