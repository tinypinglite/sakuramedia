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
import 'package:sakuramedia/features/clip_collections/data/clip_collections_api.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/movie_player/episode_selector_overlay.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface.dart';
import 'package:sakuramedia/widgets/movie_player/themed_video_player.dart';

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
    extends State<DesktopClipCollectionPlayPage> {
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<Playlist>? _playlistSub;

  List<MediaClipDto> _clips = const <MediaClipDto>[];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentIndex = 0;
  bool _isEpisodePanelOpen = false;

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
    final handoff = context.read<CollectionPlaybackHandoff>();
    final api = context.read<ClipCollectionsApi>();
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
      for (final clip in clips) {
        final url = resolveMediaUrl(rawUrl: clip.streamUrl, baseUrl: baseUrl);
        if (url != null && url.isNotEmpty) {
          medias.add(Media(url));
          playableClips.add(clip);
        }
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
      final startIndex = widget.startIndex.clamp(0, medias.length - 1);
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
        _clips = playableClips;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody(context));
  }

  String _currentClipTitle() {
    if (_currentIndex < 0 || _currentIndex >= _clips.length) {
      return '连播';
    }
    return _clips[_currentIndex].displayTitle;
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          key: Key('clip-collection-play-loading'),
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
    return Stack(
      children: [
        Positioned.fill(child: _buildPlayerSurface(context, videoController)),
        EpisodeSelectorOverlay(
          isOpen: _isEpisodePanelOpen,
          itemCount: _clips.length,
          currentIndex: _currentIndex,
          title: '选集 · ${_clips.length}',
          onClose: _closeEpisodePanel,
          itemBuilder: (context, index) {
            return _QueueItem(
              clip: _clips[index],
              index: index,
              isCurrent: index == _currentIndex,
              onTap: () {
                _closeEpisodePanel();
                _jumpTo(index);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlayerSurface(
    BuildContext context,
    VideoController videoController,
  ) {
    return ThemedVideoPlayer(
      videoController: videoController,
      useTouchOptimizedControls: widget.useTouchOptimizedControls,
      videoKey: const Key('clip-collection-play-video'),
      topControls: buildMoviePlayerTopControls(
        movieNumber: _currentClipTitle(),
        onBackPressed: _handleBack,
      ),
      bottomControls: _buildBottomControls(),
      // 全屏由 media_kit push 独立路由，页面级「选集」浮层不在其内，按钮点了
      // 也看不到——全屏态去掉该按钮，避免死按钮。换集需先退出全屏。
      fullscreenBottomControls: _buildBottomControls(
        includeEpisodeButton: false,
      ),
    );
  }

  /// 合集连播底栏：含上一首 / 下一首 + 全屏左侧的「选集」按钮。按平台选对应控件
  /// 变体——移动用触摸版、桌面用 Desktop 版（多一个音量按钮）。
  /// [includeEpisodeButton] 为 `false` 时省略「选集」按钮（全屏态用，浮层在全屏不可见）。
  List<Widget> _buildBottomControls({bool includeEpisodeButton = true}) {
    if (widget.useTouchOptimizedControls) {
      return <Widget>[
        const MaterialSkipPreviousButton(),
        const MaterialPlayOrPauseButton(),
        const MaterialSkipNextButton(),
        const MaterialPositionIndicator(),
        const Spacer(),
        if (includeEpisodeButton)
          MaterialCustomButton(
            onPressed: _openEpisodePanel,
            icon: const Icon(Icons.playlist_play_rounded),
          ),
        const MaterialFullscreenButton(),
      ];
    }
    return <Widget>[
      const MaterialDesktopSkipPreviousButton(),
      const MaterialPlayOrPauseButton(),
      const MaterialDesktopSkipNextButton(),
      const MaterialDesktopVolumeButton(),
      const MaterialPositionIndicator(),
      const Spacer(),
      if (includeEpisodeButton)
        MaterialDesktopCustomButton(
          onPressed: _openEpisodePanel,
          icon: const Icon(Icons.playlist_play_rounded),
        ),
      const MaterialFullscreenButton(),
    ];
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
    required this.clip,
    required this.index,
    required this.isCurrent,
    required this.onTap,
  });

  final MediaClipDto clip;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final coverUrl = clip.coverImage?.bestAvailableUrl;
    return Material(
      color: isCurrent ? colors.surfaceMuted : Colors.transparent,
      borderRadius: context.appRadius.smBorder,
      child: InkWell(
        key: Key('clip-collection-play-queue-item-$index'),
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
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child:
                        coverUrl != null && coverUrl.isNotEmpty
                            ? MaskedImage(url: coverUrl, fit: BoxFit.cover)
                            : ColoredBox(color: colors.surfaceMuted),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clip.displayTitle,
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
                      formatMediaTimecode(clip.durationSeconds),
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
