import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/cast/data/cast_director.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_support.dart';
import 'package:sakuramedia/features/clips/presentation/clip_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_merge_playback_candidates.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/detail/movie_clip_section_mixin.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_behavior_mixin.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_clips_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subtitles_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_plot_image_actions.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/movie_playlist_picker_dialog.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_dialog.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/rating/movie_rating_inline_panel.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_merge_playback_candidate_list.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_subtitle_viewer.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

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

  bool _isLaunchingPlayback = false;

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
    if (detailState.isLoading && detailState.movie == null) {
      // loading 用占位影片渲染真实详情布局，由 [AppSkeletonizer] 灰化。
      // 暖重进（保活命中已有影片）不进骨架，旧内容常驻直到静默刷新完成。
      return AppSkeletonizer(
        enabled: true,
        child: MovieDetailPageContent(
          surfaceColor: context.appColors.surfaceElevated,
          movie: movieDetailPlaceholder(),
          selectedPreviewKey: '',
          selectedPreviewUrl: null,
          isSubscribed: false,
          isSubscriptionUpdating: false,
          selectedMediaId: null,
          similarMovies: movieListItemPlaceholders(count: 4),
          isSimilarMoviesLoading: false,
          onInspectorPaneTap: (_) {},
          onPlaylistTap: () {},
          onMediaSelect: (_) {},
          clips: clipPlaceholders(count: 4),
          subtitleItems: movieSubtitlePlaceholders(),
        ),
      );
    }

    if (detailState.errorMessage != null || detailState.movie == null) {
      return MovieDetailErrorState(
        message:
            detailState.errorMessage ??
            AppLocalizations.of(context).moviePageDetailLoadFailed,
        onRetry: () =>
            ref.read(movieDetailProvider(widget.movieNumber).notifier).load(),
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
    final canLaunchMergedPlayback =
        const ExternalPlayerChannel().isSupported &&
        externalPlayerSelection?.hasExternalPlayer == true;
    final l10n = AppLocalizations.of(context);
    final mergePlaybackCandidates = resolveMovieMergePlaybackCandidates(
      movie,
      useExternalPlayer: canLaunchMergedPlayback,
      l10n: l10n,
    );
    final mergePlaybackLabel = mergePlaybackCandidates.isEmpty
        ? null
        : mergePlaybackCandidates.length == 1
        ? l10n.moviePageMergedPlaybackSegments(
            mergePlaybackCandidates.single.segmentCount,
          )
        : l10n.moviePageMergedPlayback;
    return MovieDetailPageContent(
      surfaceColor: context.appColors.surfaceElevated,
      showSimilarMovies: ref.watch(movieSimilarityEnabledProvider),
      ratingPanel: MovieRatingInlinePanel(movieNumber: widget.movieNumber),
      movie: movie,
      mediaItemsOverride: derived.visibleMediaItems,
      selectedPreviewKey: detailState.selectedPreviewKey,
      selectedPreviewUrl: detailState.selectedPreviewUrl,
      isSubscribed: isSubscribed,
      isSubscriptionUpdating: isSubscriptionUpdating,
      isMoreActionsUpdating:
          activeMovieAction != null &&
          activeMovieAction != MovieDetailActionType.toggleFavorite,
      selectedMediaId: selectedMedia?.mediaId,
      similarMovies: detailState.similarMovies,
      isSimilarMoviesLoading: detailState.isSimilarMoviesLoading,
      similarMoviesErrorMessage: detailState.similarMoviesErrorMessage,
      onRetrySimilarMovies: () => ref
          .read(movieDetailProvider(widget.movieNumber).notifier)
          .retryLoadSimilarMovies(),
      onSimilarMovieTap: (similarMovie) => context.pushDesktopMovieDetail(
        movieNumber: similarMovie.movieNumber,
        fallbackPath: buildDesktopMovieDetailRoutePath(widget.movieNumber),
      ),
      onSubscriptionTap: isActionControlsLocked || isBlacklisted
          ? null
          : () => toggleMovieSubscription(isSubscribed: isSubscribed),
      onFavoriteTap: isActionControlsLocked
          ? null
          : () => executeMovieAction(MovieDetailActionType.toggleFavorite),
      isFavoriteUpdating:
          activeMovieAction == MovieDetailActionType.toggleFavorite,
      onMoreActionsTap: isActionControlsLocked
          ? null
          : (globalPosition) => _showMovieActionMenu(
              globalPosition,
              movie,
              isSubscribed,
              isCollection,
              isBlacklisted,
              selectedMedia,
            ),
      onPlayTap: selectedMedia != null && selectedMedia.hasPlayableUrl
          ? () => _openMoviePlayer(movie: movie, mediaId: selectedMedia.mediaId)
          : null,
      isPlayLoading: _isLaunchingPlayback,
      onPlaylistTap: () async {
        await showMoviePlaylistPickerDialog(
          context,
          movieNumber: widget.movieNumber,
          initialPlaylists: movie.playlists,
          presentation: MoviePlaylistPickerPresentation.dialog,
        );
        if (mounted) await reloadPlaylistMembership();
      },
      onMediaSelect: selectMedia,
      mergePlaybackLabel: mergePlaybackLabel,
      onMergePlaybackTap: mergePlaybackLabel == null || _isLaunchingPlayback
          ? null
          : () => _openMergedPlayback(movie, mergePlaybackCandidates),
      isMergePlaybackLoading: _isLaunchingPlayback,
      isDeletingSelectedMedia:
          selectedMedia != null && deletingMediaId == selectedMedia.mediaId,
      onDeleteSelectedMedia: selectedMedia == null ? null : deleteSelectedMedia,
      onEditMediaTags: selectedMedia == null
          ? null
          : (mediaItem) => editMediaTags(mediaItem, mobile: false),
      onOpenMediaPointPreview: openMediaPointPreview,
      onRequestMediaPointMenu: showMediaPointActions,
      onActorTap: (actor) => context.pushDesktopActorDetail(
        actorId: actor.id,
        fallbackPath: buildDesktopMovieDetailRoutePath(widget.movieNumber),
      ),
      moviesApi: ref.read(moviesApiProvider),
      actorsApi: ref.read(actorsApiProvider),
      onActorsChanged: () =>
          ref.read(movieDetailProvider(widget.movieNumber).notifier).refresh(),
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
      onInspectorPaneTap: (pane) =>
          openInspector(movie, selectedMedia, pane: pane),
      clips: clipsState.clips,
      isClipsLoading: clipsState.isLoading,
      clipsErrorMessage: clipsState.errorMessage,
      onRetryClips: () =>
          ref.read(movieClipsProvider(widget.movieNumber).notifier).retry(),
      onOpenClipActions: openMovieClipActions,
      onPlayClip: playMovieClip,
      onRenameClip: renameMovieClip,
      onDeleteClip: deleteMovieClip,
      onAddClipToCollection: addMovieClipToCollection,
      subtitleItems:
          subtitlesState.asData?.value.items ?? const <MovieSubtitleItemDto>[],
      isSubtitlesLoading: subtitlesState.isLoading,
      subtitleErrorMessage: subtitlesState.hasError
          ? l10n.errorRetryLater
          : null,
      onRetrySubtitles: () async {
        ref.invalidate(movieSubtitlesProvider(widget.movieNumber));
      },
      onOpenSubtitle: (item) => showMovieSubtitleViewer(context, item: item),
    );
  }

  @override
  Future<bool?> confirmDeleteMedia(MovieMediaItemDto mediaItem) {
    final l10n = AppLocalizations.of(context);
    return showAppConfirmDialog(
      context,
      title: l10n.moviePageMediaDeleteTitle,
      message: mediaDeleteMessage(mediaItem),
      confirmLabel: l10n.commonDelete,
      danger: true,
      dialogKey: const Key('movie-media-delete-confirm-dialog'),
      confirmKey: const Key('movie-media-delete-confirm'),
      cancelKey: const Key('movie-media-delete-cancel'),
      extraContent: Text(
        mediaItem.fileName.trim().isEmpty
            ? l10n.moviePageMediaLabel(mediaItem.mediaId)
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
    bool isCollection,
    bool isBlacklisted,
    MovieMediaItemDto? selectedMedia,
  ) async {
    final action = await showMovieDetailDesktopActionMenu(
      context: context,
      globalPosition: globalPosition,
      actions: buildMovieDetailActionDescriptors(
        l10n: AppLocalizations.of(context),
        isSubscribed: isSubscribed,
        isCollection: isCollection,
        isBlacklisted: isBlacklisted,
        canCast:
            isCastPlatformSupported &&
            selectedMedia != null &&
            selectedMedia.hasPlayableUrl,
        castSessionLabel: activeCastSessionLabel(movie),
      ),
    );
    if (!mounted || action == null) {
      return;
    }

    await handleMovieActionSelection(
      action,
      movie: movie,
      selectedMedia: selectedMedia,
    );
  }

  @override
  Future<void> openInspector(
    MovieDetailDto movie,
    MovieMediaItemDto? selectedMedia, {
    required MovieDetailInspectorPane pane,
  }) {
    return showMovieDetailInspectorDialog(
      context: context,
      movieNumber: movie.movieNumber,
      movieTitle: movie.title,
      movieCoverUrl: movie.preferredCoverUrl,
      selectedMedia: selectedMedia,
      pane: pane,
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
      case MediaPreviewAction.addToCollection:
        return;
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
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.moviePageImageLoadFailed,
            l10n: l10n,
          ),
        );
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

  void _openMoviePlayer({
    MovieDetailDto? movie,
    int? mediaId,
    int? positionSeconds,
  }) {
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
        movie: movie ?? ref.read(movieDetailProvider(widget.movieNumber)).movie,
      ).whenComplete(() {
        if (mounted) {
          setState(() {
            _isLaunchingPlayback = false;
          });
        }
      }),
    );
  }

  Future<void> _openMergedPlayback(
    MovieDetailDto movie,
    List<MovieMergePlaybackCandidateDto> candidates,
  ) async {
    if (_isLaunchingPlayback) {
      return;
    }
    final candidate = await _pickMergePlaybackCandidate(candidates);
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
    return showDialog<MovieMergePlaybackCandidateDto>(
      context: context,
      builder: (dialogContext) => AppDesktopDialog(
        dialogKey: const Key('movie-merge-playback-library-dialog'),
        width: dialogContext.appLayoutTokens.dialogWidthSm,
        child: MovieMergePlaybackCandidateList(
          candidates: candidates,
          onSelected: (candidate) => Navigator.of(dialogContext).pop(candidate),
        ),
      ),
    );
  }
}
