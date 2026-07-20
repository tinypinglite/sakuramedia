import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_episode_queue_item.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_filmstrip_controller.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_play_split_layout.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_playback_mode.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_playback_page_mixin.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/episode_selector_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/merged_position_indicator.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_controls.dart';
import 'package:sakuramedia/widgets/base/media/video/themed_video_player.dart';
import 'package:sakuramedia/widgets/base/media/video/throttling_player.dart';

/// 切片合集连播独立页面：media_kit 播放器（原生 Playlist 自动连播）占满画面，
/// 底部控制条「选集」按钮唤出右侧滑出的剧集面板（当前高亮 / 点击跳转）。
class DesktopClipCollectionPlayPage extends StatefulWidget {
  const DesktopClipCollectionPlayPage({
    super.key,
    required this.collectionId,
    this.startIndex = 0,
    this.useTouchOptimizedControls = false,
  });

  final int collectionId;
  final int startIndex;

  /// 触摸优化控件开关：移动壳传 `true`（点击唤出控制条），桌面默认 `false`（hover 唤出）。
  final bool useTouchOptimizedControls;

  @override
  State<DesktopClipCollectionPlayPage> createState() =>
      _DesktopClipCollectionPlayPageState();
}

class _DesktopClipCollectionPlayPageState
    extends State<DesktopClipCollectionPlayPage>
    with CollectionPlaybackPageMixin<DesktopClipCollectionPlayPage> {
  List<MediaClipDto> _clips = const <MediaClipDto>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.startIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    disposePlayback();
    super.dispose();
  }

  Future<void> _load() async {
    final handoff = context.read<CollectionPlaybackHandoff>();
    final api = context.read<ClipCollectionsApi>();
    final clipsApi = context.read<ClipsApi>();
    final baseUrl = context.read<SessionStore>().baseUrl;
    try {
      // 优先用详情页「交接」来的切片（自带 streamUrl）：详情→连播零额外请求、秒开；
      // 取不到（深链/刷新）才自行并发分页拉全。
      final clips =
          handoff.takeClips(collectionId: widget.collectionId) ??
          await api.getAllCollectionClips(
            collectionId: widget.collectionId,
            pageSize: 50,
          );
      final medias = <Media>[];
      final playableClips = <MediaClipDto>[];
      // 与 playableClips 平行：每集时长（秒），合并模式累加为虚拟总时长 + 反向定位。
      final playableDurations = <int>[];
      // startIndex 基于原始切片顺序；前面有不可播切片被跳过时，索引需重映射到实际
      // 可播列表（与视频连播页 resolvedStartIndex 对齐，否则会起播错位的切片）。
      var resolvedStartIndex = 0;
      for (var i = 0; i < clips.length; i++) {
        if (i == widget.startIndex) {
          resolvedStartIndex = medias.length;
        }
        final clip = clips[i];
        final url = resolveMediaUrl(rawUrl: clip.streamUrl, baseUrl: baseUrl);
        if (url == null || url.isEmpty) {
          continue;
        }
        medias.add(Media(url));
        playableClips.add(clip);
        playableDurations.add(clip.durationSeconds);
      }
      if (!mounted) {
        return;
      }
      if (medias.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '合集内没有可播放的切片';
        });
        return;
      }
      final startIndex = resolvedStartIndex.clamp(0, medias.length - 1);
      final player = ThrottlingPlayer();
      final videoController = VideoController(
        player,
        configuration: const VideoControllerConfiguration(hwdec: 'auto'),
      );
      // 「整部合集」关键帧面板：按可播切片顺序逐集拉关键帧（切片自身时间轴 offset）。
      final clipIds =
          playableClips.map((clip) => clip.clipId).toList(growable: false);
      final filmstrip = CollectionFilmstripController(
        episodeCount: clipIds.length,
        frameLoader: (episodeIndex) async {
          final thumbnails =
              await clipsApi.getClipThumbnails(clipId: clipIds[episodeIndex]);
          return thumbnails
              .map(
                (thumbnail) => (
                  offsetSeconds: thumbnail.offsetSeconds,
                  image: thumbnail.image,
                  // 切片帧无对应 media（时刻基于 media），id 填 0 即不支持「添加时刻」。
                  mediaId: 0,
                  thumbnailId: 0,
                  // 切片缩略图后端暂未返尺寸；面板按 16:9 占位即可（与历史一致）。
                  width: null,
                  height: null,
                ),
              )
              .toList();
        },
      );
      // 详情页弹窗确认的播放形态（一次性 take，深链/刷新无值则回退 playlist）。
      final mode =
          handoff.takeMode(key: 'clip:${widget.collectionId}') ??
          CollectionPlaybackMode.playlist;
      setState(() {
        _clips = playableClips;
        attachPlayback(
          player: player,
          videoController: videoController,
          filmstrip: filmstrip,
          startIndex: startIndex,
          mode: mode,
          episodeDurationsSeconds: List<int>.unmodifiable(playableDurations),
        );
        _isLoading = false;
      });
      // 优先拉起播集的关键帧，当前集高亮立即可用。
      unawaited(filmstrip.start(priorityEpisode: startIndex));
      await player.open(Playlist(medias, index: startIndex));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '合集加载失败，请稍后重试');
      });
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody(context));
  }

  String _currentClipTitle() {
    if (currentIndex < 0 || currentIndex >= _clips.length) {
      return '连播';
    }
    return _clips[currentIndex].displayTitle;
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        child: const Center(
          child: VideoLoadingIndicator(
            key: Key('clip-collection-play-loading'),
          ),
        ),
      );
    }
    if (_errorMessage != null) {
      return wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        child: Center(child: AppEmptyState(message: _errorMessage!)),
      );
    }
    final videoController = this.videoController;
    if (videoController == null) {
      return wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        child: const Center(child: VideoLoadingIndicator()),
      );
    }
    // 左：原沉浸式播放器 + 「选集」浮层（原样保留）；右：「整部合集」关键帧面板。
    return CollectionPlaySplitLayout(
      keyPrefix: 'clip-collection',
      left: Stack(
        children: [
          Positioned.fill(child: _buildPlayerSurface(context, videoController)),
          EpisodeSelectorOverlay(
            isOpen: isEpisodePanelOpen,
            itemCount: _clips.length,
            currentIndex: currentIndex,
            title: '选集 · ${_clips.length}',
            onClose: closeEpisodePanel,
            itemBuilder: (context, index) {
              final clip = _clips[index];
              return CollectionEpisodeQueueItem(
                itemKey: Key('clip-collection-play-queue-item-$index'),
                coverUrl: clip.coverImage?.bestAvailableUrl,
                coverStyle: CollectionQueueCoverStyle.cover,
                title: clip.displayTitle,
                subtitle: formatMediaTimecode(clip.durationSeconds),
                isCurrent: index == currentIndex,
                onTap: () {
                  closeEpisodePanel();
                  jumpTo(index);
                },
              );
            },
          ),
        ],
      ),
      right: buildFilmstripPanel(),
    );
  }

  Widget _buildPlayerSurface(
    BuildContext context,
    VideoController videoController,
  ) {
    // 合并模式：底栏 progressIndicator 接管整段进度条 + 时间显示，
    // 并把 media_kit 自带的 seek bar 关掉（避免两条进度条同时显示）。
    final useMerged =
        playbackMode == CollectionPlaybackMode.merged && player != null;
    final progressIndicator =
        useMerged
            ? MergedPositionIndicator(
              player: player!,
              episodeDurationsSeconds: episodeDurationsSeconds,
              onSeekGlobalSeconds: seekToGlobalSeconds,
            )
            : null;
    return ThemedVideoPlayer(
      videoController: videoController,
      useTouchOptimizedControls: widget.useTouchOptimizedControls,
      videoKey: const Key('clip-collection-play-video'),
      displaySeekBar: !useMerged,
      topControls: buildMoviePlayerTopControls(
        movieNumber: _currentClipTitle(),
        onBackPressed: _handleBack,
      ),
      bottomControls: buildCollectionPlayBottomControls(
        useTouchOptimizedControls: widget.useTouchOptimizedControls,
        onOpenEpisodes: openEpisodePanel,
        progressIndicator: progressIndicator,
      ),
      // 全屏由 media_kit push 独立路由，页面级「选集」浮层不在其内，按钮点了
      // 也看不到——全屏态去掉该按钮，避免死按钮。换集需先退出全屏。
      fullscreenBottomControls: buildCollectionPlayBottomControls(
        useTouchOptimizedControls: widget.useTouchOptimizedControls,
        onOpenEpisodes: openEpisodePanel,
        includeEpisodeButton: false,
        progressIndicator: progressIndicator,
      ),
    );
  }

}
