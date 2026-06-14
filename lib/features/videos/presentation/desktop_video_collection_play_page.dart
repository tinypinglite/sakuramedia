import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface.dart';

/// 视频合集连播独立页面：左侧 media_kit 播放器（原生 Playlist 自动连播），
/// 右侧视频队列（当前高亮 / 点击跳转）。
///
/// 与切片合集播放页 [DesktopClipCollectionPlayPage] 对齐。区别在于视频成员只携带
/// 概要信息（无播放地址），需先逐集 `getVideoDetail` 解析首选可播 media 的 url 才能
/// 组装 [Playlist]；故此页放弃单集进度上报与缩略图 seek，单集全功能播放仍走视频详情页。
class DesktopVideoCollectionPlayPage extends StatefulWidget {
  const DesktopVideoCollectionPlayPage({
    super.key,
    required this.collectionId,
    this.startIndex = 0,
    this.sort,
  });

  final int collectionId;
  final int startIndex;

  /// 详情页透传的排序表达式（`field:direction`）；手动顺序为 `null`（按 `position:asc`）。
  final String? sort;

  @override
  State<DesktopVideoCollectionPlayPage> createState() =>
      _DesktopVideoCollectionPlayPageState();
}

class _DesktopVideoCollectionPlayPageState
    extends State<DesktopVideoCollectionPlayPage> {
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<Playlist>? _playlistSub;

  List<VideoItemListItemDto> _videos = const <VideoItemListItemDto>[];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _playlistSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final collectionsApi = context.read<VideoCollectionsApi>();
    final videosApi = context.read<VideosApi>();
    final baseUrl = context.read<SessionStore>().baseUrl;
    try {
      final items = await collectionsApi.getCollectionItems(
        collectionId: widget.collectionId,
        sort: widget.sort,
      );
      // 成员仅含概要，需逐集拉详情解析首选可播 media 的 url；并发拉取，失败的成员跳过。
      final details = await Future.wait(
        items.map((item) async {
          try {
            return await videosApi.getVideoDetail(videoId: item.video.id);
          } catch (_) {
            return null;
          }
        }),
      );
      final medias = <Media>[];
      final playableVideos = <VideoItemListItemDto>[];
      // startIndex 基于原始成员顺序；若该项不可播或前面有项被跳过，索引需重新映射到
      // 实际可播列表。记录「即将加入的位置」即可自然落到 startIndex 或其后首个可播项。
      var resolvedStartIndex = 0;
      for (var i = 0; i < items.length; i++) {
        if (i == widget.startIndex) {
          resolvedStartIndex = medias.length;
        }
        final detail = details[i];
        if (detail == null) {
          continue;
        }
        final playUrl = _resolvePlayableUrl(detail.mediaItems, baseUrl);
        if (playUrl == null) {
          continue;
        }
        medias.add(Media(playUrl));
        playableVideos.add(items[i].video);
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
      _playlistSub = player.stream.playlist.listen((playlist) {
        if (mounted && playlist.index != _currentIndex) {
          setState(() => _currentIndex = playlist.index);
        }
      });
      setState(() {
        _videos = playableVideos;
        _player = player;
        _videoController = videoController;
        _currentIndex = startIndex;
        _isLoading = false;
      });
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

  /// 从媒体列表挑首个可播放的 url 并解析为绝对地址，无可播放项返回 `null`。
  String? _resolvePlayableUrl(
    List<MovieMediaItemDto> mediaItems,
    String? baseUrl,
  ) {
    for (final media in mediaItems) {
      if (!media.hasPlayableUrl) {
        continue;
      }
      final url = resolveMediaUrl(rawUrl: media.playUrl, baseUrl: baseUrl ?? '');
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    return null;
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _jumpTo(int index) async {
    final player = _player;
    if (player == null) {
      return;
    }
    await player.jump(index);
  }

  String _currentVideoTitle() {
    if (_currentIndex < 0 || _currentIndex >= _videos.length) {
      return '连播';
    }
    return _videos[_currentIndex].preferredTitle;
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
      return const Center(
        child: SizedBox(
          key: Key('video-collection-play-loading'),
          width: 40,
          height: 40,
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(child: AppEmptyState(message: _errorMessage!));
    }
    final videoController = _videoController;
    if (videoController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildPlayerSurface(context, videoController)),
        _buildQueue(context),
      ],
    );
  }

  Widget _buildPlayerSurface(
    BuildContext context,
    VideoController videoController,
  ) {
    final theme = Theme.of(context);
    final topControls = buildMoviePlayerTopControls(
      movieNumber: _currentVideoTitle(),
      onBackPressed: _handleBack,
    );
    final desktopThemeData = buildMoviePlayerDesktopControlsThemeData(
      theme: theme,
      topControls: topControls,
      bottomControls: const <Widget>[
        MaterialDesktopSkipPreviousButton(),
        MaterialPlayOrPauseButton(),
        MaterialDesktopSkipNextButton(),
        MaterialDesktopVolumeButton(),
        MaterialPositionIndicator(),
        Spacer(),
        MaterialFullscreenButton(),
      ],
    );
    final mobileThemeData = buildMoviePlayerMobileControlsThemeData(
      theme: theme,
      topControls: topControls,
      bottomControls: const <Widget>[
        MaterialSkipPreviousButton(),
        MaterialPlayOrPauseButton(),
        MaterialSkipNextButton(),
        MaterialPositionIndicator(),
        Spacer(),
        MaterialFullscreenButton(),
      ],
    );
    return MaterialVideoControlsTheme(
      normal: mobileThemeData,
      fullscreen: mobileThemeData,
      child: MaterialDesktopVideoControlsTheme(
        normal: desktopThemeData,
        fullscreen: desktopThemeData,
        child: Video(
          key: const Key('video-collection-play-video'),
          controller: videoController,
          fit: BoxFit.contain,
          fill: Colors.black,
          controls: resolveMoviePlayerVideoControlsBuilder(
            useTouchOptimizedControls: false,
          ),
        ),
      ),
    );
  }

  Widget _buildQueue(BuildContext context) {
    final spacing = context.appSpacing;
    return Container(
      width: 320,
      color: context.appColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Text(
              '播放队列 · ${_videos.length}',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              key: const Key('video-collection-play-queue'),
              padding: EdgeInsets.symmetric(horizontal: spacing.sm),
              itemCount: _videos.length,
              separatorBuilder: (context, index) => SizedBox(height: spacing.xs),
              itemBuilder: (context, index) {
                return _QueueItem(
                  video: _videos[index],
                  index: index,
                  isCurrent: index == _currentIndex,
                  onTap: () => _jumpTo(index),
                );
              },
            ),
          ),
        ],
      ),
    );
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
