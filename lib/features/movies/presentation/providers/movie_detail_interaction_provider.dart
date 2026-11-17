import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_action_result.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_view_model.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_detail_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/system_playlist_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';

part 'movie_detail_interaction_provider.g.dart';

const Object _kSentinel = Object();

@immutable
class MovieDetailInteractionState {
  const MovieDetailInteractionState({
    this.pointOverrides = const <int, List<MovieMediaPointDto>>{},
    this.selectedMediaId,
    this.isSubscribedOverride,
    this.isBlacklistedOverride,
    this.isCollectionOverride,
    this.isSubscriptionUpdating = false,
    this.isCollectionUpdating = false,
    this.isLaunchingPlayback = false,
    this.deletingMediaId,
    this.activeMovieAction,
  });

  final Map<int, List<MovieMediaPointDto>> pointOverrides;
  final int? selectedMediaId;
  final bool? isSubscribedOverride;
  final bool? isBlacklistedOverride;
  final bool? isCollectionOverride;
  final bool isSubscriptionUpdating;
  final bool isCollectionUpdating;
  final bool isLaunchingPlayback;
  final int? deletingMediaId;
  final MovieDetailActionType? activeMovieAction;

  bool get isActionLocked =>
      isSubscriptionUpdating ||
      isCollectionUpdating ||
      activeMovieAction != null;

  MovieDetailInteractionState copyWith({
    Map<int, List<MovieMediaPointDto>>? pointOverrides,
    Object? selectedMediaId = _kSentinel,
    Object? isSubscribedOverride = _kSentinel,
    Object? isBlacklistedOverride = _kSentinel,
    Object? isCollectionOverride = _kSentinel,
    bool? isSubscriptionUpdating,
    bool? isCollectionUpdating,
    bool? isLaunchingPlayback,
    Object? deletingMediaId = _kSentinel,
    Object? activeMovieAction = _kSentinel,
  }) {
    return MovieDetailInteractionState(
      pointOverrides: pointOverrides ?? this.pointOverrides,
      selectedMediaId: identical(selectedMediaId, _kSentinel)
          ? this.selectedMediaId
          : selectedMediaId as int?,
      isSubscribedOverride: identical(isSubscribedOverride, _kSentinel)
          ? this.isSubscribedOverride
          : isSubscribedOverride as bool?,
      isBlacklistedOverride: identical(isBlacklistedOverride, _kSentinel)
          ? this.isBlacklistedOverride
          : isBlacklistedOverride as bool?,
      isCollectionOverride: identical(isCollectionOverride, _kSentinel)
          ? this.isCollectionOverride
          : isCollectionOverride as bool?,
      isSubscriptionUpdating:
          isSubscriptionUpdating ?? this.isSubscriptionUpdating,
      isCollectionUpdating: isCollectionUpdating ?? this.isCollectionUpdating,
      isLaunchingPlayback: isLaunchingPlayback ?? this.isLaunchingPlayback,
      deletingMediaId: identical(deletingMediaId, _kSentinel)
          ? this.deletingMediaId
          : deletingMediaId as int?,
      activeMovieAction: identical(activeMovieAction, _kSentinel)
          ? this.activeMovieAction
          : activeMovieAction as MovieDetailActionType?,
    );
  }

  List<MovieMediaItemDto> resolveMediaItems(MovieDetailDto movie) {
    if (pointOverrides.isEmpty) {
      return movie.mediaItems;
    }
    return movie.mediaItems
        .map((item) {
          final pointsOverride = pointOverrides[item.mediaId];
          if (pointsOverride == null) {
            return item;
          }
          return item.copyWith(points: pointsOverride);
        })
        .toList(growable: false);
  }

  MovieDetailDerived derive(MovieDetailDto movie) {
    final mediaItems = resolveMediaItems(movie);
    final selectedMedia =
        mediaItems
            .where((item) => item.mediaId == selectedMediaId)
            .firstOrNull ??
        (mediaItems.isNotEmpty ? mediaItems.first : null);
    return MovieDetailDerived(
      mediaItems: mediaItems,
      isSubscribed: isSubscribedOverride ?? movie.isSubscribed,
      isBlacklisted: isBlacklistedOverride ?? movie.isBlacklisted,
      isCollection: isCollectionOverride ?? movie.isCollection,
      isActionControlsLocked: isActionLocked,
      selectedMedia: selectedMedia,
    );
  }
}

@riverpod
class MovieDetailInteraction extends _$MovieDetailInteraction {
  bool _disposed = false;
  late String _movieNumber;

  @override
  MovieDetailInteractionState build(String movieNumber) {
    _movieNumber = movieNumber;
    ref.onDispose(() => _disposed = true);
    return const MovieDetailInteractionState();
  }

  AppLocalizations get _l10n => ref.read(appLocalizationsProvider);

  Future<MovieDetailActionResult> reloadPlaylistMembership() async {
    try {
      final movie = await ref
          .read(moviesApiProvider)
          .getMovieDetail(movieNumber: _movieNumber);
      if (_disposed) {
        return const MovieDetailActionResult.ignored();
      }
      ref.read(movieDetailProvider(_movieNumber).notifier).applyMovie(movie);
      return const MovieDetailActionResult.success();
    } catch (error) {
      return MovieDetailActionResult.error(
        ref.apiErrorMessage(
          error,
          fallback: _l10n.moviePagePlaylistUpdateFailed,
        ),
      );
    }
  }

  Future<void> loadMovieCollectionStatus() async {
    try {
      final status = await ref
          .read(moviesApiProvider)
          .getMovieCollectionStatus(movieNumber: _movieNumber);
      if (_disposed) return;
      state = state.copyWith(isCollectionOverride: status.isCollection);
    } catch (_) {
      // Fall back to the detail payload value.
    }
  }

  Future<MovieDetailActionResult> toggleCollection({
    required bool isCollection,
  }) async {
    if (state.isCollectionUpdating) {
      return const MovieDetailActionResult.ignored();
    }
    state = state.copyWith(isCollectionUpdating: true);
    final targetType = isCollection
        ? MovieCollectionType.single
        : MovieCollectionType.collection;
    try {
      final result = await ref
          .read(moviesApiProvider)
          .updateMovieCollectionType(
            movieNumbers: <String>[_movieNumber],
            collectionType: targetType,
          );
      if (_disposed) return const MovieDetailActionResult.ignored();
      if (result.updatedCount <= 0) {
        return MovieDetailActionResult.warning(
          _l10n.moviePageCollectionNotMatched,
        );
      }
      state = state.copyWith(isCollectionOverride: !isCollection);
      ref
          .read(movieCollectionTypeEventsProvider.notifier)
          .reportChange(movieNumber: _movieNumber, targetType: targetType);
      return MovieDetailActionResult.success(
        targetType == MovieCollectionType.collection
            ? _l10n.moviePageMarkedAsCollection
            : _l10n.moviePageMarkedAsSingle,
      );
    } catch (error) {
      return MovieDetailActionResult.error(
        ref.apiErrorMessage(
          error,
          fallback: _l10n.moviePageCollectionUpdateFailed,
        ),
      );
    } finally {
      if (!_disposed) {
        state = state.copyWith(isCollectionUpdating: false);
      }
    }
  }

  Future<MovieDetailActionResult> deleteMedia(int mediaId) async {
    if (state.deletingMediaId != null) {
      return const MovieDetailActionResult.ignored();
    }
    state = state.copyWith(deletingMediaId: mediaId);
    try {
      await ref.read(mediaApiProvider).deleteMedia(mediaId: mediaId);
      await _refreshAfterMediaDelete(deletedMediaId: mediaId);
      return MovieDetailActionResult.success(_l10n.moviePageMediaDeleted);
    } catch (error) {
      return MovieDetailActionResult.error(
        ref.apiErrorMessage(error, fallback: _l10n.moviePageMediaDeleteFailed),
      );
    } finally {
      if (!_disposed) {
        state = state.copyWith(deletingMediaId: null);
      }
    }
  }

  Future<void> _refreshAfterMediaDelete({required int deletedMediaId}) async {
    final detailNotifier = ref.read(movieDetailProvider(_movieNumber).notifier);
    try {
      await detailNotifier.refresh();
    } catch (_) {
      return;
    }
    if (_disposed) return;
    detailNotifier.reportView();
    final movie = ref.read(movieDetailProvider(_movieNumber)).movie;
    if (movie != null) {
      ref
          .read(movieMediaEventsProvider.notifier)
          .reportChange(
            MovieMediaChange(
              movieNumber: movie.movieNumber,
              canPlay: movie.canPlay,
              isSubscribed: movie.isSubscribed,
            ),
          );
    }
    resetAfterRefresh(deletedMediaId: deletedMediaId);
    await loadMovieCollectionStatus();
  }

  Future<MovieDetailActionResult> refreshAfterTagAssignment() async {
    try {
      await ref.read(movieDetailProvider(_movieNumber).notifier).refresh();
      return MovieDetailActionResult.success(_l10n.mediaTagsAssignmentSaved);
    } catch (_) {
      return MovieDetailActionResult.warning(
        _l10n.mediaTagsAssignmentSavedRefreshFailed,
      );
    }
  }

  void resetAfterRefresh({int? deletedMediaId}) {
    if (_disposed) return;
    final refreshedMediaItems =
        ref.read(movieDetailProvider(_movieNumber)).movie?.mediaItems ??
        const <MovieMediaItemDto>[];
    final currentId = state.selectedMediaId;
    final retainedSelectedMediaId =
        currentId != null &&
            currentId != deletedMediaId &&
            refreshedMediaItems.any((item) => item.mediaId == currentId)
        ? currentId
        : null;
    final nextSelectedMediaId =
        retainedSelectedMediaId ??
        (refreshedMediaItems.isNotEmpty
            ? refreshedMediaItems.first.mediaId
            : null);
    state = state.copyWith(
      pointOverrides: const <int, List<MovieMediaPointDto>>{},
      selectedMediaId: nextSelectedMediaId,
      isSubscribedOverride: null,
      isBlacklistedOverride: null,
      isCollectionOverride: null,
    );
  }

  void selectMedia(MovieMediaItemDto mediaItem) {
    state = state.copyWith(selectedMediaId: mediaItem.mediaId);
  }

  Future<ImageSaveResult> savePointImage(MovieMediaPointDto point) async {
    final imageUrl = resolvePointImageUrl(point);
    if (imageUrl.isEmpty) {
      return const ImageSaveResult(status: ImageSaveStatus.cancelled);
    }
    return ImageSaveService(
      fetchBytes: ref.read(apiClientProvider).getBytes,
    ).saveImageFromUrl(
      imageUrl: imageUrl,
      fileName: buildPointFileName(_movieNumber, point),
      dialogTitle: _l10n.moviePageSaveToLocal,
      l10n: _l10n,
    );
  }

  Future<MovieDetailActionResult> toggleMediaPoint(
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
    MovieMediaPointDto? existingPoint,
  ) async {
    try {
      if (existingPoint == null) {
        final createdPoint = await ref
            .read(mediaApiProvider)
            .createMediaPoint(
              mediaId: mediaItem.mediaId,
              thumbnailId: point.thumbnailId,
            );
        if (_disposed) return const MovieDetailActionResult.ignored();
        applyPointListOverride(mediaItem.mediaId, <MovieMediaPointDto>[
          ...mediaItem.points,
          movieMediaPointFromMediaPoint(createdPoint, fallback: point),
        ]);
        return MovieDetailActionResult.success(_l10n.moviePageMarkAdded);
      }

      await ref
          .read(mediaApiProvider)
          .deleteMediaPoint(pointId: existingPoint.pointId);
      if (_disposed) return const MovieDetailActionResult.ignored();
      applyPointListOverride(
        mediaItem.mediaId,
        mediaItem.points
            .where((candidate) => candidate.pointId != existingPoint.pointId)
            .toList(growable: false),
      );
      return MovieDetailActionResult.success(_l10n.moviePageMarkRemoved);
    } catch (error) {
      return MovieDetailActionResult.error(
        ref.apiErrorMessage(error, fallback: _l10n.moviePageMarkUpdateFailed),
      );
    }
  }

  MovieMediaPointDto? findCurrentPoint(int mediaId, int pointId) {
    final movie = ref.read(movieDetailProvider(_movieNumber)).movie;
    if (movie == null) return null;
    final mediaItem = state
        .resolveMediaItems(movie)
        .firstWhere(
          (item) => item.mediaId == mediaId,
          orElse: () => emptyMediaItem(mediaId),
        );
    for (final point in mediaItem.points) {
      if (point.pointId == pointId) {
        return point;
      }
    }
    return null;
  }

  void applyPointListOverride(int mediaId, List<MovieMediaPointDto> points) {
    if (_disposed) return;
    state = state.copyWith(
      pointOverrides: <int, List<MovieMediaPointDto>>{
        ...state.pointOverrides,
        mediaId: points,
      },
    );
  }

  Future<MovieSubscriptionToggleResult> toggleSubscription({
    required bool isSubscribed,
  }) async {
    if (state.isSubscriptionUpdating) {
      return const MovieSubscriptionToggleResult.ignored();
    }
    state = state.copyWith(isSubscriptionUpdating: true);
    MovieSubscriptionToggleResult result;
    try {
      if (isSubscribed) {
        await ref
            .read(moviesApiProvider)
            .unsubscribeMovie(movieNumber: _movieNumber, deleteMedia: false);
        result = const MovieSubscriptionToggleResult.unsubscribed();
        if (!_disposed) {
          state = state.copyWith(isSubscribedOverride: false);
        }
      } else {
        await ref
            .read(moviesApiProvider)
            .subscribeMovie(movieNumber: _movieNumber);
        result = const MovieSubscriptionToggleResult.subscribed();
        if (!_disposed) {
          state = state.copyWith(isSubscribedOverride: true);
        }
      }
    } catch (error) {
      if (_isBlockedByMedia(error)) {
        result = const MovieSubscriptionToggleResult.blockedByMedia();
      } else {
        result = MovieSubscriptionToggleResult.failed(
          message: ref.apiErrorMessage(
            error,
            fallback: isSubscribed
                ? _l10n.moviePageUnsubscribeFailed
                : _l10n.moviePageSubscribeFailed,
          ),
        );
      }
    }
    _reportSubscriptionChange(result);
    if (!_disposed) {
      state = state.copyWith(isSubscriptionUpdating: false);
    }
    return result;
  }

  Future<MovieDetailActionResult> toggleFavorite({
    required MovieDetailDto movie,
    required bool isFavorite,
  }) async {
    if (state.isActionLocked) {
      return const MovieDetailActionResult.ignored();
    }
    final playlistId = movie.favoritePlaylistId;
    if (playlistId == null) {
      return MovieDetailActionResult.warning(
        _l10n.moviePageFavoriteListNotReady,
      );
    }
    state = state.copyWith(
      activeMovieAction: MovieDetailActionType.toggleFavorite,
    );
    try {
      final api = ref.read(playlistsApiProvider);
      if (isFavorite) {
        await api.removeMovieFromPlaylist(
          playlistId: playlistId,
          movieNumber: movie.movieNumber,
        );
      } else {
        await api.addMovieToPlaylist(
          playlistId: playlistId,
          movieNumber: movie.movieNumber,
        );
      }
      if (_disposed) return const MovieDetailActionResult.ignored();
      ref.invalidate(
        movieSummaryProvider(
          MovieSummaryScope.playlist(playlistId: playlistId),
        ),
      );
      ref.invalidate(playlistDetailProvider(playlistId));
      ref.invalidate(systemPlaylistProvider(PlaylistKind.favorites));
      final refreshed = await reloadPlaylistMembership();
      if (!refreshed.succeeded) {
        return refreshed;
      }
      return MovieDetailActionResult.success(
        isFavorite
            ? _l10n.moviePageFavoriteRemoved
            : _l10n.moviePageFavoriteAdded,
      );
    } catch (error) {
      return MovieDetailActionResult.error(
        ref.apiErrorMessage(
          error,
          fallback: isFavorite
              ? _l10n.moviePageFavoriteRemoveFailed
              : _l10n.moviePageFavoriteAddFailed,
        ),
      );
    } finally {
      if (!_disposed) {
        state = state.copyWith(activeMovieAction: null);
      }
    }
  }

  Future<MovieDetailActionResult> setBlacklisted({
    required bool isBlacklisted,
  }) async {
    if (state.isActionLocked) {
      return const MovieDetailActionResult.ignored();
    }
    state = state.copyWith(
      activeMovieAction: MovieDetailActionType.toggleBlacklist,
    );
    try {
      await ref
          .read(moviesApiProvider)
          .setMoviesBlacklisted(
            movieNumbers: <String>[_movieNumber],
            isBlacklisted: isBlacklisted,
          );
      if (_disposed) return const MovieDetailActionResult.ignored();
      state = state.copyWith(isBlacklistedOverride: isBlacklisted);
      return MovieDetailActionResult.success(
        isBlacklisted
            ? _l10n.moviePageBlacklisted
            : _l10n.moviePageUnblacklisted,
      );
    } catch (error) {
      return MovieDetailActionResult.error(
        ref.apiErrorMessage(
          error,
          fallback: isBlacklisted
              ? _l10n.moviePageBlacklistFailed
              : _l10n.moviePageUnblacklistFailed,
        ),
      );
    } finally {
      if (!_disposed) {
        state = state.copyWith(activeMovieAction: null);
      }
    }
  }

  Future<MovieDetailActionResult> refreshMetadata() async {
    if (state.isActionLocked) {
      return const MovieDetailActionResult.ignored();
    }
    state = state.copyWith(
      activeMovieAction: MovieDetailActionType.refreshMetadata,
    );
    try {
      final movie = await ref
          .read(moviesApiProvider)
          .refreshMovieMetadata(movieNumber: _movieNumber);
      if (_disposed) return const MovieDetailActionResult.ignored();
      ref
          .read(movieDetailProvider(_movieNumber).notifier)
          .applyMovie(movie, resetPreview: true);
      ref.invalidate(movieSummaryProvider);
      return MovieDetailActionResult.success(
        _l10n.movieActionMovieMetadataRefreshed,
      );
    } catch (error) {
      return MovieDetailActionResult.error(
        ref.apiErrorMessage(
          error,
          fallback: _l10n.movieActionRefreshMovieMetadataFailed,
        ),
      );
    } finally {
      if (!_disposed) {
        state = state.copyWith(activeMovieAction: null);
      }
    }
  }

  void setPlaybackLaunching(bool value) {
    if (_disposed) return;
    state = state.copyWith(isLaunchingPlayback: value);
  }

  Future<void> addMovieActor(int actorId) async {
    await ref
        .read(moviesApiProvider)
        .addMovieActor(movieNumber: _movieNumber, actorId: actorId);
  }

  Future<void> removeMovieActor(int actorId) async {
    await ref
        .read(moviesApiProvider)
        .removeMovieActor(movieNumber: _movieNumber, actorId: actorId);
  }

  Future<void> refreshActors() async {
    await ref.read(movieDetailProvider(_movieNumber).notifier).refresh();
  }

  bool _isBlockedByMedia(Object error) {
    return error is ApiException &&
        error.error?.code == 'movie_subscription_has_media';
  }

  void _reportSubscriptionChange(MovieSubscriptionToggleResult result) {
    switch (result.status) {
      case MovieSubscriptionToggleStatus.subscribed:
        ref
            .read(movieSubscriptionEventsProvider.notifier)
            .reportChange(movieNumber: _movieNumber, isSubscribed: true);
      case MovieSubscriptionToggleStatus.unsubscribed:
        ref
            .read(movieSubscriptionEventsProvider.notifier)
            .reportChange(movieNumber: _movieNumber, isSubscribed: false);
      case MovieSubscriptionToggleStatus.blockedByMedia:
      case MovieSubscriptionToggleStatus.failed:
      case MovieSubscriptionToggleStatus.ignored:
        break;
    }
  }
}

String resolvePointImageUrl(MovieMediaPointDto point) {
  return point.image?.origin.trim() ?? '';
}

String buildPointFileName(String movieNumber, MovieMediaPointDto point) {
  final suffix = point.thumbnailId > 0 ? point.thumbnailId : point.pointId;
  return 'movie_point_${movieNumber}_$suffix.webp';
}

MovieMediaPointDto? findCurrentPointIn(
  List<MovieMediaItemDto> mediaItems,
  int mediaId,
  int pointId,
) {
  final mediaItem = mediaItems.firstWhere(
    (item) => item.mediaId == mediaId,
    orElse: () => emptyMediaItem(mediaId),
  );
  for (final point in mediaItem.points) {
    if (point.pointId == pointId) {
      return point;
    }
  }
  return null;
}

MovieMediaItemDto emptyMediaItem(int mediaId) {
  return MovieMediaItemDto(
    mediaId: mediaId,
    libraryId: null,
    providerKey: null,
    playUrl: '',
    fileName: '',
    resolution: '',
    fileSizeBytes: 0,
    durationSeconds: 0,
    valid: false,
    progress: null,
    points: const <MovieMediaPointDto>[],
    videoInfo: null,
  );
}

MovieMediaPointDto movieMediaPointFromMediaPoint(
  MediaPointDto point, {
  required MovieMediaPointDto fallback,
}) {
  return MovieMediaPointDto(
    pointId: point.pointId,
    thumbnailId: point.thumbnailId,
    offsetSeconds: point.offsetSeconds > 0
        ? point.offsetSeconds
        : fallback.offsetSeconds,
    image: point.image ?? fallback.image,
  );
}

MediaPreviewItem buildMediaPointPreviewItem({
  required String movieNumber,
  required MovieMediaItemDto mediaItem,
  required MovieMediaPointDto point,
}) {
  return MediaPreviewItem(
    imageUrl: resolvePointImageUrl(point),
    fileName: buildPointFileName(movieNumber, point),
    mediaId: mediaItem.mediaId,
    movieNumber: movieNumber,
    thumbnailId: point.thumbnailId,
    offsetSeconds: point.offsetSeconds,
  );
}
