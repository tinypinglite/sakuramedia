import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';

const Object _unsetMoviePlayerValue = Object();

@immutable
class MoviePlayerState {
  MoviePlayerState({
    this.movie,
    this.selectedMedia,
    Map<int, MediaStorageDescriptor> storageDescriptors =
        const <int, MediaStorageDescriptor>{},
    List<MovieMediaThumbnailDto> thumbnails = const <MovieMediaThumbnailDto>[],
    this.isLoading = true,
    this.isThumbnailLoading = false,
    this.isSubtitleLoading = false,
    this.isThumbnailScrollLocked = true,
    this.thumbnailColumns,
    this.hasManualThumbnailColumnOverride = false,
    this.clipSelectionMode = false,
    this.clipStartIndex,
    this.clipEndIndex,
    this.errorMessage,
    this.thumbnailErrorMessage,
    this.subtitleErrorMessage,
    this.subtitleFetchStatus = 'pending',
    List<MoviePlayerSubtitleOption> subtitleOptions =
        const <MoviePlayerSubtitleOption>[],
    this.selectedSubtitleId,
    this.startupPlaybackPosition,
    this.resumePlaybackPosition,
    this.isResumeDecisionPending = false,
  }) : storageDescriptors = Map<int, MediaStorageDescriptor>.unmodifiable(
         storageDescriptors,
       ),
       thumbnails = List<MovieMediaThumbnailDto>.unmodifiable(thumbnails),
       subtitleOptions = List<MoviePlayerSubtitleOption>.unmodifiable(
         subtitleOptions,
       );

  final MovieDetailDto? movie;
  final MovieMediaItemDto? selectedMedia;
  final Map<int, MediaStorageDescriptor> storageDescriptors;
  final List<MovieMediaThumbnailDto> thumbnails;
  final bool isLoading;
  final bool isThumbnailLoading;
  final bool isSubtitleLoading;
  final bool isThumbnailScrollLocked;
  final int? thumbnailColumns;
  final bool hasManualThumbnailColumnOverride;
  final bool clipSelectionMode;
  final int? clipStartIndex;
  final int? clipEndIndex;
  final String? errorMessage;
  final String? thumbnailErrorMessage;
  final String? subtitleErrorMessage;
  final String subtitleFetchStatus;
  final List<MoviePlayerSubtitleOption> subtitleOptions;
  final int? selectedSubtitleId;
  final Duration? startupPlaybackPosition;
  final Duration? resumePlaybackPosition;
  final bool isResumeDecisionPending;

  MediaStorageDescriptor get selectedMediaStorage =>
      resolveMediaStorageDescriptor(
        selectedMedia?.libraryId,
        storageDescriptors,
      );

  bool get usesAutoThumbnailColumns => !hasManualThumbnailColumnOverride;

  MovieMediaThumbnailDto? get clipStartThumbnail =>
      _thumbnailAt(clipStartIndex);

  MovieMediaThumbnailDto? get clipEndThumbnail => _thumbnailAt(clipEndIndex);

  bool get canCreateClip {
    final start = clipStartIndex;
    final end = clipEndIndex;
    return start != null && end != null && start != end;
  }

  int? get clipSelectionDurationSeconds {
    final start = clipStartThumbnail;
    final end = clipEndThumbnail;
    if (start == null || end == null) {
      return null;
    }
    return (end.offsetSeconds - start.offsetSeconds).abs();
  }

  MoviePlayerSubtitleState get subtitleState => MoviePlayerSubtitleState(
    options: subtitleOptions,
    selectedSubtitleId: selectedSubtitleId,
    isLoading: isSubtitleLoading,
    fetchStatus: subtitleFetchStatus,
    errorMessage: subtitleErrorMessage,
  );

  String? resolvedPlayUrl(String baseUrl) =>
      resolveMediaUrl(rawUrl: selectedMedia?.playUrl, baseUrl: baseUrl);

  MovieMediaThumbnailDto? _thumbnailAt(int? index) {
    if (index == null || index < 0 || index >= thumbnails.length) {
      return null;
    }
    return thumbnails[index];
  }

  MoviePlayerState copyWith({
    Object? movie = _unsetMoviePlayerValue,
    Object? selectedMedia = _unsetMoviePlayerValue,
    Map<int, MediaStorageDescriptor>? storageDescriptors,
    List<MovieMediaThumbnailDto>? thumbnails,
    bool? isLoading,
    bool? isThumbnailLoading,
    bool? isSubtitleLoading,
    bool? isThumbnailScrollLocked,
    Object? thumbnailColumns = _unsetMoviePlayerValue,
    bool? hasManualThumbnailColumnOverride,
    bool? clipSelectionMode,
    Object? clipStartIndex = _unsetMoviePlayerValue,
    Object? clipEndIndex = _unsetMoviePlayerValue,
    Object? errorMessage = _unsetMoviePlayerValue,
    Object? thumbnailErrorMessage = _unsetMoviePlayerValue,
    Object? subtitleErrorMessage = _unsetMoviePlayerValue,
    String? subtitleFetchStatus,
    List<MoviePlayerSubtitleOption>? subtitleOptions,
    Object? selectedSubtitleId = _unsetMoviePlayerValue,
    Object? startupPlaybackPosition = _unsetMoviePlayerValue,
    Object? resumePlaybackPosition = _unsetMoviePlayerValue,
    bool? isResumeDecisionPending,
  }) {
    return MoviePlayerState(
      movie:
          identical(movie, _unsetMoviePlayerValue)
              ? this.movie
              : movie as MovieDetailDto?,
      selectedMedia:
          identical(selectedMedia, _unsetMoviePlayerValue)
              ? this.selectedMedia
              : selectedMedia as MovieMediaItemDto?,
      storageDescriptors: storageDescriptors ?? this.storageDescriptors,
      thumbnails: thumbnails ?? this.thumbnails,
      isLoading: isLoading ?? this.isLoading,
      isThumbnailLoading: isThumbnailLoading ?? this.isThumbnailLoading,
      isSubtitleLoading: isSubtitleLoading ?? this.isSubtitleLoading,
      isThumbnailScrollLocked:
          isThumbnailScrollLocked ?? this.isThumbnailScrollLocked,
      thumbnailColumns:
          identical(thumbnailColumns, _unsetMoviePlayerValue)
              ? this.thumbnailColumns
              : thumbnailColumns as int?,
      hasManualThumbnailColumnOverride:
          hasManualThumbnailColumnOverride ??
          this.hasManualThumbnailColumnOverride,
      clipSelectionMode: clipSelectionMode ?? this.clipSelectionMode,
      clipStartIndex:
          identical(clipStartIndex, _unsetMoviePlayerValue)
              ? this.clipStartIndex
              : clipStartIndex as int?,
      clipEndIndex:
          identical(clipEndIndex, _unsetMoviePlayerValue)
              ? this.clipEndIndex
              : clipEndIndex as int?,
      errorMessage:
          identical(errorMessage, _unsetMoviePlayerValue)
              ? this.errorMessage
              : errorMessage as String?,
      thumbnailErrorMessage:
          identical(thumbnailErrorMessage, _unsetMoviePlayerValue)
              ? this.thumbnailErrorMessage
              : thumbnailErrorMessage as String?,
      subtitleErrorMessage:
          identical(subtitleErrorMessage, _unsetMoviePlayerValue)
              ? this.subtitleErrorMessage
              : subtitleErrorMessage as String?,
      subtitleFetchStatus: subtitleFetchStatus ?? this.subtitleFetchStatus,
      subtitleOptions: subtitleOptions ?? this.subtitleOptions,
      selectedSubtitleId:
          identical(selectedSubtitleId, _unsetMoviePlayerValue)
              ? this.selectedSubtitleId
              : selectedSubtitleId as int?,
      startupPlaybackPosition:
          identical(startupPlaybackPosition, _unsetMoviePlayerValue)
              ? this.startupPlaybackPosition
              : startupPlaybackPosition as Duration?,
      resumePlaybackPosition:
          identical(resumePlaybackPosition, _unsetMoviePlayerValue)
              ? this.resumePlaybackPosition
              : resumePlaybackPosition as Duration?,
      isResumeDecisionPending:
          isResumeDecisionPending ?? this.isResumeDecisionPending,
    );
  }
}
