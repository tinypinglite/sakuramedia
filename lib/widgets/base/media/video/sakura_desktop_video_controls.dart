import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart' show NativePlayer;
import 'package:media_kit_video/media_kit_video.dart';

/// 桌面播放器浮层可暂缓控制条自动隐藏。
///
/// 字幕等弹层挂在根 Overlay 上，鼠标进入弹层后视频控件收不到 hover 事件；
/// 若仍按原计时器卸载控制条，弹层会随触发器一起消失并造成点击穿透。
class SakuraDesktopVideoControlsOverlayLockScope extends InheritedWidget {
  const SakuraDesktopVideoControlsOverlayLockScope({
    super.key,
    required this.acquire,
    required this.release,
    required super.child,
  });

  final VoidCallback acquire;
  final VoidCallback release;

  static SakuraDesktopVideoControlsOverlayLockScope? maybeOf(
    BuildContext context,
  ) {
    return context
        .dependOnInheritedWidgetOfExactType<
          SakuraDesktopVideoControlsOverlayLockScope
        >();
  }

  @override
  bool updateShouldNotify(
    SakuraDesktopVideoControlsOverlayLockScope oldWidget,
  ) {
    return acquire != oldWidget.acquire || release != oldWidget.release;
  }
}

/// Desktop controls with seek-aware auto-hide handling.
///
/// media_kit_video 2.0.1 only cancels its auto-hide timer for the seek bar it
/// creates itself. This player uses a theme-provided seek bar, so the parent
/// controls can unmount it while the pointer is still down. Keep the controls
/// visible for the whole pointer interaction and cancel the timer during
/// teardown.
class SakuraDesktopVideoControls extends StatefulWidget {
  const SakuraDesktopVideoControls({super.key, required this.state});

  final VideoState state;

  @override
  State<SakuraDesktopVideoControls> createState() =>
      _SakuraDesktopVideoControlsState();
}

class _SakuraDesktopVideoControlsState
    extends State<SakuraDesktopVideoControls> {
  late bool mount;
  late bool visible;

  late MaterialDesktopVideoControlsThemeData _theme;
  Timer? _timer;
  StreamSubscription<bool>? _bufferingSubscription;
  final Set<int> _activePointers = <int>{};
  int _overlayLockCount = 0;
  bool _seekActive = false;
  bool _initialized = false;
  bool _buffering = false;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
  double? _volumeBeforeMute;

  static const List<LogicalKeyboardKey> _digitKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  VideoController get _controller => widget.state.widget.controller;

  bool get _isInteracting =>
      _seekActive || _activePointers.isNotEmpty || _overlayLockCount > 0;

  bool get _isFullscreen => FullscreenInheritedWidget.maybeOf(context) != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inheritedTheme = MaterialDesktopVideoControlsTheme.maybeOf(context);
    _theme = _isFullscreen
        ? inheritedTheme?.fullscreen ??
              kDefaultMaterialDesktopVideoControlsThemeDataFullscreen
        : inheritedTheme?.normal ??
              kDefaultMaterialDesktopVideoControlsThemeData;

    if (!_initialized) {
      _initialized = true;
      mount = _theme.visibleOnMount;
      visible = _theme.visibleOnMount;
      _buffering = _controller.player.state.buffering;
      _bufferingSubscription = _controller.player.stream.buffering.listen((
        buffering,
      ) {
        if (mounted) {
          setState(() => _buffering = buffering);
        }
      });
      if (visible) {
        _scheduleHide();
      }
    } else if (visible) {
      _scheduleHide();
    }
  }

  @override
  void activate() {
    super.activate();
    if (visible) {
      _scheduleHide();
    }
  }

  @override
  void deactivate() {
    _timer?.cancel();
    _activePointers.clear();
    _seekActive = false;
    super.deactivate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bufferingSubscription?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _timer?.cancel();
    if (!mounted || !visible || _isInteracting) {
      return;
    }
    _timer = Timer(_theme.controlsHoverDuration, _hideControls);
  }

  void _showControls() {
    if (!mounted) {
      return;
    }
    if (!mount || !visible) {
      setState(() {
        mount = true;
        visible = true;
      });
    }
    _shiftSubtitle();
    _scheduleHide();
  }

  void _hideControls() {
    if (!mounted || _isInteracting) {
      return;
    }
    if (visible) {
      setState(() => visible = false);
    }
    _unshiftSubtitle();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    _timer?.cancel();
    if (mount) {
      _showControls();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _seekActive = false;
      _scheduleHide();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _seekActive = false;
      _scheduleHide();
    }
  }

  void _handleSeekStart() {
    _seekActive = true;
    _timer?.cancel();
  }

  void _handleSeekEnd() {
    _seekActive = false;
    _scheduleHide();
  }

  void _acquireOverlayLock() {
    _overlayLockCount++;
    _timer?.cancel();
    _showControls();
  }

  void _releaseOverlayLock() {
    if (_overlayLockCount == 0) {
      return;
    }
    _overlayLockCount--;
    if (_overlayLockCount == 0) {
      _scheduleHide();
      // 锚定菜单会把自己的 FocusNode 设为 primary focus；关闭后把焦点还给
      // 播放器控件，否则空格/方向键等快捷键会失效。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _overlayLockCount > 0) {
          return;
        }
        VideoStateInheritedWidget.of(
          context,
        ).videoViewParametersNotifier.value.focusNode?.requestFocus();
      });
    }
  }

  void _shiftSubtitle() {
    if (!_theme.shiftSubtitlesOnControlsVisibilityChange) {
      return;
    }
    final verticalOffset =
        (_theme.padding?.bottom ?? 0.0) +
        _theme.bottomButtonBarMargin.vertical +
        (_theme.bottomButtonBar.isNotEmpty ? _theme.buttonBarHeight : 0.0);
    widget.state.setSubtitleViewPadding(
      widget.state.widget.subtitleViewConfiguration.padding +
          EdgeInsets.fromLTRB(0.0, 0.0, 0.0, verticalOffset),
    );
  }

  void _unshiftSubtitle() {
    if (!_theme.shiftSubtitlesOnControlsVisibilityChange) {
      return;
    }
    widget.state.setSubtitleViewPadding(
      widget.state.widget.subtitleViewConfiguration.padding,
    );
  }

  void _seekToFraction(double fraction) {
    final duration = _controller.player.state.duration;
    if (duration <= Duration.zero) return;
    unawaited(_controller.player.seek(duration * fraction));
  }

  void _toggleMute() {
    final player = _controller.player;
    final volume = player.state.volume;
    if (volume > 0) {
      _volumeBeforeMute = volume;
      unawaited(player.setVolume(0));
    } else {
      unawaited(player.setVolume(_volumeBeforeMute ?? 100));
    }
  }

  void _changeRate(double delta) {
    final rate = (_controller.player.state.rate + delta)
        .clamp(0.25, 4.0)
        .toDouble();
    unawaited(_controller.player.setRate(rate));
  }

  void _stepFrame({required bool forward}) {
    final platform = _controller.player.platform;
    if (platform is! NativePlayer) return;
    unawaited(
      platform
          .command(<String>[forward ? 'frame-step' : 'frame-back-step'])
          .catchError((Object _) {}),
    );
  }

  void _toggleFullscreen() {
    toggleFullscreen(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final fullscreen = _isFullscreen;
    final overlayPadding =
        theme.padding ??
        (fullscreen ? MediaQuery.paddingOf(context) : EdgeInsets.zero);

    return Theme(
      data: Theme.of(context).copyWith(
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: CallbackShortcuts(
        bindings:
            theme.keyboardShortcuts ??
            <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.mediaPlay): () =>
                  _controller.player.play(),
              const SingleActivator(LogicalKeyboardKey.mediaPause): () =>
                  _controller.player.pause(),
              const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
                  _controller.player.playOrPause(),
              const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () =>
                  _controller.player.next(),
              const SingleActivator(
                LogicalKeyboardKey.mediaTrackPrevious,
              ): () =>
                  _controller.player.previous(),
              const SingleActivator(LogicalKeyboardKey.space): () =>
                  _controller.player.playOrPause(),
              const SingleActivator(LogicalKeyboardKey.keyJ): () {
                final position =
                    _controller.player.state.position -
                    const Duration(seconds: 10);
                _controller.player.seek(position);
              },
              const SingleActivator(LogicalKeyboardKey.keyI): () {
                final position =
                    _controller.player.state.position +
                    const Duration(seconds: 10);
                _controller.player.seek(position);
              },
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                final position =
                    _controller.player.state.position -
                    const Duration(seconds: 2);
                _controller.player.seek(position);
              },
              const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                final position =
                    _controller.player.state.position +
                    const Duration(seconds: 2);
                _controller.player.seek(position);
              },
              const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                final volume = _controller.player.state.volume + 5.0;
                _controller.player.setVolume(volume.clamp(0.0, 100.0));
              },
              const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                final volume = _controller.player.state.volume - 5.0;
                _controller.player.setVolume(volume.clamp(0.0, 100.0));
              },
              // 0–9 跳到 0%–90%；M 静音；[ ] 调速；, . 逐帧。
              for (var digit = 0; digit < _digitKeys.length; digit++)
                SingleActivator(_digitKeys[digit]): () =>
                    _seekToFraction(digit / 10),
              const SingleActivator(LogicalKeyboardKey.keyM): _toggleMute,
              const SingleActivator(LogicalKeyboardKey.bracketLeft): () =>
                  _changeRate(-0.25),
              const SingleActivator(LogicalKeyboardKey.bracketRight): () =>
                  _changeRate(0.25),
              const SingleActivator(LogicalKeyboardKey.comma): () =>
                  _stepFrame(forward: false),
              const SingleActivator(LogicalKeyboardKey.period): () =>
                  _stepFrame(forward: true),
              const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  exitFullscreen(context),
            },
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Focus(
            focusNode: VideoStateInheritedWidget.of(
              context,
            ).videoViewParametersNotifier.value.focusNode,
            autofocus: true,
            child: Material(
              elevation: 0.0,
              borderOnForeground: false,
              animationDuration: Duration.zero,
              color: Colors.transparent,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handlePointerDown,
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerCancel,
                onPointerSignal: theme.modifyVolumeOnScroll
                    ? _handlePointerSignal
                    : null,
                child: GestureDetector(
                  onTapDown: !theme.playAndPauseOnTap ? null : _handleTapDown,
                  onTapUp: !theme.toggleFullscreenOnDoublePress
                      ? null
                      : _handleTapUp,
                  onPanUpdate: theme.modifyVolumeOnScroll
                      ? _handlePanUpdate
                      : null,
                  child: MouseRegion(
                    cursor: theme.hideMouseOnControlsRemoval && !mount
                        ? SystemMouseCursors.none
                        : SystemMouseCursors.basic,
                    onHover: (_) => _showControls(),
                    onEnter: (_) => _showControls(),
                    onExit: (_) {
                      if (!_isInteracting) {
                        _hideControls();
                      }
                    },
                    child: Stack(
                      children: <Widget>[
                        AnimatedOpacity(
                          curve: Curves.easeInOut,
                          opacity: visible ? 1.0 : 0.0,
                          duration: theme.controlsTransitionDuration,
                          onEnd: () {
                            if (!visible && mounted) {
                              setState(() => mount = false);
                            }
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomCenter,
                            children: <Widget>[
                              if (theme.topButtonBar.isNotEmpty)
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: <double>[0.0, 0.2],
                                      colors: <Color>[
                                        Colors.black.withValues(alpha: 0.38),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              if (theme.bottomButtonBar.isNotEmpty)
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: <double>[0.5, 1.0],
                                      colors: <Color>[
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.38),
                                      ],
                                    ),
                                  ),
                                ),
                              if (mount)
                                Padding(
                                  padding: overlayPadding,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      Container(
                                        height: theme.buttonBarHeight,
                                        margin: theme.topButtonBarMargin,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: theme.topButtonBar,
                                        ),
                                      ),
                                      Expanded(
                                        child: AnimatedOpacity(
                                          curve: Curves.easeInOut,
                                          opacity: _buffering ? 0.0 : 1.0,
                                          duration:
                                              theme.controlsTransitionDuration,
                                          child: Center(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: theme.primaryButtonBar,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (theme.displaySeekBar)
                                        Transform.translate(
                                          offset:
                                              theme.bottomButtonBar.isNotEmpty
                                              ? const Offset(0.0, 16.0)
                                              : Offset.zero,
                                          child: MaterialDesktopSeekBar(
                                            onSeekStart: _handleSeekStart,
                                            onSeekEnd: _handleSeekEnd,
                                          ),
                                        ),
                                      if (theme.bottomButtonBar.isNotEmpty)
                                        Container(
                                          height: theme.buttonBarHeight,
                                          margin: theme.bottomButtonBarMargin,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              for (
                                                final control
                                                in theme.bottomButtonBar
                                              )
                                                SakuraDesktopVideoControlsOverlayLockScope(
                                                  acquire: _acquireOverlayLock,
                                                  release: _releaseOverlayLock,
                                                  child: control,
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IgnorePointer(
                          child: Padding(
                            padding: overlayPadding,
                            child: Column(
                              children: <Widget>[
                                Container(
                                  height: theme.buttonBarHeight,
                                  margin: theme.topButtonBarMargin,
                                ),
                                Expanded(
                                  child: Center(
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        begin: 0.0,
                                        end: _buffering ? 1.0 : 0.0,
                                      ),
                                      duration:
                                          theme.controlsTransitionDuration,
                                      builder: (context, value, child) {
                                        if (value <= 0.0) {
                                          return const SizedBox.shrink();
                                        }
                                        return Opacity(
                                          opacity: value,
                                          child:
                                              theme.bufferingIndicatorBuilder
                                                  ?.call(context) ??
                                              child!,
                                        );
                                      },
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: theme.buttonBarHeight,
                                  margin: theme.bottomButtonBarMargin,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_theme.modifyVolumeOnScroll) {
      return;
    }
    if (event.scrollDelta.dy == 0) {
      return;
    }
    final delta = event.scrollDelta.dy > 0 ? -5.0 : 5.0;
    final volume = _controller.player.state.volume + delta;
    _controller.player.setVolume(volume.clamp(0.0, 100.0));
  }

  void _handleTapDown(TapDownDetails details) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }
    final localPosition = renderObject.globalToLocal(details.globalPosition);
    const tapPadding = 10.0;
    final bottomControlsOffset =
        (_theme.padding?.bottom ?? 0.0) +
        _theme.bottomButtonBarMargin.vertical +
        (_theme.bottomButtonBar.isNotEmpty ? _theme.buttonBarHeight : 0.0);
    if (!mount ||
        localPosition.dy <
            renderObject.size.height - bottomControlsOffset - tapPadding) {
      _controller.player.playOrPause();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    final now = DateTime.now();
    if (now.difference(_lastTap) < const Duration(milliseconds: 400)) {
      _toggleFullscreen();
    }
    _lastTap = now;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_theme.modifyVolumeOnScroll || details.delta.dy == 0) {
      return;
    }
    final delta = details.delta.dy > 0 ? -5.0 : 5.0;
    final volume = _controller.player.state.volume + delta;
    _controller.player.setVolume(volume.clamp(0.0, 100.0));
  }
}
