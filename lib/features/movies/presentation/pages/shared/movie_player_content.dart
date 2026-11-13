import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, ValueListenable, defaultTargetPlatform;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/clips/presentation/widgets/create_clip_dialog.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_player_layout.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_player_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_player_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_player_state.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/domain/media/media_thumbnail_action_support.dart';
import 'package:sakuramedia/widgets/base/media/video/player_app_fullscreen.dart';
import 'package:sakuramedia/widgets/base/media/video/initial_seek_guard.dart';
import 'package:sakuramedia/widgets/base/media/video/playback_resume_prompt.dart';
import 'package:sakuramedia/widgets/base/media/video/player_orientation_lock.dart';
import 'package:sakuramedia/widgets/base/media/video/player_screen_orientation.dart';
import 'package:sakuramedia/widgets/base/media/video/player_system_controls.dart';
import 'package:sakuramedia/widgets/base/media/video/player_viewport.dart';
import 'package:sakuramedia/widgets/base/media/video/throttling_player.dart';
import 'package:sakuramedia/widgets/base/media/video/video_controls_theme.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_controls.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawers.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_native_stats_sampler.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';
import 'package:sakuramedia/widgets/domain/media/movie_player_thumbnail_panel.dart';

/// 影片应用内播放器共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异（fallbackPath / imageSearchRoutePath / useTouchOptimizedControls /
/// dividerHandleBuffer）全部收在壳参数里；State 持有加载状态机、缩略图面板与
/// 结果动作族。移动壳额外负责横屏 SystemUI 生命周期。
class MoviePlayerContent extends ConsumerStatefulWidget {
  const MoviePlayerContent({
    super.key,
    required this.movieNumber,
    this.initialMediaId,
    this.initialPositionSeconds,
    this.fallbackPath,
    this.imageSearchRoutePath = desktopImageSearchPath,
    this.useTouchOptimizedControls = false,
    this.dividerHandleBuffer = 0,
    this.orientationLock,
  });

  final String movieNumber;
  final int? initialMediaId;
  final int? initialPositionSeconds;
  final String? fallbackPath;
  final String imageSearchRoutePath;
  final bool useTouchOptimizedControls;
  final double dividerHandleBuffer;

  /// 移动壳传入的方向锁状态；桌面壳不传，顶栏不显示锁定按钮。
  final PlayerOrientationLock? orientationLock;

  @override
  ConsumerState<MoviePlayerContent> createState() => _MoviePlayerContentState();
}

class _MoviePlayerContentState extends ConsumerState<MoviePlayerContent>
    with PlayerAppFullscreenStateMixin<MoviePlayerContent> {
  late final MoviePlayerScope _scope;
  late final MoviePlayer _controller;
  late final MultiSplitViewController _splitController;
  late final MoviePlayerSurfaceController _surfaceController;

  MoviePlayerState get _playerState => ref.read(moviePlayerProvider(_scope));

  @override
  bool get applySystemFullscreenForAppFullscreen =>
      !widget.useTouchOptimizedControls;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[player-debug] movie_player_content_init movie=${widget.movieNumber} initialMediaId=${widget.initialMediaId} initialPositionSeconds=${widget.initialPositionSeconds}',
    );
    _scope = MoviePlayerScope(
      movieNumber: widget.movieNumber,
      initialMediaId: widget.initialMediaId,
      initialPositionSeconds: widget.initialPositionSeconds,
      baseUrl: ref.read(sessionStoreProvider).baseUrl,
    );
    _controller = ref.read(moviePlayerProvider(_scope).notifier);
    _splitController = MultiSplitViewController(
      areas: [Area(flex: 0.72), Area(flex: 0.28)],
    );
    _surfaceController = MoviePlayerSurfaceController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_controller.load());
      }
    });
  }

  @override
  void dispose() {
    disposePlayerAppFullscreen();
    unawaited(_controller.flushPlaybackProgress());
    _surfaceController.dispose();
    _splitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final playerState = ref.watch(moviePlayerProvider(_scope));

    final Widget content;
    if (playerState.isLoading) {
      content = wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        child: const MoviePlayerLoadingState(),
      );
    } else if (playerState.errorMessage != null) {
      content = wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        child: MoviePlayerErrorState(
          message: playerState.errorMessage!,
          onRetry: _controller.load,
        ),
      );
    } else {
      final primaryResolvedUrl = playerState.resolvedPlayUrl(_scope.baseUrl);
      if (primaryResolvedUrl == null) {
        content = wrapWithMoviePlayerBackButton(
          onBackPressed: _handleBack,
          child: MoviePlayerSplitLayout(
            controller: _splitController,
            dividerHandleBuffer: widget.dividerHandleBuffer,
            collapsible: true,
            panelAvailable: playerState.selectedMedia != null,
            collapseWhenPortrait: widget.useTouchOptimizedControls,
            leftChild: const MoviePlayerEmptyState(),
            rightChild: playerState.selectedMedia == null
                ? const SizedBox.expand()
                : _buildThumbnailPanel(),
          ),
        );
      } else {
        content = MoviePlayerSplitLayout(
          controller: _splitController,
          dividerHandleBuffer: widget.dividerHandleBuffer,
          collapsible: true,
          panelAvailable: playerState.selectedMedia != null,
          collapseWhenPortrait: widget.useTouchOptimizedControls,
          leftChild: PlayerAppFullscreenDoubleTap(
            enabled: !widget.useTouchOptimizedControls,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isPortrait = isPortraitPlayerViewport(constraints);
                return _buildPlayerSurface(
                  context,
                  primaryResolvedUrl,
                  isPortrait: isPortrait,
                  compactTopControls: shouldUseCompactPlayerControls(
                    constraints: constraints,
                  ),
                  compactBottomControls: shouldUseCompactPlayerControls(
                    constraints: constraints,
                  ),
                );
              },
            ),
          ),
          rightChild: playerState.selectedMedia == null
              ? const SizedBox.expand()
              : _buildThumbnailPanel(),
        );
      }
    }

    // 桌面应用内全屏去掉圆角纯黑铺满；移动端本身已横屏沉浸，始终全出血。
    // 全屏/窗口态必须保持同一种 widget 类型 + 同一个 key，否则 Flutter 会把
    // 子树整个 unmount 重建，MoviePlayerSurface 内的 Player 会被 dispose 后
    // 重新 open，表现为进/退全屏都从头播放。
    final fullBleed = isAppFullscreen || widget.useTouchOptimizedControls;
    return PlayerSwipeBackGuard(
      enabled: widget.useTouchOptimizedControls,
      onBack: _handleBack,
      child: Scaffold(
        backgroundColor: fullBleed
            ? Colors.black
            : colors.movieDetailHeroBackgroundStart,
        body: PlayerAppFullscreenScope(
          isFullscreen: isAppFullscreen,
          onToggle: toggleAppFullscreen,
          child: DecoratedBox(
            key: const Key('movie-player-page-frame'),
            decoration: BoxDecoration(
              color: fullBleed
                  ? Colors.black
                  : colors.movieDetailHeroBackgroundStart.withValues(
                      alpha: 0.92,
                    ),
              borderRadius: fullBleed
                  ? BorderRadius.zero
                  : context.appRadius.lgBorder,
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerSurface(
    BuildContext context,
    String resolvedUrl, {
    required bool isPortrait,
    required bool compactTopControls,
    required bool compactBottomControls,
  }) {
    return MoviePlayerSurface(
      movieNumber: widget.movieNumber,
      resolvedUrl: resolvedUrl,
      surfaceController: _surfaceController,
      initialPosition: _playerState.startupPlaybackPosition,
      resumePosition: _playerState.resumePlaybackPosition,
      onResumePromptResolved: _controller.resolveResumePrompt,
      onPositionChanged: _controller.handlePlaybackPosition,
      onPlayingChanged: _controller.handlePlaybackPlayingChanged,
      subtitleState: _playerState.subtitleState,
      onSubtitleSelectionChanged: _controller.setSelectedSubtitleId,
      onSubtitleReloadRequested: _controller.loadSubtitles,
      onBackPressed: _handleBack,
      isPortraitOverride: isPortrait,
      compactTopControlsOverride: compactTopControls,
      compactBottomControlsOverride: compactBottomControls,
      useTouchOptimizedControls: widget.useTouchOptimizedControls,
      disableNativeFullscreen: true,
      orientationLock: widget.orientationLock,
      mediaInfo: _buildMediaInfo(),
      thumbnails: _playerState.thumbnails,
    );
  }

  MoviePlayerMediaInfo? _buildMediaInfo() {
    final media = _playerState.selectedMedia;
    if (media == null) {
      return null;
    }
    final l10n = AppLocalizations.of(context);
    return MoviePlayerMediaInfo(
      sourceLabel: media.providerKey?.trim().isNotEmpty == true
          ? media.providerKey!.trim()
          : '--',
      libraryLabel: media.libraryId == null
          ? '--'
          : l10n.moviePageMediaLibraryLabel(media.libraryId!),
      fileSizeLabel: media.fileSizeBytes > 0
          ? formatFileSize(media.fileSizeBytes)
          : '--',
      durationLabel: media.durationSeconds > 0
          ? formatMediaTimecode(media.durationSeconds)
          : '--',
      resolutionLabel: media.resolution?.trim().isNotEmpty == true
          ? media.resolution!.trim()
          : '--',
    );
  }

  Widget _buildThumbnailPanel() {
    return ValueListenableBuilder<int?>(
      valueListenable: _controller.activeThumbnailIndexListenable,
      builder: (context, activeIndex, child) {
        final playerState = _playerState;
        return MoviePlayerThumbnailPanel(
          thumbnails: playerState.thumbnails,
          isLoading: playerState.isThumbnailLoading,
          errorMessage: playerState.thumbnailErrorMessage,
          columns: playerState.thumbnailColumns,
          activeIndex: activeIndex,
          isScrollLocked: playerState.isThumbnailScrollLocked,
          usesAutoColumns: playerState.usesAutoThumbnailColumns,
          onAutoColumnsResolved: _controller.applyAutoThumbnailColumns,
          onColumnsChanged: _controller.setThumbnailColumns,
          onToggleScrollLock: _controller.toggleThumbnailScrollLock,
          onThumbnailTap: (index) {
            if (_playerState.clipSelectionMode) {
              _controller.handleClipSelectionTap(index);
              return;
            }
            _controller.handleThumbnailTap(index);
            final item = _playerState.thumbnails[index];
            _surfaceController.seekTo(Duration(seconds: item.offsetSeconds));
          },
          onThumbnailMenuRequested: _showThumbnailActions,
          onRetry: _controller.loadThumbnails,
          clipSelectionMode: playerState.clipSelectionMode,
          clipStartIndex: playerState.clipStartIndex,
          clipEndIndex: playerState.clipEndIndex,
          clipStartSeconds: playerState.clipStartThumbnail?.offsetSeconds,
          clipEndSeconds: playerState.clipEndThumbnail?.offsetSeconds,
          clipDurationSeconds: playerState.clipSelectionDurationSeconds,
          canCreateClip: playerState.canCreateClip,
          onToggleClipSelectionMode: _controller.toggleClipSelectionMode,
          onCreateClip: _handleCreateClip,
          onClearClipSelection: _controller.clearClipSelection,
        );
      },
    );
  }

  Future<void> _handleCreateClip() async {
    final media = _playerState.selectedMedia;
    final start = _playerState.clipStartThumbnail;
    final end = _playerState.clipEndThumbnail;
    if (media == null || start == null || end == null) {
      return;
    }
    final created = await showCreateClipDialog(
      context,
      mediaId: media.mediaId,
      movieNumber: widget.movieNumber,
      startThumbnailId: start.thumbnailId,
      endThumbnailId: end.thumbnailId,
      startSeconds: start.offsetSeconds,
      endSeconds: end.offsetSeconds,
    );
    if (!mounted || created == null) {
      return;
    }
    showToast(
      AppLocalizations.of(context).moviePageClipCreated,
      tone: AppToastTone.success,
    );
    // 退出圈选模式并清空已选点。
    _controller.toggleClipSelectionMode();
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(
      widget.fallbackPath ??
          DesktopRoutes.movieDetail(movieNumber: widget.movieNumber).location,
    );
  }

  Future<void> _showThumbnailActions(int index, Offset globalPosition) async {
    if (index < 0 || index >= _playerState.thumbnails.length) {
      return;
    }
    final thumbnail = _playerState.thumbnails[index];
    final point = await findMediaPointForThumbnail(
      ref: ref,
      thumbnail: thumbnail,
    );
    if (!mounted) {
      return;
    }
    final action = await showAppActionMenu<AppImageActionType>(
      context: context,
      globalPosition: globalPosition,
      items: buildImageActionMenuItems(
        buildMediaThumbnailActionDescriptors(
          l10n: AppLocalizations.of(context),
          showSearchSimilar: ref.read(imageSearchEnabledProvider),
          thumbnail: thumbnail,
          point: point,
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    final fileName =
        'movie_player_${widget.movieNumber}_${thumbnail.thumbnailId}.webp';
    await handleMediaThumbnailAction(
      context: context,
      ref: ref,
      thumbnail: thumbnail,
      action: action,
      point: point,
      fileName: fileName,
      onSearchSimilar: () => launchImageSearchFromUrl(
        context,
        imageUrl: thumbnail.image.origin,
        routePath: widget.imageSearchRoutePath,
        fallbackPath: DesktopRoutes.moviePlayer(
          movieNumber: widget.movieNumber,
          mediaId: _playerState.selectedMedia?.mediaId,
          positionSeconds: _controller.currentPlaybackSeconds,
        ).location,
        fileName: fileName,
        replaceRouteStack: true,
      ),
      onPlay: () async {
        _controller.handleThumbnailTap(index);
        _surfaceController.seekTo(Duration(seconds: thumbnail.offsetSeconds));
        _surfaceController.play();
      },
    );
  }
}

const String moviePlayerUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

Media buildMoviePlayerMedia(String resolvedUrl, {Duration? startPosition}) =>
    Media(
      resolvedUrl,
      start: startPosition,
      httpHeaders: const <String, String>{'User-Agent': moviePlayerUserAgent},
    );

PlayerConfiguration buildMoviePlayerConfiguration({TargetPlatform? platform}) =>
    switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows => const PlayerConfiguration(libass: true),
      _ => const PlayerConfiguration(),
    };

class MoviePlayerSurfaceController {
  final _seekController = StreamController<Duration>.broadcast();
  final _playController = StreamController<void>.broadcast();

  Stream<Duration> get seekStream => _seekController.stream;
  Stream<void> get playStream => _playController.stream;

  void seekTo(Duration position) {
    if (_seekController.isClosed) return;
    _seekController.add(position);
  }

  void play() {
    if (_playController.isClosed) return;
    _playController.add(null);
  }

  void dispose() {
    _seekController.close();
    _playController.close();
  }
}

MoviePlayerMobileSpeedDisplayState _mobileSpeedDisplayState(
  double rate,
  bool hasExplicitSelection,
) => MoviePlayerMobileSpeedDisplayState(
  rate: rate,
  hasExplicitSelection: hasExplicitSelection,
);

class MoviePlayerPlaybackRateCoordinator extends ChangeNotifier {
  MoviePlayerPlaybackRateCoordinator({
    required Future<void> Function(double rate) setRate,
    required double initialRate,
  }) : _setRate = setRate,
       _currentRate = initialRate,
       _mobileSpeedDisplay = ValueNotifier(
         _mobileSpeedDisplayState(initialRate, false),
       );

  final Future<void> Function(double rate) _setRate;
  final ValueNotifier<MoviePlayerMobileSpeedDisplayState> _mobileSpeedDisplay;
  double _currentRate;
  bool _hasExplicitSelection = false;
  double? _pendingRate;

  double get currentRate => _currentRate;
  bool get hasExplicitSelection => _hasExplicitSelection;
  ValueListenable<MoviePlayerMobileSpeedDisplayState> get mobileSpeedDisplay =>
      _mobileSpeedDisplay;

  void onRateStreamEvent(double rate) {
    final pendingRate = _pendingRate;
    if (pendingRate != null && (pendingRate - rate).abs() >= 0.001) {
      return;
    }
    if (pendingRate != null) {
      _pendingRate = null;
    }
    final display = _mobileSpeedDisplay.value;
    if ((display.rate - rate).abs() >= 0.001) {
      _mobileSpeedDisplay.value = _mobileSpeedDisplayState(
        rate,
        display.hasExplicitSelection,
      );
    }
    if ((_currentRate - rate).abs() < 0.001) {
      return;
    }
    _currentRate = rate;
    notifyListeners();
  }

  Future<void> select(double rate) async {
    final previousRate = _currentRate;
    final previousSelection = _hasExplicitSelection;
    _pendingRate = rate;
    _currentRate = rate;
    _hasExplicitSelection = true;
    notifyListeners();
    try {
      await _setRate(rate);
      _pendingRate = null;
    } catch (_) {
      _pendingRate = null;
      _currentRate = previousRate;
      _hasExplicitSelection = previousSelection;
      notifyListeners();
    }
  }

  Future<void> selectFromMobile(double rate) async {
    _mobileSpeedDisplay.value = _mobileSpeedDisplayState(rate, true);
    await select(rate);
    _mobileSpeedDisplay.value = _mobileSpeedDisplayState(
      _currentRate,
      _hasExplicitSelection,
    );
  }

  void resetMobileDisplayForNewMedia(double newInitialRate) {
    _mobileSpeedDisplay.value = _mobileSpeedDisplayState(newInitialRate, false);
  }

  @override
  void dispose() {
    _mobileSpeedDisplay.dispose();
    super.dispose();
  }
}

typedef MoviePlayerSurfaceOpen =
    Future<void> Function(
      String resolvedUrl, {
      required Duration? startPosition,
      required bool play,
    });

Future<int?> applyMoviePlayerSubtitleSelection({
  required Future<void> Function(SubtitleTrack track) setSubtitleTrack,
  required MoviePlayerSubtitleOption? selectedOption,
  required Future<String> Function(MoviePlayerSubtitleOption option)
  loadSubtitleText,
  required VoidCallback onError,
}) async {
  try {
    if (selectedOption == null) {
      await setSubtitleTrack(SubtitleTrack.no());
      return null;
    }
    final subtitleText = await loadSubtitleText(selectedOption);
    await setSubtitleTrack(
      SubtitleTrack.data(
        subtitleText,
        title: selectedOption.title,
        language: selectedOption.language,
      ),
    );
    return selectedOption.subtitleId;
  } catch (_) {
    try {
      await setSubtitleTrack(SubtitleTrack.no());
    } catch (_) {
      // Keep the original failure as the user-visible signal.
    }
    onError();
    return null;
  }
}

Future<void> openMoviePlayerSurface({
  required MoviePlayerSurfaceOpen open,
  required Future<void> Function() play,
  required Future<void> Function(Duration position) seek,
  required Future<void> Function() waitUntilFirstFrameRendered,
  required String resolvedUrl,
  required Duration? initialPosition,
  required bool Function() shouldContinue,
  required VoidCallback markReady,
  Future<void> Function()? waitUntilSeekReady,
}) async {
  final startupPosition =
      initialPosition != null && initialPosition > Duration.zero
      ? initialPosition
      : null;
  await open(
    resolvedUrl,
    startPosition: waitUntilSeekReady == null ? startupPosition : null,
    play: false,
  );
  if (!shouldContinue()) return;
  await play();
  if (!shouldContinue()) return;
  await waitUntilFirstFrameRendered();
  if (!shouldContinue()) return;
  if (waitUntilSeekReady != null) {
    await waitUntilSeekReady();
    if (!shouldContinue()) return;
  }
  if (startupPosition != null) {
    await seek(startupPosition);
    if (!shouldContinue()) return;
  }
  markReady();
}

class MoviePlayerSurface extends ConsumerStatefulWidget {
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
    this.isPortraitOverride,
    this.compactTopControlsOverride,
    this.compactBottomControlsOverride,
    this.useTouchOptimizedControls = false,
    this.mediaInfo,
    this.thumbnails = const <MovieMediaThumbnailDto>[],
    this.disableNativeFullscreen = false,
    this.orientationLock,
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

  /// 播放区实际布局方向。iOS 旋转后 MediaQuery 可能滞后，由宿主按播放区
  /// 约束传入；为空时回退到 MediaQuery。
  final bool? isPortraitOverride;

  /// 顶栏是否使用紧凑布局；为空时回退到 [MediaQuery]。
  final bool? compactTopControlsOverride;

  /// 底栏是否使用紧凑布局；为空时按 [isPortraitOverride] / [MediaQuery] 判断。
  /// 面板展开或窗口很窄时，竖屏判定可能仍不足以及时收窄底栏，由宿主按实际
  /// 播放区宽度显式传入。
  final bool? compactBottomControlsOverride;

  final bool useTouchOptimizedControls;
  final MoviePlayerMediaInfo? mediaInfo;

  /// 带右侧面板的播放页传 `true`：禁用 media_kit 双击进原生全屏路由
  /// （该路由只含 Video，会丢右侧面板），全屏改由应用内状态接管。
  final bool disableNativeFullscreen;

  /// 右侧时间轴面板同一份缩略图，供桌面进度条 hover 预览使用。
  final List<MovieMediaThumbnailDto> thumbnails;

  /// 移动端方向锁状态；顶栏据此显示锁定/跟随切换按钮，全屏进出按当前状态
  /// 应用方向。桌面端不传。
  final PlayerOrientationLock? orientationLock;

  @override
  ConsumerState<MoviePlayerSurface> createState() => _MoviePlayerSurfaceState();
}

class _MoviePlayerSurfaceState extends ConsumerState<MoviePlayerSurface> {
  static final Random _playbackAttemptRandom = Random.secure();

  late final Player _player;
  late final VideoController _controller;
  final ValueNotifier<bool> _isSurfaceReady = ValueNotifier<bool>(false);
  late final MoviePlayerNativeStatsSampler _statsSampler;
  late final ValueNotifier<MoviePlayerSubtitleState> _subtitleStateNotifier;
  late final ValueNotifier<bool> _isApplyingSubtitleNotifier;
  late final MoviePlayerPlaybackRateCoordinator _playbackRate;
  MoviePlayerMobileDrawerType? _activeDrawer;
  bool _isInfoSideOpen = false;
  late final PlayerSystemControls _systemControls;
  bool _systemControlsReady = false;
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

  @override
  void initState() {
    super.initState();
    _player = ThrottlingPlayer(configuration: buildMoviePlayerConfiguration());
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto'),
    );
    _statsSampler = MoviePlayerNativeStatsSampler(
      readNativeProperty: createMediaKitNativePropertyReader(_player),
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
      isSurfaceReady: () => _isSurfaceReady.value,
    );
    _subtitleStateNotifier = ValueNotifier<MoviePlayerSubtitleState>(
      widget.subtitleState,
    );
    _isApplyingSubtitleNotifier = ValueNotifier<bool>(false);
    _playbackRate = MoviePlayerPlaybackRateCoordinator(
      setRate: _player.setRate,
      initialRate: _player.state.rate,
    )..addListener(_handlePlaybackRateChanged);
    _systemControls = PlayerSystemControls();
    _initializeSystemControls();
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
    _trackSubscription = _player.stream.track.listen(_statsSampler.updateTrack);
    _videoParamsSubscription = _player.stream.videoParams.listen(
      _statsSampler.updateVideoParams,
    );
    _audioParamsSubscription = _player.stream.audioParams.listen(
      _statsSampler.updateAudioParams,
    );
    _audioBitrateSubscription = _player.stream.audioBitrate.listen(
      _statsSampler.updateAudioBitrate,
    );
    _rateSubscription = _player.stream.rate.listen(
      _playbackRate.onRateStreamEvent,
    );
    _errorSubscription = _player.stream.error.listen((error) {
      _markPlaybackFailed(error);
    });
    _statsSampler.start();
    unawaited(_openMedia());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 播放信息里的文案跟随界面语言；initState 阶段拿不到 Localizations，
    // 这里补一次注入（同一语言下是同一个实例，不会重复重建快照）。
    _statsSampler.l10n = AppLocalizations.of(context);
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
    if (oldWidget.resolvedUrl != widget.resolvedUrl) {
      _statsSampler.updateContext(originalUrl: widget.resolvedUrl);
      _playbackRate.resetMobileDisplayForNewMedia(_player.state.rate);
      _closeAllMobileDrawers();
      _hasPlaybackError = false;
      unawaited(_openMedia());
    }
    if (oldWidget.resumePosition != widget.resumePosition) {
      if (widget.resumePosition == null) {
        _resumePrompt.cancel();
      } else {
        _resumePrompt.rearm(surfaceReady: _isSurfaceReady.value);
      }
    }
    if (oldWidget.useTouchOptimizedControls &&
        !widget.useTouchOptimizedControls) {
      _closeMobileDrawer();
      _systemControlsReady = true;
    } else if (!oldWidget.useTouchOptimizedControls &&
        widget.useTouchOptimizedControls) {
      _systemControlsReady = false;
      _initializeSystemControls();
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
    _subtitleStateNotifier.dispose();
    _isApplyingSubtitleNotifier.dispose();
    _isSurfaceReady.dispose();
    unawaited(_systemControls.resetBrightness());
    _player.dispose();
    super.dispose();
  }

  void _initializeSystemControls() {
    if (!widget.useTouchOptimizedControls) {
      _systemControlsReady = true;
      return;
    }
    unawaited(
      _systemControls.initialize().whenComplete(() {
        if (!mounted || !widget.useTouchOptimizedControls) {
          return;
        }
        setState(() => _systemControlsReady = true);
      }),
    );
  }

  Future<void> _openMedia() async {
    final requestId = ++_openRequestId;
    final playbackAttemptId = _createPlaybackAttemptId();
    final playbackUrl = withPlaybackAttemptId(
      widget.resolvedUrl,
      playbackAttemptId,
    );
    _statsSampler.reset();
    _startupSeek.begin(widget.initialPosition);
    _pendingInitialSeek = null;
    _resumePrompt.beginSession(
      hasResumePosition: widget.resumePosition != null,
    );
    debugPrint(
      '[player-debug] surface_state_open_media requestId=$requestId url=${widget.resolvedUrl} initialPositionSeconds=${widget.initialPosition?.inSeconds} startupTargetSeconds=${_startupSeek.target?.inSeconds}',
    );
    _isSurfaceReady.value = false;
    await _configureSeekFramedrop();
    if (!mounted || requestId != _openRequestId) {
      return;
    }
    try {
      await openMoviePlayerSurface(
        open: (url, {required startPosition, required play}) => _player.open(
          buildMoviePlayerMedia(url, startPosition: startPosition),
          play: play,
        ),
        play: _player.play,
        seek: _player.seek,
        waitUntilFirstFrameRendered: () =>
            _controller.waitUntilFirstFrameRendered,
        resolvedUrl: playbackUrl,
        initialPosition: widget.initialPosition,
        shouldContinue: () => mounted && requestId == _openRequestId,
        waitUntilSeekReady: () => waitUntilInitialSeekReady(
          firstFrame: _controller.waitUntilFirstFrameRendered,
          positionStream: _player.stream.position,
          currentPosition: () => _player.state.position,
          isPlaying: () => _player.state.playing,
          isBuffering: () => _player.state.buffering,
        ),
        markReady: _markSurfaceReady,
      );
    } catch (error) {
      if (mounted && requestId == _openRequestId) {
        _markPlaybackFailed(error.toString());
      }
      return;
    }
    unawaited(
      _refreshPlaybackMode(
        requestId: requestId,
        playbackAttemptId: playbackAttemptId,
      ),
    );
    unawaited(_statsSampler.refreshNative());
  }

  String _createPlaybackAttemptId() {
    final bytes = List<int>.generate(
      16,
      (_) => _playbackAttemptRandom.nextInt(256),
      growable: false,
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<void> _refreshPlaybackMode({
    required int requestId,
    required String playbackAttemptId,
  }) async {
    final l10n = AppLocalizations.of(context);
    String modeLabel = l10n.widgetMoviePlayerModeUnconfirmed;
    try {
      final response = await ref
          .read(apiClientProvider)
          .get(
            '/media/playback-attempts/$playbackAttemptId',
            receiveTimeout: const Duration(seconds: 5),
          );
      modeLabel = switch (response['mode']) {
        'direct' => l10n.widgetMoviePlayerModeDirect,
        'proxy' => l10n.widgetMoviePlayerModeProxy,
        _ => l10n.widgetMoviePlayerModeUnconfirmed,
      };
    } catch (_) {
      // 播放已成功，模式查询失败不能影响播放器；如实显示未确认。
    }
    if (!mounted || requestId != _openRequestId) {
      return;
    }
    _statsSampler.updatePlaybackModeLabel(modeLabel);
  }

  Future<void> _configureSeekFramedrop() async {
    final platformPlayer = _player.platform;
    if (platformPlayer == null) {
      return;
    }
    try {
      final dynamic nativePlayer = platformPlayer;
      await nativePlayer.setProperty('hr-seek-framedrop', 'yes');
    } catch (_) {}
  }

  void _handleSurfaceSeekRequested(Duration position) {
    _resumePrompt.resolve();
    if (!_isSurfaceReady.value) {
      _pendingInitialSeek = position;
      return;
    }
    unawaited(_player.seek(position));
  }

  void _markSurfaceReady() {
    _isSurfaceReady.value = true;
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
    _closeAllMobileDrawers();
    setState(() {
      _hasPlaybackError = true;
    });
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
      final nextSubtitleId = await applyMoviePlayerSubtitleSelection(
        setSubtitleTrack: _player.setSubtitleTrack,
        selectedOption: selectedOption,
        loadSubtitleText: _loadSubtitleText,
        onError: () {
          if (mounted) {
            showToast(
              AppLocalizations.of(context).widgetMoviePlayerSubtitleLoadFailed,
              tone: AppToastTone.error,
            );
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
    final apiClient = ref.read(apiClientProvider);
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

  void _toggleMobileDrawer(MoviePlayerMobileDrawerType type) {
    _updateMobileDrawers(
      activeDrawer: _activeDrawer == type ? null : type,
      infoSideOpen: false,
    );
  }

  void _closeMobileDrawer() {
    _updateMobileDrawers(activeDrawer: null, infoSideOpen: _isInfoSideOpen);
  }

  void _openInfoSide() {
    _updateMobileDrawers(activeDrawer: null, infoSideOpen: true);
  }

  void _dismissInfoSide() {
    _updateMobileDrawers(activeDrawer: _activeDrawer, infoSideOpen: false);
  }

  void _closeAllMobileDrawers() {
    _updateMobileDrawers(activeDrawer: null, infoSideOpen: false);
  }

  void _updateMobileDrawers({
    required MoviePlayerMobileDrawerType? activeDrawer,
    required bool infoSideOpen,
  }) {
    if (_activeDrawer == activeDrawer && _isInfoSideOpen == infoSideOpen) {
      return;
    }
    setState(() {
      _activeDrawer = activeDrawer;
      _isInfoSideOpen = infoSideOpen;
    });
  }

  Future<void> _handleMobilePlaybackRateSelected(double rate) async {
    _closeMobileDrawer();
    await _playbackRate.selectFromMobile(rate);
  }

  Future<void> _handleMobileSubtitleSelected(int subtitleId) async {
    _closeMobileDrawer();
    await _handleSubtitleSelected(subtitleId);
  }

  Future<void> _toggleInfoSideDrawer() async {
    if (_isInfoSideOpen) {
      _dismissInfoSide();
      return;
    }
    await _statsSampler.refreshNative();
    if (!mounted) {
      return;
    }
    _openInfoSide();
  }

  Future<void> _applyOrientationLock() {
    return applyPlayerOrientationLock(
      locked: widget.orientationLock?.isLocked ?? true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPortrait =
        widget.isPortraitOverride ??
        (MediaQuery.orientationOf(context) == Orientation.portrait);
    final compactBottomControls =
        widget.compactBottomControlsOverride ?? isPortrait;
    final compactTopControls =
        widget.compactTopControlsOverride ??
        (isPortrait || MediaQuery.sizeOf(context).width < 720);
    final topControls = buildMoviePlayerTopControls(
      movieNumber: widget.movieNumber,
      onBackPressed: widget.onBackPressed,
      onInfoPressed: _toggleInfoSideDrawer,
      compact: compactTopControls,
      orientationLock: widget.orientationLock,
    );
    // 全屏路由内拿不到页面级浮层（信息侧栏 / 倍速 / 字幕抽屉都挂在页面 Stack 上），
    // 这些按钮在全屏里点了没反应，全屏态直接去掉。
    final fullscreenTopControls = buildMoviePlayerTopControls(
      movieNumber: widget.movieNumber,
      onBackPressed: widget.onBackPressed,
      compact: compactTopControls,
      orientationLock: widget.orientationLock,
    );
    final mobileBottomControls = buildMoviePlayerMobileBottomControls(
      activeDrawer: _activeDrawer,
      speedDisplayListenable: _playbackRate.mobileSpeedDisplay,
      onSpeedButtonPressed: () =>
          _toggleMobileDrawer(MoviePlayerMobileDrawerType.speed),
      onSubtitleButtonPressed: () =>
          _toggleMobileDrawer(MoviePlayerMobileDrawerType.subtitle),
      compact: compactBottomControls,
    );
    final mobileFullscreenBottomControls = buildMoviePlayerMobileBottomControls(
      activeDrawer: _activeDrawer,
      speedDisplayListenable: _playbackRate.mobileSpeedDisplay,
      onSpeedButtonPressed: () =>
          _toggleMobileDrawer(MoviePlayerMobileDrawerType.speed),
      onSubtitleButtonPressed: () =>
          _toggleMobileDrawer(MoviePlayerMobileDrawerType.subtitle),
      includeDrawerButtons: false,
      compact: compactBottomControls,
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
      controls: resolveMoviePlayerVideoControlsBuilder(
        useTouchOptimizedControls: widget.useTouchOptimizedControls,
        mobileControlsReady: _systemControlsReady,
      ),
      onEnterFullscreen: () async {
        if (!_player.state.playing) {
          await _player.play();
        }
        if (widget.useTouchOptimizedControls) {
          await _applyOrientationLock();
        } else {
          await defaultEnterNativeFullscreen();
        }
      },
      // 移动端退出全屏按当前方向锁状态恢复，避免解锁后被 media_kit 默认回调
      // （清方向锁 + 恢复系统栏）或旧的横屏锁把方向改回去。
      onExitFullscreen: widget.useTouchOptimizedControls
          ? _applyOrientationLock
          : defaultExitNativeFullscreen,
    );
    final playerContent = Stack(
      fit: StackFit.expand,
      children: [
        videoSurface,
        if (_resumePrompt.isVisible && widget.resumePosition != null)
          PlaybackResumePromptOverlay(
            position: widget.resumePosition!,
            onResume: () => _resumePrompt.resume(widget.resumePosition),
            onStartOver: _resumePrompt.resolve,
          ),
        if (widget.useTouchOptimizedControls)
          buildMoviePlayerMobileDrawerOverlay(
            context: context,
            activeDrawer: _activeDrawer,
            subtitleState: widget.subtitleState,
            currentRate: _playbackRate.mobileSpeedDisplay.value.rate,
            isApplyingSubtitleListenable: _isApplyingSubtitleNotifier,
            onDismiss: _closeMobileDrawer,
            onRateSelected: _handleMobilePlaybackRateSelected,
            onSubtitleSelected: _handleMobileSubtitleSelected,
          ),
        buildMoviePlayerInfoSideDrawerOverlay(
          context: context,
          isOpen: _isInfoSideOpen,
          onDismiss: _dismissInfoSide,
          infoListenable: _statsSampler.snapshot,
          mediaInfo: widget.mediaInfo,
        ),
      ],
    );

    // 有可用媒体时页面右侧才有可收起的缩略图面板与右上角常显开关；顶栏需为其让位。
    final reserveTopRightToggle = widget.mediaInfo != null;
    final player = MaterialVideoControlsTheme(
      normal: _mobileControlsTheme(
        theme,
        topControls,
        mobileBottomControls,
        reserveTopRightToggle: reserveTopRightToggle,
      ),
      fullscreen: _mobileControlsTheme(
        theme,
        fullscreenTopControls,
        mobileFullscreenBottomControls,
      ),
      child: MaterialDesktopVideoControlsTheme(
        normal: _desktopControlsTheme(
          theme,
          topControls,
          desktopBottomControls,
          reserveTopRightToggle: reserveTopRightToggle,
        ),
        fullscreen: _desktopControlsTheme(
          theme,
          topControls,
          desktopBottomControls,
        ),
        child: ColoredBox(color: backgroundColor, child: playerContent),
      ),
    );
    final framedPlayer = ValueListenableBuilder<bool>(
      valueListenable: _isSurfaceReady,
      child: player,
      builder: (context, isReady, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            if (!isReady)
              Positioned.fill(
                child: ColoredBox(
                  key: const Key('movie-player-surface-ready-mask'),
                  color: backgroundColor,
                  child: Center(
                    child: VideoLoadingIndicator(
                      label: AppLocalizations.of(
                        context,
                      ).widgetMoviePlayerLoading,
                    ),
                  ),
                ),
              ),
            if (!isReady && widget.onBackPressed != null)
              MoviePlayerBackOverlay(onPressed: widget.onBackPressed!),
          ],
        );
      },
    );
    if (!_hasPlaybackError) {
      return framedPlayer;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        framedPlayer,
        const MoviePlayerPlaybackErrorOverlay(),
        if (widget.onBackPressed case final onBackPressed?)
          MoviePlayerBackOverlay(onPressed: onBackPressed),
      ],
    );
  }

  MaterialDesktopVideoControlsThemeData _desktopControlsTheme(
    ThemeData theme,
    List<Widget> topControls,
    List<Widget> bottomControls, {
    bool reserveTopRightToggle = false,
  }) {
    return buildMoviePlayerDesktopControlsThemeData(
      theme: theme,
      topControls: topControls,
      bottomControls: bottomControls,
      reserveTopRightToggle: reserveTopRightToggle,
      toggleFullscreenOnDoublePress: !widget.disableNativeFullscreen,
      bottomSeekBar: widget.useTouchOptimizedControls
          ? null
          : MoviePlayerSeekBarPreview(
              thumbnails: widget.thumbnails,
              readDuration: () => _player.state.duration,
              seekBar: const MaterialDesktopSeekBar(),
            ),
    );
  }

  MaterialVideoControlsThemeData _mobileControlsTheme(
    ThemeData theme,
    List<Widget> topControls,
    List<Widget> bottomControls, {
    bool reserveTopRightToggle = false,
  }) {
    return buildMoviePlayerMobileControlsThemeData(
      theme: theme,
      systemControls: _systemControls,
      topControls: topControls,
      bottomControls: bottomControls,
      reserveTopRightToggle: reserveTopRightToggle,
    );
  }
}

/// 续播提示状态机(从 `_MoviePlayerSurfaceState` 抽出的引擎件)。
///
/// 语义:媒体始终先从头播放,surface ready 后弹「继续播放?」提示;
/// - 用户点「继续」→ [resume]:seek 到历史位置并 play,完成后回调;
/// - 用户点「从头」/发生外部 seek → [resolve]:收起并回调;
/// - 换片 → [beginSession];resumePosition 被清空 → [cancel](静默收起,**不**回调);
/// - 位置流喂 [onPosition]:检测到用户自行拖动(位移超出正常播放推进)时自动 resolve。
///
/// 状态变化经 [ChangeNotifier] 通知,宿主 State 监听后 setState;
/// 播放命令与回调均构造注入,可纯 Dart 测试。
class MoviePlayerResumePromptCoordinator extends ChangeNotifier {
  MoviePlayerResumePromptCoordinator({
    required Future<void> Function(Duration position) seek,
    required Future<void> Function() play,
    required Duration Function() currentPosition,
    required double Function() playbackRate,
    void Function()? onResolved,
    void Function()? onResumeCompleted,
  }) : _seek = seek,
       _play = play,
       _currentPosition = currentPosition,
       _playbackRate = playbackRate,
       _onResolved = onResolved,
       _onResumeCompleted = onResumeCompleted;

  final Future<void> Function(Duration position) _seek;
  final Future<void> Function() _play;
  final Duration Function() _currentPosition;
  final double Function() _playbackRate;
  final void Function()? _onResolved;
  final void Function()? _onResumeCompleted;

  bool _visible = false;
  bool _resolved = true;
  Duration? _lastPosition;
  DateTime? _lastPositionAt;

  bool get isVisible => _visible;
  bool get isResolved => _resolved;

  /// 开播新媒体:有历史位置则进入「待询问」,否则视为已解决。
  void beginSession({required bool hasResumePosition}) {
    _visible = false;
    _resolved = !hasResumePosition;
    _lastPosition = null;
    _lastPositionAt = null;
    notifyListeners();
  }

  /// resumePosition 被外部清空:静默收起,不触发 onResolved 回调。
  void cancel() {
    _visible = false;
    _resolved = true;
    notifyListeners();
  }

  /// 重新收到历史位置(didUpdateWidget):回到「待询问」;
  /// surface 已 ready 则立即弹出。
  void rearm({required bool surfaceReady}) {
    _resolved = false;
    if (surfaceReady) {
      show();
    } else {
      notifyListeners();
    }
  }

  /// 弹出提示,并记录当前位置作为「用户是否自行拖动」的运动基线。
  void show() {
    _lastPosition = _currentPosition();
    _lastPositionAt = DateTime.now();
    _visible = true;
    notifyListeners();
  }

  /// 位置流探针:提示可见期间,位移明显超出「正常播放推进 + 容差」
  /// (前跳)或回退超 2s,视为用户已自行定位,自动 resolve。
  void onPosition(Duration position) {
    if (!_visible || _resolved) {
      return;
    }
    final previousPosition = _lastPosition;
    final previousAt = _lastPositionAt;
    final now = DateTime.now();
    _lastPosition = position;
    _lastPositionAt = now;
    if (previousPosition == null || previousAt == null) {
      return;
    }
    final elapsedMilliseconds = now.difference(previousAt).inMilliseconds;
    final expectedForwardMilliseconds =
        (elapsedMilliseconds * _playbackRate()).round() + 2000;
    final deltaMilliseconds =
        position.inMilliseconds - previousPosition.inMilliseconds;
    if (deltaMilliseconds < -2000 ||
        deltaMilliseconds > expectedForwardMilliseconds) {
      resolve();
    }
  }

  /// 收起提示并触发 onResolved(幂等)。
  void resolve() {
    if (_resolved) {
      return;
    }
    _resolved = true;
    _visible = false;
    notifyListeners();
    _onResolved?.call();
  }

  /// 用户选择「继续播放」:seek 到历史位置并恢复播放,完成后
  /// 触发 onResumeCompleted(无论 seek 成败)。
  void resume(Duration? position) {
    if (position == null) {
      resolve();
      return;
    }
    _resolved = true;
    _visible = false;
    notifyListeners();
    unawaited(() async {
      try {
        await _seek(position);
        await _play();
      } finally {
        _onResumeCompleted?.call();
      }
    }());
  }
}

/// 起播 seek 重试状态机(从 `_MoviePlayerSurfaceState` 抽出的引擎件)。
///
/// 远程签名直链上 open 时的初始 seek 偶尔被静默吞掉。开播后在
/// [maxWindowMs] 窗口内用位置流探针验证「已接近目标」([minNearSamples]
/// 个连续样本);不达标且过了 [retryDelayMs] 冷却则补发 seek,最多
/// [maxRetries] 次;窗口耗尽放弃。
class MoviePlayerStartupSeekCoordinator {
  MoviePlayerStartupSeekCoordinator({
    required Future<void> Function(Duration position) seek,
    required bool Function() isSurfaceReady,
    DateTime Function()? now,
  }) : _seek = seek,
       _isSurfaceReady = isSurfaceReady,
       _now = now ?? DateTime.now;

  static const int toleranceSeconds = 2;
  static const int retryDelayMs = 800;
  static const int maxWindowMs = 8000;
  static const int maxRetries = 2;
  static const int minNearSamples = 2;

  final Future<void> Function(Duration position) _seek;
  final bool Function() _isSurfaceReady;
  final DateTime Function() _now;

  Duration? _target;
  DateTime? _startedAt;
  bool _settled = true;
  int _retryCount = 0;
  int _nearTargetSamples = 0;

  /// 当前守卫的目标位置(无目标 / 已 settle 时探针不工作)。
  Duration? get target => _target;

  /// 开播新媒体:`initialPosition > 0` 才进入守卫,否则直接 settle。
  void begin(Duration? initialPosition) {
    _target = initialPosition != null && initialPosition > Duration.zero
        ? initialPosition
        : null;
    _startedAt = _now();
    _retryCount = 0;
    _nearTargetSamples = 0;
    _settled = _target == null;
  }

  /// 位置流探针:验证 / 重试 / 放弃。
  void onPosition(Duration currentPosition) {
    final target = _target;
    if (target == null || _settled) {
      return;
    }
    if (!_isSurfaceReady()) {
      return;
    }
    final startedAt = _startedAt;
    if (startedAt == null) {
      _settled = true;
      return;
    }
    final elapsedMs = _now().difference(startedAt).inMilliseconds;
    final currentSeconds = currentPosition.inSeconds;
    final targetSeconds = target.inSeconds;
    final isNearTarget = currentSeconds >= targetSeconds - toleranceSeconds;

    debugPrint(
      '[player-debug] startup_seek_probe currentSeconds=$currentSeconds targetSeconds=$targetSeconds elapsedMs=$elapsedMs retries=$_retryCount nearSamples=$_nearTargetSamples',
    );

    if (isNearTarget) {
      _nearTargetSamples++;
    } else {
      _nearTargetSamples = 0;
    }

    if (_nearTargetSamples >= minNearSamples) {
      _settled = true;
      debugPrint(
        '[player-debug] startup_seek_verified currentSeconds=$currentSeconds targetSeconds=$targetSeconds retries=$_retryCount nearSamples=$_nearTargetSamples',
      );
      return;
    }

    if (elapsedMs >= maxWindowMs) {
      _settled = true;
      debugPrint(
        '[player-debug] startup_seek_give_up reason=window_timeout currentSeconds=$currentSeconds targetSeconds=$targetSeconds retries=$_retryCount',
      );
      return;
    }

    if (elapsedMs < retryDelayMs || _retryCount >= maxRetries) {
      return;
    }

    _retryCount++;
    debugPrint(
      '[player-debug] startup_seek_retry attempt=$_retryCount currentSeconds=$currentSeconds targetSeconds=$targetSeconds',
    );
    unawaited(_seek(target));
  }
}

const double _cardWidth = 176;
const double _cardHeight = _cardWidth * 9 / 16;
const double _cardGap = 6;

/// 桌面进度条的 hover 预览层。
///
/// 包裹 media_kit 的 `MaterialDesktopSeekBar`（由调用方通过 [seekBar] 注入），
/// 鼠标悬停时在光标上方显示时间轴里最近的一帧缩略图；内部不处理拖动/点击，
/// 进度条本体的交互与显隐仍由 media_kit 控件负责。
class MoviePlayerSeekBarPreview extends StatefulWidget {
  const MoviePlayerSeekBarPreview({
    super.key,
    required this.thumbnails,
    required this.readDuration,
    required this.seekBar,
  });

  /// 与右侧时间轴面板同一份缩略图列表（按 offset 升序）。
  final List<MovieMediaThumbnailDto> thumbnails;

  /// 当前媒体总时长；媒体未就绪时返回 [Duration.zero]。
  final Duration Function() readDuration;
  final Widget seekBar;

  @override
  State<MoviePlayerSeekBarPreview> createState() =>
      _MoviePlayerSeekBarPreviewState();
}

class _MoviePlayerSeekBarPreviewState extends State<MoviePlayerSeekBarPreview> {
  static const Duration _switchDelay = Duration(milliseconds: 120);

  Timer? _switchTimer;
  MovieMediaThumbnailDto? _pending;
  MovieMediaThumbnailDto? _preview;
  double _cursorX = 0;

  @override
  void dispose() {
    _switchTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MoviePlayerSeekBarPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.thumbnails, widget.thumbnails)) {
      _switchTimer?.cancel();
      _pending = null;
      _preview = null;
    }
  }

  void _handleHover(double localX, double width) {
    if (width <= 0 || widget.thumbnails.isEmpty) {
      return;
    }
    final duration = widget.readDuration();
    if (duration <= Duration.zero) {
      return;
    }
    final fraction = (localX / width).clamp(0.0, 1.0);
    final targetSeconds = duration.inMilliseconds * fraction / 1000;
    final nearest = _nearestThumbnail(targetSeconds.toDouble());
    _cursorX = localX;
    if (nearest.offsetSeconds == (_preview ?? _pending)?.offsetSeconds) {
      if (_preview != null) {
        setState(() {});
      }
      return;
    }
    _pending = nearest;
    _switchTimer?.cancel();
    _switchTimer = Timer(_switchDelay, () {
      if (!mounted) {
        return;
      }
      setState(() => _preview = _pending);
    });
    if (_preview != null) {
      setState(() {});
    }
  }

  void _handleExit() {
    _switchTimer?.cancel();
    _pending = null;
    if (_preview != null) {
      setState(() => _preview = null);
    }
  }

  MovieMediaThumbnailDto _nearestThumbnail(double targetSeconds) {
    var nearest = widget.thumbnails.first;
    var nearestDistance = (nearest.offsetSeconds - targetSeconds).abs();
    for (final thumbnail in widget.thumbnails.skip(1)) {
      final distance = (thumbnail.offsetSeconds - targetSeconds).abs();
      if (distance < nearestDistance) {
        nearest = thumbnail;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final preview = _preview;
        return MouseRegion(
          onHover: (event) => _handleHover(event.localPosition.dx, width),
          onExit: (_) => _handleExit(),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              widget.seekBar,
              if (preview != null)
                Positioned(
                  top: -(_cardHeight + _cardGap),
                  left: (_cursorX - _cardWidth / 2).clamp(
                    0.0,
                    max(0.0, width - _cardWidth),
                  ),
                  child: IgnorePointer(
                    child: _SeekBarPreviewCard(thumbnail: preview),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SeekBarPreviewCard extends StatelessWidget {
  const _SeekBarPreviewCard({required this.thumbnail});

  final MovieMediaThumbnailDto thumbnail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: theme.appRadius.mdBorder,
        border: Border.all(color: Colors.white24),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black54, blurRadius: 12),
        ],
      ),
      child: ClipRRect(
        borderRadius: theme.appRadius.mdBorder,
        child: SizedBox(
          width: _cardWidth,
          height: _cardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              MaskedImage(
                url: thumbnail.image.origin,
                fit: BoxFit.cover,
                memCacheWidth: (_cardWidth * 2).round(),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: EdgeInsets.all(context.appSpacing.xs),
                  padding: EdgeInsets.symmetric(
                    horizontal: context.appSpacing.xs,
                    vertical: context.appSpacing.xs / 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.66),
                    borderRadius: theme.appRadius.xsBorder,
                  ),
                  child: Text(
                    formatMediaTimecode(thumbnail.offsetSeconds),
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s10,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.onMedia,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MoviePlayerPlaybackErrorOverlay extends StatelessWidget {
  const MoviePlayerPlaybackErrorOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      key: const Key('movie-player-playback-error-overlay'),
      color: context.appColors.movieDetailHeroBackgroundStart,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(context.appSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: context.appComponentTokens.iconSizeLg,
                color: context.appTextPalette.onMedia,
              ),
              SizedBox(height: context.appSpacing.md),
              Text(
                l10n.widgetMoviePlayerPlaybackFailed,
                key: const Key('movie-player-playback-error-title'),
                textAlign: TextAlign.center,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.onMedia,
                ),
              ),
              SizedBox(height: context.appSpacing.sm),
              Text(
                l10n.widgetMoviePlayerPlaybackUnavailable,
                key: const Key('movie-player-playback-error-message'),
                textAlign: TextAlign.center,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  tone: AppTextTone.onMedia,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
