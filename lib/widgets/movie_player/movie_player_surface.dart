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
  });

  final String resolvedUrl;
  final MoviePlayerSurfaceController surfaceController;
  final Duration? initialPosition;
  final ValueChanged<Duration>? onPositionChanged;
  final ValueChanged<bool>? onPlayingChanged;

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
    await driver.open(
      resolvedUrl,
      startPosition:
          initialPosition != null && initialPosition > Duration.zero
              ? initialPosition
              : null,
      play: false,
    );
    if (!shouldContinue()) {
      return;
    }

    await driver.play();
    if (!shouldContinue()) {
      return;
    }

    await driver.waitUntilFirstFrameRendered();
    if (!shouldContinue()) {
      return;
    }

    markReady();
  }
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
  static const MoviePlayerSurfaceOpenCoordinator _openCoordinator =
      MoviePlayerSurfaceOpenCoordinator();

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
    _readiness.reset();
    await _openCoordinator.open(
      driver: _playbackDriver,
      resolvedUrl: widget.resolvedUrl,
      initialPosition: widget.initialPosition,
      shouldContinue: () => mounted && requestId == _openRequestId,
      markReady: _readiness.markReady,
    );
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
      normal: _materialControlsTheme(context, controls),
      fullscreen: _materialControlsTheme(context, controls),
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
    BuildContext context,
    List<Widget> controls,
  ) {
    final theme = Theme.of(context);
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
