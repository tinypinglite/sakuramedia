import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_copy.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_support.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/detail/movie_clip_section_mixin.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_behavior_mixin.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_clips_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subtitles_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_plot_image_actions.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/movie_playlist_picker_dialog.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_dialog.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_subtitle_viewer.dart';

class DesktopMovieDetailPage extends ConsumerStatefulWidget {
  const DesktopMovieDetailPage({super.key, required this.movieNumber});

  final String movieNumber;

  @override
  ConsumerState<DesktopMovieDetailPage> createState() =>
      _DesktopMovieDetailPageState();
}

class _DesktopMovieDetailPageState extends ConsumerState<DesktopMovieDetailPage>
    with MovieClipSectionMixin, MovieDetailBehaviorMixin {
  late final MovieSubscriptionEvents _subscriptionChangeNotifier;

  @override
  String get movieNumber => widget.movieNumber;

  @override
  String get pageCacheKey => desktopMovieDetailPageCacheKey(widget.movieNumber);

  @override
  MovieSubscriptionEvents get subscriptionChangeNotifier =>
      _subscriptionChangeNotifier;

  @override
  void initState() {
    super.initState();
    _subscriptionChangeNotifier = resolveMovieSubscriptionNotifier(context);
    // 挂 keepAlive link 到 RiverpodPageCache：详情 + 切片 provider 的
    // cacheLink 一并托管，跨导航保活；LRU 驱逐时统一 close。
    mountPageCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(movieDetailProvider(widget.movieNumber).notifier).load(),
      );
      unawaited(
        ref.read(movieClipsProvider(widget.movieNumber).notifier).load(),
      );
      loadMovieCollectionStatus();
    });
  }

  @override
  void dispose() {
    unmountPageCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(movieDetailProvider(widget.movieNumber));
    final clipsState = ref.watch(movieClipsProvider(widget.movieNumber));
    final subtitlesState = ref.watch(
      movieSubtitlesProvider(widget.movieNumber),
    );
    return AppPageRefreshScope(
      onRefresh: () async {
        await ref
            .read(movieDetailProvider(widget.movieNumber).notifier)
            .refresh();
        ref.invalidate(movieSubtitlesProvider(widget.movieNumber));
      },
      child: Builder(
        builder: (context) {
          if (detailState.isLoading) {
            return const MovieDetailLoadingSkeleton();
          }

          if (detailState.errorMessage != null || detailState.movie == null) {
            return MovieDetailErrorState(
              message: detailState.errorMessage ?? '影片详情暂时无法加载，请稍后重试',
              onRetry: () => ref
                  .read(movieDetailProvider(widget.movieNumber).notifier)
                  .load(),
            );
          }

          final movie = detailState.movie!;
          final derived = resolveDerived(movie, detailState);
          final isSubscribed = derived.isSubscribed;
          final isBlacklisted = derived.isBlacklisted;
          final isCollection = derived.isCollection;
          final isActionControlsLocked = derived.isActionControlsLocked;
          final selectedMedia = derived.selectedMedia;
          return MovieDetailPageContent(
            movie: movie,
            mediaItemsOverride: derived.visibleMediaItems,
            selectedPreviewKey: detailState.selectedPreviewKey,
            selectedPreviewUrl: detailState.selectedPreviewUrl,
            isCollection: isCollection,
            isSubscribed: isSubscribed,
            isCollectionUpdating: isCollectionUpdating,
            isSubscriptionUpdating: isSubscriptionUpdating,
            isMoreActionsUpdating: activeMovieAction != null,
            selectedMediaId: selectedMedia?.mediaId,
            statItems: buildMovieDetailStatItems(context, movie),
            similarMovies: detailState.similarMovies,
            isSimilarMoviesLoading: detailState.isSimilarMoviesLoading,
            similarMoviesErrorMessage: detailState.similarMoviesErrorMessage,
            onRetrySimilarMovies: () => ref
                .read(movieDetailProvider(widget.movieNumber).notifier)
                .retryLoadSimilarMovies(),
            onSimilarMovieTap: (similarMovie) => context.pushDesktopMovieDetail(
              movieNumber: similarMovie.movieNumber,
              fallbackPath: buildDesktopMovieDetailRoutePath(
                widget.movieNumber,
              ),
            ),
            onSubscriptionTap: isActionControlsLocked || isBlacklisted
                ? null
                : () => toggleMovieSubscription(isSubscribed: isSubscribed),
            onMoreActionsTap: isActionControlsLocked
                ? null
                : (globalPosition) => _showMovieActionMenu(
                    globalPosition,
                    movie,
                    isSubscribed,
                    isBlacklisted,
                    selectedMedia,
                  ),
            onPlayTap: selectedMedia != null && selectedMedia.hasPlayableUrl
                ? () => context.pushDesktopMoviePlayer(
                    movieNumber: widget.movieNumber,
                    fallbackPath: buildDesktopMovieDetailRoutePath(
                      widget.movieNumber,
                    ),
                    mediaId: selectedMedia.mediaId,
                  )
                : null,
            onPlaylistTap: () => showMoviePlaylistPickerDialog(
              context,
              movieNumber: widget.movieNumber,
              initialPlaylists: movie.playlists,
              presentation: MoviePlaylistPickerPresentation.dialog,
            ),
            onCollectionToggle: isActionControlsLocked
                ? null
                : () => toggleMovieCollectionType(isCollection: isCollection),
            onMediaSelect: (item) => setState(() {
              selectedMediaId = item.mediaId;
            }),
            isDeletingSelectedMedia:
                selectedMedia != null &&
                deletingMediaId == selectedMedia.mediaId,
            onDeleteSelectedMedia: selectedMedia == null
                ? null
                : deleteSelectedMedia,
            onOpenMediaPointPreview: openMediaPointPreview,
            onRequestMediaPointMenu: showMediaPointActions,
            onActorTap: (actor) => context.pushDesktopActorDetail(
              actorId: actor.id,
              fallbackPath: buildDesktopMovieDetailRoutePath(
                widget.movieNumber,
              ),
            ),
            onSeriesTap: movie.seriesId == null
                ? null
                : () => context.pushDesktopMovieSeries(
                    seriesId: movie.seriesId!,
                    seriesName: movie.seriesName,
                    fallbackPath: buildDesktopMovieDetailRoutePath(
                      widget.movieNumber,
                    ),
                  ),
            onTagTap: (tag) => context.pushDesktopTags(tagId: tag.tagId),
            onRequestPlotImageMenu: (menuContext, index, globalPosition) =>
                showMoviePlotImageActionMenu(
                  context: menuContext,
                  hostContext: context,
                  plotImages: movie.plotImages,
                  movieNumber: widget.movieNumber,
                  index: index,
                  globalPosition: globalPosition,
                ),
            onOpenPlotPreview: (index) => showMoviePlotPreviewOverlay(
              context: context,
              plotImages: movie.plotImages,
              initialIndex: index,
              onRequestImageMenu: (menuContext, previewIndex, globalPosition) =>
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
            onInspectorTap: () => openInspector(movie, selectedMedia),
            clips: clipsState.clips,
            isClipsLoading: clipsState.isLoading,
            clipsErrorMessage: clipsState.errorMessage,
            onRetryClips: () => ref
                .read(movieClipsProvider(widget.movieNumber).notifier)
                .retry(),
            onPlayClip: playMovieClip,
            onRenameClip: renameMovieClip,
            onDeleteClip: deleteMovieClip,
            onAddClipToCollection: addMovieClipToCollection,
            subtitleItems:
                subtitlesState.asData?.value.items ??
                const <MovieSubtitleItemDto>[],
            isSubtitlesLoading: subtitlesState.isLoading,
            subtitleErrorMessage: subtitlesState.hasError ? '请稍后重试' : null,
            onRetrySubtitles: () async {
              ref.invalidate(movieSubtitlesProvider(widget.movieNumber));
            },
            onOpenSubtitle: (item) =>
                showMovieSubtitleViewer(context, item: item),
          );
        },
      ),
    );
  }

  @override
  Future<bool?> confirmDeleteMedia(MovieMediaItemDto mediaItem) {
    return showAppConfirmDialog(
      context,
      title: '删除媒体文件',
      message: mediaDeleteMessage(mediaItem),
      confirmLabel: '删除',
      danger: true,
      dialogKey: const Key('movie-media-delete-confirm-dialog'),
      confirmKey: const Key('movie-media-delete-confirm'),
      cancelKey: const Key('movie-media-delete-cancel'),
      extraContent: Text(
        mediaItem.fileName.trim().isEmpty
            ? '媒体 ${mediaItem.mediaId}'
            : mediaItem.fileName.trim(),
        key: const Key('movie-media-delete-path'),
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          tone: AppTextTone.muted,
        ),
      ),
    );
  }

  Future<void> _showMovieActionMenu(
    Offset globalPosition,
    MovieDetailDto movie,
    bool isSubscribed,
    bool isBlacklisted,
    MovieMediaItemDto? selectedMedia,
  ) async {
    final action = await showMovieDetailDesktopActionMenu(
      context: context,
      globalPosition: globalPosition,
      actions: buildMovieDetailActionDescriptors(
        movie: movie,
        isSubscribed: isSubscribed,
        isBlacklisted: isBlacklisted,
      ),
    );
    if (!mounted || action == null) {
      return;
    }

    if (action == MovieDetailActionType.openInspector) {
      await openInspector(movie, selectedMedia);
      return;
    }

    if (action == MovieDetailActionType.refreshMetadata) {
      await _confirmRefreshMetadata();
      return;
    }

    await executeMovieAction(action);
  }

  @override
  Future<void> openInspector(
    MovieDetailDto movie,
    MovieMediaItemDto? selectedMedia,
  ) {
    return showMovieDetailInspectorDialog(
      context: context,
      movieNumber: movie.movieNumber,
      selectedMedia: selectedMedia,
    );
  }

  Future<void> _confirmRefreshMetadata() {
    var isSubmitting = false;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> handleConfirm() async {
            if (isSubmitting) {
              return;
            }
            setDialogState(() {
              isSubmitting = true;
            });
            final succeeded = await executeMovieAction(
              MovieDetailActionType.refreshMetadata,
            );
            if (!dialogContext.mounted) {
              return;
            }
            if (succeeded) {
              Navigator.of(dialogContext).pop();
              return;
            }
            setDialogState(() {
              isSubmitting = false;
            });
          }

          return AppDesktopDialog(
            dialogKey: const Key('movie-detail-refresh-metadata-dialog'),
            width: dialogContext.appLayoutTokens.dialogWidthSm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MovieDetailRefreshConfirmationCopy.title,
                  style: resolveAppTextStyle(
                    dialogContext,
                    size: AppTextSize.s18,
                  ),
                ),
                SizedBox(height: dialogContext.appSpacing.lg),
                Text(MovieDetailRefreshConfirmationCopy.description),
                SizedBox(height: dialogContext.appSpacing.sm),
                Text(
                  MovieDetailRefreshConfirmationCopy.hint,
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
                        key: const Key('movie-detail-refresh-metadata-cancel'),
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                        label: MovieDetailRefreshConfirmationCopy.cancelLabel,
                      ),
                    ),
                    SizedBox(width: dialogContext.appSpacing.md),
                    Expanded(
                      child: AppButton(
                        key: const Key('movie-detail-refresh-metadata-confirm'),
                        onPressed: isSubmitting ? null : handleConfirm,
                        label: MovieDetailRefreshConfirmationCopy.confirmLabel,
                        variant: AppButtonVariant.primary,
                        isLoading: isSubmitting,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Future<void> openMediaPointPreview(
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
  ) async {
    final action = await showMediaPreviewOverlay(
      context: context,
      presentation: MediaPreviewPresentation.dialog,
      builder: (_) => MediaPreviewDialog(
        item: buildMediaPointPreviewItem(mediaItem, point),
        availableActions: <MediaPreviewAction>{
          if (resolvePointImageUrl(point).isNotEmpty)
            MediaPreviewAction.searchSimilar,
          if (mediaItem.hasPlayableUrl) MediaPreviewAction.play,
        },
        onPointRemoved: () => applyPointListOverride(
          mediaItem.mediaId,
          mediaItem.points
              .where((candidate) => candidate.pointId != point.pointId)
              .toList(growable: false),
        ),
        closeOnPointRemoved: true,
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case MediaPreviewAction.searchSimilar:
        await searchSimilarFromPoint(point);
      case MediaPreviewAction.play:
        openPlayerForPoint(mediaItem, point);
      case MediaPreviewAction.openMovieDetail:
        return;
    }
  }

  @override
  Future<bool> searchSimilarFromPoint(MovieMediaPointDto point) async {
    final imageUrl = resolvePointImageUrl(point);
    if (imageUrl.isEmpty) {
      return false;
    }
    try {
      await launchDesktopImageSearchFromUrl(
        context,
        imageUrl: imageUrl,
        fallbackPath: buildDesktopMovieDetailRoutePath(widget.movieNumber),
        fileName: buildPointFileName(point),
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

  @override
  void openPlayerForPoint(
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
}
