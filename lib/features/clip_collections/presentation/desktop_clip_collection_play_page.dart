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
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface.dart';

/// 切片合集连播独立页面：左侧 media_kit 播放器（原生 Playlist 自动连播），
/// 右侧切片队列（当前高亮 / 点击跳转）。
class DesktopClipCollectionPlayPage extends StatefulWidget {
  const DesktopClipCollectionPlayPage({
    super.key,
    required this.collectionId,
    this.startIndex = 0,
  });

  final int collectionId;
  final int startIndex;

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
    final api = context.read<ClipCollectionsApi>();
    final baseUrl = context.read<SessionStore>().baseUrl;
    try {
      final clips = await _fetchAllClips(api);
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

  Future<List<MediaClipDto>> _fetchAllClips(ClipCollectionsApi api) async {
    final result = <MediaClipDto>[];
    var page = 1;
    while (true) {
      final response = await api.getCollectionClips(
        collectionId: widget.collectionId,
        page: page,
        pageSize: 50,
      );
      result.addAll(response.items.map((item) => item.clip));
      if (result.length >= response.total || response.items.isEmpty) {
        break;
      }
      page += 1;
    }
    return result;
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
      movieNumber: _currentClipTitle(),
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
          key: const Key('clip-collection-play-video'),
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
              '播放队列 · ${_clips.length}',
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
              key: const Key('clip-collection-play-queue'),
              padding: EdgeInsets.symmetric(horizontal: spacing.sm),
              itemCount: _clips.length,
              separatorBuilder:
                  (context, index) => SizedBox(height: spacing.xs),
              itemBuilder: (context, index) {
                return _QueueItem(
                  clip: _clips[index],
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
