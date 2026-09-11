import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/core/media/media_playback_progress_controller.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/media/playback_resume_policy.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/base/media/video/themed_video_player.dart';
import 'package:sakuramedia/widgets/base/media/video/throttling_player.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_play_split_layout.dart';
import 'package:sakuramedia/widgets/domain/media/media_playback_info_button.dart';
import 'package:sakuramedia/widgets/domain/media/media_thumbnail_action_support.dart';
import 'package:sakuramedia/widgets/domain/media/movie_player_thumbnail_panel.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_controls.dart';

class VideoPlayerContent extends ConsumerStatefulWidget {
  const VideoPlayerContent({
    super.key,
    required this.videoId,
    this.initialTitle,
    this.fallbackPath,
    this.initialPositionSeconds,
    this.imageSearchRoutePath = desktopImageSearchPath,
    this.useTouchOptimizedControls = false,
  });

  final int videoId;
  final String? initialTitle;
  final String? fallbackPath;
  final int? initialPositionSeconds;
  final String imageSearchRoutePath;
  final bool useTouchOptimizedControls;

  @override
  ConsumerState<VideoPlayerContent> createState() => _VideoPlayerContentState();
}

class _VideoPlayerContentState extends ConsumerState<VideoPlayerContent> {
  final ValueNotifier<int?> _activeThumbnailIndex = ValueNotifier<int?>(null);

  late final MediaPlaybackProgressController _progressController;
  Player? _player;
  VideoController? _controller;
  MovieMediaItemDto? _media;
  List<MovieMediaThumbnailDto> _thumbnails = const <MovieMediaThumbnailDto>[];
  String _title = '视频';
  bool _isLoading = true;
  String? _errorMessage;
  bool _isThumbnailLoading = false;
  String? _thumbnailErrorMessage;
  bool _isThumbnailScrollLocked = true;
  bool _hasManualThumbnailColumnOverride = false;
  int? _thumbnailColumns;
  int _thumbnailRequestVersion = 0;
  Duration? _resumePosition;
  bool _isResumeDecisionPending = false;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;

  @override
  void initState() {
    super.initState();
    _progressController = MediaPlaybackProgressController(
      reportProgress: ({required mediaId, required positionSeconds}) async {
        await ref
            .read(mediaApiProvider)
            .updateMediaProgress(
              mediaId: mediaId,
              positionSeconds: positionSeconds,
            );
      },
      resolveMediaId: () => _media?.mediaId,
      shouldDeferReport: () => _isResumeDecisionPending,
    );
    final initialTitle = widget.initialTitle?.trim();
    if (initialTitle != null && initialTitle.isNotEmpty) {
      _title = initialTitle;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _thumbnailRequestVersion++;
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    unawaited(_progressController.flush());
    _progressController.dispose();
    _activeThumbnailIndex.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    final videosApi = ref.read(videosApiProvider);
    final mediaApi = ref.read(mediaApiProvider);
    final baseUrl = ref.read(sessionStoreProvider).baseUrl;
    try {
      final detail = await videosApi.getVideoDetail(videoId: widget.videoId);
      if (!mounted) {
        return;
      }
      final playable = _resolvePlayableMedia(detail.mediaItems, baseUrl);
      if (playable == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '暂无可播放的媒体';
        });
        return;
      }

      final player = ThrottlingPlayer();
      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(hwdec: 'auto'),
      );
      _media = playable.media;
      _title = detail.preferredTitle;
      _progressController.reset();
      final initialPositionSeconds = widget.initialPositionSeconds;
      if (initialPositionSeconds != null && initialPositionSeconds >= 0) {
        _resumePosition = null;
        _isResumeDecisionPending = false;
      } else {
        _resumePosition = resolvePlaybackResumePosition(
          storedPositionSeconds:
              playable.media.progress?.lastPositionSeconds ?? 0,
          durationSeconds: playable.media.durationSeconds,
        );
        _isResumeDecisionPending = _resumePosition != null;
      }
      _positionSubscription = player.stream.position.listen(
        _handlePlaybackPosition,
      );
      _playingSubscription = player.stream.playing.listen(
        _handlePlayingChanged,
      );
      setState(() {
        _isLoading = false;
        _isThumbnailLoading = true;
        _player = player;
        _controller = controller;
      });
      unawaited(_loadThumbnails(mediaApi, playable.media.mediaId));
      await _openMedia(player, playable.url);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '加载失败，请重试');
      });
    }
  }

  Future<void> _openMedia(Player player, String url) async {
    try {
      await player.open(Media(withPlaybackAttemptId(url)));
      final initialPositionSeconds = widget.initialPositionSeconds;
      if (initialPositionSeconds != null && initialPositionSeconds > 0) {
        await player.seek(Duration(seconds: initialPositionSeconds));
      }
    } catch (error) {
      _showPlaybackError(error);
    }
  }

  Future<void> _loadThumbnails(MediaApi mediaApi, int mediaId) async {
    final requestVersion = ++_thumbnailRequestVersion;
    if (mounted) {
      setState(() {
        _isThumbnailLoading = true;
        _thumbnailErrorMessage = null;
      });
    }
    try {
      final thumbnails = await mediaApi.getMediaThumbnails(mediaId: mediaId);
      if (!mounted || requestVersion != _thumbnailRequestVersion) {
        return;
      }
      setState(() {
        _thumbnails = thumbnails;
        _isThumbnailLoading = false;
      });
      _updateActiveThumbnailIndex();
    } catch (error) {
      if (!mounted || requestVersion != _thumbnailRequestVersion) {
        return;
      }
      setState(() {
        _thumbnails = const <MovieMediaThumbnailDto>[];
        _isThumbnailLoading = false;
        _thumbnailErrorMessage = apiErrorMessage(error, fallback: '请稍后重试。');
      });
      _setActiveThumbnailIndex(null);
    }
  }

  ({MovieMediaItemDto media, String url})? _resolvePlayableMedia(
    List<MovieMediaItemDto> mediaItems,
    String? baseUrl,
  ) {
    for (final media in mediaItems) {
      if (!media.hasPlayableUrl) {
        continue;
      }
      final url = resolveMediaUrl(
        rawUrl: media.playUrl,
        baseUrl: baseUrl ?? '',
      );
      if (url != null && url.isNotEmpty) {
        return (media: media, url: url);
      }
    }
    return null;
  }

  void _showPlaybackError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = apiErrorMessage(error, fallback: '加载失败，请重试');
    });
  }

  void _handlePlaybackPosition(Duration position) {
    final previousSeconds = _progressController.currentPlaybackSeconds;
    _progressController.handlePlaybackPosition(position);
    if (previousSeconds == _progressController.currentPlaybackSeconds) {
      return;
    }
    _updateActiveThumbnailIndex();
  }

  void _handlePlayingChanged(bool playing) {
    _progressController.handlePlaybackPlayingChanged(playing);
  }

  void _resolveResumePrompt() {
    if (!_isResumeDecisionPending || !mounted) {
      return;
    }
    setState(() {
      _isResumeDecisionPending = false;
      _resumePosition = null;
    });
  }

  void _updateActiveThumbnailIndex() {
    if (_thumbnails.isEmpty) {
      _setActiveThumbnailIndex(null);
      return;
    }
    var candidate = 0;
    for (var index = 0; index < _thumbnails.length; index++) {
      if (_thumbnails[index].offsetSeconds <=
          _progressController.currentPlaybackSeconds) {
        candidate = index;
        continue;
      }
      break;
    }
    _setActiveThumbnailIndex(candidate);
  }

  void _setActiveThumbnailIndex(int? index) {
    if (_activeThumbnailIndex.value != index) {
      _activeThumbnailIndex.value = index;
    }
  }

  void _handleThumbnailTap(int index) {
    if (index < 0 || index >= _thumbnails.length || _player == null) {
      return;
    }
    final seconds = _thumbnails[index].offsetSeconds;
    _progressController.setCurrentPlaybackSeconds(seconds);
    _setActiveThumbnailIndex(index);
    unawaited(_player!.seek(Duration(seconds: seconds)));
  }

  void _applyAutoThumbnailColumns(int columns) {
    if (!mounted || _hasManualThumbnailColumnOverride) {
      return;
    }
    if (_thumbnailColumns != columns) {
      setState(() => _thumbnailColumns = columns);
    }
  }

  void _setThumbnailColumns(int columns) {
    setState(() {
      _thumbnailColumns = columns;
      _hasManualThumbnailColumnOverride = true;
    });
  }

  void _toggleThumbnailScrollLock() {
    setState(() => _isThumbnailScrollLocked = !_isThumbnailScrollLocked);
  }

  void _retryThumbnails() {
    final mediaId = _media?.mediaId;
    if (mediaId == null) {
      return;
    }
    unawaited(_loadThumbnails(ref.read(mediaApiProvider), mediaId));
  }

  Future<void> _showThumbnailActions(int index, Offset globalPosition) async {
    if (index < 0 || index >= _thumbnails.length) {
      return;
    }
    final thumbnail = _thumbnails[index];
    final point = await findMediaPointForThumbnail(
      ref: ref,
      thumbnail: thumbnail,
    );
    if (!mounted) {
      return;
    }
    final action = await showAppImageActionMenu(
      context: context,
      actions: buildMediaThumbnailActionDescriptors(
        thumbnail: thumbnail,
        point: point,
      ),
      globalPosition: globalPosition,
      presentation: AppImageActionMenuPresentation.auto,
    );
    if (!mounted || action == null) {
      return;
    }
    final fileName =
        'video_player_${widget.videoId}_${thumbnail.thumbnailId}.webp';
    await handleMediaThumbnailAction(
      context: context,
      ref: ref,
      thumbnail: thumbnail,
      action: action,
      point: point,
      fileName: fileName,
      onSearchSimilar: () => launchImageSearchFromUrl(
        context,
        imageUrl: thumbnail.image.resolvedUrl,
        routePath: widget.imageSearchRoutePath,
        fallbackPath: widget.fallbackPath,
        fileName: fileName,
        replaceRouteStack: true,
      ),
      onPlay: () async {
        _handleThumbnailTap(index);
        await _player?.play();
      },
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final fallbackPath = widget.fallbackPath;
    if (fallbackPath != null && fallbackPath.isNotEmpty) {
      context.go(fallbackPath);
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    if (_errorMessage != null) {
      return wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        backButtonKey: const Key('video-player-back-button'),
        child: Center(child: AppEmptyState(message: _errorMessage!)),
      );
    }
    final controller = _controller;
    if (_isLoading || controller == null) {
      return wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        backButtonKey: const Key('video-player-back-button'),
        child: const Center(child: VideoLoadingIndicator()),
      );
    }

    return CollectionPlaySplitLayout(
      keyPrefix: 'video-single',
      left: _buildPlayerSurface(controller),
      right: _buildThumbnailPanel(),
    );
  }

  Widget _buildPlayerSurface(VideoController videoController) {
    final title = _title.trim();
    final bottomControls = <Widget>[
      const MaterialPlayOrPauseButton(),
      if (!widget.useTouchOptimizedControls)
        const MaterialDesktopVolumeButton(),
      const MaterialPositionIndicator(),
      const Spacer(),
      const MaterialFullscreenButton(),
    ];
    return ThemedVideoPlayer(
      videoController: videoController,
      useTouchOptimizedControls: widget.useTouchOptimizedControls,
      guardInitialSeek: true,
      resumePosition: _resumePosition,
      onResumePromptResolved: _resolveResumePrompt,
      playbackSessionKey: widget.videoId,
      videoKey: const Key('video-player-video'),
      topControls: [
        ...buildMoviePlayerTopControls(
          movieNumber: title.isEmpty ? '视频' : title,
          onBackPressed: _handleBack,
        ),
        const Spacer(),
        MediaPlaybackInfoButton(player: videoController.player),
      ],
      bottomControls: bottomControls,
    );
  }

  Widget _buildThumbnailPanel() {
    return ValueListenableBuilder<int?>(
      valueListenable: _activeThumbnailIndex,
      builder: (context, activeIndex, child) {
        return MoviePlayerThumbnailPanel(
          thumbnails: _thumbnails,
          isLoading: _isThumbnailLoading,
          errorMessage: _thumbnailErrorMessage,
          columns: _thumbnailColumns,
          activeIndex: activeIndex,
          isScrollLocked: _isThumbnailScrollLocked,
          usesAutoColumns: !_hasManualThumbnailColumnOverride,
          onAutoColumnsResolved: _applyAutoThumbnailColumns,
          onColumnsChanged: _setThumbnailColumns,
          onToggleScrollLock: _toggleThumbnailScrollLock,
          onThumbnailTap: _handleThumbnailTap,
          onThumbnailMenuRequested: _showThumbnailActions,
          onRetry: _retryThumbnails,
        );
      },
    );
  }
}
