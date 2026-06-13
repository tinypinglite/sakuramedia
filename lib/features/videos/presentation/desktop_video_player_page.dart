import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_controller.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/video_player_detail_adapter.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface_controller.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_thumbnail_panel.dart';

/// 非 JAV 视频播放页（全屏）。复用泛化后的 [MoviePlayerController] + [MoviePlayerSurface]
/// + [MoviePlayerThumbnailPanel]，字幕来源传 `null`（视频无字幕抓取），缩略图/进度走
/// mediaId 维度的共享端点。
///
/// 合集连播：当 [playlistVideoIds] 非空时，本集自然播放结束后自动跳转下一集（保留
/// 合集上下文）；非合集进入时 [onCompleted] 不跳转。
class DesktopVideoPlayerPage extends StatefulWidget {
  const DesktopVideoPlayerPage({
    super.key,
    required this.videoId,
    this.initialMediaId,
    this.initialPositionSeconds,
    this.fallbackPath,
    this.collectionId,
    this.playlistVideoIds,
  });

  final int videoId;
  final int? initialMediaId;
  final int? initialPositionSeconds;
  final String? fallbackPath;

  /// 合集连播上下文：所属合集 id 与有序成员视频 id 列表（含当前视频）。
  final int? collectionId;
  final List<int>? playlistVideoIds;

  @override
  State<DesktopVideoPlayerPage> createState() => _DesktopVideoPlayerPageState();
}

class _DesktopVideoPlayerPageState extends State<DesktopVideoPlayerPage> {
  late final MoviePlayerController _controller;
  late final MultiSplitViewController _splitController;
  late final MoviePlayerSurfaceController _surfaceController;

  @override
  void initState() {
    super.initState();
    final videosApi = context.read<VideosApi>();
    final moviesApi = context.read<MoviesApi>();
    _controller = MoviePlayerController(
      movieNumber: 'video-${widget.videoId}',
      initialMediaId: widget.initialMediaId,
      initialPositionSeconds: widget.initialPositionSeconds,
      baseUrl: context.read<SessionStore>().baseUrl,
      fetchMovieDetail: ({required String movieNumber}) async =>
          adaptVideoDetailToMovieDetail(
            await videosApi.getVideoDetail(videoId: widget.videoId),
          ),
      fetchMediaThumbnails: moviesApi.getMediaThumbnails,
      // 视频无字幕抓取，传 null → 控制器内部短路为 unsupported。
      fetchMovieSubtitles: null,
      updateMediaProgress: moviesApi.updateMediaProgress,
    )..load();
    _splitController = MultiSplitViewController(
      areas: [Area(flex: 0.72), Area(flex: 0.28)],
    );
    _surfaceController = MoviePlayerSurfaceController();
  }

  @override
  void dispose() {
    unawaited(_controller.flushPlaybackProgress());
    _surfaceController.dispose();
    _splitController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 本集自然结束：在合集连播上下文中自动跳到下一集。
  void _handleCompleted() {
    final next = _nextVideoId();
    if (next == null) {
      return;
    }
    context.go(_playerLocation(next));
  }

  int? _nextVideoId() {
    final playlist = widget.playlistVideoIds;
    if (playlist == null || playlist.isEmpty) {
      return null;
    }
    final index = playlist.indexOf(widget.videoId);
    if (index < 0 || index + 1 >= playlist.length) {
      return null;
    }
    return playlist[index + 1];
  }

  String _playerLocation(int videoId) {
    final query = <String, String>{};
    if (widget.collectionId != null) {
      query['collectionId'] = '${widget.collectionId}';
    }
    if (widget.playlistVideoIds != null) {
      query['playlist'] = widget.playlistVideoIds!.join(',');
    }
    return Uri(
      path: '$desktopVideosPath/$videoId/player',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(widget.fallbackPath ?? '$desktopVideosPath/${widget.videoId}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.movieDetailHeroBackgroundStart,
      body: DecoratedBox(
        key: const Key('video-player-page-frame'),
        decoration: BoxDecoration(
          color: colors.movieDetailHeroBackgroundStart.withValues(alpha: 0.92),
          borderRadius: context.appRadius.lgBorder,
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (_controller.isLoading) {
              return const _VideoPlayerMessage(
                title: '加载中',
                message: '正在准备播放器…',
                icon: Icons.hourglass_empty_rounded,
              );
            }
            if (_controller.errorMessage != null) {
              return _VideoPlayerMessage(
                title: '播放器加载失败',
                message: _controller.errorMessage!,
                icon: Icons.play_disabled_outlined,
                actionLabel: '重试',
                onAction: _controller.load,
              );
            }
            final resolvedUrl = _controller.resolvedPlayUrl;
            if (resolvedUrl == null) {
              return const _VideoPlayerMessage(
                title: '暂无可播放媒体',
                message: '当前视频还没有可用的播放地址。',
                icon: Icons.play_circle_outline_rounded,
              );
            }
            return _buildSplitLayout(context, resolvedUrl);
          },
        ),
      ),
    );
  }

  Widget _buildSplitLayout(BuildContext context, String resolvedUrl) {
    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: context.appSpacing.xs,
        dividerPainter: DividerPainters.grooved1(
          color: context.appColors.borderSubtle,
        ),
      ),
      child: MultiSplitView(
        controller: _splitController,
        axis: Axis.horizontal,
        builder: (context, area) => area.index == 0
            ? _buildPlayerSurface(context, resolvedUrl)
            : _buildThumbnailPanel(),
      ),
    );
  }

  Widget _buildPlayerSurface(BuildContext context, String resolvedUrl) {
    return ClipRRect(
      key: const Key('video-player-left-panel'),
      borderRadius: context.appRadius.lgBorder,
      child: MoviePlayerSurface(
        movieNumber: _controller.movie?.preferredTitle ?? '',
        resolvedUrl: resolvedUrl,
        surfaceController: _surfaceController,
        initialPosition: _controller.initialPlaybackPosition,
        onPositionChanged: _controller.handlePlaybackPosition,
        onPlayingChanged: _controller.handlePlaybackPlayingChanged,
        onCompleted: _handleCompleted,
        onBackPressed: _handleBack,
      ),
    );
  }

  Widget _buildThumbnailPanel() {
    if (_controller.selectedMedia == null) {
      return const SizedBox.expand();
    }
    return Container(
      key: const Key('video-player-thumbnail-panel'),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.xsBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: ValueListenableBuilder<int?>(
        valueListenable: _controller.activeThumbnailIndexListenable,
        builder: (context, activeIndex, child) {
          return MoviePlayerThumbnailPanel(
            thumbnails: _controller.thumbnails,
            isLoading: _controller.isThumbnailLoading,
            errorMessage: _controller.thumbnailErrorMessage,
            columns: _controller.thumbnailColumns,
            activeIndex: activeIndex,
            isScrollLocked: _controller.isThumbnailScrollLocked,
            usesAutoColumns: _controller.usesAutoThumbnailColumns,
            onAutoColumnsResolved: _controller.applyAutoThumbnailColumns,
            onColumnsChanged: _controller.setThumbnailColumns,
            onToggleScrollLock: _controller.toggleThumbnailScrollLock,
            onThumbnailTap: (index) {
              _controller.handleThumbnailTap(index);
              final item = _controller.thumbnails[index];
              _surfaceController.seekTo(Duration(seconds: item.offsetSeconds));
            },
            onRetry: _controller.loadThumbnails,
          );
        },
      ),
    );
  }
}

class _VideoPlayerMessage extends StatelessWidget {
  const _VideoPlayerMessage({
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appColors.movieDetailHeroBackgroundStart,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: EdgeInsets.all(context.appSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: context.appComponentTokens.iconSize2xl,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: context.appSpacing.lg),
                Text(
                  title,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s18,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.onMedia,
                  ),
                ),
                SizedBox(height: context.appSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: context.appSpacing.lg),
                  AppButton(
                    label: actionLabel!,
                    variant: AppButtonVariant.primary,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
