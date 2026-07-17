import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/media/playback_resume_policy.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';
import 'package:sakuramedia/widgets/domain/movies/player/landscape_player_system_ui.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_surface.dart';
import 'package:sakuramedia/widgets/base/media/video/themed_video_player.dart';

/// 移动端单视频全屏横屏播放页：进入锁定横屏沉浸式、退出恢复原方向。
///
/// 与切片不同，视频列表项不含播放地址，需先 `GET /videos/{id}` 解析首个可播 media
/// （与桌面 `video_quick_play_dialog` 一致）；本页放弃缩略图，但保留完整媒体的续播提示
/// 与进度上报。播放控件去掉上一首 / 下一首，对齐切片全屏播放页。
class MobileVideoPlayerPage extends StatefulWidget {
  const MobileVideoPlayerPage({
    super.key,
    required this.videoId,
    required this.title,
  });

  final int videoId;
  final String title;

  @override
  State<MobileVideoPlayerPage> createState() => _MobileVideoPlayerPageState();
}

class _MobileVideoPlayerPageState extends State<MobileVideoPlayerPage> {
  Player? _player;
  VideoController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  Timer? _progressTimer;
  VideosApi? _videosApi;
  int? _mediaId;
  int _currentPlaybackSeconds = 0;
  int? _lastReportedPositionSeconds;
  Duration? _resumePosition;
  bool _isResumeDecisionPending = false;

  @override
  void initState() {
    super.initState();
    unawaited(enterLandscapePlayerSystemUi());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    unawaited(restoreSystemUiAfterLandscapePlayer());
    _progressTimer?.cancel();
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    unawaited(_reportProgressIfNeeded());
    _player?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    final videosApi = context.read<VideosApi>();
    final baseUrl = context.read<SessionStore>().baseUrl;
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
      final player = Player();
      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(hwdec: 'auto'),
      );
      _videosApi = videosApi;
      _mediaId = playable.media.mediaId;
      _currentPlaybackSeconds = 0;
      _lastReportedPositionSeconds = null;
      _resumePosition = resolvePlaybackResumePosition(
        storedPositionSeconds:
            playable.media.progress?.lastPositionSeconds ?? 0,
        durationSeconds: playable.media.durationSeconds,
      );
      _isResumeDecisionPending = _resumePosition != null;
      _positionSubscription = player.stream.position.listen((position) {
        _currentPlaybackSeconds = position.inSeconds;
      });
      _playingSubscription = player.stream.playing.listen(
        _handlePlayingChanged,
      );
      setState(() {
        _isLoading = false;
        _player = player;
        _controller = controller;
      });
      await player.open(Media(playable.url));
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

  /// 从媒体列表挑首个可播放的 url 并解析为绝对地址，无可播放项返回 `null`。
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

  void _handlePlayingChanged(bool playing) {
    _progressTimer?.cancel();
    _progressTimer = null;
    if (!playing) {
      return;
    }
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_reportProgressIfNeeded());
    });
  }

  void _resolveResumePrompt() {
    if (!_isResumeDecisionPending) {
      return;
    }
    setState(() {
      _isResumeDecisionPending = false;
      _resumePosition = null;
    });
  }

  Future<void> _reportProgressIfNeeded() async {
    final videosApi = _videosApi;
    final mediaId = _mediaId;
    final positionSeconds = _currentPlaybackSeconds;
    if (videosApi == null ||
        mediaId == null ||
        _isResumeDecisionPending ||
        positionSeconds <= 0 ||
        positionSeconds == _lastReportedPositionSeconds) {
      return;
    }
    _lastReportedPositionSeconds = positionSeconds;
    try {
      await videosApi.updateMediaProgress(
        mediaId: mediaId,
        positionSeconds: positionSeconds,
      );
    } catch (_) {
      _lastReportedPositionSeconds = null;
    }
  }

  void _handleBack() {
    // 本页用 Navigator.push（rootNavigator）推入、不在 go_router 栈内，
    // 故用 Navigator 自身 pop，而非 go_router 的 context.pop。
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
        backButtonKey: const Key('mobile-video-player-back-button'),
        child: Center(child: AppEmptyState(message: _errorMessage!)),
      );
    }
    final controller = _controller;
    if (_isLoading || controller == null) {
      return wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        backButtonKey: const Key('mobile-video-player-back-button'),
        child: const Center(child: VideoLoadingIndicator()),
      );
    }
    return _buildPlayerSurface(context, controller);
  }

  Widget _buildPlayerSurface(
    BuildContext context,
    VideoController videoController,
  ) {
    final title = widget.title.trim();
    return ThemedVideoPlayer(
      videoController: videoController,
      useTouchOptimizedControls: true,
      guardInitialSeek: true,
      resumePosition: _resumePosition,
      onResumePromptResolved: _resolveResumePrompt,
      videoKey: const Key('mobile-video-player-video'),
      topControls: buildMoviePlayerTopControls(
        movieNumber: title.isEmpty ? '视频' : title,
        onBackPressed: _handleBack,
      ),
      bottomControls: const <Widget>[
        MaterialPlayOrPauseButton(),
        MaterialPositionIndicator(),
        Spacer(),
        MaterialFullscreenButton(),
      ],
    );
  }
}
