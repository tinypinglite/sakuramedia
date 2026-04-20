import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/movie_plot_image_actions.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/playlists/presentation/movie_playlist_picker_dialog.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/media/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/media/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_inspector_dialog.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_preview_overlay.dart';

class DesktopMovieDetailPage extends StatefulWidget {
  const DesktopMovieDetailPage({super.key, required this.movieNumber});

  final String movieNumber;

  @override
  State<DesktopMovieDetailPage> createState() => _DesktopMovieDetailPageState();
}

class _DesktopMovieDetailPageState extends State<DesktopMovieDetailPage> {
  late final MovieDetailController _controller;
  final Map<int, List<MovieMediaPointDto>> _pointOverrides =
      <int, List<MovieMediaPointDto>>{};
  int? _selectedMediaId;
  bool? _isSubscribedOverride;
  bool? _isCollectionOverride;
  bool _isSubscriptionUpdating = false;
  bool _isCollectionUpdating = false;
  int? _deletingMediaId;

  @override
  void initState() {
    super.initState();
    _controller = MovieDetailController(
      movieNumber: widget.movieNumber,
      fetchMovieDetail: context.read<MoviesApi>().getMovieDetail,
      fetchSimilarMovies: context.read<MoviesApi>().getSimilarMovies,
    )..load();
    _loadMovieCollectionStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isLoading) {
          return MovieDetailLoadingSkeleton(controller: _controller);
        }

        if (_controller.errorMessage != null || _controller.movie == null) {
          return MovieDetailErrorState(
            message: _controller.errorMessage ?? '影片详情暂时无法加载，请稍后重试',
            onRetry: _controller.load,
          );
        }

        final movie = _controller.movie!;
        final mediaItems = _resolveMediaItems(movie);
        final isSubscribed = _isSubscribedOverride ?? movie.isSubscribed;
        final isCollection = _isCollectionOverride ?? movie.isCollection;
        final selectedMedia =
            mediaItems
                .where((item) => item.mediaId == _selectedMediaId)
                .firstOrNull ??
            (mediaItems.isNotEmpty ? mediaItems.first : null);
        return MovieDetailPageContent(
          movie: movie,
          mediaItemsOverride: mediaItems,
          selectedPreviewKey: _controller.selectedPreviewKey,
          selectedPreviewUrl: _controller.selectedPreviewUrl,
          isCollection: isCollection,
          isSubscribed: isSubscribed,
          isCollectionUpdating: _isCollectionUpdating,
          isSubscriptionUpdating: _isSubscriptionUpdating,
          selectedMediaId: selectedMedia?.mediaId,
          statItems: buildMovieDetailStatItems(context, movie),
          similarMovies: _controller.similarMovies,
          isSimilarMoviesLoading: _controller.isSimilarMoviesLoading,
          similarMoviesErrorMessage: _controller.similarMoviesErrorMessage,
          onRetrySimilarMovies: _controller.retryLoadSimilarMovies,
          onSimilarMovieTap:
              (similarMovie) => context.pushDesktopMovieDetail(
                movieNumber: similarMovie.movieNumber,
                fallbackPath: buildDesktopMovieDetailRoutePath(
                  widget.movieNumber,
                ),
              ),
          onSubscriptionTap:
              _isSubscriptionUpdating
                  ? null
                  : () => _toggleMovieSubscription(isSubscribed: isSubscribed),
          onPlayTap:
              selectedMedia != null && selectedMedia.hasPlayableUrl
                  ? () => context.pushDesktopMoviePlayer(
                    movieNumber: widget.movieNumber,
                    fallbackPath: buildDesktopMovieDetailRoutePath(
                      widget.movieNumber,
                    ),
                    mediaId: selectedMedia.mediaId,
                  )
                  : null,
          onPlaylistTap:
              () => showMoviePlaylistPickerDialog(
                context,
                movieNumber: widget.movieNumber,
                initialPlaylists: movie.playlists,
                presentation: MoviePlaylistPickerPresentation.dialog,
              ),
          onCollectionToggle:
              _isCollectionUpdating
                  ? null
                  : () =>
                      _toggleMovieCollectionType(isCollection: isCollection),
          onMediaSelect:
              (item) => setState(() {
                _selectedMediaId = item.mediaId;
              }),
          isDeletingSelectedMedia:
              selectedMedia != null &&
              _deletingMediaId == selectedMedia.mediaId,
          onDeleteSelectedMedia:
              selectedMedia == null ? null : _deleteSelectedMedia,
          onOpenMediaPointPreview: _openMediaPointPreview,
          onRequestMediaPointMenu: _showMediaPointActions,
          onActorTap:
              (actor) => context.pushDesktopActorDetail(
                actorId: actor.id,
                fallbackPath: buildDesktopMovieDetailRoutePath(
                  widget.movieNumber,
                ),
              ),
          onRequestPlotImageMenu:
              (menuContext, index, globalPosition) =>
                  showMoviePlotImageActionMenu(
                    context: menuContext,
                    hostContext: context,
                    plotImages: movie.plotImages,
                    movieNumber: widget.movieNumber,
                    index: index,
                    globalPosition: globalPosition,
                  ),
          onOpenPlotPreview:
              (index) => showMoviePlotPreviewOverlay(
                context: context,
                plotImages: movie.plotImages,
                initialIndex: index,
                onRequestImageMenu:
                    (menuContext, previewIndex, globalPosition) =>
                        showMoviePlotImageActionMenu(
                          context: menuContext,
                          hostContext: context,
                          plotImages: movie.plotImages,
                          movieNumber: widget.movieNumber,
                          index: previewIndex,
                          globalPosition: globalPosition,
                          closeCurrentRouteOnSearch: true,
                        ),
              ),
          onInspectorTap:
              () => showMovieDetailInspectorDialog(
                context: context,
                movieNumber: movie.movieNumber,
                selectedMedia: selectedMedia,
              ),
        );
      },
    );
  }

  Future<void> _loadMovieCollectionStatus() async {
    try {
      final status = await context.read<MoviesApi>().getMovieCollectionStatus(
        movieNumber: widget.movieNumber,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isCollectionOverride = status.isCollection;
      });
    } catch (_) {
      // Fall back to detail payload value when status lookup fails.
    }
  }

  Future<void> _toggleMovieCollectionType({required bool isCollection}) async {
    if (_isCollectionUpdating) {
      return;
    }
    setState(() {
      _isCollectionUpdating = true;
    });

    final targetType =
        isCollection
            ? MovieCollectionType.single
            : MovieCollectionType.collection;
    try {
      final result = await context.read<MoviesApi>().updateMovieCollectionType(
        movieNumbers: <String>[widget.movieNumber],
        collectionType: targetType,
      );
      if (!mounted) {
        return;
      }
      if (result.updatedCount <= 0) {
        showToast('未匹配到影片，未更新合集状态');
        return;
      }
      setState(() {
        _isCollectionOverride = !isCollection;
      });
      context.read<MovieCollectionTypeChangeNotifier>().reportChange(
        movieNumber: widget.movieNumber,
        targetType: targetType,
      );
      showToast(
        targetType == MovieCollectionType.collection ? '已标记为合集' : '已标记为单体',
      );
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '更新合集状态失败'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCollectionUpdating = false;
        });
      }
    }
  }

  Future<void> _deleteSelectedMedia(MovieMediaItemDto mediaItem) async {
    if (_deletingMediaId != null) {
      return;
    }

    final confirmed = await _confirmDeleteMedia(mediaItem);
    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _deletingMediaId = mediaItem.mediaId;
    });

    try {
      await context.read<MediaApi>().deleteMedia(mediaId: mediaItem.mediaId);
      await _refreshAfterMediaDelete(deletedMediaId: mediaItem.mediaId);
      if (mounted) {
        showToast('媒体文件已删除');
      }
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '删除媒体文件失败'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingMediaId = null;
        });
      }
    }
  }

  Future<bool?> _confirmDeleteMedia(MovieMediaItemDto mediaItem) {
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AppDesktopDialog(
            dialogKey: const Key('movie-media-delete-confirm-dialog'),
            width: dialogContext.appLayoutTokens.dialogWidthSm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '删除媒体文件',
                  style: resolveAppTextStyle(
                    dialogContext,
                    size: AppTextSize.s18,
                  ),
                ),
                SizedBox(height: dialogContext.appSpacing.lg),
                Text(
                  '确认删除媒体“${_buildMediaDeleteLabel(mediaItem)}”？该操作会删除本地媒体文件且不可恢复。',
                ),
                SizedBox(height: dialogContext.appSpacing.sm),
                Text(
                  mediaItem.path,
                  key: const Key('movie-media-delete-path'),
                  style: resolveAppTextStyle(
                    dialogContext,
                    size: AppTextSize.s12,
                    tone: AppTextTone.muted,
                  ),
                ),
                SizedBox(height: dialogContext.appSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        key: const Key('movie-media-delete-cancel'),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        label: '取消',
                      ),
                    ),
                    SizedBox(width: dialogContext.appSpacing.md),
                    Expanded(
                      child: AppButton(
                        key: const Key('movie-media-delete-confirm'),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        label: '删除',
                        variant: AppButtonVariant.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _refreshAfterMediaDelete({required int deletedMediaId}) async {
    try {
      await _controller.refresh();
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }
    _resetDetailOverridesAfterRefresh(deletedMediaId: deletedMediaId);
    await _loadMovieCollectionStatus();
  }

  void _resetDetailOverridesAfterRefresh({required int deletedMediaId}) {
    final refreshedMediaItems = _controller.movie?.mediaItems ?? const [];
    final retainedSelectedMediaId =
        _selectedMediaId != null &&
                _selectedMediaId != deletedMediaId &&
                refreshedMediaItems.any(
                  (item) => item.mediaId == _selectedMediaId,
                )
            ? _selectedMediaId
            : null;
    setState(() {
      _pointOverrides.clear();
      _selectedMediaId =
          retainedSelectedMediaId ??
          (refreshedMediaItems.isNotEmpty
              ? refreshedMediaItems.first.mediaId
              : null);
      _isSubscribedOverride = null;
      _isCollectionOverride = null;
    });
  }

  List<MovieMediaItemDto> _resolveMediaItems(MovieDetailDto movie) {
    if (_pointOverrides.isEmpty) {
      return movie.mediaItems;
    }
    return movie.mediaItems
        .map((item) {
          final pointsOverride = _pointOverrides[item.mediaId];
          if (pointsOverride == null) {
            return item;
          }
          return _copyMediaItemWithPoints(item, pointsOverride);
        })
        .toList(growable: false);
  }

  String _buildMediaDeleteLabel(MovieMediaItemDto mediaItem) {
    final label = mediaItem.specialTags.trim();
    if (label.isNotEmpty) {
      return label;
    }
    return '媒体源 ${mediaItem.mediaId}';
  }

  MovieMediaItemDto _copyMediaItemWithPoints(
    MovieMediaItemDto item,
    List<MovieMediaPointDto> points,
  ) {
    return MovieMediaItemDto(
      mediaId: item.mediaId,
      libraryId: item.libraryId,
      playUrl: item.playUrl,
      path: item.path,
      storageMode: item.storageMode,
      resolution: item.resolution,
      fileSizeBytes: item.fileSizeBytes,
      durationSeconds: item.durationSeconds,
      specialTags: item.specialTags,
      valid: item.valid,
      progress: item.progress,
      points: points,
      videoInfo: item.videoInfo,
    );
  }

  Future<void> _openMediaPointPreview(
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
  ) {
    return showDialog<void>(
      context: context,
      builder:
          (_) => MediaPreviewDialog(
            item: _buildMediaPointPreviewItem(mediaItem, point),
            onSearchSimilar: () => _searchSimilarFromPoint(point),
            onPlay:
                mediaItem.hasPlayableUrl
                    ? () => _openPlayerForPoint(mediaItem, point)
                    : null,
            onPointRemoved:
                () => _applyPointListOverride(
                  mediaItem.mediaId,
                  mediaItem.points
                      .where((candidate) => candidate.pointId != point.pointId)
                      .toList(growable: false),
                ),
            closeOnPointRemoved: true,
          ),
    );
  }

  Future<void> _showMediaPointActions(
    BuildContext menuContext,
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
    Offset globalPosition,
  ) async {
    final hasImage = _resolvePointImageUrl(point).isNotEmpty;
    final currentPoint = _findCurrentPoint(mediaItem.mediaId, point.pointId);
    final action = await showAppImageActionMenu(
      context: menuContext,
      globalPosition: globalPosition,
      actions: <AppImageActionDescriptor>[
        AppImageActionDescriptor(
          type: AppImageActionType.searchSimilar,
          label: '相似图片',
          icon: Icons.image_search_outlined,
          enabled: hasImage,
        ),
        AppImageActionDescriptor(
          type: AppImageActionType.saveToLocal,
          label: '保存到本地',
          icon: Icons.download_outlined,
          enabled: hasImage,
        ),
        AppImageActionDescriptor(
          type: AppImageActionType.toggleMark,
          label: currentPoint == null ? '添加标记' : '删除标记',
          icon:
              currentPoint == null
                  ? Icons.bookmark_add_outlined
                  : Icons.bookmark_remove_outlined,
          enabled:
              mediaItem.mediaId > 0 &&
              (currentPoint != null || point.thumbnailId > 0),
        ),
        AppImageActionDescriptor(
          type: AppImageActionType.play,
          label: '播放',
          icon: Icons.play_circle_outline_rounded,
          enabled: mediaItem.mediaId > 0 && mediaItem.hasPlayableUrl,
        ),
      ],
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case AppImageActionType.searchSimilar:
        await _searchSimilarFromPoint(point);
        break;
      case AppImageActionType.saveToLocal:
        await _savePointImageToLocal(point);
        break;
      case AppImageActionType.toggleMark:
        await _toggleMediaPoint(mediaItem, point, currentPoint);
        break;
      case AppImageActionType.play:
        _openPlayerForPoint(mediaItem, point);
        break;
      case AppImageActionType.movieDetail:
        break;
    }
  }

  MediaPreviewItem _buildMediaPointPreviewItem(
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
  ) {
    return MediaPreviewItem(
      imageUrl: _resolvePointImageUrl(point),
      fileName: _buildPointFileName(point),
      mediaId: mediaItem.mediaId,
      movieNumber: widget.movieNumber,
      thumbnailId: point.thumbnailId,
      offsetSeconds: point.offsetSeconds,
    );
  }

  String _resolvePointImageUrl(MovieMediaPointDto point) {
    final origin = point.image?.origin.trim() ?? '';
    if (origin.isNotEmpty) {
      return origin;
    }
    return point.image?.bestAvailableUrl.trim() ?? '';
  }

  String _buildPointFileName(MovieMediaPointDto point) {
    final suffix = point.thumbnailId > 0 ? point.thumbnailId : point.pointId;
    return 'movie_point_${widget.movieNumber}_$suffix.webp';
  }

  Future<bool> _searchSimilarFromPoint(MovieMediaPointDto point) async {
    final imageUrl = _resolvePointImageUrl(point);
    if (imageUrl.isEmpty) {
      return false;
    }
    try {
      await launchDesktopImageSearchFromUrl(
        context,
        imageUrl: imageUrl,
        fallbackPath: buildDesktopMovieDetailRoutePath(widget.movieNumber),
        fileName: _buildPointFileName(point),
        currentMovieNumber: widget.movieNumber,
      );
      return true;
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '读取图片失败，请稍后重试'));
      }
      return false;
    }
  }

  Future<void> _savePointImageToLocal(MovieMediaPointDto point) async {
    final imageUrl = _resolvePointImageUrl(point);
    if (imageUrl.isEmpty) {
      return;
    }
    final result = await ImageSaveService(
      fetchBytes: context.read<ApiClient>().getBytes,
    ).saveImageFromUrl(
      imageUrl: imageUrl,
      fileName: _buildPointFileName(point),
      dialogTitle: '保存到本地',
    );
    if (!mounted) {
      return;
    }
    if (result.status == ImageSaveStatus.success) {
      showToast(result.message ?? '图片已保存');
    }
    if (result.status == ImageSaveStatus.failed) {
      showToast(result.message ?? '保存失败，请稍后重试');
    }
  }

  Future<void> _toggleMediaPoint(
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
    MovieMediaPointDto? existingPoint,
  ) async {
    try {
      if (existingPoint == null) {
        final createdPoint = await context.read<MediaApi>().createMediaPoint(
          mediaId: mediaItem.mediaId,
          thumbnailId: point.thumbnailId,
        );
        if (!mounted) {
          return;
        }
        final nextPoints = <MovieMediaPointDto>[
          ...mediaItem.points,
          _movieMediaPointFromMediaPoint(createdPoint, fallback: point),
        ];
        _applyPointListOverride(mediaItem.mediaId, nextPoints);
        showToast('已添加标记');
        return;
      }

      await context.read<MediaApi>().deleteMediaPoint(
        mediaId: mediaItem.mediaId,
        pointId: existingPoint.pointId,
      );
      if (!mounted) {
        return;
      }
      final nextPoints = mediaItem.points
          .where((candidate) => candidate.pointId != existingPoint.pointId)
          .toList(growable: false);
      _applyPointListOverride(mediaItem.mediaId, nextPoints);
      showToast('已删除标记');
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '更新标记失败'));
      }
    }
  }

  MovieMediaPointDto? _findCurrentPoint(int mediaId, int pointId) {
    final movie = _controller.movie;
    if (movie == null) {
      return null;
    }
    final mediaItem = _resolveMediaItems(movie).firstWhere(
      (item) => item.mediaId == mediaId,
      orElse: () => _emptyMediaItem(mediaId),
    );
    for (final point in mediaItem.points) {
      if (point.pointId == pointId) {
        return point;
      }
    }
    return null;
  }

  MovieMediaItemDto _emptyMediaItem(int mediaId) {
    return MovieMediaItemDto(
      mediaId: mediaId,
      libraryId: null,
      playUrl: '',
      path: '',
      storageMode: '',
      resolution: '',
      fileSizeBytes: 0,
      durationSeconds: 0,
      specialTags: '',
      valid: false,
      progress: null,
      points: const <MovieMediaPointDto>[],
      videoInfo: null,
    );
  }

  MovieMediaPointDto _movieMediaPointFromMediaPoint(
    MediaPointDto point, {
    required MovieMediaPointDto fallback,
  }) {
    return MovieMediaPointDto(
      pointId: point.pointId,
      thumbnailId: point.thumbnailId,
      offsetSeconds:
          point.offsetSeconds > 0
              ? point.offsetSeconds
              : fallback.offsetSeconds,
      image: point.image ?? fallback.image,
    );
  }

  void _applyPointListOverride(int mediaId, List<MovieMediaPointDto> points) {
    if (!mounted) {
      return;
    }
    setState(() {
      _pointOverrides[mediaId] = points;
    });
  }

  void _openPlayerForPoint(
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
  ) {
    context.pushDesktopMoviePlayer(
      movieNumber: widget.movieNumber,
      fallbackPath: buildDesktopMovieDetailRoutePath(widget.movieNumber),
      mediaId: mediaItem.mediaId,
      positionSeconds: point.offsetSeconds,
    );
  }

  Future<void> _toggleMovieSubscription({required bool isSubscribed}) async {
    if (_isSubscriptionUpdating) {
      return;
    }

    setState(() {
      _isSubscriptionUpdating = true;
    });

    MovieSubscriptionToggleResult result;

    try {
      if (isSubscribed) {
        await context.read<MoviesApi>().unsubscribeMovie(
          movieNumber: widget.movieNumber,
          deleteMedia: false,
        );
        result = const MovieSubscriptionToggleResult.unsubscribed();
        _isSubscribedOverride = false;
      } else {
        await context.read<MoviesApi>().subscribeMovie(
          movieNumber: widget.movieNumber,
        );
        result = const MovieSubscriptionToggleResult.subscribed();
        _isSubscribedOverride = true;
      }
    } catch (error) {
      if (_isBlockedByMedia(error)) {
        result = const MovieSubscriptionToggleResult.blockedByMedia();
      } else {
        result = MovieSubscriptionToggleResult.failed(
          message: apiErrorMessage(
            error,
            fallback: isSubscribed ? '取消订阅影片失败' : '订阅影片失败',
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubscriptionUpdating = false;
    });
    showMovieSubscriptionFeedback(result);
  }

  bool _isBlockedByMedia(Object error) {
    return error is ApiException &&
        error.error?.code == 'movie_subscription_has_media';
  }
}
