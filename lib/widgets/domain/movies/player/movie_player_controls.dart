import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/widgets/base/media/video/player_app_fullscreen.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawers.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_speed_button.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_subtitle_button.dart';

/// 播放器窗口态顶栏:左「返回 + 番号」、右「视频信息」按钮。
/// 也被切片/视频单播与合集连播页复用(只传 onBackPressed)。
List<Widget> buildMoviePlayerTopControls({
  required String movieNumber,
  required VoidCallback? onBackPressed,
  VoidCallback? onInfoPressed,
}) {
  if (onBackPressed == null && onInfoPressed == null) {
    return const <Widget>[];
  }
  final controls = <Widget>[];
  if (onBackPressed != null) {
    controls.add(
      MoviePlayerBackWithNumberControl(
        onPressed: onBackPressed,
        movieNumber: movieNumber,
      ),
    );
  }
  if (onInfoPressed != null) {
    if (controls.isNotEmpty) {
      controls.add(const Spacer());
    }
    controls.add(MoviePlayerInfoButton(onPressed: onInfoPressed));
  }
  return controls;
}

List<Widget> buildMoviePlayerMobileBottomControls({
  required MoviePlayerMobileDrawerType? activeDrawer,
  required ValueListenable<MoviePlayerMobileSpeedDisplayState>
  speedDisplayListenable,
  required VoidCallback onSpeedButtonPressed,
  required VoidCallback onSubtitleButtonPressed,
  bool includeDrawerButtons = true,
}) {
  // 移动播放页进入即锁横屏并隐藏系统栏；底栏不再提供全屏入口。
  return <Widget>[
    const MaterialPlayOrPauseButton(),
    const MaterialDesktopVolumeButton(),
    const MaterialPositionIndicator(),
    const Spacer(),
    // 全屏态传 false：倍速 / 字幕抽屉浮层挂在播放页 Stack 上，不在 media_kit
    // push 的全屏路由内，按钮点了没反应，直接隐藏。
    if (includeDrawerButtons)
      ...buildMoviePlayerMobileDrawerToggleButtons(
        activeDrawer: activeDrawer,
        speedDisplayListenable: speedDisplayListenable,
        onSpeedButtonPressed: onSpeedButtonPressed,
        onSubtitleButtonPressed: onSubtitleButtonPressed,
      ),
  ];
}

List<Widget> buildMoviePlayerDesktopBottomControls({
  required double currentRate,
  required bool hasExplicitSelection,
  required Future<void> Function(double rate) onRateSelected,
  required ValueListenable<MoviePlayerSubtitleState> subtitleStateListenable,
  required ValueListenable<bool> isApplyingListenable,
  required Future<void> Function(int? subtitleId) onSubtitleSelected,
  required Future<void> Function() onSubtitleReloadRequested,
}) {
  return <Widget>[
    const MaterialPlayOrPauseButton(),
    const MaterialDesktopVolumeButton(),
    const MaterialPositionIndicator(),
    const Spacer(),
    MoviePlayerSpeedButton(
      currentRate: currentRate,
      hasExplicitSelection: hasExplicitSelection,
      onRateSelected: onRateSelected,
    ),
    MoviePlayerSubtitleButton(
      subtitleStateListenable: subtitleStateListenable,
      isApplyingListenable: isApplyingListenable,
      onSubtitleSelected: onSubtitleSelected,
      onReloadRequested: onSubtitleReloadRequested,
    ),
    const PlayerAppFullscreenButton(),
  ];
}
