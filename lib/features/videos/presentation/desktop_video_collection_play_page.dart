import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/movie_player/collection_filmstrip_controller.dart';
import 'package:sakuramedia/widgets/movie_player/collection_play_split_layout.dart';
import 'package:sakuramedia/widgets/movie_player/collection_playback_page_mixin.dart';
import 'package:sakuramedia/widgets/movie_player/episode_selector_overlay.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface.dart';
import 'package:sakuramedia/widgets/movie_player/themed_video_player.dart';

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
  bool _isEpisodePanelOpen = false;

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
            return const <({int offsetSeconds, MovieImageDto image})>[];
          }
          final thumbnails = await moviesApi.getMediaThumbnails(mediaId: mediaId);
          return thumbnails
              .map(
                (thumbnail) => (
                  offsetSeconds: thumbnail.offsetSeconds,
                  image: thumbnail.image,
                ),
              )
              .toList();
        },
      );
      setState(() {
        _videos = playableVideos;
        attachPlayback(
          player: player,
          videoController: videoController,
          filmstrip: filmstrip,
          startIndex: startIndex,
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
          child: SizedBox(
            key: Key('video-collection-play-loading'),
            width: 40,
            height: 40,
            child: CircularProgressIndicator(),
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
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    // 左：原沉浸式播放器 + 「选集」浮层（原样保留）；右：「整部合集」关键帧面板。
    return CollectionPlaySplitLayout(
      keyPrefix: 'video-collection',
      left: Stack(
        children: [
          Positioned.fill(child: _buildPlayerSurface(context, videoController)),
          EpisodeSelectorOverlay(
            isOpen: _isEpisodePanelOpen,
            itemCount: _videos.length,
            currentIndex: currentIndex,
            title: '选集 · ${_videos.length}',
            onClose: _closeEpisodePanel,
            itemBuilder: (context, index) {
              return _QueueItem(
                video: _videos[index],
                index: index,
                isCurrent: index == currentIndex,
                onTap: () {
                  _closeEpisodePanel();
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
    return ThemedVideoPlayer(
      videoController: videoController,
      useTouchOptimizedControls: widget.useTouchOptimizedControls,
      videoKey: const Key('video-collection-play-video'),
      topControls: buildMoviePlayerTopControls(
        movieNumber: _currentVideoTitle(),
        onBackPressed: _handleBack,
      ),
      bottomControls: buildCollectionPlayBottomControls(
        useTouchOptimizedControls: widget.useTouchOptimizedControls,
        onOpenEpisodes: _openEpisodePanel,
      ),
      // 全屏由 media_kit push 独立路由，页面级「选集」浮层不在其内，按钮点了
      // 也看不到——全屏态去掉该按钮，避免死按钮。换集需先退出全屏。
      fullscreenBottomControls: buildCollectionPlayBottomControls(
        useTouchOptimizedControls: widget.useTouchOptimizedControls,
        onOpenEpisodes: _openEpisodePanel,
        includeEpisodeButton: false,
      ),
    );
  }

  void _openEpisodePanel() {
    setState(() => _isEpisodePanelOpen = true);
  }

  void _closeEpisodePanel() {
    if (!_isEpisodePanelOpen) {
      return;
    }
    setState(() => _isEpisodePanelOpen = false);
  }
}

class _QueueItem extends StatelessWidget {
  const _QueueItem({
    required this.video,
    required this.index,
    required this.isCurrent,
    required this.onTap,
  });

  final VideoItemListItemDto video;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final coverUrl = video.coverImage?.bestAvailableUrl;
    return Material(
      color: isCurrent ? colors.surfaceMuted : Colors.transparent,
      borderRadius: context.appRadius.smBorder,
      child: InkWell(
        key: Key('video-collection-play-queue-item-$index'),
        borderRadius: context.appRadius.smBorder,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(spacing.xs),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: context.appRadius.xsBorder,
                child: SizedBox(
                  width: 88,
                  // pornbox 视频不一定横屏：缩略图按 contain 完整居中、两侧留底，不裁切。
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ColoredBox(
                      color: colors.surfaceMuted,
                      child:
                          coverUrl != null && coverUrl.isNotEmpty
                              ? MaskedImage(url: coverUrl, fit: BoxFit.contain)
                              : null,
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.preferredTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight:
                            isCurrent
                                ? AppTextWeight.semibold
                                : AppTextWeight.regular,
                        tone:
                            isCurrent
                                ? AppTextTone.primary
                                : AppTextTone.secondary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      '第 ${index + 1} 集',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Padding(
                  padding: EdgeInsets.only(left: spacing.xs),
                  child: Icon(
                    Icons.equalizer_rounded,
                    size: context.appComponentTokens.iconSizeSm,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
