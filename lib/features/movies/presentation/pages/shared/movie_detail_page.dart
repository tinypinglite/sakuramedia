import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/cast/data/cast_director.dart';
import 'package:sakuramedia/features/cast/presentation/actions/cast_movie_playback.dart';
import 'package:sakuramedia/features/cast/presentation/providers/cast_session_provider.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_merge_playback_candidates.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/detail/movie_clip_section_mixin.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_action_result.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_overlay_presenter.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_view_model.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_interaction_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subtitles_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_clips_provider.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_actor_picker_sheet.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/rating/movie_rating_inline_panel.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';

class MovieDetailPage extends ConsumerStatefulWidget {
  const MovieDetailPage({
    super.key,
    required this.movieNumber,
    required this.mobile,
  });

  final String movieNumber;
  final bool mobile;

  @override
  ConsumerState<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends ConsumerState<MovieDetailPage>
    with MovieClipSectionMixin {
  RiverpodPageHandle? _pageCacheHandle;

  @override
  String get movieNumber => widget.movieNumber;

  MovieDetailOverlayPresenter get _overlays =>
      MovieDetailOverlayPresenter(mobile: widget.mobile);

  MovieDetailInteraction get _interaction =>
      ref.read(movieDetailInteractionProvider(movieNumber).notifier);

  Color get _surfaceColor => widget.mobile
      ? context.appColors.surfaceCard
      : context.appColors.surfaceElevated;

  String get _pageCacheKey => widget.mobile
      ? mobileMovieDetailPageCacheKey(movieNumber)
      : desktopMovieDetailPageCacheKey(movieNumber);

  @override
  void initState() {
    super.initState();
    _mountPageCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(movieDetailProvider(movieNumber).notifier).load());
      unawaited(ref.read(movieClipsProvider(movieNumber).notifier).load());
      unawaited(_interaction.loadMovieCollectionStatus());
    });
  }

  @override
  void dispose() {
    _pageCacheHandle?.release();
    super.dispose();
  }

  void _mountPageCache() {
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: _pageCacheKey,
          resolveLinks: () {
            final links = <KeepAliveLink>[];
            final detailLink = ref
                .read(movieDetailProvider(movieNumber).notifier)
                .cacheLink;
            final clipsLink = ref
                .read(movieClipsProvider(movieNumber).notifier)
                .cacheLink;
            if (detailLink != null) links.add(detailLink);
            if (clipsLink != null) links.add(clipsLink);
            return links;
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(movieDetailProvider(movieNumber));
    final clipsState = ref.watch(movieClipsProvider(movieNumber));
    final subtitlesState = ref.watch(movieSubtitlesProvider(movieNumber));
    final interaction = ref.watch(movieDetailInteractionProvider(movieNumber));
    final config = MovieDetailViewConfig(
      surfaceColor: _surfaceColor,
      showSimilarMovies: ref.watch(movieSimilarityEnabledProvider),
      ratingPanel: MovieRatingInlinePanel(movieNumber: movieNumber),
    );

    if (detailState.isLoading && detailState.movie == null) {
      final placeholderConfig = MovieDetailViewConfig(
        surfaceColor: _surfaceColor,
        showSimilarMovies: config.showSimilarMovies,
      );
      return _wrapMobile(
        AppSkeletonizer(
          enabled: true,
          child: MovieDetailPageContent(
            data: MovieDetailViewData.placeholder(),
            state: const MovieDetailViewState(),
            actions: MovieDetailViewActions.placeholder(),
            config: placeholderConfig,
          ),
        ),
      );
    }

    if (detailState.errorMessage != null || detailState.movie == null) {
      return _wrapMobile(
        MovieDetailErrorState(
          message:
              detailState.errorMessage ??
              AppLocalizations.of(context).moviePageDetailLoadFailed,
          onRetry: () =>
              ref.read(movieDetailProvider(movieNumber).notifier).load(),
        ),
      );
    }

    final movie = detailState.movie!;
    final derived = interaction.derive(movie);
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

    final data = MovieDetailViewData(
      movie: movie,
      mediaItems: derived.mediaItems,
      selectedPreviewKey: detailState.selectedPreviewKey,
      selectedPreviewUrl: detailState.selectedPreviewUrl,
      selectedMediaId: selectedMedia?.mediaId,
      similarMovies: detailState.similarMovies,
      clips: clipsState.clips,
      subtitleItems:
          subtitlesState.asData?.value.items ?? const <MovieSubtitleItemDto>[],
    );
    final state = MovieDetailViewState(
      isSubscribed: derived.isSubscribed,
      isSubscriptionUpdating: interaction.isSubscriptionUpdating,
      isFavoriteUpdating:
          interaction.activeMovieAction == MovieDetailActionType.toggleFavorite,
      isMoreActionsUpdating:
          interaction.activeMovieAction != null &&
          interaction.activeMovieAction != MovieDetailActionType.toggleFavorite,
      isDeletingSelectedMedia:
          selectedMedia != null &&
          interaction.deletingMediaId == selectedMedia.mediaId,
      isPlayLoading: interaction.isLaunchingPlayback,
      mergePlaybackLabel: mergePlaybackLabel,
      isMergePlaybackLoading: interaction.isLaunchingPlayback,
      isSimilarMoviesLoading: detailState.isSimilarMoviesLoading,
      similarMoviesErrorMessage: detailState.similarMoviesErrorMessage,
      isClipsLoading: clipsState.isLoading,
      clipsErrorMessage: clipsState.errorMessage,
      isSubtitlesLoading: subtitlesState.isLoading,
      subtitleErrorMessage: subtitlesState.hasError
          ? l10n.errorRetryLater
          : null,
    );

    final actions = MovieDetailViewActions(
      onSubscriptionTap: derived.isActionControlsLocked || derived.isBlacklisted
          ? null
          : () => _toggleSubscription(derived.isSubscribed),
      onFavoriteTap: derived.isActionControlsLocked
          ? null
          : () => _toggleFavorite(movie),
      onMoreActionsTap: derived.isActionControlsLocked
          ? null
          : (position) => _showActionMenu(position, movie, derived),
      onPlayTap: selectedMedia != null && selectedMedia.hasPlayableUrl
          ? () => _openMoviePlayer(movie: movie, mediaId: selectedMedia.mediaId)
          : null,
      onPlaylistTap: () => unawaited(_openPlaylistPicker(movie)),
      onMediaSelect: _interaction.selectMedia,
      onMergePlaybackTap:
          mergePlaybackLabel == null || interaction.isLaunchingPlayback
          ? null
          : () => _openMergedPlayback(movie, mergePlaybackCandidates),
      onDeleteSelectedMedia: selectedMedia == null
          ? null
          : (media) => unawaited(_deleteMedia(media)),
      onEditMediaTags: selectedMedia == null
          ? null
          : (media) => unawaited(_editMediaTags(media)),
      onOpenMediaPointPreview: (media, point) =>
          unawaited(_openMediaPointPreview(media, point)),
      onRequestMediaPointMenu: _showMediaPointActions,
      onActorTap: (actor) => _openActor(actor.id),
      actorActions: _actorActions(),
      onSeriesTap: movie.seriesId == null ? null : () => _openSeries(movie),
      onTagTap: (tag) => _openTag(tag.tagId),
      onRequestPlotImageMenu: _showPlotImageMenu,
      onOpenPlotPreview: _openPlotPreview,
      onRetrySimilarMovies: () => ref
          .read(movieDetailProvider(movieNumber).notifier)
          .retryLoadSimilarMovies(),
      onSimilarMovieTap: (similarMovie) => _openMovie(similarMovie.movieNumber),
      onRetryClips: () =>
          ref.read(movieClipsProvider(movieNumber).notifier).retry(),
      onOpenClipActions: openMovieClipActions,
      onPlayClip: playMovieClip,
      onRenameClip: renameMovieClip,
      onDeleteClip: deleteMovieClip,
      onAddClipToCollection: addMovieClipToCollection,
      onRetrySubtitles: () async {
        ref.invalidate(movieSubtitlesProvider(movieNumber));
      },
      onOpenSubtitle: (item) =>
          _overlays.openSubtitle(context: context, item: item),
      onInspectorPaneTap: (pane) => _openInspector(movie, selectedMedia, pane),
    );

    return _wrapMobile(
      MovieDetailPageContent(
        data: data,
        state: state,
        actions: actions,
        config: config,
      ),
    );
  }

  Widget _wrapMobile(Widget child) {
    if (!widget.mobile) return child;
    return ColoredBox(
      key: const Key('mobile-movie-detail-page-surface'),
      color: context.appColors.surfaceCard,
      child: child,
    );
  }

  Future<void> _toggleSubscription(bool isSubscribed) async {
    final result = await _interaction.toggleSubscription(
      isSubscribed: isSubscribed,
    );
    if (!mounted) return;
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  Future<void> _toggleFavorite(MovieDetailDto movie) async {
    final result = await _interaction.toggleFavorite(
      movie: movie,
      isFavorite: movie.playlists.any(
        (playlist) => playlist.kind == PlaylistKind.favorites,
      ),
    );
    _showActionFeedback(result);
  }

  Future<void> _showActionMenu(
    Offset globalPosition,
    MovieDetailDto movie,
    MovieDetailDerived derived,
  ) async {
    final selectedMedia = derived.selectedMedia;
    final action = await _overlays.showActionMenu(
      context: context,
      globalPosition: globalPosition,
      movie: movie,
      isSubscribed: derived.isSubscribed,
      isCollection: derived.isCollection,
      isBlacklisted: derived.isBlacklisted,
      selectedMedia: selectedMedia,
      castSessionLabel: _activeCastSessionLabel(movie),
      canCast:
          isCastPlatformSupported &&
          selectedMedia != null &&
          selectedMedia.hasPlayableUrl,
    );
    if (!mounted || action == null) return;
    await _handleActionSelection(action, movie, derived);
  }

  Future<void> _handleActionSelection(
    MovieDetailActionType action,
    MovieDetailDto movie,
    MovieDetailDerived derived,
  ) async {
    switch (action) {
      case MovieDetailActionType.castToDevice:
        final castSession = ref.read(castSessionControllerProvider);
        if (castSession != null &&
            castSession.movieNumber == movie.movieNumber) {
          openCastRemotePage(context);
        } else {
          await launchMovieCast(
            context,
            movie: movie,
            selectedMedia: derived.selectedMedia,
          );
        }
      case MovieDetailActionType.refreshMetadata:
        final confirmed = await _overlays.confirmRefreshMetadata(
          context: context,
          isActorsManuallyManaged: movie.isActorsManuallyManaged,
        );
        if (confirmed) {
          _showActionFeedback(await _interaction.executeRemoteAction(action));
        }
      case MovieDetailActionType.openMagnetSearch:
        await _openInspector(
          movie,
          derived.selectedMedia,
          MovieDetailInspectorPane.magnetSearch,
        );
      case MovieDetailActionType.toggleSubscription:
        await _toggleSubscription(derived.isSubscribed);
      case MovieDetailActionType.toggleFavorite:
        await _toggleFavorite(movie);
      case MovieDetailActionType.toggleBlacklist:
        final blacklist = !derived.isBlacklisted;
        if (blacklist && !await _overlays.confirmBlacklist(context)) {
          return;
        }
        _showActionFeedback(
          await _interaction.setBlacklisted(isBlacklisted: blacklist),
        );
      case MovieDetailActionType.recomputeHeat:
        _showActionFeedback(await _interaction.executeRemoteAction(action));
      case MovieDetailActionType.toggleCollectionType:
        _showActionFeedback(
          await _interaction.toggleCollection(
            isCollection: derived.isCollection,
          ),
        );
    }
  }

  String? _activeCastSessionLabel(MovieDetailDto movie) {
    final session = ref.read(castSessionControllerProvider);
    if (session == null || session.movieNumber != movie.movieNumber) {
      return null;
    }
    return AppLocalizations.of(
      context,
    ).moviePageCastSessionLabel(session.device.name);
  }

  Future<void> _openPlaylistPicker(MovieDetailDto movie) async {
    await _overlays.showPlaylistPicker(context: context, movie: movie);
    if (!mounted) return;
    _showActionFeedback(await _interaction.reloadPlaylistMembership());
  }

  Future<void> _deleteMedia(MovieMediaItemDto media) async {
    final confirmed = await _overlays.confirmDeleteMedia(
      context: context,
      mediaItem: media,
    );
    if (confirmed != true) return;
    _showActionFeedback(await _interaction.deleteMedia(media.mediaId));
  }

  Future<void> _editMediaTags(MovieMediaItemDto media) async {
    final assignment = await _overlays.editMediaTags(
      context: context,
      mediaItem: media,
    );
    if (assignment == null) return;
    _showActionFeedback(await _interaction.refreshAfterTagAssignment());
  }

  Future<void> _openMediaPointPreview(
    MovieMediaItemDto media,
    MovieMediaPointDto point,
  ) async {
    final action = await _overlays.openMediaPointPreview(
      context: context,
      item: buildMediaPointPreviewItem(
        movieNumber: movieNumber,
        mediaItem: media,
        point: point,
      ),
      availableActions: <MediaPreviewAction>{
        if (resolvePointImageUrl(point).isNotEmpty)
          MediaPreviewAction.searchSimilar,
        if (media.hasPlayableUrl) MediaPreviewAction.play,
      },
      onPointRemoved: () => _interaction.applyPointListOverride(
        media.mediaId,
        media.points
            .where((candidate) => candidate.pointId != point.pointId)
            .toList(growable: false),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case MediaPreviewAction.searchSimilar:
        await _searchSimilarFromPoint(point);
      case MediaPreviewAction.play:
        _openMoviePlayer(
          mediaId: media.mediaId,
          positionSeconds: point.offsetSeconds,
        );
      case MediaPreviewAction.addToCollection:
      case MediaPreviewAction.openMovieDetail:
        return;
    }
  }

  Future<void> _showMediaPointActions(
    BuildContext menuContext,
    MovieMediaItemDto media,
    MovieMediaPointDto point,
    Offset globalPosition,
  ) async {
    final currentPoint = _interaction.findCurrentPoint(
      media.mediaId,
      point.pointId,
    );
    final action = await showAppActionMenu<AppImageActionType>(
      context: menuContext,
      globalPosition: globalPosition,
      items: buildImageActionMenuItems(
        _buildMediaPointActionDescriptors(
          media,
          point,
          currentPoint,
          resolvePointImageUrl(point).isNotEmpty,
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case AppImageActionType.searchSimilar:
        await _searchSimilarFromPoint(point);
      case AppImageActionType.saveToLocal:
        _showImageSaveResult(await _interaction.savePointImage(point));
      case AppImageActionType.toggleMark:
        _showActionFeedback(
          await _interaction.toggleMediaPoint(media, point, currentPoint),
        );
      case AppImageActionType.play:
        _openMoviePlayer(
          mediaId: media.mediaId,
          positionSeconds: point.offsetSeconds,
        );
      case AppImageActionType.addToCollection:
      case AppImageActionType.setCover:
      case AppImageActionType.movieDetail:
        return;
    }
  }

  List<AppImageActionDescriptor> _buildMediaPointActionDescriptors(
    MovieMediaItemDto media,
    MovieMediaPointDto point,
    MovieMediaPointDto? currentPoint,
    bool hasImage,
  ) {
    final l10n = AppLocalizations.of(context);
    return <AppImageActionDescriptor>[
      if (ref.read(imageSearchEnabledProvider))
        AppImageActionDescriptor(
          type: AppImageActionType.searchSimilar,
          label: l10n.moviePageActionSimilarImage,
          icon: Icons.image_search_outlined,
          enabled: hasImage,
        ),
      AppImageActionDescriptor(
        type: AppImageActionType.saveToLocal,
        label: l10n.moviePageSaveToLocal,
        icon: Icons.download_outlined,
        enabled: hasImage,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.toggleMark,
        label: currentPoint == null
            ? l10n.moviePageActionAddMark
            : l10n.moviePageActionRemoveMark,
        icon: currentPoint == null
            ? Icons.bookmark_add_outlined
            : Icons.bookmark_remove_outlined,
        enabled:
            media.mediaId > 0 &&
            (currentPoint != null || point.thumbnailId > 0),
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.play,
        label: l10n.moviePageActionPlay,
        icon: Icons.play_circle_outline_rounded,
        enabled: media.mediaId > 0 && media.hasPlayableUrl,
      ),
    ];
  }

  Future<void> _searchSimilarFromPoint(MovieMediaPointDto point) async {
    final imageUrl = resolvePointImageUrl(point);
    if (imageUrl.isEmpty) return;
    _showActionFeedback(
      await _overlays.searchSimilarFromPoint(
        context: context,
        ref: ref,
        movieNumber: movieNumber,
        imageUrl: imageUrl,
        fileName: buildPointFileName(movieNumber, point),
      ),
    );
  }

  Future<void> _openInspector(
    MovieDetailDto movie,
    MovieMediaItemDto? selectedMedia,
    MovieDetailInspectorPane pane,
  ) async {
    await _overlays.openInspector(
      context: context,
      movie: movie,
      selectedMedia: selectedMedia,
      pane: pane,
      onSearchSimilar: (thumbnail, imageUrl, fileName) =>
          _searchSimilarFromUrl(imageUrl, fileName),
      onPlay: (thumbnail) => _openMoviePlayer(
        movie: movie,
        mediaId: thumbnail.mediaId > 0
            ? thumbnail.mediaId
            : widget.mobile
            ? selectedMedia?.mediaId
            : null,
        positionSeconds: thumbnail.offsetSeconds,
      ),
    );
  }

  Future<void> _searchSimilarFromUrl(String imageUrl, String fileName) async {
    _showActionFeedback(
      await _overlays.searchSimilarFromPoint(
        context: context,
        ref: ref,
        movieNumber: movieNumber,
        imageUrl: imageUrl,
        fileName: fileName,
      ),
    );
  }

  Future<void> _showPlotImageMenu(
    BuildContext menuContext,
    int index,
    Offset globalPosition, {
    bool closeCurrentRouteOnSearch = false,
  }) {
    return _overlays.showPlotImageMenu(
      context: menuContext,
      hostContext: context,
      movie: ref.read(movieDetailProvider(movieNumber)).movie!,
      index: index,
      globalPosition: globalPosition,
      closeCurrentRouteOnSearch: closeCurrentRouteOnSearch,
      onSearchSimilar: (context, imageUrl, fileName) =>
          _searchSimilarFromUrl(imageUrl, fileName),
    );
  }

  Future<void> _openPlotPreview(int index) {
    final movie = ref.read(movieDetailProvider(movieNumber)).movie!;
    return _overlays.showPlotPreview(
      context: context,
      movie: movie,
      initialIndex: index,
      onRequestImageMenu: (menuContext, previewIndex, position) =>
          _showPlotImageMenu(
            menuContext,
            previewIndex,
            position,
            closeCurrentRouteOnSearch: true,
          ),
    );
  }

  void _openMoviePlayer({
    MovieDetailDto? movie,
    int? mediaId,
    int? positionSeconds,
  }) {
    final interaction = ref.read(movieDetailInteractionProvider(movieNumber));
    if (interaction.isLaunchingPlayback) return;
    _interaction.setPlaybackLaunching(true);
    unawaited(
      launchMoviePlayback(
        context,
        movieNumber: movieNumber,
        mediaId: mediaId,
        positionSeconds: positionSeconds,
        movie: widget.mobile
            ? null
            : movie ?? ref.read(movieDetailProvider(movieNumber)).movie,
      ).whenComplete(() => _interaction.setPlaybackLaunching(false)),
    );
  }

  Future<void> _openMergedPlayback(
    MovieDetailDto movie,
    List<MovieMergePlaybackCandidateDto> candidates,
  ) async {
    final interaction = ref.read(movieDetailInteractionProvider(movieNumber));
    if (interaction.isLaunchingPlayback) return;
    final candidate = await _overlays.pickMergeCandidate(
      context: context,
      candidates: candidates,
    );
    if (candidate == null || !mounted) return;
    _interaction.setPlaybackLaunching(true);
    try {
      await launchMovieMergedPlayback(
        context,
        movieNumber: movie.movieNumber,
        libraryId: candidate.libraryId,
        movie: movie,
      );
    } finally {
      _interaction.setPlaybackLaunching(false);
    }
  }

  void _openMovie(String movieNumber) {
    if (widget.mobile) {
      MobileMovieDetailRouteData(movieNumber: movieNumber).push(context);
      return;
    }
    context.pushDesktopMovieDetail(
      movieNumber: movieNumber,
      fallbackPath: buildDesktopMovieDetailRoutePath(this.movieNumber),
    );
  }

  void _openActor(int actorId) {
    if (widget.mobile) {
      MobileActorDetailRouteData(actorId: actorId).push(context);
      return;
    }
    context.pushDesktopActorDetail(
      actorId: actorId,
      fallbackPath: buildDesktopMovieDetailRoutePath(movieNumber),
    );
  }

  void _openSeries(MovieDetailDto movie) {
    final seriesId = movie.seriesId;
    if (seriesId == null) return;
    if (widget.mobile) {
      context.pushMobileMovieSeries(
        seriesId: seriesId,
        seriesName: movie.seriesName,
        fallbackPath: buildMobileMovieDetailRoutePath(movieNumber),
      );
    } else {
      context.pushDesktopMovieSeries(
        seriesId: seriesId,
        seriesName: movie.seriesName,
        fallbackPath: buildDesktopMovieDetailRoutePath(movieNumber),
      );
    }
  }

  void _openTag(int tagId) {
    if (widget.mobile) {
      context.pushMobileTags(tagId: tagId);
    } else {
      context.pushDesktopTags(tagId: tagId);
    }
  }

  void _showActionFeedback(MovieDetailActionResult result) {
    if (!mounted || result.status == MovieDetailActionResultStatus.ignored) {
      return;
    }
    final message = result.message;
    if (message == null || message.isEmpty) return;
    showToast(
      message,
      tone: switch (result.status) {
        MovieDetailActionResultStatus.success => AppToastTone.success,
        MovieDetailActionResultStatus.warning => AppToastTone.warning,
        MovieDetailActionResultStatus.error => AppToastTone.error,
        MovieDetailActionResultStatus.ignored => AppToastTone.info,
      },
    );
  }

  void _showImageSaveResult(ImageSaveResult result) {
    if (!mounted) return;
    if (result.status == ImageSaveStatus.success) {
      showToast(
        result.message ?? AppLocalizations.of(context).moviePageImageSaved,
        tone: AppToastTone.success,
      );
    } else if (result.status == ImageSaveStatus.failed) {
      showToast(
        result.message ?? AppLocalizations.of(context).moviePageImageSaveFailed,
        tone: AppToastTone.error,
      );
    }
  }

  MovieDetailActorActions _actorActions() {
    return MovieDetailActorActions(
      pickActors: (context, existingActorIds) => showMovieActorPickerSheet(
        context,
        actorsApi: ref.read(actorsApiProvider),
        existingActorIds: existingActorIds,
      ),
      addActor: _interaction.addMovieActor,
      removeActor: _interaction.removeMovieActor,
      refreshActors: _interaction.refreshActors,
    );
  }
}
