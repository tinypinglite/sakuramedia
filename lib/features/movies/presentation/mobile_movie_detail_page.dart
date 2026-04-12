import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/movie_plot_image_actions.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/playlists/presentation/movie_playlist_picker_dialog.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/media/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/media/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_inspector_dialog.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_bottom_info_bar.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_preview_overlay.dart';

class MobileMovieDetailPage extends StatefulWidget {
  const MobileMovieDetailPage({super.key, required this.movieNumber});

  final String movieNumber;

  @override
  State<MobileMovieDetailPage> createState() => _MobileMovieDetailPageState();
}

class _MobileMovieDetailPageState extends State<MobileMovieDetailPage> {
  late final MovieDetailController _controller;
  final Map<int, List<MovieMediaPointDto>> _pointOverrides =
      <int, List<MovieMediaPointDto>>{};
  int? _selectedMediaId;
  bool? _isSubscribedOverride;
  bool? _isCollectionOverride;
  bool _isSubscriptionUpdating = false;
  bool _isCollectionUpdating = false;

  @override
  void initState() {
    super.initState();
    _controller = MovieDetailController(
      movieNumber: widget.movieNumber,
      fetchMovieDetail: context.read<MoviesApi>().getMovieDetail,
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
    return ColoredBox(
      key: const Key('mobile-movie-detail-page-surface'),
      color: context.appColors.surfaceCard,
      child: AnimatedBuilder(
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

          return AppPullToRefresh(
            onRefresh: _handleRefresh,
            child: MovieDetailPageContent(
              movie: movie,
              mediaItemsOverride: mediaItems,
              selectedPreviewKey: _controller.selectedPreviewKey,
              selectedPreviewUrl: _controller.selectedPreviewUrl,
              isCollection: isCollection,
              contentPadding: EdgeInsets.symmetric(
                horizontal: context.appSpacing.sm,
              ),
              bottomInfoBarVariant:
                  MovieDetailBottomInfoBarVariant.mobileFullWidth,
              isSubscribed: isSubscribed,
              isSubscriptionUpdating: _isSubscriptionUpdating,
              isCollectionUpdating: _isCollectionUpdating,
              selectedMediaId: selectedMedia?.mediaId,
              statItems: buildMovieDetailStatItems(context, movie),
              scrollPhysics: const AlwaysScrollableScrollPhysics(),
              onSubscriptionTap:
                  _isSubscriptionUpdating
                      ? null
                      : () =>
                          _toggleMovieSubscription(isSubscribed: isSubscribed),
              onPlayTap:
                  selectedMedia != null && selectedMedia.hasPlayableUrl
                      ? () => _openMoviePlayer(mediaId: selectedMedia.mediaId)
                      : null,
              onPlaylistTap:
                  () => showMoviePlaylistPickerDialog(
                    context,
                    movieNumber: widget.movieNumber,
                    initialPlaylists: movie.playlists,
                    presentation: MoviePlaylistPickerPresentation.bottomDrawer,
                  ),
              onCollectionToggle:
                  _isCollectionUpdating
                      ? null
                      : () => _toggleMovieCollectionType(
                        isCollection: isCollection,
                      ),
              onMediaSelect:
                  (item) => setState(() {
                    _selectedMediaId = item.mediaId;
                  }),
              onOpenMediaPointPreview: _openMediaPointPreview,
              onRequestMediaPointMenu: _showMediaPointActions,
              onActorTap:
                  (actor) => MobileActorDetailRouteData(
                    actorId: actor.id,
                  ).push(context),
              onRequestPlotImageMenu:
                  (menuContext, index, globalPosition) =>
                      showMoviePlotImageActionMenu(
                        context: menuContext,
                        hostContext: context,
                        plotImages: movie.plotImages,
                        movieNumber: widget.movieNumber,
                        index: index,
                        globalPosition: globalPosition,
                        onSearchSimilar:
                            (hostContext, imageUrl, fileName) =>
                                _openImageSearchFromUrl(
                                  imageUrl: imageUrl,
                                  fileName: fileName,
                                ),
                      ),
              onOpenPlotPreview:
                  (index) => showMoviePlotPreviewOverlay(
                    context: context,
                    plotImages: movie.plotImages,
                    initialIndex: index,
                    presentation: MoviePlotPreviewPresentation.bottomDrawer,
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
                              onSearchSimilar:
                                  (hostContext, imageUrl, fileName) =>
                                      _openImageSearchFromUrl(
                                        imageUrl: imageUrl,
                                        fileName: fileName,
                                      ),
                            ),
                  ),
              onInspectorTap:
                  () => showMobileMovieDetailInspectorBottomSheet(
                    context: context,
                    movieNumber: movie.movieNumber,
                    selectedMedia: selectedMedia,
                    onSearchSimilar: (thumbnail, imageUrl, fileName) {
                      return _openImageSearchFromUrl(
                        imageUrl: imageUrl,
                        fileName: fileName,
                      );
                    },
                    onPlay:
                        (thumbnail) => _openMoviePlayer(
                          mediaId:
                              thumbnail.mediaId > 0
                                  ? thumbnail.mediaId
                                  : selectedMedia?.mediaId,
                          positionSeconds: thumbnail.offsetSeconds,
                        ),
                  ),
            ),
          );
        },
      ),
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

  Future<void> _handleRefresh() async {
    try {
      await _controller.refresh();
      if (mounted) {
        setState(() {
          _pointOverrides.clear();
          _selectedMediaId = null;
          _isSubscribedOverride = null;
          _isCollectionOverride = null;
        });
      }
      await _loadMovieCollectionStatus();
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
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
    return showAppBottomDrawer<void>(
      maxHeightFactor: 0.7,
      context: context,
      drawerKey: const Key('movie-media-point-preview-bottom-sheet'),
      builder:
          (_) => MediaPreviewDialog(
            item: _buildMediaPointPreviewItem(mediaItem, point),
            onSearchSimilar: () => _searchSimilarFromPoint(point),
            onPlay:
                mediaItem.hasPlayableUrl
                    ? () => _openMoviePlayer(
                      mediaId: mediaItem.mediaId,
                      positionSeconds: point.offsetSeconds,
                    )
                    : null,
            onPointRemoved:
                () => _applyPointListOverride(
                  mediaItem.mediaId,
                  mediaItem.points
                      .where((candidate) => candidate.pointId != point.pointId)
                      .toList(growable: false),
                ),
            closeOnPointRemoved: true,
            presentation: MediaPreviewPresentation.bottomDrawer,
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
        _openMoviePlayer(
          mediaId: mediaItem.mediaId,
          positionSeconds: point.offsetSeconds,
        );
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
      await _openImageSearchFromUrl(
        imageUrl: imageUrl,
        fileName: _buildPointFileName(point),
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

  void _openMoviePlayer({int? mediaId, int? positionSeconds}) {
    MobileMoviePlayerRouteData(
      movieNumber: widget.movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
    ).push(context);
  }

  Future<void> _openImageSearchFromUrl({
    required String imageUrl,
    required String fileName,
  }) async {
    try {
      final imageBytes = await context.read<ApiClient>().getBytes(imageUrl);
      if (!mounted) {
        return;
      }
      final draftId = context.read<ImageSearchDraftStore>().save(
        fileName: fileName,
        bytes: imageBytes,
        mimeType: guessImageMimeType(fileName),
      );
      MobileImageSearchRouteData(
        draftId: draftId,
        currentMovieNumber: widget.movieNumber,
      ).push(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '读取图片失败，请稍后重试'));
    }
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
