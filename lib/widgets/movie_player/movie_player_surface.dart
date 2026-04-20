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
import 'package:sakuramedia/widgets/movie_player/movie_player_playback_info.dart';
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
  final overlayTokens = theme.appOverlayTokens;
  return MaterialVideoControlsThemeData(
    horizontalGestureSensitivity: 3000,
    seekOnDoubleTap: true,
    seekBarMargin: EdgeInsets.fromLTRB(
      overlayTokens.playerSeekBarHorizontalInset,
      0,
      overlayTokens.playerSeekBarHorizontalInset,
      overlayTokens.playerSeekBarBottomInset,
    ),
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
    topButtonBarMargin: EdgeInsets.fromLTRB(
      overlayTokens.playerControlBarHorizontalInset,
      overlayTokens.playerControlBarTopInset,
      overlayTokens.playerControlBarHorizontalInset,
      0,
    ),
    bottomButtonBar: bottomControls,
  );
}

@visibleForTesting
MaterialDesktopVideoControlsThemeData buildMoviePlayerDesktopControlsThemeData({
  required ThemeData theme,
  required List<Widget> topControls,
  required List<Widget> bottomControls,
}) {
  final overlayTokens = theme.appOverlayTokens;
  return MaterialDesktopVideoControlsThemeData(
    seekBarThumbColor: theme.colorScheme.primary,
    seekBarPositionColor: theme.colorScheme.primary,
    seekBarHeight: 6,
    seekBarThumbSize: 14,
    displaySeekBar: true,
    topButtonBar: topControls,
    topButtonBarMargin: EdgeInsets.fromLTRB(
      overlayTokens.playerControlBarHorizontalInset,
      overlayTokens.playerControlBarTopInset,
      overlayTokens.playerControlBarHorizontalInset,
      0,
    ),
    bottomButtonBar: bottomControls,
  );
}

enum MoviePlayerMobileDrawerType { speed, subtitle }

@visibleForTesting
class MoviePlayerMobileSpeedDisplayState {
  const MoviePlayerMobileSpeedDisplayState({
    required this.rate,
    required this.hasExplicitSelection,
  });

  final double rate;
  final bool hasExplicitSelection;

  MoviePlayerMobileSpeedDisplayState copyWith({
    double? rate,
    bool? hasExplicitSelection,
  }) {
    return MoviePlayerMobileSpeedDisplayState(
      rate: rate ?? this.rate,
      hasExplicitSelection: hasExplicitSelection ?? this.hasExplicitSelection,
    );
  }
}

const Duration _moviePlayerMobileDrawerAnimationDuration = Duration(
  milliseconds: 220,
);
const String _moviePlayerMobileNoSubtitleLabel = '无可用字幕';

class _MoviePlayerSurfaceState extends State<MoviePlayerSurface> {
  late final Player _player;
  late final VideoController _controller;
  late final MoviePlayerSurfaceReadiness _readiness;
  late final MoviePlayerSurfacePlaybackDriver _playbackDriver;
  late final ValueNotifier<MoviePlayerPlaybackInfoSnapshot>
  _playbackInfoNotifier;
  late final ValueNotifier<MoviePlayerSubtitleState> _subtitleStateNotifier;
  late final ValueNotifier<bool> _isApplyingSubtitleNotifier;
  late final ValueNotifier<MoviePlayerMobileSpeedDisplayState>
  _mobileSpeedDisplayNotifier;
  StreamSubscription<Duration>? _seekSubscription;
  StreamSubscription<void>? _playSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<double>? _rateSubscription;
  StreamSubscription<Track>? _trackSubscription;
  StreamSubscription<VideoParams>? _videoParamsSubscription;
  StreamSubscription<AudioParams>? _audioParamsSubscription;
  StreamSubscription<double?>? _audioBitrateSubscription;
  Timer? _nativePlaybackInfoTimer;
  int _openRequestId = 0;
  bool _isApplyingSubtitle = false;
  bool _isRefreshingNativePlaybackInfo = false;
  bool _isInfoSideDrawerOpen = false;
  double _currentPlaybackRate = 1.0;
  bool _hasExplicitPlaybackRateSelection = false;
  double? _pendingPlaybackRate;
  Track _currentTrack = const Track();
  VideoParams _currentVideoParams = const VideoParams();
  AudioParams _currentAudioParams = const AudioParams();
  double? _currentAudioBitrate;
  double? _currentVideoBitrate;
  double? _currentEstimatedVfFps;
  String? _currentHwdecCurrent;
  double? _currentFrameDropCount;
  double? _currentDecoderFrameDropCount;
  double? _currentVoDelayedFrameCount;
  double? _currentMistimedFrameCount;
  double? _frameDropPerSecond;
  double? _decoderFrameDropPerSecond;
  double? _voDelayedFramePerSecond;
  double? _mistimedFramePerSecond;
  DateTime? _previousPlaybackCounterSampleAt;
  double? _previousFrameDropCount;
  double? _previousDecoderFrameDropCount;
  double? _previousVoDelayedFrameCount;
  double? _previousMistimedFrameCount;
  MoviePlayerMobileDrawerType? _activeMobileDrawer;
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
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto'),
    );
    _currentPlaybackRate = _player.state.rate;
    _readiness = MoviePlayerSurfaceReadiness();
    _playbackDriver = _MediaKitMoviePlayerSurfacePlaybackDriver(
      player: _player,
      controller: _controller,
    );
    _playbackInfoNotifier = ValueNotifier<MoviePlayerPlaybackInfoSnapshot>(
      MoviePlayerPlaybackInfoSnapshot.empty,
    );
    _subtitleStateNotifier = ValueNotifier<MoviePlayerSubtitleState>(
      widget.subtitleState,
    );
    _isApplyingSubtitleNotifier = ValueNotifier<bool>(_isApplyingSubtitle);
    _mobileSpeedDisplayNotifier =
        ValueNotifier<MoviePlayerMobileSpeedDisplayState>(
          MoviePlayerMobileSpeedDisplayState(
            rate: _currentPlaybackRate,
            hasExplicitSelection: false,
          ),
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
    _trackSubscription = _player.stream.track.listen((track) {
      _currentTrack = track;
      _refreshPlaybackInfoSnapshot();
    });
    _videoParamsSubscription = _player.stream.videoParams.listen((params) {
      _currentVideoParams = params;
      _refreshPlaybackInfoSnapshot();
    });
    _audioParamsSubscription = _player.stream.audioParams.listen((params) {
      _currentAudioParams = params;
      _refreshPlaybackInfoSnapshot();
    });
    _audioBitrateSubscription = _player.stream.audioBitrate.listen((bitrate) {
      _currentAudioBitrate = bitrate;
      _refreshPlaybackInfoSnapshot();
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
      final mobileSpeedDisplay = _mobileSpeedDisplayNotifier.value;
      if ((mobileSpeedDisplay.rate - rate).abs() >= 0.001) {
        _mobileSpeedDisplayNotifier.value = mobileSpeedDisplay.copyWith(
          rate: rate,
        );
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
    _refreshPlaybackInfoSnapshot();
    _nativePlaybackInfoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshNativePlaybackInfo());
    });
    unawaited(_refreshNativePlaybackInfo());
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
      _mobileSpeedDisplayNotifier.value = MoviePlayerMobileSpeedDisplayState(
        rate: _player.state.rate,
        hasExplicitSelection: false,
      );
      _resetPlaybackInfoState();
      _closeMobileDrawer(notify: false);
      _isInfoSideDrawerOpen = false;
      unawaited(_openMedia());
    }
    if (oldWidget.useTouchOptimizedControls &&
        !widget.useTouchOptimizedControls) {
      _closeMobileDrawer();
    }
  }

  @override
  void dispose() {
    _seekSubscription?.cancel();
    _playSubscription?.cancel();
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _rateSubscription?.cancel();
    _trackSubscription?.cancel();
    _videoParamsSubscription?.cancel();
    _audioParamsSubscription?.cancel();
    _audioBitrateSubscription?.cancel();
    _nativePlaybackInfoTimer?.cancel();
    _playbackInfoNotifier.dispose();
    _subtitleStateNotifier.dispose();
    _isApplyingSubtitleNotifier.dispose();
    _mobileSpeedDisplayNotifier.dispose();
    _readiness.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _openMedia() async {
    final requestId = ++_openRequestId;
    _resetPlaybackInfoState();
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
    unawaited(_refreshNativePlaybackInfo());
  }

  void _resetPlaybackInfoState() {
    _currentVideoBitrate = null;
    _currentEstimatedVfFps = null;
    _currentHwdecCurrent = null;
    _currentFrameDropCount = null;
    _currentDecoderFrameDropCount = null;
    _currentVoDelayedFrameCount = null;
    _currentMistimedFrameCount = null;
    _frameDropPerSecond = null;
    _decoderFrameDropPerSecond = null;
    _voDelayedFramePerSecond = null;
    _mistimedFramePerSecond = null;
    _previousPlaybackCounterSampleAt = null;
    _previousFrameDropCount = null;
    _previousDecoderFrameDropCount = null;
    _previousVoDelayedFrameCount = null;
    _previousMistimedFrameCount = null;
    _refreshPlaybackInfoSnapshot();
  }

  void _refreshPlaybackInfoSnapshot() {
    final snapshot = buildMoviePlayerPlaybackInfoSnapshot(
      track: _currentTrack,
      videoParams: _currentVideoParams,
      audioParams: _currentAudioParams,
      audioBitrate: _currentAudioBitrate,
      videoBitrate: _currentVideoBitrate,
      estimatedVfFps: _currentEstimatedVfFps,
      hwdecCurrent: _currentHwdecCurrent,
      renderDropFrameCount: _currentFrameDropCount,
      decoderDropFrameCount: _currentDecoderFrameDropCount,
      delayedFrameCount: _currentVoDelayedFrameCount,
      mistimedFrameCount: _currentMistimedFrameCount,
      renderDropFramePerSecond: _frameDropPerSecond,
      decoderDropFramePerSecond: _decoderFrameDropPerSecond,
      delayedFramePerSecond: _voDelayedFramePerSecond,
      mistimedFramePerSecond: _mistimedFramePerSecond,
    );
    if (_playbackInfoNotifier.value == snapshot) {
      return;
    }
    _playbackInfoNotifier.value = snapshot;
  }

  Future<void> _refreshNativePlaybackInfo() async {
    if (_isRefreshingNativePlaybackInfo || kIsWeb) {
      return;
    }
    _isRefreshingNativePlaybackInfo = true;
    try {
      final results = await Future.wait<String?>([
        _getNativePlayerProperty('hwdec-current'),
        _getNativePlayerProperty('video-bitrate'),
        _getNativePlayerProperty('estimated-vf-fps'),
        _getNativePlayerProperty('frame-drop-count'),
        _getNativePlayerProperty('decoder-frame-drop-count'),
        _getNativePlayerProperty('vo-delayed-frame-count'),
        _getNativePlayerProperty('mistimed-frame-count'),
      ]);
      if (!mounted) {
        return;
      }
      final now = DateTime.now();
      final frameDropCount = _parseNativeCounter(results[3]);
      final decoderFrameDropCount = _parseNativeCounter(results[4]);
      final voDelayedFrameCount = _parseNativeCounter(results[5]);
      final mistimedFrameCount = _parseNativeCounter(results[6]);
      final previousSampleAt = _previousPlaybackCounterSampleAt;
      final elapsedSeconds =
          previousSampleAt == null
              ? null
              : now.difference(previousSampleAt).inMilliseconds / 1000;

      _currentHwdecCurrent = results[0];
      _currentVideoBitrate = _parseNativeDouble(results[1]);
      _currentEstimatedVfFps = _parseNativeDouble(results[2]);
      _currentFrameDropCount = frameDropCount;
      _currentDecoderFrameDropCount = decoderFrameDropCount;
      _currentVoDelayedFrameCount = voDelayedFrameCount;
      _currentMistimedFrameCount = mistimedFrameCount;
      _frameDropPerSecond = _computeCounterDeltaPerSecond(
        currentValue: frameDropCount,
        previousValue: _previousFrameDropCount,
        elapsedSeconds: elapsedSeconds,
      );
      _decoderFrameDropPerSecond = _computeCounterDeltaPerSecond(
        currentValue: decoderFrameDropCount,
        previousValue: _previousDecoderFrameDropCount,
        elapsedSeconds: elapsedSeconds,
      );
      _voDelayedFramePerSecond = _computeCounterDeltaPerSecond(
        currentValue: voDelayedFrameCount,
        previousValue: _previousVoDelayedFrameCount,
        elapsedSeconds: elapsedSeconds,
      );
      _mistimedFramePerSecond = _computeCounterDeltaPerSecond(
        currentValue: mistimedFrameCount,
        previousValue: _previousMistimedFrameCount,
        elapsedSeconds: elapsedSeconds,
      );
      _previousPlaybackCounterSampleAt = now;
      _previousFrameDropCount = frameDropCount;
      _previousDecoderFrameDropCount = decoderFrameDropCount;
      _previousVoDelayedFrameCount = voDelayedFrameCount;
      _previousMistimedFrameCount = mistimedFrameCount;
      _refreshPlaybackInfoSnapshot();
    } finally {
      _isRefreshingNativePlaybackInfo = false;
    }
  }

  Future<String?> _getNativePlayerProperty(String property) async {
    final platformPlayer = _player.platform;
    if (platformPlayer == null) {
      return null;
    }
    final dynamic nativePlayer = platformPlayer;
    try {
      final raw = await nativePlayer.getProperty(property);
      if (raw is! String) {
        return null;
      }
      final normalized = raw.trim();
      if (normalized.isEmpty) {
        return null;
      }
      return normalized;
    } catch (_) {
      return null;
    }
  }

  double? _parseNativeDouble(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  double? _parseNativeCounter(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return null;
    }
    return parsed;
  }

  double? _computeCounterDeltaPerSecond({
    required double? currentValue,
    required double? previousValue,
    required double? elapsedSeconds,
  }) {
    if (currentValue == null ||
        previousValue == null ||
        elapsedSeconds == null ||
        elapsedSeconds <= 0) {
      return null;
    }
    final delta = currentValue - previousValue;
    if (!delta.isFinite || delta < 0) {
      return null;
    }
    final value = delta / elapsedSeconds;
    if (!value.isFinite || value < 0) {
      return null;
    }
    return value;
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

  void _toggleMobileDrawer(MoviePlayerMobileDrawerType drawerType) {
    if (!widget.useTouchOptimizedControls) {
      return;
    }
    setState(() {
      _isInfoSideDrawerOpen = false;
      _activeMobileDrawer =
          _activeMobileDrawer == drawerType ? null : drawerType;
    });
  }

  void _closeMobileDrawer({bool notify = true}) {
    if (_activeMobileDrawer == null) {
      return;
    }
    _activeMobileDrawer = null;
    if (notify && mounted) {
      setState(() {});
    }
  }

  Future<void> _handleMobilePlaybackRateSelected(double rate) async {
    _mobileSpeedDisplayNotifier.value = MoviePlayerMobileSpeedDisplayState(
      rate: rate,
      hasExplicitSelection: true,
    );
    _closeMobileDrawer();
    await _handlePlaybackRateSelected(rate);
    _mobileSpeedDisplayNotifier.value = MoviePlayerMobileSpeedDisplayState(
      rate: _currentPlaybackRate,
      hasExplicitSelection: _hasExplicitPlaybackRateSelection,
    );
  }

  Future<void> _handleMobileSubtitleSelected(int subtitleId) async {
    _closeMobileDrawer();
    await _handleSubtitleSelected(subtitleId);
  }

  Future<void> _toggleInfoSideDrawer() async {
    if (_isInfoSideDrawerOpen) {
      _dismissInfoSideDrawer();
      return;
    }
    _closeMobileDrawer(notify: false);
    await _refreshNativePlaybackInfo();
    if (!mounted) {
      return;
    }
    setState(() {
      _isInfoSideDrawerOpen = true;
    });
  }

  void _dismissInfoSideDrawer() {
    if (!_isInfoSideDrawerOpen) {
      return;
    }
    setState(() {
      _isInfoSideDrawerOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topControls = buildMoviePlayerTopControls(
      movieNumber: widget.movieNumber,
      onBackPressed: widget.onBackPressed,
      onInfoPressed: _toggleInfoSideDrawer,
    );
    final mobileBottomControls = buildMoviePlayerMobileBottomControls(
      activeDrawer: _activeMobileDrawer,
      speedDisplayListenable: _mobileSpeedDisplayNotifier,
      onSpeedButtonPressed:
          () => _toggleMobileDrawer(MoviePlayerMobileDrawerType.speed),
      onSubtitleButtonPressed:
          () => _toggleMobileDrawer(MoviePlayerMobileDrawerType.subtitle),
    );
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
    final videoSurface = Video(
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
    );
    final playerContent = Stack(
      fit: StackFit.expand,
      children: [
        videoSurface,
        if (widget.useTouchOptimizedControls)
          buildMoviePlayerMobileDrawerOverlay(
            context: context,
            activeDrawer: _activeMobileDrawer,
            subtitleState: widget.subtitleState,
            currentRate: _mobileSpeedDisplayNotifier.value.rate,
            isApplyingSubtitle: _isApplyingSubtitle,
            onDismiss: _closeMobileDrawer,
            onRateSelected: _handleMobilePlaybackRateSelected,
            onSubtitleSelected: _handleMobileSubtitleSelected,
          ),
        buildMoviePlayerInfoSideDrawerOverlay(
          context: context,
          isOpen: _isInfoSideDrawerOpen,
          onDismiss: _dismissInfoSideDrawer,
          infoListenable: _playbackInfoNotifier,
        ),
      ],
    );

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
          child: playerContent,
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

@visibleForTesting
List<Widget> buildMoviePlayerMobileBottomControls({
  required MoviePlayerMobileDrawerType? activeDrawer,
  required ValueListenable<MoviePlayerMobileSpeedDisplayState>
  speedDisplayListenable,
  required VoidCallback onSpeedButtonPressed,
  required VoidCallback onSubtitleButtonPressed,
}) {
  return <Widget>[
    const MaterialPlayOrPauseButton(),
    const MaterialDesktopVolumeButton(),
    const MaterialPositionIndicator(),
    const Spacer(),
    ...buildMoviePlayerMobileDrawerToggleButtons(
      activeDrawer: activeDrawer,
      speedDisplayListenable: speedDisplayListenable,
      onSpeedButtonPressed: onSpeedButtonPressed,
      onSubtitleButtonPressed: onSubtitleButtonPressed,
    ),
    const MaterialFullscreenButton(),
  ];
}

@visibleForTesting
List<Widget> buildMoviePlayerMobileDrawerToggleButtons({
  required MoviePlayerMobileDrawerType? activeDrawer,
  required ValueListenable<MoviePlayerMobileSpeedDisplayState>
  speedDisplayListenable,
  required VoidCallback onSpeedButtonPressed,
  required VoidCallback onSubtitleButtonPressed,
}) {
  return <Widget>[
    _MoviePlayerMobileSpeedDrawerToggleButton(
      buttonKey: const Key('movie-player-mobile-speed-button'),
      speedDisplayListenable: speedDisplayListenable,
      active: activeDrawer == MoviePlayerMobileDrawerType.speed,
      onTap: onSpeedButtonPressed,
    ),
    _MoviePlayerMobileDrawerToggleButton(
      key: const Key('movie-player-mobile-subtitle-button'),
      label: '字幕',
      active: activeDrawer == MoviePlayerMobileDrawerType.subtitle,
      onTap: onSubtitleButtonPressed,
    ),
  ];
}

@visibleForTesting
Widget buildMoviePlayerMobileDrawerOverlay({
  required BuildContext context,
  required MoviePlayerMobileDrawerType? activeDrawer,
  required MoviePlayerSubtitleState subtitleState,
  required double currentRate,
  required bool isApplyingSubtitle,
  required VoidCallback onDismiss,
  required Future<void> Function(double rate) onRateSelected,
  required Future<void> Function(int subtitleId) onSubtitleSelected,
}) {
  final overlayTokens = context.appOverlayTokens;
  return IgnorePointer(
    key: const Key('movie-player-mobile-drawer-layer'),
    ignoring: activeDrawer == null,
    child: GestureDetector(
      key: const Key('movie-player-mobile-drawer-dismiss-area'),
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: overlayTokens.playerDrawerHorizontalInset,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: AnimatedSwitcher(
              duration: _moviePlayerMobileDrawerAnimationDuration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation);
                return SlideTransition(position: offsetAnimation, child: child);
              },
              child: switch (activeDrawer) {
                MoviePlayerMobileDrawerType.speed =>
                  _MoviePlayerMobileSpeedDrawer(
                    key: const ValueKey<String>(
                      'movie-player-mobile-speed-drawer',
                    ),
                    currentRate: currentRate,
                    onRateSelected: onRateSelected,
                  ),
                MoviePlayerMobileDrawerType.subtitle =>
                  _MoviePlayerMobileSubtitleDrawer(
                    key: const ValueKey<String>(
                      'movie-player-mobile-subtitle-drawer',
                    ),
                    subtitleState: subtitleState,
                    isApplyingSubtitle: isApplyingSubtitle,
                    onSubtitleSelected: onSubtitleSelected,
                  ),
                null => const SizedBox.shrink(
                  key: ValueKey<String>('movie-player-mobile-drawer-closed'),
                ),
              },
            ),
          ),
        ),
      ),
    ),
  );
}

@visibleForTesting
Widget buildMoviePlayerInfoSideDrawerOverlay({
  required BuildContext context,
  required bool isOpen,
  required VoidCallback onDismiss,
  required ValueListenable<MoviePlayerPlaybackInfoSnapshot> infoListenable,
}) {
  final overlayTokens = context.appOverlayTokens;
  return IgnorePointer(
    key: const Key('movie-player-info-side-drawer-layer'),
    ignoring: !isOpen,
    child: GestureDetector(
      key: const Key('movie-player-info-side-drawer-dismiss-area'),
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: overlayTokens.playerDrawerHorizontalInset,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: AnimatedSwitcher(
              duration: _moviePlayerMobileDrawerAnimationDuration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation);
                return SlideTransition(position: offsetAnimation, child: child);
              },
              child:
                  isOpen
                      ? _MoviePlayerInfoSideDrawer(
                        key: const ValueKey<String>(
                          'movie-player-info-side-drawer',
                        ),
                        infoListenable: infoListenable,
                      )
                      : const SizedBox.shrink(
                        key: ValueKey<String>(
                          'movie-player-info-side-drawer-closed',
                        ),
                      ),
            ),
          ),
        ),
      ),
    ),
  );
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
String formatMoviePlayerPlaybackRateLabel(double rate) {
  final hundredths = (rate * 100).round();
  if (hundredths % 100 == 0 || hundredths % 50 == 0) {
    return '${rate.toStringAsFixed(1)}x';
  }
  return '${rate.toStringAsFixed(2)}x';
}

class _MoviePlayerMobileDrawerToggleButton extends StatelessWidget {
  const _MoviePlayerMobileDrawerToggleButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minWidth: overlayTokens.controlMinWidth,
          minHeight: overlayTokens.controlMinHeight,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: overlayTokens.controlHorizontalPadding,
          vertical: overlayTokens.controlVerticalPadding,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: active ? AppTextTone.accent : AppTextTone.onMedia,
          ),
        ),
      ),
    );
  }
}

class _MoviePlayerMobileSpeedDrawerToggleButton extends StatelessWidget {
  const _MoviePlayerMobileSpeedDrawerToggleButton({
    required this.buttonKey,
    required this.speedDisplayListenable,
    required this.active,
    required this.onTap,
  });

  final Key buttonKey;
  final ValueListenable<MoviePlayerMobileSpeedDisplayState>
  speedDisplayListenable;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MoviePlayerMobileSpeedDisplayState>(
      valueListenable: speedDisplayListenable,
      builder: (context, speedDisplay, child) {
        final showsRateLabel =
            speedDisplay.hasExplicitSelection ||
            (speedDisplay.rate - 1.0).abs() >= 0.001;
        final label =
            showsRateLabel
                ? formatMoviePlayerPlaybackRateLabel(speedDisplay.rate)
                : '倍速';
        return _MoviePlayerMobileDrawerToggleButton(
          key: buttonKey,
          label: label,
          active: active,
          onTap: onTap,
        );
      },
    );
  }
}

class _MoviePlayerMobileDrawerSurface extends StatelessWidget {
  const _MoviePlayerMobileDrawerSurface({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final overlayTokens = context.appOverlayTokens;
    return Container(
      width: width ?? overlayTokens.playerDrawerWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: colors.movieDetailHeroBackgroundStart.withValues(
          alpha: overlayTokens.drawerSurfaceAlpha,
        ),
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(overlayTokens.surfaceRadius),
        ),
        border: Border.all(
          color: context.appTextPalette.onMedia.withValues(
            alpha: overlayTokens.surfaceBorderAlpha,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: overlayTokens.surfaceShadowAlpha,
            ),
            blurRadius: overlayTokens.surfaceShadowBlur,
            offset: Offset(0, overlayTokens.surfaceShadowOffsetY),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MoviePlayerMobileSpeedDrawer extends StatelessWidget {
  const _MoviePlayerMobileSpeedDrawer({
    super.key,
    required this.currentRate,
    required this.onRateSelected,
  });

  final double currentRate;
  final Future<void> Function(double rate) onRateSelected;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    final selectedColor = resolveAppTextToneColor(context, AppTextTone.accent);
    return _MoviePlayerMobileDrawerSurface(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: overlayTokens.drawerVerticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: kMoviePlayerPlaybackRates
              .map((rate) {
                final selected = (currentRate - rate).abs() < 0.001;
                return GestureDetector(
                  key: Key(
                    'movie-player-mobile-speed-drawer-item-${rate.toString().replaceAll('.', '_')}',
                  ),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(onRateSelected(rate)),
                  child: SizedBox(
                    height: overlayTokens.menuItemHeight,
                    child: Row(
                      children: [
                        SizedBox(width: overlayTokens.controlSideGap),
                        SizedBox(width: overlayTokens.controlSideGap),
                        Expanded(
                          child: Center(
                            child: Text(
                              formatMoviePlayerPlaybackRateLabel(rate),
                              style: resolveAppTextStyle(
                                context,
                                size: AppTextSize.s14,
                                tone:
                                    selected
                                        ? AppTextTone.accent
                                        : AppTextTone.onMedia,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: overlayTokens.controlCheckSlotWidth,
                          child: Center(
                            child:
                                selected
                                    ? Icon(
                                      Icons.check_rounded,
                                      key: Key(
                                        'movie-player-mobile-speed-drawer-item-check-${rate.toString().replaceAll('.', '_')}',
                                      ),
                                      size: overlayTokens.controlCheckIconSize,
                                      color: selectedColor,
                                    )
                                    : SizedBox(
                                      key: Key(
                                        'movie-player-mobile-speed-drawer-item-check-slot-${rate.toString().replaceAll('.', '_')}',
                                      ),
                                      width: overlayTokens.controlCheckIconSize,
                                      height:
                                          overlayTokens.controlCheckIconSize,
                                    ),
                          ),
                        ),
                        SizedBox(width: overlayTokens.controlTrailingGap),
                      ],
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _MoviePlayerInfoSideDrawer extends StatelessWidget {
  const _MoviePlayerInfoSideDrawer({super.key, required this.infoListenable});

  final ValueListenable<MoviePlayerPlaybackInfoSnapshot> infoListenable;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final overlayTokens = context.appOverlayTokens;
    return Container(
      width: overlayTokens.playerInfoDrawerWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceMuted.withValues(
          alpha: overlayTokens.infoDrawerSurfaceAlpha,
        ),
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(overlayTokens.surfaceRadius),
        ),
        border: Border.all(
          color: context.appTextPalette.onMedia.withValues(
            alpha: overlayTokens.infoDrawerSurfaceAlpha / 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: overlayTokens.surfaceShadowAlpha,
            ),
            blurRadius: overlayTokens.surfaceShadowBlur,
            offset: Offset(0, overlayTokens.surfaceShadowOffsetY),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(context.appSpacing.md),
        child: MoviePlayerPlaybackInfoPanel(infoListenable: infoListenable),
      ),
    );
  }
}

class _MoviePlayerMobileSubtitleDrawer extends StatelessWidget {
  const _MoviePlayerMobileSubtitleDrawer({
    super.key,
    required this.subtitleState,
    required this.isApplyingSubtitle,
    required this.onSubtitleSelected,
  });

  final MoviePlayerSubtitleState subtitleState;
  final bool isApplyingSubtitle;
  final Future<void> Function(int subtitleId) onSubtitleSelected;

  @override
  Widget build(BuildContext context) {
    final options = subtitleState.options;
    final overlayTokens = context.appOverlayTokens;
    final selectedColor = Theme.of(context).colorScheme.primary;
    return _MoviePlayerMobileDrawerSurface(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: overlayTokens.drawerVerticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:
              options.isEmpty
                  ? <Widget>[
                    SizedBox(
                      key: const Key(
                        'movie-player-mobile-subtitle-drawer-empty',
                      ),
                      height: overlayTokens.menuItemHeight,
                      child: Center(
                        child: Text(
                          _moviePlayerMobileNoSubtitleLabel,
                          style: resolveAppTextStyle(
                            context,
                            size: AppTextSize.s14,
                            tone: AppTextTone.muted,
                          ),
                        ),
                      ),
                    ),
                  ]
                  : options
                      .map((option) {
                        final selected =
                            subtitleState.selectedSubtitleId ==
                            option.subtitleId;
                        return GestureDetector(
                          key: Key(
                            'movie-player-mobile-subtitle-drawer-item-${option.subtitleId}',
                          ),
                          behavior: HitTestBehavior.opaque,
                          onTap:
                              isApplyingSubtitle
                                  ? null
                                  : () => unawaited(
                                    onSubtitleSelected(option.subtitleId),
                                  ),
                          child: SizedBox(
                            height: overlayTokens.menuItemHeight,
                            child: Row(
                              children: [
                                SizedBox(width: overlayTokens.controlSideGap),
                                SizedBox(width: overlayTokens.controlSideGap),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      option.label,
                                      style: resolveAppTextStyle(
                                        context,
                                        size: AppTextSize.s14,
                                        tone:
                                            selected
                                                ? AppTextTone.accent
                                                : AppTextTone.onMedia,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: overlayTokens.controlCheckSlotWidth,
                                  child: Center(
                                    child:
                                        selected
                                            ? Icon(
                                              Icons.check_rounded,
                                              key: Key(
                                                'movie-player-mobile-subtitle-drawer-item-check-${option.subtitleId}',
                                              ),
                                              size:
                                                  overlayTokens
                                                      .controlCheckIconSize,
                                              color: selectedColor,
                                            )
                                            : SizedBox(
                                              key: Key(
                                                'movie-player-mobile-subtitle-drawer-item-check-slot-${option.subtitleId}',
                                              ),
                                              width:
                                                  overlayTokens
                                                      .controlCheckIconSize,
                                              height:
                                                  overlayTokens
                                                      .controlCheckIconSize,
                                            ),
                                  ),
                                ),
                                SizedBox(
                                  width: overlayTokens.controlTrailingGap,
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
        ),
      ),
    );
  }
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
