import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_episode_queue_item.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_filmstrip_controller.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_play_split_layout.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_playback_mode.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_playback_page_mixin.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/episode_selector_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/merged_position_indicator.dart';
import 'package:sakuramedia/widgets/domain/media/movie_media_thumbnail_grid.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_surface.dart';
import 'package:sakuramedia/widgets/base/media/video/themed_video_player.dart';

/// 视频合集连播独立页面：media_kit 播放器（原生 Playlist 自动连播）占满画面，
/// 底部控制条「选集」按钮唤出右侧滑出的剧集面板（当前高亮 / 点击跳转）。
///
/// 与切片合集播放页 [DesktopClipCollectionPlayPage] 对齐（共用 [CollectionPlaybackPageMixin]、
/// 分栏壳与右侧关键帧面板）。区别在于视频成员不自带播放地址，靠后端 `include_play_url`
/// 内联「首个媒体」的签名 url 组装 [Playlist]（切片则自带 streamUrl）；右侧「整部合集」
/// 关键帧面板按成员的 `firstMediaId` 逐集拉缩略图。
class DesktopVideoCollectionPlayPage extends StatefulWidget {
  const DesktopVideoCollectionPlayPage({
    super.key,
    required this.collectionId,
    this.startIndex = 0,
    this.sort,
    this.useTouchOptimizedControls = false,
  });

  final int collectionId;
  final int startIndex;

  /// 详情页透传的排序表达式（`field:direction`）；手动顺序为 `null`（按 `position:asc`）。
  final String? sort;

  /// 触摸优化控件开关：移动壳传 `true`（点击唤出控制条），桌面默认 `false`（hover 唤出）。
  final bool useTouchOptimizedControls;

  @override
  State<DesktopVideoCollectionPlayPage> createState() =>
      _DesktopVideoCollectionPlayPageState();
}

class _DesktopVideoCollectionPlayPageState
    extends State<DesktopVideoCollectionPlayPage>
    with CollectionPlaybackPageMixin<DesktopVideoCollectionPlayPage> {
  List<VideoItemListItemDto> _videos = const <VideoItemListItemDto>[];
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
    final collectionsApi = context.read<VideoCollectionsApi>();
    final moviesApi = context.read<MoviesApi>();
    final baseUrl = context.read<SessionStore>().baseUrl;
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
      final medias = <Media>[];
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
          resolvedStartIndex = medias.length;
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
        medias.add(Media(playUrl));
        playableVideos.add(items[i].video);
        playableFirstMediaIds.add(items[i].firstMediaId);
        playableDurations.add(items[i].video.durationSeconds);
      }
      if (!mounted) {
        return;
      }
      if (medias.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '合集内没有可播放的视频';
        });
        return;
      }
      final startIndex = resolvedStartIndex.clamp(0, medias.length - 1);
      final player = Player();
      final videoController = VideoController(
        player,
        configuration: const VideoControllerConfiguration(hwdec: 'auto'),
      );
      // 「整部合集」关键帧面板：按可播成员顺序逐集拉「首个媒体」的缩略图（媒体自身时间轴
      // offset，整段从 0 起播）；无媒体的集（firstMediaId 为空）帧段为空、自然跳过。
      final firstMediaIds = List<int?>.unmodifiable(playableFirstMediaIds);
      final filmstrip = CollectionFilmstripController(
        episodeCount: firstMediaIds.length,
        frameLoader: (episodeIndex) async {
          final mediaId = firstMediaIds[episodeIndex];
          if (mediaId == null) {
            return const <({
              int offsetSeconds,
              MovieImageDto image,
              int mediaId,
              int thumbnailId,
              int? width,
              int? height,
            })>[];
          }
          final thumbnails = await moviesApi.getMediaThumbnails(mediaId: mediaId);
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
      // 详情页弹窗确认的播放形态（一次性 take，深链/刷新无值则回退 playlist）。
      // key 含 sort 以与 items 信箱一致，详情页同一合集换排序后选择不会串。
      final mode =
          handoff.takeMode(
            key: 'video:${widget.collectionId}:${widget.sort ?? ''}',
          ) ??
          CollectionPlaybackMode.playlist;
      setState(() {
        _videos = playableVideos;
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

  String _currentVideoTitle() {
    if (currentIndex < 0 || currentIndex >= _videos.length) {
      return '连播';
    }
    return _videos[currentIndex].preferredTitle;
  }

  /// 右键/长按「整部合集」某帧 → 弹「添加/删除时刻」菜单（桌面定位弹窗、移动底部抽屉）。
  /// 时刻即 MediaPoint，故仅 pornbox（每帧带真实 media/thumbnail id）支持；无媒体的帧静默忽略。
  Future<void> _showThumbnailActions(int index, Offset globalPosition) async {
    final thumbnails = filmstrip?.thumbnails ?? const <MovieMediaThumbnailDto>[];
    if (index < 0 || index >= thumbnails.length) {
      return;
    }
    final thumbnail = thumbnails[index];
    if (thumbnail.mediaId <= 0 || thumbnail.thumbnailId <= 0) {
      return;
    }
    final mediaApi = context.read<MediaApi>();
    // 先查该帧是否已是时刻，决定菜单展示「添加」还是「删除」。
    final existingPoint = await _findMatchingPoint(mediaApi, thumbnail);
    if (!mounted) {
      return;
    }
    final action = await showAppImageActionMenu(
      context: context,
      actions: <AppImageActionDescriptor>[
        AppImageActionDescriptor(
          type: AppImageActionType.toggleMark,
          label: existingPoint == null ? '添加时刻' : '删除时刻',
          icon:
              existingPoint == null
                  ? Icons.bookmark_add_outlined
                  : Icons.bookmark_remove_outlined,
          destructive: existingPoint != null,
        ),
      ],
      globalPosition: globalPosition,
      // 触摸端用底部抽屉、桌面用定位弹窗，对齐图片菜单的两端范式。
      presentation:
          widget.useTouchOptimizedControls
              ? AppImageActionMenuPresentation.bottomDrawer
              : AppImageActionMenuPresentation.popup,
    );
    if (!mounted || action != AppImageActionType.toggleMark) {
      return;
    }
    try {
      if (existingPoint == null) {
        await mediaApi.createMediaPoint(
          mediaId: thumbnail.mediaId,
          thumbnailId: thumbnail.thumbnailId,
        );
        if (mounted) showToast('已添加时刻');
      } else {
        await mediaApi.deleteMediaPoint(
          mediaId: thumbnail.mediaId,
          pointId: existingPoint.pointId,
        );
        if (mounted) showToast('已删除时刻');
      }
    } catch (_) {
      if (mounted) showToast('更新时刻失败，请稍后重试');
    }
  }

  /// 与 jav 播放器 `_loadMatchingPoint` 同构（有意各写一份：jav 菜单含
  /// 相似图片/保存/播放 + 失败抛出，本页只 toggleMark + 失败静默）。
  Future<MediaPointDto?> _findMatchingPoint(
    MediaApi mediaApi,
    MovieMediaThumbnailDto thumbnail,
  ) async {
    try {
      final points = await mediaApi.getMediaPoints(mediaId: thumbnail.mediaId);
      for (final point in points) {
        if (point.thumbnailId == thumbnail.thumbnailId) {
          return point;
        }
      }
    } catch (_) {
      // 查询失败按「未标记」处理：菜单仍可点「添加时刻」，由创建接口兜底报错。
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(context),
    );
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
    // 左：原沉浸式播放器 + 「选集」浮层（原样保留）；右：「整部合集」关键帧面板。
    return CollectionPlaySplitLayout(
      keyPrefix: 'video-collection',
      left: Stack(
        children: [
          Positioned.fill(child: _buildPlayerSurface(context, videoController)),
          EpisodeSelectorOverlay(
            isOpen: isEpisodePanelOpen,
            itemCount: _videos.length,
            currentIndex: currentIndex,
            title: '选集 · ${_videos.length}',
            onClose: closeEpisodePanel,
            itemBuilder: (context, index) {
              final video = _videos[index];
              return CollectionEpisodeQueueItem(
                itemKey: Key('video-collection-play-queue-item-$index'),
                coverUrl: video.coverImage?.bestAvailableUrl,
                coverStyle: CollectionQueueCoverStyle.containOnMuted,
                title: video.preferredTitle,
                subtitle: '第 ${index + 1} 集',
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
      guardInitialSeek: true,
      videoKey: const Key('video-collection-play-video'),
      displaySeekBar: !useMerged,
      topControls: buildMoviePlayerTopControls(
        movieNumber: _currentVideoTitle(),
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
