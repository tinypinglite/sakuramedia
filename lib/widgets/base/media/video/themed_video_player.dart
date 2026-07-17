import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/widgets/base/media/video/initial_seek_guard.dart';
import 'package:sakuramedia/widgets/base/media/video/playback_resume_prompt.dart';
import 'package:sakuramedia/widgets/base/media/video/video_controls_theme.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';

/// 「层级二」播放器统一入口：把裸 [Video] 外面的三层控制主题嵌套
/// （[MaterialVideoControlsTheme] + [MaterialDesktopVideoControlsTheme] + 控件 builder）
/// 收敛成一个播放器展示组件，供所有无字幕的轻量播放场景复用
/// （快播弹窗、单切片/单视频全屏、切片/视频合集连播）。
///
/// 直接复用 [video_controls_theme] 里的主题构建函数，不重写主题逻辑：
/// - [buildMoviePlayerMobileControlsThemeData] / [buildMoviePlayerDesktopControlsThemeData]
/// - [resolveMoviePlayerVideoControlsBuilder]（`useTouchOptimizedControls` 决定
///   点击唤出 vs 鼠标 hover 唤出控制条）。
///
/// 该主题原本定义在 `movie_player_surface.dart`，为断开 base→domain 反向依赖，
/// 已抽到 `base/media/video/video_controls_theme.dart`（供 base 层的 ThemedVideoPlayer
/// 与 domain 层的 MoviePlayerSurface 共用）。
///
/// 顶/底控制条由调用方按场景传入（合集有上一首/下一首、单片/弹窗没有），
/// 本组件只负责把它们装进统一主题并渲染 [Video]。
class ThemedVideoPlayer extends StatefulWidget {
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
    this.displaySeekBar = true,
    this.guardInitialSeek = false,
    this.resumePosition,
    this.onResumePromptResolved,
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

  /// 是否显示 media_kit 内置 seek bar；合集合并模式传 `false`，由调用方在 [bottomControls]
  /// 里塞自定义合并进度条（含 [Expanded] 占满中间空间），避免与内置 seek bar 双进度条。
  final bool displaySeekBar;

  /// 完整远程媒体可启用：在首帧后的短暂网络预读窗口内保留进度展示、关闭 seek 手势，
  /// 并拦截控制层指针事件。切片等本地产物保持 `false`，不改变既有交互。
  final bool guardInitialSeek;

  /// 有有效历史记录时，从头播放并在播放器稳定后显示续播提示。点击继续后才执行 seek。
  final Duration? resumePosition;

  /// 用户继续、从头、手动 seek 或提示超时后调用，用于解除业务层的进度上报冻结。
  final VoidCallback? onResumePromptResolved;

  @override
  State<ThemedVideoPlayer> createState() => _ThemedVideoPlayerState();
}

class _ThemedVideoPlayerState extends State<ThemedVideoPlayer> {
  int _guardRequestId = 0;
  int _firstFrameRequestId = 0;
  late bool _seekEnabled;
  bool _initialFrameReady = false;
  bool _resumePromptVisible = false;
  StreamSubscription<Duration>? _positionSubscription;
  Duration? _lastPromptPosition;
  DateTime? _lastPromptPositionAt;

  @override
  void initState() {
    super.initState();
    _seekEnabled = !widget.guardInitialSeek;
    _attachPositionMonitor();
    _armFirstFrameIndicator();
    _armInitialSeekGuard();
  }

  @override
  void didUpdateWidget(covariant ThemedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoController != widget.videoController ||
        oldWidget.guardInitialSeek != widget.guardInitialSeek) {
      _seekEnabled = !widget.guardInitialSeek;
      _initialFrameReady = false;
      _resumePromptVisible = false;
      _attachPositionMonitor();
      _armFirstFrameIndicator();
      _armInitialSeekGuard();
      return;
    }
    if (oldWidget.resumePosition != widget.resumePosition) {
      if (widget.resumePosition == null) {
        _resumePromptVisible = false;
      } else if (_seekEnabled) {
        _showResumePrompt();
      }
    }
  }

  @override
  void dispose() {
    _guardRequestId++;
    _firstFrameRequestId++;
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _armFirstFrameIndicator() {
    final requestId = ++_firstFrameRequestId;
    unawaited(
      widget.videoController.waitUntilFirstFrameRendered.then((_) {
        if (!mounted || requestId != _firstFrameRequestId) {
          return;
        }
        setState(() => _initialFrameReady = true);
      }),
    );
  }

  void _attachPositionMonitor() {
    _positionSubscription?.cancel();
    _positionSubscription = widget.videoController.player.stream.position
        .listen(_handlePositionChanged);
  }

  void _armInitialSeekGuard() {
    final requestId = ++_guardRequestId;
    if (!widget.guardInitialSeek && widget.resumePosition == null) {
      return;
    }
    final controller = widget.videoController;
    final player = controller.player;
    unawaited(
      waitUntilInitialSeekReady(
        firstFrame: controller.waitUntilFirstFrameRendered,
        positionStream: player.stream.position,
        currentPosition: () => player.state.position,
        isPlaying: () => player.state.playing,
        isBuffering: () => player.state.buffering,
      ).then((_) {
        if (!mounted || requestId != _guardRequestId) {
          return;
        }
        setState(() {
          _seekEnabled = true;
          if (widget.resumePosition != null) {
            _showResumePrompt(notify: false);
          }
        });
      }),
    );
  }

  void _showResumePrompt({bool notify = true}) {
    _resumePromptVisible = true;
    _lastPromptPosition = widget.videoController.player.state.position;
    _lastPromptPositionAt = DateTime.now();
    if (notify && mounted) {
      setState(() {});
    }
  }

  void _handlePositionChanged(Duration position) {
    if (!_resumePromptVisible) {
      return;
    }
    final previousPosition = _lastPromptPosition;
    final previousAt = _lastPromptPositionAt;
    final now = DateTime.now();
    _lastPromptPosition = position;
    _lastPromptPositionAt = now;
    if (previousPosition == null || previousAt == null) {
      return;
    }

    final elapsedMilliseconds = now.difference(previousAt).inMilliseconds;
    final rate = widget.videoController.player.state.rate;
    final expectedForwardMilliseconds =
        (elapsedMilliseconds * rate).round() + 2000;
    final deltaMilliseconds =
        position.inMilliseconds - previousPosition.inMilliseconds;
    if (deltaMilliseconds < -2000 ||
        deltaMilliseconds > expectedForwardMilliseconds) {
      _resolveResumePrompt();
    }
  }

  void _resolveResumePrompt() {
    if (!_resumePromptVisible) {
      return;
    }
    setState(() => _resumePromptVisible = false);
    widget.onResumePromptResolved?.call();
  }

  void _resumePlayback() {
    final position = widget.resumePosition;
    if (position == null) {
      _resolveResumePrompt();
      return;
    }
    setState(() => _resumePromptVisible = false);
    final player = widget.videoController.player;
    unawaited(() async {
      try {
        await player.seek(position);
        await player.play();
      } finally {
        if (mounted) {
          widget.onResumePromptResolved?.call();
        }
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullscreenBottom =
        widget.fullscreenBottomControls ?? widget.bottomControls;
    final desktopThemeData = buildMoviePlayerDesktopControlsThemeData(
      theme: theme,
      topControls: widget.topControls,
      bottomControls: widget.bottomControls,
      displaySeekBar: widget.displaySeekBar,
    );
    final desktopFullscreenThemeData = buildMoviePlayerDesktopControlsThemeData(
      theme: theme,
      topControls: widget.topControls,
      bottomControls: fullscreenBottom,
      displaySeekBar: widget.displaySeekBar,
    );
    final mobileThemeData = buildMoviePlayerMobileControlsThemeData(
      theme: theme,
      topControls: widget.topControls,
      bottomControls: widget.bottomControls,
      displaySeekBar: widget.displaySeekBar,
      seekEnabled: _seekEnabled,
    );
    final mobileFullscreenThemeData = buildMoviePlayerMobileControlsThemeData(
      theme: theme,
      topControls: widget.topControls,
      bottomControls: fullscreenBottom,
      displaySeekBar: widget.displaySeekBar,
      seekEnabled: _seekEnabled,
    );
    return MaterialVideoControlsTheme(
      normal: mobileThemeData,
      fullscreen: mobileFullscreenThemeData,
      child: MaterialDesktopVideoControlsTheme(
        normal: desktopThemeData,
        fullscreen: desktopFullscreenThemeData,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: widget.guardInitialSeek && !_seekEnabled,
              child: Video(
                key: widget.videoKey,
                controller: widget.videoController,
                fit: widget.fit,
                fill: widget.fill,
                controls: resolveMoviePlayerVideoControlsBuilder(
                  useTouchOptimizedControls: widget.useTouchOptimizedControls,
                ),
              ),
            ),
            if (!_initialFrameReady)
              const IgnorePointer(
                child: Center(
                  child: VideoLoadingIndicator(label: '正在加载视频…'),
                ),
              ),
            if (_resumePromptVisible && widget.resumePosition != null)
              PlaybackResumePromptOverlay(
                position: widget.resumePosition!,
                useTouchOptimizedLayout: widget.useTouchOptimizedControls,
                onResume: _resumePlayback,
                onStartOver: _resolveResumePrompt,
              ),
          ],
        ),
      ),
    );
  }
}
