import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_subtitle_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_speed_button.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_subtitle_button.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface_controller.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface_readiness.dart';

class MoviePlayerSurface extends StatefulWidget {
  const MoviePlayerSurface({
    super.key,
    required this.movieNumber,
    required this.resolvedUrl,
    required this.surfaceController,
    this.initialPosition,
    this.onPositionChanged,
    this.onPlayingChanged,
    this.subtitleState = MoviePlayerSubtitleState.empty,
    this.onSubtitleSelectionChanged,
    this.onSubtitleReloadRequested,
    this.onBackPressed,
    this.useTouchOptimizedControls = false,
  });

  final String movieNumber;
  final String resolvedUrl;
  final MoviePlayerSurfaceController surfaceController;
  final Duration? initialPosition;
  final ValueChanged<Duration>? onPositionChanged;
  final ValueChanged<bool>? onPlayingChanged;
  final MoviePlayerSubtitleState subtitleState;
  final ValueChanged<int?>? onSubtitleSelectionChanged;
  final Future<void> Function()? onSubtitleReloadRequested;
  final VoidCallback? onBackPressed;
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

  Future<void> setSubtitleTrack(SubtitleTrack track);
}

typedef MoviePlayerSurfaceSubtitleTextLoader =
    Future<String> Function(MoviePlayerSubtitleOption option);

class MoviePlayerSurfaceSubtitleCoordinator {
  const MoviePlayerSurfaceSubtitleCoordinator();

  Future<int?> applySelection({
    required MoviePlayerSurfacePlaybackDriver driver,
    required MoviePlayerSubtitleOption? selectedOption,
    required MoviePlayerSurfaceSubtitleTextLoader loadSubtitleText,
    required VoidCallback onError,
  }) async {
    try {
      if (selectedOption == null) {
        debugPrint('[player-debug] subtitle_apply_begin mode=off');
        await driver.setSubtitleTrack(SubtitleTrack.no());
        debugPrint('[player-debug] subtitle_apply_success mode=off');
        return null;
      }
      debugPrint(
        '[player-debug] subtitle_apply_begin mode=select subtitleId=${selectedOption.subtitleId} url=${selectedOption.resolvedUrl} title=${selectedOption.title}',
      );
      final subtitleText = await loadSubtitleText(selectedOption);
      debugPrint(
        '[player-debug] subtitle_apply_loaded subtitleId=${selectedOption.subtitleId} textLength=${subtitleText.length}',
      );
      await driver.setSubtitleTrack(
        SubtitleTrack.data(
          subtitleText,
          title: selectedOption.title,
          language: selectedOption.language,
        ),
      );
      debugPrint(
        '[player-debug] subtitle_apply_success mode=select subtitleId=${selectedOption.subtitleId}',
      );
      return selectedOption.subtitleId;
    } catch (error) {
      debugPrint('[player-debug] subtitle_apply_error error=$error');
      try {
        await driver.setSubtitleTrack(SubtitleTrack.no());
        debugPrint('[player-debug] subtitle_apply_fallback mode=off');
      } catch (_) {
        // Keep the original failure as the user-visible signal.
      }
      onError();
      return null;
    }
  }
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
Widget buildMoviePlayerMobileVideoControls(VideoState state) {
  return MaterialVideoControls(state);
}

@visibleForTesting
Widget buildMoviePlayerDesktopVideoControls(VideoState state) {
  return MaterialDesktopVideoControls(state);
}

@visibleForTesting
Widget Function(VideoState state) resolveMoviePlayerVideoControlsBuilder({
  required bool useTouchOptimizedControls,
}) {
  return useTouchOptimizedControls
      ? buildMoviePlayerMobileVideoControls
      : buildMoviePlayerDesktopVideoControls;
}

@visibleForTesting
MaterialVideoControlsThemeData buildMoviePlayerMobileControlsThemeData({
  required ThemeData theme,
  required List<Widget> topControls,
  required List<Widget> bottomControls,
}) {
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
    topButtonBar: topControls,
    topButtonBarMargin: const EdgeInsets.fromLTRB(12, 18, 12, 0),
    bottomButtonBar: bottomControls,
  );
}

@visibleForTesting
MaterialDesktopVideoControlsThemeData buildMoviePlayerDesktopControlsThemeData({
  required ThemeData theme,
  required List<Widget> topControls,
  required List<Widget> bottomControls,
}) {
  return MaterialDesktopVideoControlsThemeData(
    seekBarThumbColor: theme.colorScheme.primary,
    seekBarPositionColor: theme.colorScheme.primary,
    seekBarHeight: 6,
    seekBarThumbSize: 14,
    displaySeekBar: true,
    topButtonBar: topControls,
    topButtonBarMargin: const EdgeInsets.fromLTRB(12, 18, 12, 0),
    bottomButtonBar: bottomControls,
  );
}

class _MoviePlayerSurfaceState extends State<MoviePlayerSurface> {
  late final Player _player;
  late final VideoController _controller;
  late final MoviePlayerSurfaceReadiness _readiness;
  late final MoviePlayerSurfacePlaybackDriver _playbackDriver;
  late final ValueNotifier<MoviePlayerSubtitleState> _subtitleStateNotifier;
  late final ValueNotifier<bool> _isApplyingSubtitleNotifier;
  StreamSubscription<Duration>? _seekSubscription;
  StreamSubscription<void>? _playSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<double>? _rateSubscription;
  int _openRequestId = 0;
  bool _isApplyingSubtitle = false;
  double _currentPlaybackRate = 1.0;
  bool _hasExplicitPlaybackRateSelection = false;
  double? _pendingPlaybackRate;
  Duration? _startupSeekTarget;
  DateTime? _startupSeekStartedAt;
  bool _startupSeekSettled = true;
  int _startupSeekRetryCount = 0;
  int _startupSeekNearTargetSamples = 0;
  static const MoviePlayerSurfaceOpenCoordinator _openCoordinator =
      MoviePlayerSurfaceOpenCoordinator();
  static const MoviePlayerSurfaceSubtitleCoordinator _subtitleCoordinator =
      MoviePlayerSurfaceSubtitleCoordinator();
  static const int _startupSeekToleranceSeconds = 2;
  static const int _startupSeekRetryDelayMs = 800;
  static const int _startupSeekMaxWindowMs = 8000;
  static const int _startupSeekMaxRetries = 2;
  static const int _startupSeekMinNearSamples = 2;

  @override
  void initState() {
    super.initState();
    _player = Player(configuration: buildMoviePlayerConfiguration());
    _controller = VideoController(_player);
    _currentPlaybackRate = _player.state.rate;
    _readiness = MoviePlayerSurfaceReadiness();
    _playbackDriver = _MediaKitMoviePlayerSurfacePlaybackDriver(
      player: _player,
      controller: _controller,
    );
    _subtitleStateNotifier = ValueNotifier<MoviePlayerSubtitleState>(
      widget.subtitleState,
    );
    _isApplyingSubtitleNotifier = ValueNotifier<bool>(_isApplyingSubtitle);
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
    _rateSubscription = _player.stream.rate.listen((rate) {
      debugPrint(
        '[player-debug] playback_rate_stream rate=$rate pending=$_pendingPlaybackRate current=$_currentPlaybackRate',
      );
      final pendingRate = _pendingPlaybackRate;
      if (pendingRate != null && (pendingRate - rate).abs() >= 0.001) {
        debugPrint(
          '[player-debug] playback_rate_stream_ignored rate=$rate pending=$pendingRate',
        );
        return;
      }
      if (pendingRate != null && (pendingRate - rate).abs() < 0.001) {
        _pendingPlaybackRate = null;
      }
      if ((_currentPlaybackRate - rate).abs() < 0.001) {
        return;
      }
      if (!mounted) {
        _currentPlaybackRate = rate;
        return;
      }
      setState(() {
        _currentPlaybackRate = rate;
      });
    });
    unawaited(_openMedia());
  }

  @override
  void didUpdateWidget(covariant MoviePlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.subtitleState, widget.subtitleState)) {
      _subtitleStateNotifier.value = widget.subtitleState;
    }
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
    _rateSubscription?.cancel();
    _subtitleStateNotifier.dispose();
    _isApplyingSubtitleNotifier.dispose();
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

  Future<void> _handleSubtitleSelected(int? subtitleId) async {
    if (_isApplyingSubtitle) {
      debugPrint(
        '[player-debug] subtitle_selection_ignored reason=already_applying requestedSubtitleId=$subtitleId',
      );
      return;
    }

    MoviePlayerSubtitleOption? selectedOption;
    if (subtitleId != null) {
      for (final option in widget.subtitleState.options) {
        if (option.subtitleId == subtitleId) {
          selectedOption = option;
          break;
        }
      }
      if (selectedOption == null) {
        debugPrint(
          '[player-debug] subtitle_selection_ignored reason=option_not_found requestedSubtitleId=$subtitleId',
        );
        return;
      }
    }

    debugPrint(
      '[player-debug] subtitle_selection_requested requestedSubtitleId=$subtitleId currentSelected=${widget.subtitleState.selectedSubtitleId}',
    );

    setState(() {
      _isApplyingSubtitle = true;
      _isApplyingSubtitleNotifier.value = true;
    });

    try {
      final nextSubtitleId = await _subtitleCoordinator.applySelection(
        driver: _playbackDriver,
        selectedOption: selectedOption,
        loadSubtitleText: _loadSubtitleText,
        onError: () {
          if (mounted) {
            showToast('加载字幕失败，请稍后重试');
          }
        },
      );
      debugPrint(
        '[player-debug] subtitle_selection_result requestedSubtitleId=$subtitleId nextSubtitleId=$nextSubtitleId',
      );
      widget.onSubtitleSelectionChanged?.call(nextSubtitleId);
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingSubtitle = false;
          _isApplyingSubtitleNotifier.value = false;
        });
      }
    }
  }

  Future<String> _loadSubtitleText(MoviePlayerSubtitleOption option) async {
    final apiClient = context.read<ApiClient>();
    debugPrint(
      '[player-debug] subtitle_text_load_begin subtitleId=${option.subtitleId} url=${option.resolvedUrl}',
    );
    final bytes = await apiClient.getBytes(option.resolvedUrl);
    debugPrint(
      '[player-debug] subtitle_text_load_bytes subtitleId=${option.subtitleId} byteLength=${bytes.length}',
    );
    final text = utf8.decode(bytes);
    debugPrint(
      '[player-debug] subtitle_text_load_decoded subtitleId=${option.subtitleId} textLength=${text.length}',
    );
    return text;
  }

  Future<void> _handleSubtitleReloadRequested() async {
    if (_isApplyingSubtitle) {
      return;
    }
    await widget.onSubtitleReloadRequested?.call();
  }

  Future<void> _handlePlaybackRateSelected(double rate) async {
    debugPrint(
      '[player-debug] playback_rate_selected rate=$rate current=$_currentPlaybackRate explicit=$_hasExplicitPlaybackRateSelection',
    );
    final previousRate = _currentPlaybackRate;
    final previousSelection = _hasExplicitPlaybackRateSelection;
    _pendingPlaybackRate = rate;
    if (mounted) {
      setState(() {
        _currentPlaybackRate = rate;
        _hasExplicitPlaybackRateSelection = true;
      });
    } else {
      _currentPlaybackRate = rate;
      _hasExplicitPlaybackRateSelection = true;
    }
    try {
      await _player.setRate(rate);
      final appliedRate = _player.state.rate;
      _pendingPlaybackRate = null;
      debugPrint(
        '[player-debug] playback_rate_applied requested=$rate state=$appliedRate',
      );
      if (!mounted) {
        _currentPlaybackRate = appliedRate;
        return;
      }
      setState(() {
        _currentPlaybackRate = appliedRate;
      });
    } catch (error) {
      _pendingPlaybackRate = null;
      debugPrint(
        '[player-debug] playback_rate_select_error rate=$rate error=$error',
      );
      if (!mounted) {
        _currentPlaybackRate = previousRate;
        _hasExplicitPlaybackRateSelection = previousSelection;
        return;
      }
      setState(() {
        _currentPlaybackRate = previousRate;
        _hasExplicitPlaybackRateSelection = previousSelection;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topControls = buildMoviePlayerTopControls(
      movieNumber: widget.movieNumber,
      onBackPressed: widget.onBackPressed,
    );
    final mobileBottomControls = buildMoviePlayerMobileBottomControls();
    final desktopBottomControls = buildMoviePlayerDesktopBottomControls(
      currentRate: _currentPlaybackRate,
      hasExplicitSelection: _hasExplicitPlaybackRateSelection,
      onRateSelected: _handlePlaybackRateSelected,
      subtitleStateListenable: _subtitleStateNotifier,
      isApplyingListenable: _isApplyingSubtitleNotifier,
      onSubtitleSelected: _handleSubtitleSelected,
      onSubtitleReloadRequested: _handleSubtitleReloadRequested,
    );
    final backgroundColor = context.appColors.movieDetailHeroBackgroundStart;

    return MaterialVideoControlsTheme(
      normal: _mobileControlsTheme(theme, topControls, mobileBottomControls),
      fullscreen: _mobileControlsTheme(
        theme,
        topControls,
        mobileBottomControls,
      ),
      child: MaterialDesktopVideoControlsTheme(
        normal: _desktopControlsTheme(
          theme,
          topControls,
          desktopBottomControls,
        ),
        fullscreen: _desktopControlsTheme(
          theme,
          topControls,
          desktopBottomControls,
        ),
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
    List<Widget> topControls,
    List<Widget> bottomControls,
  ) {
    return buildMoviePlayerDesktopControlsThemeData(
      theme: theme,
      topControls: topControls,
      bottomControls: bottomControls,
    );
  }

  MaterialVideoControlsThemeData _mobileControlsTheme(
    ThemeData theme,
    List<Widget> topControls,
    List<Widget> bottomControls,
  ) {
    return buildMoviePlayerMobileControlsThemeData(
      theme: theme,
      topControls: topControls,
      bottomControls: bottomControls,
    );
  }
}

@visibleForTesting
List<Widget> buildMoviePlayerTopControls({
  required String movieNumber,
  required VoidCallback? onBackPressed,
}) {
  if (onBackPressed == null) {
    return const <Widget>[];
  }

  return <Widget>[
    MoviePlayerBackWithNumberControl(
      onPressed: onBackPressed,
      movieNumber: movieNumber,
    ),
  ];
}

@visibleForTesting
List<Widget> buildMoviePlayerMobileBottomControls() {
  return <Widget>[
    const MaterialPlayOrPauseButton(),
    const MaterialDesktopVolumeButton(),
    const MaterialPositionIndicator(),
    const Spacer(),
    const MaterialFullscreenButton(),
  ];
}

@visibleForTesting
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
    const MaterialFullscreenButton(),
  ];
}

@visibleForTesting
PlayerConfiguration buildMoviePlayerConfiguration({
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) {
  if (isWeb) {
    return const PlayerConfiguration();
  }

  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return const PlayerConfiguration(libass: true);
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return const PlayerConfiguration();
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

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) {
    return _player.setSubtitleTrack(track);
  }
}
