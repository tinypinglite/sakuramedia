import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/clips/presentation/widgets/create_clip_dialog.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_player_layout.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_player_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_player_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_player_state.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/domain/media/media_thumbnail_action_support.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_surface.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_surface_controller.dart';
import 'package:sakuramedia/widgets/domain/media/movie_player_thumbnail_panel.dart';

typedef MoviePlayerSurfaceBuilder =
    Widget Function(
      BuildContext context,
      String resolvedUrl,
      MoviePlayerSurfaceController surfaceController,
      Duration? initialPosition,
      Duration? resumePosition,
      VoidCallback onResumePromptResolved,
      ValueChanged<Duration>? onPositionChanged,
      ValueChanged<bool>? onPlayingChanged,
      MoviePlayerSubtitleState subtitleState,
      ValueChanged<int?> onSubtitleSelectionChanged,
      Future<void> Function() onSubtitleReloadRequested,
      VoidCallback onBackPressed,
      bool useTouchOptimizedControls,
    );

/// 影片应用内播放器共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异（fallbackPath / imageSearchRoutePath / useTouchOptimizedControls /
/// dividerHandleBuffer / surfaceBuilder）全部收在壳参数里；State 持有加载状态机、
/// 缩略图面板与结果动作族。移动壳额外负责横屏 SystemUI 生命周期。
class MoviePlayerContent extends ConsumerStatefulWidget {
  const MoviePlayerContent({
    super.key,
    required this.movieNumber,
    this.initialMediaId,
    this.initialPositionSeconds,
    this.fallbackPath,
    this.imageSearchRoutePath = desktopImageSearchPath,
    this.useTouchOptimizedControls = false,
    this.dividerHandleBuffer = 0,
    this.surfaceBuilder,
  });

  final String movieNumber;
  final int? initialMediaId;
  final int? initialPositionSeconds;
  final String? fallbackPath;
  final String imageSearchRoutePath;
  final bool useTouchOptimizedControls;
  final double dividerHandleBuffer;
  final MoviePlayerSurfaceBuilder? surfaceBuilder;

  @override
  ConsumerState<MoviePlayerContent> createState() => _MoviePlayerContentState();
}

class _MoviePlayerContentState extends ConsumerState<MoviePlayerContent> {
  late final MoviePlayerScope _scope;
  late final MoviePlayer _controller;
  late final MultiSplitViewController _splitController;
  late final MoviePlayerSurfaceController _surfaceController;

  MoviePlayerState get _playerState => ref.read(moviePlayerProvider(_scope));

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[player-debug] movie_player_content_init movie=${widget.movieNumber} initialMediaId=${widget.initialMediaId} initialPositionSeconds=${widget.initialPositionSeconds}',
    );
    _scope = MoviePlayerScope(
      movieNumber: widget.movieNumber,
      initialMediaId: widget.initialMediaId,
      initialPositionSeconds: widget.initialPositionSeconds,
      baseUrl: ref.read(sessionStoreProvider).baseUrl,
    );
    _controller = ref.read(moviePlayerProvider(_scope).notifier);
    _splitController = MultiSplitViewController(
      areas: [Area(flex: 0.72), Area(flex: 0.28)],
    );
    _surfaceController = MoviePlayerSurfaceController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_controller.load());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_controller.flushPlaybackProgress());
    _surfaceController.dispose();
    _splitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final playerState = ref.watch(moviePlayerProvider(_scope));

    final Widget content;
    if (playerState.isLoading) {
      content = wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        child: const MoviePlayerLoadingState(),
      );
    } else if (playerState.errorMessage != null) {
      content = wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        child: MoviePlayerErrorState(
          message: playerState.errorMessage!,
          onRetry: _controller.load,
        ),
      );
    } else {
      final primaryResolvedUrl = playerState.resolvedPlayUrl(_scope.baseUrl);
      if (primaryResolvedUrl == null) {
        content = wrapWithMoviePlayerBackButton(
          onBackPressed: _handleBack,
          child: MoviePlayerSplitLayout(
            controller: _splitController,
            dividerHandleBuffer: widget.dividerHandleBuffer,
            leftChild: const MoviePlayerEmptyState(),
            rightChild: playerState.selectedMedia == null
                ? const SizedBox.expand()
                : _buildThumbnailPanel(),
          ),
        );
      } else {
        content = MoviePlayerSplitLayout(
          controller: _splitController,
          dividerHandleBuffer: widget.dividerHandleBuffer,
          leftChild: _buildPlayerSurface(context, primaryResolvedUrl),
          rightChild: playerState.selectedMedia == null
              ? const SizedBox.expand()
              : _buildThumbnailPanel(),
        );
      }
    }

    return Scaffold(
      backgroundColor: colors.movieDetailHeroBackgroundStart,
      body: DecoratedBox(
        key: const Key('movie-player-page-frame'),
        decoration: BoxDecoration(
          color: colors.movieDetailHeroBackgroundStart.withValues(alpha: 0.92),
          borderRadius: context.appRadius.lgBorder,
        ),
        child: content,
      ),
    );
  }

  Widget _buildPlayerSurface(BuildContext context, String resolvedUrl) {
    if (widget.surfaceBuilder != null) {
      return widget.surfaceBuilder!(
        context,
        resolvedUrl,
        _surfaceController,
        _playerState.startupPlaybackPosition,
        _playerState.resumePlaybackPosition,
        _controller.resolveResumePrompt,
        _controller.handlePlaybackPosition,
        _controller.handlePlaybackPlayingChanged,
        _playerState.subtitleState,
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
      initialPosition: _playerState.startupPlaybackPosition,
      resumePosition: _playerState.resumePlaybackPosition,
      onResumePromptResolved: _controller.resolveResumePrompt,
      onPositionChanged: _controller.handlePlaybackPosition,
      onPlayingChanged: _controller.handlePlaybackPlayingChanged,
      subtitleState: _playerState.subtitleState,
      onSubtitleSelectionChanged: _controller.setSelectedSubtitleId,
      onSubtitleReloadRequested: _controller.loadSubtitles,
      onBackPressed: _handleBack,
      useTouchOptimizedControls: widget.useTouchOptimizedControls,
      mediaInfo: _buildMediaInfo(),
    );
  }

  MoviePlayerMediaInfo? _buildMediaInfo() {
    final media = _playerState.selectedMedia;
    if (media == null) {
      return null;
    }
    return MoviePlayerMediaInfo(
      sourceLabel: media.providerKey?.trim().isNotEmpty == true
          ? media.providerKey!.trim()
          : '--',
      libraryLabel: media.libraryId == null ? '--' : '媒体库 ${media.libraryId}',
      fileSizeLabel: media.fileSizeBytes > 0
          ? formatFileSize(media.fileSizeBytes)
          : '--',
      durationLabel: media.durationSeconds > 0
          ? formatMediaTimecode(media.durationSeconds)
          : '--',
      resolutionLabel: media.resolution?.trim().isNotEmpty == true
          ? media.resolution!.trim()
          : '--',
    );
  }

  Widget _buildThumbnailPanel() {
    return ValueListenableBuilder<int?>(
      valueListenable: _controller.activeThumbnailIndexListenable,
      builder: (context, activeIndex, child) {
        final playerState = _playerState;
        return MoviePlayerThumbnailPanel(
          thumbnails: playerState.thumbnails,
          isLoading: playerState.isThumbnailLoading,
          errorMessage: playerState.thumbnailErrorMessage,
          columns: playerState.thumbnailColumns,
          activeIndex: activeIndex,
          isScrollLocked: playerState.isThumbnailScrollLocked,
          usesAutoColumns: playerState.usesAutoThumbnailColumns,
          onAutoColumnsResolved: _controller.applyAutoThumbnailColumns,
          onColumnsChanged: _controller.setThumbnailColumns,
          onToggleScrollLock: _controller.toggleThumbnailScrollLock,
          onThumbnailTap: (index) {
            if (_playerState.clipSelectionMode) {
              _controller.handleClipSelectionTap(index);
              return;
            }
            _controller.handleThumbnailTap(index);
            final item = _playerState.thumbnails[index];
            _surfaceController.seekTo(Duration(seconds: item.offsetSeconds));
          },
          onThumbnailMenuRequested: _showThumbnailActions,
          onRetry: _controller.loadThumbnails,
          clipSelectionMode: playerState.clipSelectionMode,
          clipStartIndex: playerState.clipStartIndex,
          clipEndIndex: playerState.clipEndIndex,
          clipStartSeconds: playerState.clipStartThumbnail?.offsetSeconds,
          clipEndSeconds: playerState.clipEndThumbnail?.offsetSeconds,
          clipDurationSeconds: playerState.clipSelectionDurationSeconds,
          canCreateClip: playerState.canCreateClip,
          onToggleClipSelectionMode: _controller.toggleClipSelectionMode,
          onCreateClip: _handleCreateClip,
          onClearClipSelection: _controller.clearClipSelection,
        );
      },
    );
  }

  Future<void> _handleCreateClip() async {
    final media = _playerState.selectedMedia;
    final start = _playerState.clipStartThumbnail;
    final end = _playerState.clipEndThumbnail;
    if (media == null || start == null || end == null) {
      return;
    }
    final created = await showCreateClipDialog(
      context,
      mediaId: media.mediaId,
      movieNumber: widget.movieNumber,
      startThumbnailId: start.thumbnailId,
      endThumbnailId: end.thumbnailId,
      startSeconds: start.offsetSeconds,
      endSeconds: end.offsetSeconds,
    );
    if (!mounted || created == null) {
      return;
    }
    showToast('切片已生成');
    // 退出圈选模式并清空已选点。
    _controller.toggleClipSelectionMode();
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
    if (index < 0 || index >= _playerState.thumbnails.length) {
      return;
    }
    final thumbnail = _playerState.thumbnails[index];
    final point = await findMediaPointForThumbnail(
      ref: ref,
      thumbnail: thumbnail,
    );
    if (!mounted) {
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
        'movie_player_${widget.movieNumber}_${thumbnail.thumbnailId}.webp';
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
        fallbackPath: buildDesktopMoviePlayerRoutePath(
          widget.movieNumber,
          mediaId: _playerState.selectedMedia?.mediaId,
          positionSeconds: _controller.currentPlaybackSeconds,
        ),
        fileName: fileName,
        replaceRouteStack: true,
      ),
      onPlay: () async {
        _controller.handleThumbnailTap(index);
        _surfaceController.seekTo(Duration(seconds: thumbnail.offsetSeconds));
        _surfaceController.play();
      },
    );
  }
}
