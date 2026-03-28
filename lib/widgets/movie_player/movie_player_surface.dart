import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface_controller.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface_readiness.dart';

class MoviePlayerSurface extends StatefulWidget {
  const MoviePlayerSurface({
    super.key,
    required this.resolvedUrl,
    required this.surfaceController,
    this.initialPosition,
    this.onPositionChanged,
    this.onPlayingChanged,
    this.useTouchOptimizedControls = false,
  });

  final String resolvedUrl;
  final MoviePlayerSurfaceController surfaceController;
  final Duration? initialPosition;
  final ValueChanged<Duration>? onPositionChanged;
  final ValueChanged<bool>? onPlayingChanged;
  final bool useTouchOptimizedControls;

  @override
  State<MoviePlayerSurface> createState() => _MoviePlayerSurfaceState();
}

abstract class MoviePlayerSurfacePlaybackDriver {
  Future<void> open(
    String resolvedUrl, {
    required Duration? startPosition,
    required bool play,
  });

  Future<void> seek(Duration position);

  Future<void> play();

  Future<void> waitUntilFirstFrameRendered();
}

class MoviePlayerSurfaceOpenCoordinator {
  const MoviePlayerSurfaceOpenCoordinator();

  Future<void> open({
    required MoviePlayerSurfacePlaybackDriver driver,
    required String resolvedUrl,
    required Duration? initialPosition,
    required bool Function() shouldContinue,
    required VoidCallback markReady,
  }) async {
    final startupPosition =
        initialPosition != null && initialPosition > Duration.zero
            ? initialPosition
            : null;
    debugPrint(
      '[player-debug] surface_open_begin url=$resolvedUrl initialPositionSeconds=${initialPosition?.inSeconds} startupPositionSeconds=${startupPosition?.inSeconds}',
    );
    await driver.open(resolvedUrl, startPosition: startupPosition, play: false);
    if (!shouldContinue()) {
      debugPrint('[player-debug] surface_open_abort_after=open');
      return;
    }

    debugPrint('[player-debug] surface_open_step=play');
    await driver.play();
    if (!shouldContinue()) {
      debugPrint('[player-debug] surface_open_abort_after=play');
      return;
    }

    debugPrint('[player-debug] surface_open_step=wait_first_frame');
    await driver.waitUntilFirstFrameRendered();
    if (!shouldContinue()) {
      debugPrint('[player-debug] surface_open_abort_after=wait_first_frame');
      return;
    }

    if (startupPosition != null) {
      debugPrint(
        '[player-debug] surface_open_step=seek startupPositionSeconds=${startupPosition.inSeconds}',
      );
      await driver.seek(startupPosition);
      if (!shouldContinue()) {
        debugPrint('[player-debug] surface_open_abort_after=seek');
        return;
      }
    }

    debugPrint('[player-debug] surface_open_step=ready');
    markReady();
  }
}

@visibleForTesting
Widget Function(VideoState state) resolveMoviePlayerVideoControlsBuilder({
  required bool useTouchOptimizedControls,
}) {
  if (useTouchOptimizedControls) {
    // The mobile custom controls are removed. Keep using media_kit defaults.
  }
  return AdaptiveVideoControls;
}

@visibleForTesting
MaterialVideoControlsThemeData buildMoviePlayerMaterialControlsThemeData({
  required ThemeData theme,
  required List<Widget> controls,
  required bool useTouchOptimizedControls,
}) {
  if (useTouchOptimizedControls) {
    // Touch-specific seek bar overrides are removed with custom mobile controls.
  }
  return MaterialVideoControlsThemeData(
    horizontalGestureSensitivity: 3000,
    seekOnDoubleTap: true,
    seekBarMargin: const EdgeInsets.fromLTRB(30, 0, 30, 75),
    seekGesture: true,
    volumeGesture: true,
    speedUpOnLongPress: true,
    brightnessGesture: true,
    seekBarThumbColor: theme.colorScheme.primary,
    seekBarPositionColor: theme.colorScheme.primary,
    seekBarHeight: 6,
    seekBarThumbSize: 14,
    displaySeekBar: true,
    bottomButtonBar: controls,
  );
}

class _MoviePlayerSurfaceState extends State<MoviePlayerSurface> {
  late final Player _player;
  late final VideoController _controller;
  late final MoviePlayerSurfaceReadiness _readiness;
  late final MoviePlayerSurfacePlaybackDriver _playbackDriver;
  StreamSubscription<Duration>? _seekSubscription;
  StreamSubscription<void>? _playSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  int _openRequestId = 0;
  Duration? _startupSeekTarget;
  DateTime? _startupSeekStartedAt;
  bool _startupSeekSettled = true;
  int _startupSeekRetryCount = 0;
  int _startupSeekNearTargetSamples = 0;
  static const MoviePlayerSurfaceOpenCoordinator _openCoordinator =
      MoviePlayerSurfaceOpenCoordinator();
  static const int _startupSeekToleranceSeconds = 2;
  static const int _startupSeekRetryDelayMs = 800;
  static const int _startupSeekMaxWindowMs = 8000;
  static const int _startupSeekMaxRetries = 2;
  static const int _startupSeekMinNearSamples = 2;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _readiness = MoviePlayerSurfaceReadiness();
    _playbackDriver = _MediaKitMoviePlayerSurfacePlaybackDriver(
      player: _player,
      controller: _controller,
    );
    _seekSubscription = widget.surfaceController.seekStream.listen(
      _player.seek,
    );
    _playSubscription = widget.surfaceController.playStream.listen((_) {
      unawaited(_player.play());
    });
    _positionSubscription = _player.stream.position.listen((position) {
      widget.onPositionChanged?.call(position);
      _maybeRetryStartupSeek(position);
    });
    _playingSubscription = _player.stream.playing.listen((playing) {
      widget.onPlayingChanged?.call(playing);
    });
    unawaited(_openMedia());
  }

  @override
  void didUpdateWidget(covariant MoviePlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surfaceController != widget.surfaceController) {
      _seekSubscription?.cancel();
      _seekSubscription = widget.surfaceController.seekStream.listen(
        _player.seek,
      );
      _playSubscription?.cancel();
      _playSubscription = widget.surfaceController.playStream.listen((_) {
        unawaited(_player.play());
      });
    }
    if (oldWidget.resolvedUrl != widget.resolvedUrl) {
      unawaited(_openMedia());
    }
  }

  @override
  void dispose() {
    _seekSubscription?.cancel();
    _playSubscription?.cancel();
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _readiness.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _openMedia() async {
    final requestId = ++_openRequestId;
    _startupSeekTarget =
        widget.initialPosition != null &&
                widget.initialPosition! > Duration.zero
            ? widget.initialPosition
            : null;
    _startupSeekStartedAt = DateTime.now();
    _startupSeekRetryCount = 0;
    _startupSeekNearTargetSamples = 0;
    _startupSeekSettled = _startupSeekTarget == null;
    debugPrint(
      '[player-debug] surface_state_open_media requestId=$requestId url=${widget.resolvedUrl} initialPositionSeconds=${widget.initialPosition?.inSeconds} startupTargetSeconds=${_startupSeekTarget?.inSeconds}',
    );
    _readiness.reset();
    await _openCoordinator.open(
      driver: _playbackDriver,
      resolvedUrl: widget.resolvedUrl,
      initialPosition: widget.initialPosition,
      shouldContinue: () => mounted && requestId == _openRequestId,
      markReady: _readiness.markReady,
    );
  }

  void _maybeRetryStartupSeek(Duration currentPosition) {
    final target = _startupSeekTarget;
    if (target == null || _startupSeekSettled) {
      return;
    }
    if (!_readiness.isReady) {
      return;
    }
    final startedAt = _startupSeekStartedAt;
    if (startedAt == null) {
      _startupSeekSettled = true;
      return;
    }
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    final currentSeconds = currentPosition.inSeconds;
    final targetSeconds = target.inSeconds;
    final isNearTarget =
        currentSeconds >= targetSeconds - _startupSeekToleranceSeconds;

    debugPrint(
      '[player-debug] startup_seek_probe currentSeconds=$currentSeconds targetSeconds=$targetSeconds elapsedMs=$elapsedMs retries=$_startupSeekRetryCount nearSamples=$_startupSeekNearTargetSamples',
    );

    if (isNearTarget) {
      _startupSeekNearTargetSamples++;
    } else {
      _startupSeekNearTargetSamples = 0;
    }

    if (_startupSeekNearTargetSamples >= _startupSeekMinNearSamples) {
      _startupSeekSettled = true;
      debugPrint(
        '[player-debug] startup_seek_verified currentSeconds=$currentSeconds targetSeconds=$targetSeconds retries=$_startupSeekRetryCount nearSamples=$_startupSeekNearTargetSamples',
      );
      return;
    }

    if (elapsedMs >= _startupSeekMaxWindowMs) {
      _startupSeekSettled = true;
      debugPrint(
        '[player-debug] startup_seek_give_up reason=window_timeout currentSeconds=$currentSeconds targetSeconds=$targetSeconds retries=$_startupSeekRetryCount',
      );
      return;
    }

    if (elapsedMs < _startupSeekRetryDelayMs ||
        _startupSeekRetryCount >= _startupSeekMaxRetries) {
      return;
    }

    _startupSeekRetryCount++;
    debugPrint(
      '[player-debug] startup_seek_retry attempt=$_startupSeekRetryCount currentSeconds=$currentSeconds targetSeconds=$targetSeconds',
    );
    unawaited(_player.seek(target));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controls = <Widget>[
      const MaterialPlayOrPauseButton(),
      const MaterialDesktopVolumeButton(),
      const MaterialPositionIndicator(),
      const Spacer(),
      const MaterialFullscreenButton(),
    ];
    final backgroundColor = context.appColors.movieDetailHeroBackgroundStart;

    return MaterialVideoControlsTheme(
      normal: _materialControlsTheme(theme, controls),
      fullscreen: _materialControlsTheme(theme, controls),
      child: MaterialDesktopVideoControlsTheme(
        normal: _desktopControlsTheme(theme, controls),
        fullscreen: _desktopControlsTheme(theme, controls),
        child: ListenableBuilder(
          listenable: _readiness,
          builder: (context, child) {
            return MoviePlayerSurfaceFrame(
              isReady: _readiness.isReady,
              child: child!,
            );
          },
          child: Video(
            controller: _controller,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.fitWidth,
            fill: backgroundColor,
            filterQuality: FilterQuality.none,
            controls: resolveMoviePlayerVideoControlsBuilder(
              useTouchOptimizedControls: widget.useTouchOptimizedControls,
            ),
            onEnterFullscreen: () async {
              if (!_player.state.playing) {
                await _player.play();
              }
            },
          ),
        ),
      ),
    );
  }

  MaterialDesktopVideoControlsThemeData _desktopControlsTheme(
    ThemeData theme,
    List<Widget> controls,
  ) {
    return MaterialDesktopVideoControlsThemeData(
      seekBarThumbColor: theme.colorScheme.primary,
      seekBarPositionColor: theme.colorScheme.primary,
      seekBarHeight: 6,
      seekBarThumbSize: 14,
      displaySeekBar: true,
      bottomButtonBar: controls,
    );
  }

  MaterialVideoControlsThemeData _materialControlsTheme(
    ThemeData theme,
    List<Widget> controls,
  ) {
    return buildMoviePlayerMaterialControlsThemeData(
      theme: theme,
      controls: controls,
      useTouchOptimizedControls: widget.useTouchOptimizedControls,
    );
  }
}

class _MediaKitMoviePlayerSurfacePlaybackDriver
    implements MoviePlayerSurfacePlaybackDriver {
  _MediaKitMoviePlayerSurfacePlaybackDriver({
    required Player player,
    required VideoController controller,
  }) : _player = player,
       _controller = controller;

  final Player _player;
  final VideoController _controller;

  @override
  Future<void> open(
    String resolvedUrl, {
    required Duration? startPosition,
    required bool play,
  }) {
    return _player.open(Media(resolvedUrl, start: startPosition), play: play);
  }

  @override
  Future<void> play() {
    return _player.play();
  }

  @override
  Future<void> seek(Duration position) {
    return _player.seek(position);
  }

  @override
  Future<void> waitUntilFirstFrameRendered() {
    return _controller.waitUntilFirstFrameRendered;
  }
}
