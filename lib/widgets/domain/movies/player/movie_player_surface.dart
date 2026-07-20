import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/video/initial_seek_guard.dart';
import 'package:sakuramedia/widgets/base/media/video/throttling_player.dart';
import 'package:sakuramedia/widgets/base/media/video/playback_resume_prompt.dart';
import 'package:sakuramedia/widgets/base/media/video/video_controls_theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_controls.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_media_source.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawer_coordinator.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawers.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_native_stats_sampler.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_error_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_rate_coordinator.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_resume_seek_coordinators.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_surface_controller.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_surface_coordinators.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_surface_readiness.dart';

class MoviePlayerSurface extends StatefulWidget {
  const MoviePlayerSurface({
    super.key,
    required this.movieNumber,
    required this.resolvedUrl,
    required this.surfaceController,
    this.initialPosition,
    this.resumePosition,
    this.onResumePromptResolved,
    this.onPositionChanged,
    this.onPlayingChanged,
    this.onCompleted,
    this.subtitleState = MoviePlayerSubtitleState.empty,
    this.onSubtitleSelectionChanged,
    this.onSubtitleReloadRequested,
    this.onBackPressed,
    this.useTouchOptimizedControls = false,
    this.mediaSourceKind = MoviePlayerMediaSourceKind.unknown,
    this.mediaInfo,
  });

  final String movieNumber;
  final String resolvedUrl;
  final MoviePlayerSurfaceController surfaceController;

  /// 调用方明确指定的起播位置（如从时刻/缩略图进入），不显示续播提示。
  final Duration? initialPosition;

  /// 历史播放位置：媒体始终先从头播放，待 surface 可安全 seek 后再询问用户。
  final Duration? resumePosition;
  final VoidCallback? onResumePromptResolved;
  final ValueChanged<Duration>? onPositionChanged;
  final ValueChanged<bool>? onPlayingChanged;

  /// 当前媒体播放至自然结束时回调一次，供调用方实现合集连播等续播逻辑。
  /// 不传则无副作用（JAV 单片播放器即不传）。
  final VoidCallback? onCompleted;
  final MoviePlayerSubtitleState subtitleState;
  final ValueChanged<int?>? onSubtitleSelectionChanged;
  final Future<void> Function()? onSubtitleReloadRequested;
  final VoidCallback? onBackPressed;
  final bool useTouchOptimizedControls;
  final MoviePlayerMediaSourceKind mediaSourceKind;
  final MoviePlayerMediaInfo? mediaInfo;

  @override
  State<MoviePlayerSurface> createState() => _MoviePlayerSurfaceState();
}

class _MoviePlayerSurfaceState extends State<MoviePlayerSurface> {
  late final Player _player;
  late final VideoController _controller;
  late final MoviePlayerSurfaceReadiness _readiness;
  late final MoviePlayerNativeStatsSampler _statsSampler;
  late final ValueNotifier<MoviePlayerSubtitleState> _subtitleStateNotifier;
  late final ValueNotifier<bool> _isApplyingSubtitleNotifier;
  late final MoviePlayerPlaybackRateCoordinator _playbackRate;
  late final MoviePlayerMobileDrawerCoordinator _mobileDrawer;
  StreamSubscription<Duration>? _seekSubscription;
  StreamSubscription<void>? _playSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<double>? _rateSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<Track>? _trackSubscription;
  StreamSubscription<VideoParams>? _videoParamsSubscription;
  StreamSubscription<AudioParams>? _audioParamsSubscription;
  StreamSubscription<double?>? _audioBitrateSubscription;
  int _openRequestId = 0;
  bool _hasPlaybackError = false;
  Duration? _pendingInitialSeek;
  late final MoviePlayerResumePromptCoordinator _resumePrompt;
  late final MoviePlayerStartupSeekCoordinator _startupSeek;
  static const MoviePlayerSurfaceOpenCoordinator _openCoordinator =
      MoviePlayerSurfaceOpenCoordinator();
  static const MoviePlayerSurfaceSubtitleCoordinator _subtitleCoordinator =
      MoviePlayerSurfaceSubtitleCoordinator();

  @override
  void initState() {
    super.initState();
    _player = ThrottlingPlayer(configuration: buildMoviePlayerConfiguration());
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto'),
    );
    _readiness = MoviePlayerSurfaceReadiness();
    _statsSampler = MoviePlayerNativeStatsSampler(
      readNativeProperty: createMediaKitNativePropertyReader(_player),
      mediaOrigin: moviePlayerPlaybackMediaOriginFor(widget.mediaSourceKind),
      originalUrl: widget.resolvedUrl,
    );
    _resumePrompt = MoviePlayerResumePromptCoordinator(
      seek: _player.seek,
      play: _player.play,
      currentPosition: () => _player.state.position,
      playbackRate: () => _player.state.rate,
      onResolved: () => widget.onResumePromptResolved?.call(),
      onResumeCompleted: () {
        if (mounted) {
          widget.onResumePromptResolved?.call();
        }
      },
    )..addListener(_handleResumePromptChanged);
    _startupSeek = MoviePlayerStartupSeekCoordinator(
      seek: _player.seek,
      isSurfaceReady: () => _readiness.isReady,
    );
    _subtitleStateNotifier = ValueNotifier<MoviePlayerSubtitleState>(
      widget.subtitleState,
    );
    _isApplyingSubtitleNotifier = ValueNotifier<bool>(false);
    _playbackRate = MoviePlayerPlaybackRateCoordinator(
      setRate: _player.setRate,
      initialRate: _player.state.rate,
    )..addListener(_handlePlaybackRateChanged);
    _mobileDrawer = MoviePlayerMobileDrawerCoordinator()
      ..addListener(_handleMobileDrawerChanged);
    _seekSubscription = widget.surfaceController.seekStream.listen(
      _handleSurfaceSeekRequested,
    );
    _playSubscription = widget.surfaceController.playStream.listen((_) {
      unawaited(_player.play());
    });
    _positionSubscription = _player.stream.position.listen((position) {
      widget.onPositionChanged?.call(position);
      _startupSeek.onPosition(position);
      _resumePrompt.onPosition(position);
    });
    _playingSubscription = _player.stream.playing.listen((playing) {
      widget.onPlayingChanged?.call(playing);
    });
    _completedSubscription = _player.stream.completed.listen((completed) {
      if (completed) {
        widget.onCompleted?.call();
      }
    });
    _trackSubscription = _player.stream.track.listen(
      _statsSampler.updateTrack,
    );
    _videoParamsSubscription = _player.stream.videoParams.listen(
      _statsSampler.updateVideoParams,
    );
    _audioParamsSubscription = _player.stream.audioParams.listen(
      _statsSampler.updateAudioParams,
    );
    _audioBitrateSubscription = _player.stream.audioBitrate.listen(
      _statsSampler.updateAudioBitrate,
    );
    _rateSubscription = _player.stream.rate.listen(_playbackRate.onRateStreamEvent);
    _errorSubscription = _player.stream.error.listen((error) {
      _markPlaybackFailed(error);
    });
    _statsSampler.start();
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
        _handleSurfaceSeekRequested,
      );
      _playSubscription?.cancel();
      _playSubscription = widget.surfaceController.playStream.listen((_) {
        unawaited(_player.play());
      });
    }
    if (oldWidget.resolvedUrl != widget.resolvedUrl ||
        oldWidget.mediaSourceKind != widget.mediaSourceKind) {
      _statsSampler.updateContext(
        mediaOrigin: moviePlayerPlaybackMediaOriginFor(widget.mediaSourceKind),
        originalUrl: widget.resolvedUrl,
      );
    }
    if (oldWidget.resolvedUrl != widget.resolvedUrl) {
      _playbackRate.resetMobileDisplayForNewMedia(_player.state.rate);
      _mobileDrawer.closeAll();
      _hasPlaybackError = false;
      unawaited(_openMedia());
    }
    if (oldWidget.resumePosition != widget.resumePosition) {
      if (widget.resumePosition == null) {
        _resumePrompt.cancel();
      } else {
        _resumePrompt.rearm(surfaceReady: _readiness.isReady);
      }
    }
    if (oldWidget.useTouchOptimizedControls &&
        !widget.useTouchOptimizedControls) {
      _mobileDrawer.closeDrawer();
    }
  }

  @override
  void dispose() {
    _seekSubscription?.cancel();
    _playSubscription?.cancel();
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _completedSubscription?.cancel();
    _rateSubscription?.cancel();
    _errorSubscription?.cancel();
    _trackSubscription?.cancel();
    _videoParamsSubscription?.cancel();
    _audioParamsSubscription?.cancel();
    _audioBitrateSubscription?.cancel();
    _statsSampler.dispose();
    _resumePrompt.removeListener(_handleResumePromptChanged);
    _resumePrompt.dispose();
    _playbackRate.removeListener(_handlePlaybackRateChanged);
    _playbackRate.dispose();
    _mobileDrawer.removeListener(_handleMobileDrawerChanged);
    _mobileDrawer.dispose();
    _subtitleStateNotifier.dispose();
    _isApplyingSubtitleNotifier.dispose();
    _readiness.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _openMedia() async {
    final requestId = ++_openRequestId;
    _statsSampler.reset();
    _startupSeek.begin(widget.initialPosition);
    _pendingInitialSeek = null;
    _resumePrompt.beginSession(
      hasResumePosition: widget.resumePosition != null,
    );
    debugPrint(
      '[player-debug] surface_state_open_media requestId=$requestId url=${widget.resolvedUrl} initialPositionSeconds=${widget.initialPosition?.inSeconds} startupTargetSeconds=${_startupSeek.target?.inSeconds}',
    );
    _readiness.reset();
    try {
      await _openCoordinator.open(
        open: (url, {required startPosition, required play}) => _player.open(
          buildMoviePlayerMedia(url, startPosition: startPosition),
          play: play,
        ),
        play: _player.play,
        seek: _player.seek,
        waitUntilFirstFrameRendered: () =>
            _controller.waitUntilFirstFrameRendered,
        resolvedUrl: widget.resolvedUrl,
        initialPosition: widget.initialPosition,
        shouldContinue: () => mounted && requestId == _openRequestId,
        waitUntilSeekReady: _guardsInitialSeek
            ? () => waitUntilInitialSeekReady(
                  firstFrame: _controller.waitUntilFirstFrameRendered,
                  positionStream: _player.stream.position,
                  currentPosition: () => _player.state.position,
                  isPlaying: () => _player.state.playing,
                  isBuffering: () => _player.state.buffering,
                )
            : null,
        markReady: _markSurfaceReady,
      );
    } catch (error) {
      if (mounted && requestId == _openRequestId) {
        _markPlaybackFailed(error.toString());
      }
      return;
    }
    unawaited(_statsSampler.refreshNative());
  }

  bool get _guardsInitialSeek =>
      widget.mediaSourceKind != MoviePlayerMediaSourceKind.local;

  void _handleSurfaceSeekRequested(Duration position) {
    _resumePrompt.resolve();
    if (_guardsInitialSeek && !_readiness.isReady) {
      _pendingInitialSeek = position;
      return;
    }
    unawaited(_player.seek(position));
  }

  void _markSurfaceReady() {
    _readiness.markReady();
    final pendingSeek = _pendingInitialSeek;
    _pendingInitialSeek = null;
    if (pendingSeek != null) {
      unawaited(_player.seek(pendingSeek));
    }
    if (!_resumePrompt.isResolved && widget.resumePosition != null) {
      _resumePrompt.show();
    }
  }

  void _handleResumePromptChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _markPlaybackFailed(String error) {
    if (!mounted || _hasPlaybackError) {
      return;
    }
    debugPrint('[player-debug] playback_failed error=$error');
    _mobileDrawer.closeAll();
    setState(() {
      _hasPlaybackError = true;
    });
  }

  void _handleMobileDrawerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _handleSubtitleSelected(int? subtitleId) async {
    if (_isApplyingSubtitleNotifier.value) {
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

    _isApplyingSubtitleNotifier.value = true;

    try {
      final nextSubtitleId = await _subtitleCoordinator.applySelection(
        setSubtitleTrack: _player.setSubtitleTrack,
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
        _isApplyingSubtitleNotifier.value = false;
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
    if (_isApplyingSubtitleNotifier.value) {
      return;
    }
    await widget.onSubtitleReloadRequested?.call();
  }

  void _handlePlaybackRateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _handleMobilePlaybackRateSelected(double rate) async {
    _mobileDrawer.closeDrawer();
    await _playbackRate.selectFromMobile(rate);
  }

  Future<void> _handleMobileSubtitleSelected(int subtitleId) async {
    _mobileDrawer.closeDrawer();
    await _handleSubtitleSelected(subtitleId);
  }

  Future<void> _toggleInfoSideDrawer() async {
    if (_mobileDrawer.isInfoSideOpen) {
      _mobileDrawer.dismissInfoSide();
      return;
    }
    await _statsSampler.refreshNative();
    if (!mounted) {
      return;
    }
    _mobileDrawer.openInfoSide();
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
      activeDrawer: _mobileDrawer.activeDrawer,
      speedDisplayListenable: _playbackRate.mobileSpeedDisplay,
      onSpeedButtonPressed: () =>
          _mobileDrawer.toggle(MoviePlayerMobileDrawerType.speed),
      onSubtitleButtonPressed: () =>
          _mobileDrawer.toggle(MoviePlayerMobileDrawerType.subtitle),
    );
    final desktopBottomControls = buildMoviePlayerDesktopBottomControls(
      currentRate: _playbackRate.currentRate,
      hasExplicitSelection: _playbackRate.hasExplicitSelection,
      onRateSelected: _playbackRate.select,
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
        if (_resumePrompt.isVisible && widget.resumePosition != null)
          PlaybackResumePromptOverlay(
            position: widget.resumePosition!,
            useTouchOptimizedLayout: widget.useTouchOptimizedControls,
            onResume: () => _resumePrompt.resume(widget.resumePosition),
            onStartOver: _resumePrompt.resolve,
          ),
        if (widget.useTouchOptimizedControls)
          buildMoviePlayerMobileDrawerOverlay(
            context: context,
            activeDrawer: _mobileDrawer.activeDrawer,
            subtitleState: widget.subtitleState,
            currentRate: _playbackRate.mobileSpeedDisplay.value.rate,
            isApplyingSubtitleListenable: _isApplyingSubtitleNotifier,
            onDismiss: _mobileDrawer.closeDrawer,
            onRateSelected: _handleMobilePlaybackRateSelected,
            onSubtitleSelected: _handleMobileSubtitleSelected,
          ),
        buildMoviePlayerInfoSideDrawerOverlay(
          context: context,
          isOpen: _mobileDrawer.isInfoSideOpen,
          onDismiss: _mobileDrawer.dismissInfoSide,
          infoListenable: _statsSampler.snapshot,
          mediaInfo: widget.mediaInfo,
        ),
      ],
    );

    final player = MaterialVideoControlsTheme(
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
              onBackPressed: widget.onBackPressed,
              child: child!,
            );
          },
          child: playerContent,
        ),
      ),
    );
    if (!_hasPlaybackError) {
      return player;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        player,
        MoviePlayerPlaybackErrorOverlay(
          sourceKind: widget.mediaSourceKind,
        ),
        if (widget.onBackPressed case final onBackPressed?)
          MoviePlayerBackOverlay(onPressed: onBackPressed),
      ],
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

