import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_subtitle_state.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/media/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_surface_controller.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_thumbnail_panel.dart';

typedef MoviePlayerSurfaceBuilder =
    Widget Function(
      BuildContext context,
      String resolvedUrl,
      MoviePlayerSurfaceController surfaceController,
      Duration? initialPosition,
      ValueChanged<Duration>? onPositionChanged,
      ValueChanged<bool>? onPlayingChanged,
      MoviePlayerSubtitleState subtitleState,
      ValueChanged<int?> onSubtitleSelectionChanged,
      Future<void> Function() onSubtitleReloadRequested,
      VoidCallback onBackPressed,
      bool useTouchOptimizedControls,
    );

class DesktopMoviePlayerPage extends StatefulWidget {
  const DesktopMoviePlayerPage({
    super.key,
    required this.movieNumber,
    this.initialMediaId,
    this.initialPositionSeconds,
    this.fallbackPath,
    this.enableThumbnailActionMenu = true,
    this.imageSearchRoutePath = desktopImageSearchPath,
    this.useTouchOptimizedControls = false,
    this.dividerHandleBuffer = 0,
    this.surfaceBuilder,
  });

  final String movieNumber;
  final int? initialMediaId;
  final int? initialPositionSeconds;
  final String? fallbackPath;
  final bool enableThumbnailActionMenu;
  final String imageSearchRoutePath;
  final bool useTouchOptimizedControls;
  final double dividerHandleBuffer;
  final MoviePlayerSurfaceBuilder? surfaceBuilder;

  @override
  State<DesktopMoviePlayerPage> createState() => _DesktopMoviePlayerPageState();
}

class _DesktopMoviePlayerPageState extends State<DesktopMoviePlayerPage> {
  late final MoviePlayerController _controller;
  late final MultiSplitViewController _splitController;
  late final MoviePlayerSurfaceController _surfaceController;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[player-debug] desktop_player_page_init movie=${widget.movieNumber} initialMediaId=${widget.initialMediaId} initialPositionSeconds=${widget.initialPositionSeconds} fallbackPath=${widget.fallbackPath}',
    );
    _controller = MoviePlayerController(
      movieNumber: widget.movieNumber,
      initialMediaId: widget.initialMediaId,
      initialPositionSeconds: widget.initialPositionSeconds,
      baseUrl: context.read<SessionStore>().baseUrl,
      fetchMovieDetail: context.read<MoviesApi>().getMovieDetail,
      fetchMediaThumbnails: context.read<MoviesApi>().getMediaThumbnails,
      fetchMovieSubtitles: context.read<MoviesApi>().getMovieSubtitles,
      updateMediaProgress: context.read<MoviesApi>().updateMediaProgress,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.movieDetailHeroBackgroundStart,
      body: DecoratedBox(
        key: const Key('movie-player-page-frame'),
        decoration: BoxDecoration(
          color: colors.movieDetailHeroBackgroundStart.withValues(alpha: 0.92),
          borderRadius: context.appRadius.lgBorder,
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (_controller.isLoading) {
              return _MoviePlayerLoadingState(
                dividerHandleBuffer: widget.dividerHandleBuffer,
              );
            }

            if (_controller.errorMessage != null) {
              return _MoviePlayerErrorState(
                message: _controller.errorMessage!,
                onRetry: _controller.load,
                dividerHandleBuffer: widget.dividerHandleBuffer,
              );
            }

            final resolvedUrl = _controller.resolvedPlayUrl;
            return _MoviePlayerSplitLayout(
              controller: _splitController,
              dividerHandleBuffer: widget.dividerHandleBuffer,
              leftChild:
                  resolvedUrl == null
                      ? const _MoviePlayerEmptyState()
                      : _buildPlayerSurface(context, resolvedUrl),
              rightChild:
                  _controller.selectedMedia == null
                      ? const SizedBox.expand()
                      : _buildThumbnailPanel(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerSurface(BuildContext context, String resolvedUrl) {
    if (widget.surfaceBuilder != null) {
      return widget.surfaceBuilder!(
        context,
        resolvedUrl,
        _surfaceController,
        _controller.initialPlaybackPosition,
        _controller.handlePlaybackPosition,
        _controller.handlePlaybackPlayingChanged,
        _controller.subtitleState,
        _controller.setSelectedSubtitleId,
        _controller.loadSubtitles,
        _handleBack,
        widget.useTouchOptimizedControls,
      );
    }
    return MoviePlayerSurface(
      movieNumber: widget.movieNumber,
      resolvedUrl: resolvedUrl,
      surfaceController: _surfaceController,
      initialPosition: _controller.initialPlaybackPosition,
      onPositionChanged: _controller.handlePlaybackPosition,
      onPlayingChanged: _controller.handlePlaybackPlayingChanged,
      subtitleState: _controller.subtitleState,
      onSubtitleSelectionChanged: _controller.setSelectedSubtitleId,
      onSubtitleReloadRequested: _controller.loadSubtitles,
      onBackPressed: _handleBack,
      useTouchOptimizedControls: widget.useTouchOptimizedControls,
    );
  }

  Widget _buildThumbnailPanel() {
    return ValueListenableBuilder<int?>(
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
          onThumbnailMenuRequested:
              widget.enableThumbnailActionMenu ? _showThumbnailActions : null,
          onRetry: _controller.loadThumbnails,
        );
      },
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(
      widget.fallbackPath ??
          buildDesktopMovieDetailRoutePath(widget.movieNumber),
    );
  }

  Future<void> _showThumbnailActions(int index, Offset globalPosition) async {
    if (index < 0 || index >= _controller.thumbnails.length) {
      return;
    }
    final thumbnail = _controller.thumbnails[index];
    final point = await _loadMatchingPoint(thumbnail);
    if (!mounted) {
      return;
    }
    final action = await showAppImageActionMenu(
      context: context,
      actions: _buildThumbnailActionDescriptors(thumbnail, point),
      globalPosition: globalPosition,
    );
    if (!mounted || action == null) {
      return;
    }
    await _handleThumbnailAction(index, thumbnail, action, point);
  }

  List<AppImageActionDescriptor> _buildThumbnailActionDescriptors(
    MovieMediaThumbnailDto thumbnail,
    MediaPointDto? point,
  ) {
    final hasMedia = thumbnail.mediaId > 0;
    return <AppImageActionDescriptor>[
      const AppImageActionDescriptor(
        type: AppImageActionType.searchSimilar,
        label: '相似图片',
        icon: Icons.image_search_outlined,
      ),
      const AppImageActionDescriptor(
        type: AppImageActionType.saveToLocal,
        label: '保存到本地',
        icon: Icons.download_outlined,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.toggleMark,
        label: point == null ? '添加标记' : '删除标记',
        icon:
            point == null
                ? Icons.bookmark_add_outlined
                : Icons.bookmark_remove_outlined,
        enabled: hasMedia,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.play,
        label: '播放',
        icon: Icons.play_circle_outline_rounded,
        enabled: hasMedia,
      ),
    ];
  }

  Future<MediaPointDto?> _loadMatchingPoint(
    MovieMediaThumbnailDto thumbnail,
  ) async {
    if (thumbnail.mediaId <= 0 || thumbnail.thumbnailId <= 0) {
      return null;
    }
    final points = await context.read<MediaApi>().getMediaPoints(
      mediaId: thumbnail.mediaId,
    );
    for (final point in points) {
      if (point.thumbnailId == thumbnail.thumbnailId) {
        return point;
      }
    }
    return null;
  }

  Future<void> _handleThumbnailAction(
    int index,
    MovieMediaThumbnailDto thumbnail,
    AppImageActionType action,
    MediaPointDto? point,
  ) async {
    final imageUrl =
        thumbnail.image.origin.trim().isNotEmpty
            ? thumbnail.image.origin
            : thumbnail.image.bestAvailableUrl;
    final fileName =
        'movie_player_${widget.movieNumber}_${thumbnail.thumbnailId}.webp';

    switch (action) {
      case AppImageActionType.searchSimilar:
        await launchImageSearchFromUrl(
          context,
          imageUrl: imageUrl,
          routePath: widget.imageSearchRoutePath,
          fallbackPath: buildDesktopMoviePlayerRoutePath(
            widget.movieNumber,
            mediaId: _controller.selectedMedia?.mediaId,
            positionSeconds: _controller.currentPlaybackSeconds,
          ),
          fileName: fileName,
          replaceRouteStack: true,
        );
        break;
      case AppImageActionType.saveToLocal:
        final result = await ImageSaveService(
          fetchBytes: context.read<ApiClient>().getBytes,
        ).saveImageFromUrl(
          imageUrl: imageUrl,
          fileName: fileName,
          dialogTitle: '保存到本地',
        );
        if (!mounted) {
          return;
        }
        if (result.status == ImageSaveStatus.success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.message ?? '图片已保存')));
        }
        if (result.status == ImageSaveStatus.failed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? '保存失败，请稍后重试')),
          );
        }
        break;
      case AppImageActionType.toggleMark:
        if (thumbnail.mediaId <= 0 || thumbnail.thumbnailId <= 0) {
          return;
        }
        try {
          if (point == null) {
            await context.read<MediaApi>().createMediaPoint(
              mediaId: thumbnail.mediaId,
              thumbnailId: thumbnail.thumbnailId,
            );
          } else {
            await context.read<MediaApi>().deleteMediaPoint(
              mediaId: thumbnail.mediaId,
              pointId: point.pointId,
            );
          }
        } catch (_) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('更新标记失败')));
        }
        break;
      case AppImageActionType.play:
        _controller.handleThumbnailTap(index);
        _surfaceController.seekTo(Duration(seconds: thumbnail.offsetSeconds));
        _surfaceController.play();
        break;
      case AppImageActionType.movieDetail:
        break;
    }
  }
}

class _MoviePlayerSplitLayout extends StatelessWidget {
  const _MoviePlayerSplitLayout({
    required this.controller,
    required this.dividerHandleBuffer,
    required this.leftChild,
    required this.rightChild,
  });

  final MultiSplitViewController controller;
  final double dividerHandleBuffer;
  final Widget leftChild;
  final Widget rightChild;

  @override
  Widget build(BuildContext context) {
    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: context.appSpacing.xs,
        dividerHandleBuffer: dividerHandleBuffer,
        dividerPainter: DividerPainters.grooved1(
          color: context.appColors.borderSubtle,
        ),
      ),
      child: MultiSplitView(
        controller: controller,
        axis: Axis.horizontal,
        builder:
            (context, area) =>
                area.index == 0
                    ? _MoviePlayerPanel(child: leftChild)
                    : _MoviePlayerSidePanel(child: rightChild),
      ),
    );
  }
}

class _MoviePlayerPanel extends StatelessWidget {
  const _MoviePlayerPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const Key('movie-player-left-panel'),
      borderRadius: context.appRadius.lgBorder,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.movieDetailHeroBackgroundStart,
        ),
        child: child,
      ),
    );
  }
}

class _MoviePlayerSidePanel extends StatelessWidget {
  const _MoviePlayerSidePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('movie-player-thumbnail-panel'),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.xsBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: child,
    );
  }
}

class _MoviePlayerLoadingState extends StatelessWidget {
  const _MoviePlayerLoadingState({required this.dividerHandleBuffer});

  final double dividerHandleBuffer;

  @override
  Widget build(BuildContext context) {
    return _MoviePlayerSplitLayout(
      controller: MultiSplitViewController(
        areas: [Area(flex: 0.72), Area(flex: 0.28)],
      ),
      dividerHandleBuffer: dividerHandleBuffer,
      leftChild: const _MoviePlayerLoadingPanel(),
      rightChild: const SizedBox.expand(),
    );
  }
}

class _MoviePlayerLoadingPanel extends StatelessWidget {
  const _MoviePlayerLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('movie-player-loading-state'),
      color: context.appColors.movieDetailHeroBackgroundStart,
      child: const SizedBox.expand(key: Key('movie-player-left-blackout')),
    );
  }
}

class _MoviePlayerErrorState extends StatelessWidget {
  const _MoviePlayerErrorState({
    required this.message,
    required this.onRetry,
    required this.dividerHandleBuffer,
  });

  final String message;
  final VoidCallback onRetry;
  final double dividerHandleBuffer;

  @override
  Widget build(BuildContext context) {
    return _MoviePlayerSplitLayout(
      controller: MultiSplitViewController(
        areas: [Area(flex: 0.72), Area(flex: 0.28)],
      ),
      dividerHandleBuffer: dividerHandleBuffer,
      leftChild: _MoviePlayerPanelMessage(
        title: '播放器加载失败',
        message: message,
        icon: Icons.play_disabled_outlined,
        actionLabel: '重试',
        onAction: onRetry,
      ),
      rightChild: const SizedBox.expand(),
    );
  }
}

class _MoviePlayerEmptyState extends StatelessWidget {
  const _MoviePlayerEmptyState();

  @override
  Widget build(BuildContext context) {
    return const _MoviePlayerPanelMessage(
      title: '暂无可播放媒体',
      message: '当前影片还没有可用的播放地址，请稍后再试。',
      icon: Icons.play_circle_outline_rounded,
      actionLabel: null,
      onAction: null,
    );
  }
}

class _MoviePlayerPanelMessage extends StatelessWidget {
  const _MoviePlayerPanelMessage({
    required this.title,
    required this.message,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
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
                  ).copyWith(
                    color: context.appTextPalette.onMedia.withValues(
                      alpha: 0.8,
                    ),
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
