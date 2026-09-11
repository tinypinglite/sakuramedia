import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/domain/media/media_playback_info_button.dart';
import 'package:sakuramedia/features/shared/presentation/providers/collection_playback_handoff_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/video_collection_episode_actions.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_playback_factory_provider.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_filmstrip_controller.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_play_split_layout.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_playback_page_mixin.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/episode_selector_overlay.dart';
import 'package:sakuramedia/widgets/domain/media/media_thumbnail_action_support.dart';
import 'package:sakuramedia/widgets/domain/media/movie_media_thumbnail_grid.dart';
import 'package:sakuramedia/widgets/domain/movies/player/merged_position_indicator.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_controls.dart';
import 'package:sakuramedia/widgets/base/media/video/themed_video_player.dart';

/// 视频合集连播共享实现：media_kit 播放器（原生 Playlist 自动连播）占满画面，
/// 底部控制条「选集」按钮唤出右侧滑出的剧集面板（当前高亮 / 点击跳转）。
///
/// 与切片合集播放页 [ClipCollectionPlayContent] 对齐（共用 [CollectionPlaybackPageMixin]、
/// 分栏壳与右侧关键帧面板）。区别在于视频成员不自带播放地址，靠后端 `include_play_url`
/// 内联「首个媒体」的签名 url 组装 [Playlist]（切片则自带 streamUrl）；右侧「整部合集」
/// 关键帧面板按成员的 `firstMediaId` 逐集拉缩略图。
class VideoCollectionPlayContent extends ConsumerStatefulWidget {
  const VideoCollectionPlayContent({
    super.key,
    required this.collectionId,
    this.startIndex = 0,
    this.sort,
    this.imageSearchRoutePath = desktopImageSearchPath,
    this.useTouchOptimizedControls = false,
  });

  final int collectionId;
  final int startIndex;

  /// 详情页透传的排序表达式（`field:direction`）；手动顺序为 `null`（按 `position:asc`）。
  final String? sort;
  final String imageSearchRoutePath;

  /// 触摸优化控件开关：移动壳传 `true`（点击唤出控制条），桌面默认 `false`（hover 唤出）。
  final bool useTouchOptimizedControls;

  @override
  ConsumerState<VideoCollectionPlayContent> createState() =>
      _VideoCollectionPlayContentState();
}

class _VideoCollectionPlayContentState
    extends ConsumerState<VideoCollectionPlayContent>
    with CollectionPlaybackPageMixin<VideoCollectionPlayContent> {
  List<VideoItemListItemDto> _videos = const <VideoItemListItemDto>[];
  List<String> _playUrls = <String>[];
  List<int> _collectionItemIds = <int>[];
  final _queueRevision = ValueNotifier<int>(0);
  final _videoKey = GlobalKey<VideoState>();
  OverlayEntry? _playerOverlayEntry;
  int? _mutatingVideoId;
  bool _episodeActionsOpen = false;
  MediaPlaybackInfoController? _playbackInfoController;
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
    _playerOverlayEntry?.remove();
    _playerOverlayEntry?.dispose();
    _queueRevision.dispose();
    _playbackInfoController?.dispose();
    disposePlayback();
    super.dispose();
  }

  Future<void> _load() async {
    final handoff = ref.read(collectionPlaybackHandoffProvider);
    final collectionsApi = ref.read(videoCollectionsApiProvider);
    final mediaApi = ref.read(mediaApiProvider);
    final baseUrl = ref.read(sessionStoreProvider).baseUrl;
    try {
      // 优先用详情页「交接」来的成员（已带播放地址）：常规的「详情页点某集进连播」
      // 路径下零额外请求、秒开。取不到（深链/刷新）才自行并发分页拉全——后端已内联
      // 「首个媒体」播放地址，免去逐集 getVideoDetail 的 N+1 风暴。
      final items =
          handoff.takeVideoItems(
            collectionId: widget.collectionId,
            sort: widget.sort,
          ) ??
          await collectionsApi.getAllCollectionItems(
            collectionId: widget.collectionId,
            sort: widget.sort,
            includePlayUrl: true,
          );
      final playUrls = <String>[];
      final collectionItemIds = <int>[];
      final playableVideos = <VideoItemListItemDto>[];
      // 与 playableVideos 平行：每集「首个媒体」id（可空），供右侧关键帧面板逐集拉缩略图。
      final playableFirstMediaIds = <int?>[];
      // 与 playableVideos 平行：每集时长（秒，来自首条媒体），合并模式累加为虚拟总时长。
      final playableDurations = <int>[];
      // startIndex 基于原始成员顺序；若该项不可播或前面有项被跳过，索引需重新映射到
      // 实际可播列表。记录「即将加入的位置」即可自然落到 startIndex 或其后首个可播项。
      var resolvedStartIndex = 0;
      for (var i = 0; i < items.length; i++) {
        if (i == widget.startIndex) {
          resolvedStartIndex = playUrls.length;
        }
        final rawUrl = items[i].playUrl;
        if (rawUrl == null || rawUrl.isEmpty) {
          // 无媒体/不可播成员（后端 play_url 为空）跳过，索引随重映射自然落位。
          continue;
        }
        final playUrl = resolveMediaUrl(rawUrl: rawUrl, baseUrl: baseUrl);
        if (playUrl == null || playUrl.isEmpty) {
          continue;
        }
        playUrls.add(playUrl);
        playableVideos.add(items[i].video);
        collectionItemIds.add(items[i].itemId);
        playableFirstMediaIds.add(items[i].firstMediaId);
        playableDurations.add(items[i].video.durationSeconds);
      }
      if (!mounted) {
        return;
      }
      if (playUrls.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '合集内没有可播放的视频';
        });
        return;
      }
      final startIndex = resolvedStartIndex.clamp(0, playUrls.length - 1);
      final playback = ref.read(videoCollectionPlaybackFactoryProvider)();
      final player = playback.player;
      final videoController = playback.videoController;
      // 「整部合集」关键帧面板：按可播成员顺序逐集拉「首个媒体」的缩略图（媒体自身时间轴
      // offset，整段从 0 起播）；无媒体的集（firstMediaId 为空）帧段为空、自然跳过。
      final firstMediaIds = List<int?>.unmodifiable(playableFirstMediaIds);
      final filmstrip = CollectionFilmstripController(
        episodeCount: firstMediaIds.length,
        frameLoader: (episodeIndex) async {
          final mediaId = firstMediaIds[episodeIndex];
          if (mediaId == null) {
            return const <
              ({
                int offsetSeconds,
                MovieImageDto image,
                int mediaId,
                int thumbnailId,
                int? width,
                int? height,
              })
            >[];
          }
          final thumbnails = await mediaApi.getMediaThumbnails(
            mediaId: mediaId,
          );
          return thumbnails
              .map(
                (thumbnail) => (
                  offsetSeconds: thumbnail.offsetSeconds,
                  image: thumbnail.image,
                  // 透传真实 id 供右面板「添加时刻」（创建 MediaPoint）。
                  mediaId: thumbnail.mediaId,
                  thumbnailId: thumbnail.thumbnailId,
                  // 媒体分辨率（整组一致；未探测出时为 null），瀑布流面板据此预算 tile 高度。
                  width: thumbnail.width,
                  height: thumbnail.height,
                ),
              )
              .toList();
        },
      );
      final playbackInfoController = MediaPlaybackInfoController(
        player: player,
        readApiClient: () => ref.read(apiClientProvider),
      );
      setState(() {
        _videos = playableVideos;
        _playUrls = playUrls;
        _collectionItemIds = collectionItemIds;
        _playbackInfoController?.dispose();
        _playbackInfoController = playbackInfoController;
        attachPlayback(
          player: player,
          videoController: videoController,
          filmstrip: filmstrip,
          startIndex: startIndex,
          episodeDurationsSeconds: List<int>.unmodifiable(playableDurations),
        );
        _isLoading = false;
      });
      // 优先拉起播集的关键帧，当前集高亮立即可用。
      unawaited(filmstrip.start(priorityEpisode: startIndex));
      await _openPlaylist(player, startIndex);
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

  Future<void> _openPlaylist(Player activePlayer, int index) async {
    if (index < 0 || index >= _playUrls.length) {
      return;
    }
    final sourceUrl = _playUrls[index];
    try {
      await activePlayer.open(
        Playlist(
          _playUrls
              .map((url) => Media(withPlaybackAttemptId(url)))
              .toList(growable: false),
          index: index,
        ),
      );
    } catch (error) {
      if (index >= _playUrls.length || _playUrls[index] != sourceUrl) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = apiErrorMessage(error, fallback: '合集加载失败，请稍后重试');
      });
    }
  }

  Future<void> _showEpisodes() async {
    if (isEpisodePanelOpen || _videos.isEmpty) return;
    final fullscreen = _videoKey.currentState!.isFullscreen();
    final overlayBox =
        Navigator.of(
              context,
              rootNavigator: true,
            ).overlay!.context.findRenderObject()!
            as RenderBox;
    isEpisodePanelOpen = true;
    try {
      // 根浮层兼容全屏路由；窗口态仍限制在播放器分栏内。
      await showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        pageBuilder: (panelContext, _, _) => ValueListenableBuilder<int>(
          valueListenable: _queueRevision,
          builder: (_, revision, child) => StreamBuilder<Playlist>(
            stream: player!.stream.playlist,
            builder: (_, snapshot) => LayoutBuilder(
              builder: (_, constraints) {
                // 在布局阶段读取当前边界，窗口缩放后跟随播放器分栏。
                final playerBox =
                    _videoKey.currentContext!.findRenderObject()! as RenderBox;
                final bounds = fullscreen
                    ? Offset.zero & constraints.biggest
                    : playerBox.localToGlobal(
                            Offset.zero,
                            ancestor: overlayBox,
                          ) &
                          playerBox.size;
                return Stack(
                  children: [
                    Positioned.fromRect(
                      rect: bounds,
                      child: Stack(
                        children: [
                          EpisodeSelectorOverlay(
                            isOpen: true,
                            itemCount: _videos.length,
                            currentIndex: currentIndex,
                            title: '选集 · ${_videos.length}',
                            onClose: () => Navigator.of(panelContext).pop(),
                            itemBuilder: (_, index) =>
                                _buildEpisodeItem(panelContext, index),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    } finally {
      isEpisodePanelOpen = false;
    }
  }

  Widget _buildEpisodeItem(BuildContext panelContext, int index) {
    final video = _videos[index];
    return VideoEpisodeQueueItem(
      key: ValueKey(video.id),
      video: video,
      index: index,
      isCurrent: index == currentIndex,
      isBusy: _mutatingVideoId == video.id,
      onPlay: _mutatingVideoId != null
          ? null
          : () {
              Navigator.of(panelContext).pop();
              jumpTo(index);
            },
      onActions: _mutatingVideoId != null
          ? null
          : (position) => _showEpisodeActions(panelContext, video, position),
    );
  }

  Future<void> _showEpisodeActions(
    BuildContext panelContext,
    VideoItemListItemDto video,
    Offset position,
  ) async {
    if (_episodeActionsOpen || _mutatingVideoId != null) return;
    _episodeActionsOpen = true;
    try {
      final action = await showVideoCollectionEpisodeActions(
        context: panelContext,
        title: video.preferredTitle,
        position: position,
        useTouchOptimizedControls: widget.useTouchOptimizedControls,
      );
      if (!mounted || !panelContext.mounted || action == null) return;
      if (action == VideoCollectionEpisodeAction.delete) {
        await showVideoEpisodeDeleteConfirmation(
          context: panelContext,
          title: video.preferredTitle,
          onConfirm: () => _removeEpisode(video.id, deleteMedia: true),
        );
      } else {
        try {
          await _removeEpisode(video.id, deleteMedia: false);
        } catch (error) {
          if (mounted) showToast(apiErrorMessage(error, fallback: '移出失败，请重试'));
        }
      }
    } finally {
      _episodeActionsOpen = false;
      if (mounted && _videos.isEmpty && panelContext.mounted) {
        Navigator.of(panelContext).pop();
        await _videoKey.currentState?.exitFullscreen();
      }
    }
  }

  Future<void> _removeEpisode(int videoId, {required bool deleteMedia}) async {
    final index = _videos.indexWhere((video) => video.id == videoId);
    if (index < 0 || _mutatingVideoId != null) return;
    final itemId = _collectionItemIds[index];
    final videosApi = ref.read(videosApiProvider);
    final collectionsApi = ref.read(videoCollectionsApiProvider);
    final broadcaster = ref.read(videoMutationEventsProvider.notifier);
    var committed = false;
    _mutatingVideoId = videoId;
    _queueRevision.value++;
    try {
      await removePlaybackEpisode(
        index,
        deleteMedia: deleteMedia,
        persist: () => deleteMedia
            ? videosApi.deleteVideo(videoId)
            : collectionsApi.removeCollectionItem(
                collectionId: widget.collectionId,
                itemId: itemId,
              ),
        onRemoved: () {
          committed = true;
          if (deleteMedia) {
            broadcaster.reportDeleted(videoId);
          } else {
            broadcaster.reportCollectionMembershipChanged(
              videoId: videoId,
              collectionId: widget.collectionId,
              removedFromCollection: true,
            );
          }
          if (!mounted) return;
          _videos.removeAt(index);
          _playUrls.removeAt(index);
          _collectionItemIds.removeAt(index);
        },
      );
      if (mounted) showToast(deleteMedia ? '已删除选集及关联媒体' : '已移出合集，视频仍保留');
    } catch (error) {
      if (!committed) rethrow;
      if (mounted) {
        await player?.stop();
        _errorMessage = '选集已更新，播放队列更新失败，请返回合集重新播放';
        showToast(_errorMessage!);
      }
    } finally {
      _mutatingVideoId = null;
      if (mounted) {
        setState(() {});
        _queueRevision.value++;
      }
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  String _currentVideoTitle() {
    if (currentIndex < 0 || currentIndex >= _videos.length) {
      return '连播';
    }
    return _videos[currentIndex].preferredTitle;
  }

  /// 右键/长按「整部合集」某帧 → 弹与 JAV 播放器一致的图片菜单。
  Future<void> _showThumbnailActions(int index, Offset globalPosition) async {
    final thumbnails =
        filmstrip?.thumbnails ?? const <MovieMediaThumbnailDto>[];
    if (index < 0 || index >= thumbnails.length) {
      return;
    }
    final thumbnail = thumbnails[index];
    if (thumbnail.mediaId <= 0 || thumbnail.thumbnailId <= 0) {
      return;
    }
    final point = await tryFindMediaPointForThumbnail(
      ref: ref,
      thumbnail: thumbnail,
    );
    if (!mounted ||
        _mutatingVideoId != null ||
        !(filmstrip?.thumbnails.any(
              (frame) =>
                  frame.mediaId == thumbnail.mediaId &&
                  frame.thumbnailId == thumbnail.thumbnailId,
            ) ??
            false)) {
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
        'video_collection_${widget.collectionId}_${thumbnail.thumbnailId}.webp';
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
        fileName: fileName,
        replaceRouteStack: true,
      ),
      onPlay: () async {
        seekToFrame(index);
        await player?.play();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        child: const Center(
          child: VideoLoadingIndicator(
            key: Key('video-collection-play-loading'),
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
    // 保留局部 Overlay，让播放信息抽屉仍限制在播放器区域；显式刷新现有 entry。
    _playerOverlayEntry ??= OverlayEntry(
      builder: (overlayContext) => Positioned.fill(
        child: _buildPlayerSurface(overlayContext, videoController),
      ),
    );
    _playerOverlayEntry!.markNeedsBuild();
    // 播放器保持挂载，最后一集移除后也能先关闭全屏路由，再展示空态。
    return CollectionPlaySplitLayout(
      keyPrefix: 'video-collection',
      left: Stack(
        fit: StackFit.expand,
        children: [
          Overlay(initialEntries: [_playerOverlayEntry!]),
          if (_videos.isEmpty)
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppEmptyState(message: '合集内暂无可播放视频'),
                    SizedBox(height: context.appSpacing.lg),
                    AppButton(label: '返回合集', onPressed: _handleBack),
                  ],
                ),
              ),
            ),
        ],
      ),
      right: buildFilmstripPanel(
        onThumbnailMenuRequested: _showThumbnailActions,
        // pornbox 帧自带 width/height（=媒体分辨率），按真实比例瀑布流排版，混合横竖图无两侧留底。
        layout: ThumbnailGridLayout.staggered,
      ),
    );
  }

  Widget _buildPlayerSurface(
    BuildContext context,
    VideoController videoController,
  ) {
    final playbackInfoController = _playbackInfoController!;
    // 全屏会捕获 controls 主题，因此让控件自行订阅队列变更，避免持有旧时长和标题。
    final progressIndicator = ValueListenableBuilder<int>(
      valueListenable: _queueRevision,
      builder: (_, revision, child) => MergedPositionIndicator(
        player: player!,
        episodeDurationsSeconds: episodeDurationsSeconds,
        onSeekGlobalSeconds: seekToGlobalSeconds,
      ),
    );
    return ThemedVideoPlayer(
      videoController: videoController,
      useTouchOptimizedControls: widget.useTouchOptimizedControls,
      guardInitialSeek: true,
      playbackSessionKey: _videos.isEmpty
          ? null
          : _videos[currentIndex.clamp(0, _videos.length - 1)].id,
      videoKey: _videoKey,
      displaySeekBar: false,
      topControls: [
        ...buildMoviePlayerTopControls(
          movieNumber: '',
          onBackPressed: _handleBack,
        ),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: _queueRevision,
            builder: (_, revision, child) => StreamBuilder<Playlist>(
              stream: player!.stream.playlist,
              builder: (_, snapshot) => Text(
                _currentVideoTitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  tone: AppTextTone.onMedia,
                ),
              ),
            ),
          ),
        ),
        Builder(
          builder: (buttonContext) => MoviePlayerInfoButton(
            onPressed: () => playbackInfoController.showLocal(buttonContext),
          ),
        ),
      ],
      bottomControls: buildCollectionPlayBottomControls(
        useTouchOptimizedControls: widget.useTouchOptimizedControls,
        onOpenEpisodes: _showEpisodes,
        progressIndicator: progressIndicator,
      ),
    );
  }
}
