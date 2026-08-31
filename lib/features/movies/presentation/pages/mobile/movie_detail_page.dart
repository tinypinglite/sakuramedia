import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_draft_store_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_support.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/detail/movie_clip_section_mixin.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_behavior_mixin.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_clips_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subtitles_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_plot_image_actions.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/movie_playlist_picker_dialog.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_mobile_confirm_actions.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_dialog.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_bottom_info_bar.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_merge_playback_candidate_list.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_subtitle_viewer.dart';

class MobileMovieDetailPage extends ConsumerStatefulWidget {
  const MobileMovieDetailPage({super.key, required this.movieNumber});

  final String movieNumber;

  @override
  ConsumerState<MobileMovieDetailPage> createState() =>
      _MobileMovieDetailPageState();
}

class _MobileMovieDetailPageState extends ConsumerState<MobileMovieDetailPage>
    with MovieClipSectionMixin, MovieDetailBehaviorMixin {
  late final MovieSubscriptionEvents _subscriptionChangeNotifier;

  /// 播放入口进行中，播放按钮显示 loading 并禁用。
  bool _isLaunchingPlayback = false;

  @override
  String get movieNumber => widget.movieNumber;

  @override
  String get pageCacheKey => mobileMovieDetailPageCacheKey(widget.movieNumber);

  @override
  MovieSubscriptionEvents get subscriptionChangeNotifier =>
      _subscriptionChangeNotifier;

  @override
  void initState() {
    super.initState();
    _subscriptionChangeNotifier = resolveMovieSubscriptionNotifier(context);
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
    return ColoredBox(
      key: const Key('mobile-movie-detail-page-surface'),
      color: context.appColors.surfaceCard,
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
          final externalPlayerSelection = ref
              .watch(externalPlayerPreferenceProvider)
              .value;
          final mergePlaybackCandidates = movie.mergePlaybackCandidates;
          final canLaunchMergedPlayback =
              const ExternalPlayerChannel().isSupported &&
              externalPlayerSelection?.hasExternalPlayer == true;
          final mergePlaybackLabel =
              !canLaunchMergedPlayback || mergePlaybackCandidates.isEmpty
              ? null
              : mergePlaybackCandidates.length == 1
              ? '合并播放（${mergePlaybackCandidates.single.segmentCount} 段）'
              : '合并播放（${mergePlaybackCandidates.length} 个媒体库）';

          return MovieDetailPageContent(
            movie: movie,
            mediaItemsOverride: derived.visibleMediaItems,
            selectedPreviewKey: detailState.selectedPreviewKey,
            selectedPreviewUrl: detailState.selectedPreviewUrl,
            isCollection: isCollection,
            bottomInfoBarVariant:
                MovieDetailBottomInfoBarVariant.mobileFullWidth,
            isSubscribed: isSubscribed,
            isSubscriptionUpdating: isSubscriptionUpdating,
            isCollectionUpdating: isCollectionUpdating,
            isMoreActionsUpdating: activeMovieAction != null,
            selectedMediaId: selectedMedia?.mediaId,
            statItems: buildMovieDetailStatItems(context, movie),
            similarMovies: detailState.similarMovies,
            isSimilarMoviesLoading: detailState.isSimilarMoviesLoading,
            similarMoviesErrorMessage: detailState.similarMoviesErrorMessage,
            onRetrySimilarMovies: () => ref
                .read(movieDetailProvider(widget.movieNumber).notifier)
                .retryLoadSimilarMovies(),
            onSimilarMovieTap: (similarMovie) => MobileMovieDetailRouteData(
              movieNumber: similarMovie.movieNumber,
            ).push(context),
            scrollPhysics: const AlwaysScrollableScrollPhysics(),
            scrollViewBuilder: (context, content, scrollPhysics) =>
                AppAdaptiveRefreshScrollView(
                  onRefresh: _handleRefresh,
                  physics: scrollPhysics,
                  slivers: <Widget>[SliverToBoxAdapter(child: content)],
                ),
            onSubscriptionTap: isActionControlsLocked || isBlacklisted
                ? null
                : () => toggleMovieSubscription(isSubscribed: isSubscribed),
            onMoreActionsTap: isActionControlsLocked
                ? null
                : (_) => _showMovieActionDrawer(
                    movie,
                    isSubscribed,
                    isBlacklisted,
                    selectedMedia,
                  ),
            onPlayTap: selectedMedia != null && selectedMedia.hasPlayableUrl
                ? () => _openMoviePlayer(mediaId: selectedMedia.mediaId)
                : null,
            isPlayLoading: _isLaunchingPlayback,
            onPlaylistTap: () => showMoviePlaylistPickerDialog(
              context,
              movieNumber: widget.movieNumber,
              initialPlaylists: movie.playlists,
              presentation: MoviePlaylistPickerPresentation.bottomDrawer,
            ),
            onCollectionToggle: isActionControlsLocked
                ? null
                : () => toggleMovieCollectionType(isCollection: isCollection),
            onMediaSelect: selectMedia,
            mergePlaybackLabel: mergePlaybackLabel,
            onMergePlaybackTap:
                mergePlaybackLabel == null || _isLaunchingPlayback
                ? null
                : () => _openMergedPlayback(movie),
            isMergePlaybackLoading: _isLaunchingPlayback,
            isDeletingSelectedMedia:
                selectedMedia != null &&
                deletingMediaId == selectedMedia.mediaId,
            onDeleteSelectedMedia: selectedMedia == null
                ? null
                : deleteSelectedMedia,
            onOpenMediaPointPreview: openMediaPointPreview,
            onRequestMediaPointMenu: showMediaPointActions,
            onActorTap: (actor) =>
                MobileActorDetailRouteData(actorId: actor.id).push(context),
            onTagTap: (tag) => context.pushMobileTags(tagId: tag.tagId),
            onSeriesTap: movie.seriesId == null
                ? null
                : () => context.pushMobileMovieSeries(
                    seriesId: movie.seriesId!,
                    seriesName: movie.seriesName,
                    fallbackPath: buildMobileMovieDetailRoutePath(
                      widget.movieNumber,
                    ),
                  ),
            onRequestPlotImageMenu: (menuContext, index, globalPosition) =>
                showMoviePlotImageActionMenu(
                  context: menuContext,
                  hostContext: context,
                  plotImages: movie.plotImages,
                  movieNumber: widget.movieNumber,
                  index: index,
                  globalPosition: globalPosition,
                  onSearchSimilar: (hostContext, imageUrl, fileName) =>
                      _openImageSearchFromUrl(
                        imageUrl: imageUrl,
                        fileName: fileName,
                      ),
                ),
            onOpenPlotPreview: (index) => showMoviePlotPreviewOverlay(
              context: context,
              plotImages: movie.plotImages,
              initialIndex: index,
              presentation: MoviePlotPreviewPresentation.bottomDrawer,
              onRequestImageMenu: (menuContext, previewIndex, globalPosition) =>
                  showMoviePlotImageActionMenu(
                    context: menuContext,
                    hostContext: context,
                    plotImages: movie.plotImages,
                    movieNumber: widget.movieNumber,
                    index: previewIndex,
                    globalPosition: globalPosition,
                    closeCurrentRouteOnSearch: true,
                    onSearchSimilar: (hostContext, imageUrl, fileName) =>
                        _openImageSearchFromUrl(
                          imageUrl: imageUrl,
                          fileName: fileName,
                        ),
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
    return showAppBottomDrawer<bool>(
      context: context,
      drawerKey: const Key('movie-media-delete-confirm-drawer'),
      maxHeightFactor: 0.48,
      builder: (drawerContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '删除媒体文件',
            style: resolveAppTextStyle(drawerContext, size: AppTextSize.s18),
          ),
          SizedBox(height: drawerContext.appSpacing.lg),
          Text(mediaDeleteMessage(mediaItem)),
          SizedBox(height: drawerContext.appSpacing.sm),
          Text(
            mediaItem.fileName.trim().isEmpty
                ? '媒体 ${mediaItem.mediaId}'
                : mediaItem.fileName.trim(),
            key: const Key('movie-media-delete-path'),
            style: resolveAppTextStyle(
              drawerContext,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: drawerContext.appSpacing.xl),
          AppMobileConfirmActions(
            cancelKey: const Key('movie-media-delete-cancel'),
            confirmKey: const Key('movie-media-delete-confirm'),
            confirmLabel: '删除',
            isDangerous: true,
            onCancel: () => Navigator.of(drawerContext).pop(false),
            onConfirm: () => Navigator.of(drawerContext).pop(true),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await ref
          .read(movieDetailProvider(widget.movieNumber).notifier)
          .refresh();
      if (mounted) {
        resetDetailOverridesAfterRefresh();
      }
      await loadMovieCollectionStatus();
      unawaited(
        ref.read(movieClipsProvider(widget.movieNumber).notifier).load(),
      );
      ref.invalidate(movieSubtitlesProvider(widget.movieNumber));
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }

  Future<void> _showMovieActionDrawer(
    MovieDetailDto movie,
    bool isSubscribed,
    bool isBlacklisted,
    MovieMediaItemDto? selectedMedia,
  ) async {
    final action = await showMovieDetailMobileActionDrawer(
      context: context,
      movieNumber: movie.movieNumber,
      actions: buildMovieDetailActionDescriptors(
        movie: movie,
        isSubscribed: isSubscribed,
        isBlacklisted: isBlacklisted,
      ),
      onExecuteAction: executeMovieAction,
    );
    if (!mounted || action != MovieDetailActionType.openInspector) {
      return;
    }

    await openInspector(movie, selectedMedia);
  }

  @override
  Future<void> openInspector(
    MovieDetailDto movie,
    MovieMediaItemDto? selectedMedia,
  ) {
    return showMobileMovieDetailInspectorBottomSheet(
      context: context,
      movieNumber: movie.movieNumber,
      selectedMedia: selectedMedia,
      onSearchSimilar: (thumbnail, imageUrl, fileName) {
        return _openImageSearchFromUrl(imageUrl: imageUrl, fileName: fileName);
      },
      onPlay: (thumbnail) => _openMoviePlayer(
        mediaId: thumbnail.mediaId > 0
            ? thumbnail.mediaId
            : selectedMedia?.mediaId,
        positionSeconds: thumbnail.offsetSeconds,
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
      presentation: MediaPreviewPresentation.bottomDrawer,
      drawerKey: const Key('movie-media-point-preview-bottom-sheet'),
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
        presentation: MediaPreviewPresentation.bottomDrawer,
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case MediaPreviewAction.searchSimilar:
        await searchSimilarFromPoint(point);
      case MediaPreviewAction.play:
        _openMoviePlayer(
          mediaId: mediaItem.mediaId,
          positionSeconds: point.offsetSeconds,
        );
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
      await _openImageSearchFromUrl(
        imageUrl: imageUrl,
        fileName: buildPointFileName(point),
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
    _openMoviePlayer(
      mediaId: mediaItem.mediaId,
      positionSeconds: point.offsetSeconds,
    );
  }

  void _openMoviePlayer({int? mediaId, int? positionSeconds}) {
    if (_isLaunchingPlayback) {
      return;
    }
    setState(() {
      _isLaunchingPlayback = true;
    });
    unawaited(
      launchMoviePlayback(
        context,
        movieNumber: widget.movieNumber,
        mediaId: mediaId,
        positionSeconds: positionSeconds,
        movie: ref.read(movieDetailProvider(widget.movieNumber)).movie,
      ).whenComplete(() {
        if (mounted) {
          setState(() {
            _isLaunchingPlayback = false;
          });
        }
      }),
    );
  }

  Future<void> _openMergedPlayback(MovieDetailDto movie) async {
    if (_isLaunchingPlayback) {
      return;
    }
    final candidate = await _pickMergePlaybackCandidate(
      movie.mergePlaybackCandidates,
    );
    if (candidate == null || !mounted) {
      return;
    }
    setState(() {
      _isLaunchingPlayback = true;
    });
    try {
      await launchMovieMergedPlayback(
        context,
        movieNumber: movie.movieNumber,
        libraryId: candidate.libraryId,
        movie: movie,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingPlayback = false;
        });
      }
    }
  }

  Future<MovieMergePlaybackCandidateDto?> _pickMergePlaybackCandidate(
    List<MovieMergePlaybackCandidateDto> candidates,
  ) {
    if (candidates.length == 1) {
      return Future<MovieMergePlaybackCandidateDto?>.value(candidates.single);
    }
    return showAppBottomDrawer<MovieMergePlaybackCandidateDto>(
      context: context,
      drawerKey: const Key('movie-merge-playback-library-drawer'),
      maxHeightFactor: 0.5,
      builder: (drawerContext) => MovieMergePlaybackCandidateList(
        candidates: candidates,
        onSelected: (candidate) => Navigator.of(drawerContext).pop(candidate),
      ),
    );
  }

  Future<void> _openImageSearchFromUrl({
    required String imageUrl,
    required String fileName,
  }) async {
    try {
      final imageBytes = await ref.read(apiClientProvider).getBytes(imageUrl);
      if (!mounted) {
        return;
      }
      final draftId = ref
          .read(imageSearchDraftStoreProvider)
          .save(
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
}
