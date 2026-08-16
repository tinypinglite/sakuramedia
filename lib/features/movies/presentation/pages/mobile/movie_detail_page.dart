import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/external_player/data/potplayer_launcher.dart';
import 'package:sakuramedia/features/external_player/presentation/external_player_availability.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_draft_store_provider.dart';
import 'package:sakuramedia/features/media/data/media_play_url_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_support.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/detail/movie_clip_section_mixin.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_behavior_mixin.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_clips_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_playback_options.dart';
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

  /// 播放模式显式选择；null 表示未选择，由 [_effectivePlayMode] 推导默认值
  /// （合并播放可用时默认合并，否则单个）。
  MoviePlayUrlMode? _playMode;

  /// 合并播放探测/拉起外部播放器进行中，播放按钮显示 loading 并禁用。
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
          final isCollection = derived.isCollection;
          final isActionControlsLocked = derived.isActionControlsLocked;
          final sourceOptions = derived.sourceOptions;
          final effectivePlaySource = derived.effectivePlaySource;
          final selectedMedia = derived.selectedMedia;
          final canLaunchPotPlayer =
              selectedMedia != null &&
              selectedMedia.hasPlayableUrl &&
              isPotPlayerSupported();
          final mergedPlaybackAvailable = _isMergedPlaybackAvailable;

          return MovieDetailPageContent(
                movie: movie,
                mediaItemsOverride: derived.visibleMediaItems,
                storageDescriptors: detailState.storageDescriptors,
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
                similarMoviesErrorMessage:
                    detailState.similarMoviesErrorMessage,
                onRetrySimilarMovies: () => ref
                    .read(movieDetailProvider(widget.movieNumber).notifier)
                    .retryLoadSimilarMovies(),
                onSimilarMovieTap:
                    (similarMovie) => MobileMovieDetailRouteData(
                      movieNumber: similarMovie.movieNumber,
                    ).push(context),
                scrollPhysics: const AlwaysScrollableScrollPhysics(),
                scrollViewBuilder:
                    (context, content, scrollPhysics) =>
                        AppAdaptiveRefreshScrollView(
                          onRefresh: _handleRefresh,
                          physics: scrollPhysics,
                          slivers: <Widget>[SliverToBoxAdapter(child: content)],
                        ),
                onSubscriptionTap:
                    isActionControlsLocked
                        ? null
                        : () => toggleMovieSubscription(
                          isSubscribed: isSubscribed,
                        ),
                onMoreActionsTap:
                    isActionControlsLocked
                        ? null
                        : (_) => _showMovieActionDrawer(
                          movie,
                          isSubscribed,
                          selectedMedia,
                        ),
                onPlayTap:
                    selectedMedia != null && selectedMedia.hasPlayableUrl
                        ? () => _openMoviePlayer(mediaId: selectedMedia.mediaId)
                        : null,
                onPotPlayerTap:
                    canLaunchPotPlayer
                        ? () => _launchPotPlayer(
                          mediaId: selectedMedia?.mediaId,
                        )
                        : null,
                sourceOptions: sourceOptions,
                selectedPlaySource: effectivePlaySource,
                onPlaySourceChanged: _handlePlaySourceChanged,
                mergedPlaybackAvailable: mergedPlaybackAvailable,
                selectedPlayMode: _effectivePlayMode,
                onPlayModeChanged: (mode) {
                  setState(() {
                    _playMode = mode;
                  });
                },
                isPlayLoading: _isLaunchingPlayback,
                onPlaylistTap:
                    () => showMoviePlaylistPickerDialog(
                      context,
                      movieNumber: widget.movieNumber,
                      initialPlaylists: movie.playlists,
                      presentation:
                          MoviePlaylistPickerPresentation.bottomDrawer,
                    ),
                onCollectionToggle:
                    isActionControlsLocked
                        ? null
                        : () => toggleMovieCollectionType(
                          isCollection: isCollection,
                        ),
                onMediaSelect:
                    (item) => setState(() {
                      selectedMediaId = item.mediaId;
                    }),
                isDeletingSelectedMedia:
                    selectedMedia != null &&
                    deletingMediaId == selectedMedia.mediaId,
                onDeleteSelectedMedia:
                    selectedMedia == null ? null : deleteSelectedMedia,
                onOpenMediaPointPreview: openMediaPointPreview,
                onRequestMediaPointMenu: showMediaPointActions,
                onActorTap:
                    (actor) => MobileActorDetailRouteData(
                      actorId: actor.id,
                    ).push(context),
                onTagTap: (tag) => context.pushMobileTags(tagId: tag.tagId),
                onSeriesTap:
                    movie.seriesId == null
                        ? null
                        : () => context.pushMobileMovieSeries(
                          seriesId: movie.seriesId!,
                          seriesName: movie.seriesName,
                          fallbackPath: buildMobileMovieDetailRoutePath(
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
              );
        },
      ),
    );
  }

  @override
  Future<bool?> confirmDeleteMedia(MovieMediaItemDto mediaItem) {
    final storage = resolveMediaStorageDescriptor(
      mediaItem.libraryId,
      ref.read(movieDetailProvider(widget.movieNumber)).storageDescriptors,
    );
    return showAppBottomDrawer<bool>(
      context: context,
      drawerKey: const Key('movie-media-delete-confirm-drawer'),
      maxHeightFactor: 0.48,
      builder:
          (drawerContext) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '删除媒体文件',
                style: resolveAppTextStyle(
                  drawerContext,
                  size: AppTextSize.s18,
                ),
              ),
              SizedBox(height: drawerContext.appSpacing.lg),
              Text(
                mediaDeleteMessage(
                  mediaItem,
                  isCloud115: storage.isCloud115,
                  isLocal: storage.isLocal,
                ),
              ),
              SizedBox(height: drawerContext.appSpacing.sm),
              Text(
                mediaStorageLabel(storage),
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
      await ref.read(movieDetailProvider(widget.movieNumber).notifier).refresh();
      if (mounted) {
        resetDetailOverridesAfterRefresh();
      }
      await loadMovieCollectionStatus();
      unawaited(ref.read(movieClipsProvider(widget.movieNumber).notifier).load());
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }

  Future<void> _showMovieActionDrawer(
    MovieDetailDto movie,
    bool isSubscribed,
    MovieMediaItemDto? selectedMedia,
  ) async {
    final action = await showMovieDetailMobileActionDrawer(
      context: context,
      movieNumber: movie.movieNumber,
      actions: buildMovieDetailActionDescriptors(
        movie: movie,
        isSubscribed: isSubscribed,
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
      onPlay:
          (thumbnail) => _openMoviePlayer(
            mediaId:
                thumbnail.mediaId > 0
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
      builder:
          (_) => MediaPreviewDialog(
            item: buildMediaPointPreviewItem(mediaItem, point),
            availableActions: <MediaPreviewAction>{
              if (resolvePointImageUrl(point).isNotEmpty)
                MediaPreviewAction.searchSimilar,
              if (mediaItem.hasPlayableUrl) MediaPreviewAction.play,
            },
            onPointRemoved:
                () => applyPointListOverride(
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

  /// 当前生效播放源：未显式选择时取该影片可播媒体的默认源。
  ///
  /// 合并可用性与播放启动都基于它，避免「可用性按默认源、启动却回退本地源」
  /// 的不一致（纯 115 多分段影片必须拿到 cloud115 源才能解析合并链接）。
  MoviePlayUrlSource? get _effectivePlaySource {
    final movie = ref.read(movieDetailProvider(widget.movieNumber)).movie;
    if (movie == null) {
      return playSource;
    }
    final sourceOptions = resolveMoviePlaybackSourceOptions(
      mediaItems: resolveMediaItems(movie),
      storageDescriptors: ref.read(movieDetailProvider(widget.movieNumber)).storageDescriptors,
    );
    return playSource ?? sourceOptions.defaultSource;
  }

  /// 合并播放对当前选中源是否可用（外部播放器就绪 + 该源多分段）。
  bool get _isMergedPlaybackAvailable {
    final movie = ref.read(movieDetailProvider(widget.movieNumber)).movie;
    if (movie == null) {
      return false;
    }
    final sourceOptions = resolveMoviePlaybackSourceOptions(
      mediaItems: resolveMediaItems(movie),
      storageDescriptors: ref.read(movieDetailProvider(widget.movieNumber)).storageDescriptors,
    );
    if (!isExternalPlayerReady(context)) {
      return false;
    }
    return switch (_effectivePlaySource) {
      MoviePlayUrlSource.local => sourceOptions.localCount >= 2,
      MoviePlayUrlSource.cloud115 => sourceOptions.cloud115Count >= 2,
      null => false,
    };
  }

  /// 当前生效播放模式：未显式选择时，合并播放可用则默认合并，否则单个。
  MoviePlayUrlMode get _effectivePlayMode =>
      _playMode ??
      (_isMergedPlaybackAvailable
          ? MoviePlayUrlMode.merged
          : MoviePlayUrlMode.single);

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
        playSource: _effectivePlaySource ?? MoviePlayUrlSource.local,
        playMode: _effectivePlayMode,
      ).whenComplete(() {
        if (mounted) {
          setState(() {
            _isLaunchingPlayback = false;
          });
        }
      }),
    );
  }

  void _launchPotPlayer({int? mediaId}) {
    if (_isLaunchingPlayback) {
      return;
    }
    setState(() {
      _isLaunchingPlayback = true;
    });
    unawaited(
      launchPotPlayerPlayback(
        context,
        movieNumber: widget.movieNumber,
        mediaId: mediaId,
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

  /// 切换播放源：选中该源下第一个可播放媒体；若合并模式在新源下不可用则回落到单个。
  void _handlePlaySourceChanged(MoviePlayUrlSource source) {
    final movie = ref.read(movieDetailProvider(widget.movieNumber)).movie;
    if (movie == null) {
      return;
    }
    setState(() {
      playSource = source;
      final target = resolveFirstPlayableMediaId(
        mediaItems: resolveMediaItems(movie),
        storageDescriptors: ref.read(movieDetailProvider(widget.movieNumber)).storageDescriptors,
        source: source,
      );
      if (target != null) {
        selectedMediaId = target;
      }
      final newSourceOptions = resolveMoviePlaybackSourceOptions(
        mediaItems: resolveMediaItems(movie),
        storageDescriptors: ref.read(movieDetailProvider(widget.movieNumber)).storageDescriptors,
      );
      final mergedStillAvailable =
          isExternalPlayerReady(context) &&
          switch (source) {
            MoviePlayUrlSource.local => newSourceOptions.localCount >= 2,
            MoviePlayUrlSource.cloud115 => newSourceOptions.cloud115Count >= 2,
          };
      if (_playMode == MoviePlayUrlMode.merged && !mergedStillAvailable) {
        _playMode = MoviePlayUrlMode.single;
      }
    });
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
