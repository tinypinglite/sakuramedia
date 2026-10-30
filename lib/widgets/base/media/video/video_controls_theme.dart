import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/media/video/sakura_desktop_video_controls.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';

/// 「层级二」轻量播放器的控制主题 / 控件 builder 构建函数。
///
/// 原本定义在 `movie_player_surface.dart`,现抽到 base 层——供 [ThemedVideoPlayer]
/// (`base/media/video/themed_video_player.dart`)与 `MoviePlayerSurface`
/// (`domain/movies/player/movie_player_surface.dart`)共用,断开 base→domain 的
/// 反向依赖。改控制条样式 / 按钮只改这里,一处生效(进度条 / 全屏 / 音量样式一致)。

@visibleForTesting
Widget buildMoviePlayerMobileVideoControls(VideoState state) {
  return MaterialVideoControls(state);
}

@visibleForTesting
Widget buildMoviePlayerDesktopVideoControls(VideoState state) {
  // media_kit 2.0.1 不会暂停外部 bottomSeekBar 的自动隐藏 timer。
  return SakuraDesktopVideoControls(state: state);
}

Widget Function(VideoState state) resolveMoviePlayerVideoControlsBuilder({
  required bool useTouchOptimizedControls,
}) {
  return useTouchOptimizedControls
      ? buildMoviePlayerMobileVideoControls
      : buildMoviePlayerDesktopVideoControls;
}

@visibleForTesting
Widget buildMoviePlayerBufferingIndicator(BuildContext context) {
  return VideoLoadingIndicator(
    label: appL10n(context).baseVideoBuffering,
  );
}

MaterialVideoControlsThemeData buildMoviePlayerMobileControlsThemeData({
  required ThemeData theme,
  required List<Widget> topControls,
  required List<Widget> bottomControls,
  bool displaySeekBar = true,
  bool seekEnabled = true,
  bool showBufferingIndicator = true,
  bool reserveTopRightToggle = false,
}) {
  final overlayTokens = theme.appOverlayTokens;
  // 右上角界面为常显的缩略图面板开关预留一格（开关贴右上角、与顶栏同宽内缩），
  // 让顶栏最右侧的「视频信息」按钮整体左移，避免与开关重叠。
  final topBarTrailingInset =
      overlayTokens.playerControlBarHorizontalInset +
      (reserveTopRightToggle
          ? overlayTokens.playerBackBadgeMinHeight + theme.appSpacing.sm
          : 0);
  return MaterialVideoControlsThemeData(
    horizontalGestureSensitivity: 3000,
    seekOnDoubleTap: seekEnabled,
    seekBarMargin: EdgeInsets.fromLTRB(
      overlayTokens.playerSeekBarHorizontalInset,
      0,
      overlayTokens.playerSeekBarHorizontalInset,
      overlayTokens.playerSeekBarBottomInset,
    ),
    seekGesture: seekEnabled,
    volumeGesture: true,
    speedUpOnLongPress: true,
    brightnessGesture: true,
    bufferingIndicatorBuilder: showBufferingIndicator
        ? buildMoviePlayerBufferingIndicator
        : (_) => const SizedBox.shrink(),
    seekBarThumbColor: theme.colorScheme.primary,
    seekBarPositionColor: theme.colorScheme.primary,
    seekBarHeight: 6,
    seekBarThumbSize: 14,
    // 初始化 seek 保护期只禁用交互，不隐藏进度条，避免完整媒体看起来没有进度。
    displaySeekBar: displaySeekBar,
    topButtonBar: topControls,
    topButtonBarMargin: EdgeInsets.fromLTRB(
      overlayTokens.playerControlBarHorizontalInset,
      overlayTokens.playerControlBarTopInset,
      topBarTrailingInset,
      0,
    ),
    bottomButtonBar: bottomControls,
  );
}

MaterialDesktopVideoControlsThemeData buildMoviePlayerDesktopControlsThemeData({
  required ThemeData theme,
  required List<Widget> topControls,
  required List<Widget> bottomControls,
  bool displaySeekBar = true,
  bool showBufferingIndicator = true,
  Widget? bottomSeekBar,
  bool reserveTopRightToggle = false,
  // 带右侧面板的播放页传 false：禁用 media_kit 双击进原生全屏路由
  // （该路由只含 Video，会丢右侧面板），改由应用内全屏接管。
  // 无面板场景（快播弹窗等）保持默认 true，行为不变。
  bool toggleFullscreenOnDoublePress = true,
}) {
  final overlayTokens = theme.appOverlayTokens;
  final topBarTrailingInset =
      overlayTokens.playerControlBarHorizontalInset +
      (reserveTopRightToggle
          ? overlayTokens.playerBackBadgeMinHeight + theme.appSpacing.sm
          : 0);
  return MaterialDesktopVideoControlsThemeData(
    toggleFullscreenOnDoublePress: toggleFullscreenOnDoublePress,
    bufferingIndicatorBuilder: showBufferingIndicator
        ? buildMoviePlayerBufferingIndicator
        : (_) => const SizedBox.shrink(),
    seekBarThumbColor: theme.colorScheme.primary,
    seekBarPositionColor: theme.colorScheme.primary,
    seekBarHeight: 6,
    seekBarThumbSize: 14,
    // media_kit_video 的 MaterialDesktopVolumeButton 内部用 AnimatedSwitcher 做
    // 音量图标切换动画；Flutter 有个已知 bug（flutter/flutter#121336）：动画过渡期间
    // 若同 key 的 widget 被快速再次触发切换，会在内部 Stack 里堆出两份相同 key，
    // 触发 "Duplicate keys found" 断言并连带炸出一串 layout 错误。触发场景是拖动
    // seek bar 造成的高频状态更新，音量图标切换本身不需要过渡动画（用户感知不到），
    // 直接设为 0 让切换在单帧内完成，从根上避开这条过渡期叠加窗口。
    volumeBarTransitionDuration: Duration.zero,
    displaySeekBar: bottomSeekBar == null && displaySeekBar,
    // 自定义进度条自带横向内边距（由 bottomButtonBarMargin 提供），
    // 这里清零避免与 media_kit 默认的 seekBarMargin 叠加。
    seekBarMargin: bottomSeekBar == null
        ? EdgeInsets.symmetric(horizontal: theme.appSpacing.lg)
        : EdgeInsets.zero,
    topButtonBar: bottomSeekBar == null
        ? topControls
        : <Widget>[
            Expanded(
              // 底栏集群把 buttonBarHeight 撑高后，用固定 56 高的贴顶行
              // 保持顶栏控件的原有纵向位置。
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  height: _moviePlayerDesktopButtonBarHeight,
                  child: Row(children: topControls),
                ),
              ),
            ),
          ],
    topButtonBarMargin: EdgeInsets.fromLTRB(
      overlayTokens.playerControlBarHorizontalInset,
      overlayTokens.playerControlBarTopInset,
      topBarTrailingInset,
      0,
    ),
    bottomButtonBar: bottomSeekBar == null
        ? bottomControls
        : <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  bottomSeekBar,
                  SizedBox(
                    height: _moviePlayerDesktopButtonBarHeight,
                    child: Row(children: bottomControls),
                  ),
                ],
              ),
            ),
          ],
    buttonBarHeight: bottomSeekBar == null
        ? _moviePlayerDesktopButtonBarHeight
        : _moviePlayerDesktopSeekBarClusterHeight,
  );
}

const double _moviePlayerDesktopButtonBarHeight = 56;

/// 自定义底栏 = 进度条容器（36）+ 按钮行（56）。
const double _moviePlayerDesktopSeekBarClusterHeight =
    _moviePlayerDesktopButtonBarHeight + 36;
