// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_detail_dto.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MovieMediaItemDtoCWProxy {
  MovieMediaItemDto mediaId(int mediaId);

  MovieMediaItemDto libraryId(int? libraryId);

  MovieMediaItemDto providerKey(String? providerKey);

  MovieMediaItemDto playUrl(String playUrl);

  MovieMediaItemDto resolution(String? resolution);

  MovieMediaItemDto fileName(String fileName);

  MovieMediaItemDto fileSizeBytes(int fileSizeBytes);

  MovieMediaItemDto durationSeconds(int durationSeconds);

  MovieMediaItemDto valid(bool valid);

  MovieMediaItemDto progress(MovieMediaProgressDto? progress);

  MovieMediaItemDto points(List<MovieMediaPointDto> points);

  MovieMediaItemDto videoInfo(MovieMediaVideoInfoDto? videoInfo);

  MovieMediaItemDto tags(List<MediaTagRefDto> tags);

  MovieMediaItemDto isMediaTagsManuallyManaged(bool isMediaTagsManuallyManaged);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MovieMediaItemDto(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MovieMediaItemDto(...).copyWith(id: 12, name: "My name")
  /// ```
  MovieMediaItemDto call({
    int mediaId,
    int? libraryId,
    String? providerKey,
    String playUrl,
    String? resolution,
    String fileName,
    int fileSizeBytes,
    int durationSeconds,
    bool valid,
    MovieMediaProgressDto? progress,
    List<MovieMediaPointDto> points,
    MovieMediaVideoInfoDto? videoInfo,
    List<MediaTagRefDto> tags,
    bool isMediaTagsManuallyManaged,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMovieMediaItemDto.copyWith(...)` or call `instanceOfMovieMediaItemDto.copyWith.fieldName(value)` for a single field.
class _$MovieMediaItemDtoCWProxyImpl implements _$MovieMediaItemDtoCWProxy {
  const _$MovieMediaItemDtoCWProxyImpl(this._value);

  final MovieMediaItemDto _value;

  @override
  MovieMediaItemDto mediaId(int mediaId) => call(mediaId: mediaId);

  @override
  MovieMediaItemDto libraryId(int? libraryId) => call(libraryId: libraryId);

  @override
  MovieMediaItemDto providerKey(String? providerKey) =>
      call(providerKey: providerKey);

  @override
  MovieMediaItemDto playUrl(String playUrl) => call(playUrl: playUrl);

  @override
  MovieMediaItemDto resolution(String? resolution) =>
      call(resolution: resolution);

  @override
  MovieMediaItemDto fileName(String fileName) => call(fileName: fileName);

  @override
  MovieMediaItemDto fileSizeBytes(int fileSizeBytes) =>
      call(fileSizeBytes: fileSizeBytes);

  @override
  MovieMediaItemDto durationSeconds(int durationSeconds) =>
      call(durationSeconds: durationSeconds);

  @override
  MovieMediaItemDto valid(bool valid) => call(valid: valid);

  @override
  MovieMediaItemDto progress(MovieMediaProgressDto? progress) =>
      call(progress: progress);

  @override
  MovieMediaItemDto points(List<MovieMediaPointDto> points) =>
      call(points: points);

  @override
  MovieMediaItemDto videoInfo(MovieMediaVideoInfoDto? videoInfo) =>
      call(videoInfo: videoInfo);

  @override
  MovieMediaItemDto tags(List<MediaTagRefDto> tags) => call(tags: tags);

  @override
  MovieMediaItemDto isMediaTagsManuallyManaged(
    bool isMediaTagsManuallyManaged,
  ) => call(isMediaTagsManuallyManaged: isMediaTagsManuallyManaged);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MovieMediaItemDto(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MovieMediaItemDto(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MovieMediaItemDto call({
    Object? mediaId = const $CopyWithPlaceholder(),
    Object? libraryId = const $CopyWithPlaceholder(),
    Object? providerKey = const $CopyWithPlaceholder(),
    Object? playUrl = const $CopyWithPlaceholder(),
    Object? resolution = const $CopyWithPlaceholder(),
    Object? fileName = const $CopyWithPlaceholder(),
    Object? fileSizeBytes = const $CopyWithPlaceholder(),
    Object? durationSeconds = const $CopyWithPlaceholder(),
    Object? valid = const $CopyWithPlaceholder(),
    Object? progress = const $CopyWithPlaceholder(),
    Object? points = const $CopyWithPlaceholder(),
    Object? videoInfo = const $CopyWithPlaceholder(),
    Object? tags = const $CopyWithPlaceholder(),
    Object? isMediaTagsManuallyManaged = const $CopyWithPlaceholder(),
  }) {
    return MovieMediaItemDto(
      mediaId: mediaId == const $CopyWithPlaceholder() || mediaId == null
          ? _value.mediaId
          // ignore: cast_nullable_to_non_nullable
          : mediaId as int,
      libraryId: libraryId == const $CopyWithPlaceholder()
          ? _value.libraryId
          // ignore: cast_nullable_to_non_nullable
          : libraryId as int?,
      providerKey: providerKey == const $CopyWithPlaceholder()
          ? _value.providerKey
          // ignore: cast_nullable_to_non_nullable
          : providerKey as String?,
      playUrl: playUrl == const $CopyWithPlaceholder() || playUrl == null
          ? _value.playUrl
          // ignore: cast_nullable_to_non_nullable
          : playUrl as String,
      resolution: resolution == const $CopyWithPlaceholder()
          ? _value.resolution
          // ignore: cast_nullable_to_non_nullable
          : resolution as String?,
      fileName: fileName == const $CopyWithPlaceholder() || fileName == null
          ? _value.fileName
          // ignore: cast_nullable_to_non_nullable
          : fileName as String,
      fileSizeBytes:
          fileSizeBytes == const $CopyWithPlaceholder() || fileSizeBytes == null
          ? _value.fileSizeBytes
          // ignore: cast_nullable_to_non_nullable
          : fileSizeBytes as int,
      durationSeconds:
          durationSeconds == const $CopyWithPlaceholder() ||
              durationSeconds == null
          ? _value.durationSeconds
          // ignore: cast_nullable_to_non_nullable
          : durationSeconds as int,
      valid: valid == const $CopyWithPlaceholder() || valid == null
          ? _value.valid
          // ignore: cast_nullable_to_non_nullable
          : valid as bool,
      progress: progress == const $CopyWithPlaceholder()
          ? _value.progress
          // ignore: cast_nullable_to_non_nullable
          : progress as MovieMediaProgressDto?,
      points: points == const $CopyWithPlaceholder() || points == null
          ? _value.points
          // ignore: cast_nullable_to_non_nullable
          : points as List<MovieMediaPointDto>,
      videoInfo: videoInfo == const $CopyWithPlaceholder()
          ? _value.videoInfo
          // ignore: cast_nullable_to_non_nullable
          : videoInfo as MovieMediaVideoInfoDto?,
      tags: tags == const $CopyWithPlaceholder() || tags == null
          ? _value.tags
          // ignore: cast_nullable_to_non_nullable
          : tags as List<MediaTagRefDto>,
      isMediaTagsManuallyManaged:
          isMediaTagsManuallyManaged == const $CopyWithPlaceholder() ||
              isMediaTagsManuallyManaged == null
          ? _value.isMediaTagsManuallyManaged
          // ignore: cast_nullable_to_non_nullable
          : isMediaTagsManuallyManaged as bool,
    );
  }
}

extension $MovieMediaItemDtoCopyWith on MovieMediaItemDto {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMovieMediaItemDto.copyWith(...)` or `instanceOfMovieMediaItemDto.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MovieMediaItemDtoCWProxy get copyWith =>
      _$MovieMediaItemDtoCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MovieDetailDto _$MovieDetailDtoFromJson(
  Map<String, dynamic> json,
) => MovieDetailDto(
  id: json['id'] == null ? 0 : const IntJsonConverter().fromJson(json['id']),
  metadataSourceName: _metadataSourceNameFromJson(json['metadata_source']),
  movieNumber: const StringJsonConverter().fromJson(json['movie_number']),
  title: const StringJsonConverter().fromJson(json['title']),
  seriesId: const NullableIntJsonConverter().fromJson(json['series_id']),
  seriesName: const StringJsonConverter().fromJson(json['series_name']),
  makerName: const StringJsonConverter().fromJson(json['maker_name']),
  directorName: const StringJsonConverter().fromJson(json['director_name']),
  coverImage: movieImageFromJson(json['cover_image']),
  releaseDate: const DateTimeJsonConverter().fromJson(json['release_date']),
  durationMinutes: const IntJsonConverter().fromJson(json['duration_minutes']),
  interactionStats: _interactionStatsFromJson(json['interaction_stats']),
  statsSource: const NullableStringJsonConverter().fromJson(
    json['stats_source'],
  ),
  statsUpdatedAt: const DateTimeJsonConverter().fromJson(
    json['stats_updated_at'],
  ),
  heat: const IntJsonConverter().fromJson(json['heat']),
  isCollection: const BoolJsonConverter().fromJson(json['is_collection']),
  isSubscribed: const BoolJsonConverter().fromJson(json['is_subscribed']),
  isBlacklisted: json['is_blacklisted'] == null
      ? false
      : const BoolJsonConverter().fromJson(json['is_blacklisted']),
  canPlay: const BoolJsonConverter().fromJson(json['can_play']),
  summary: const StringJsonConverter().fromJson(json['summary']),
  thinCoverImage: movieImageFromJson(json['thin_cover_image']),
  plotImages: _plotImagesFromJson(json['plot_images']),
  actors: _actorsFromJson(json['actors']),
  isActorsManuallyManaged: json['is_actors_manually_managed'] == null
      ? false
      : const BoolJsonConverter().fromJson(json['is_actors_manually_managed']),
  tags: _movieTagsFromJson(json['tags']),
  mediaItems: _mediaItemsFromJson(json['media_items']),
  mergePlaybackCandidates: json['merge_playback_candidates'] == null
      ? const <MovieMergePlaybackCandidateDto>[]
      : _mergePlaybackCandidatesFromJson(json['merge_playback_candidates']),
  playlists: _playlistsFromJson(json['playlists']),
  favoritePlaylistId: const NullableIntJsonConverter().fromJson(
    json['favorite_playlist_id'],
  ),
  rankings: json['rankings'] == null
      ? const <MovieRankingDto>[]
      : _rankingsFromJson(json['rankings']),
);

MovieMergePlaybackCandidateDto _$MovieMergePlaybackCandidateDtoFromJson(
  Map<String, dynamic> json,
) => MovieMergePlaybackCandidateDto(
  libraryId: const IntJsonConverter().fromJson(json['library_id']),
  libraryName: const StringJsonConverter().fromJson(json['library_name']),
  providerKey: const StringJsonConverter().fromJson(json['provider_key']),
  segmentCount: const IntJsonConverter().fromJson(json['segment_count']),
);

MovieMergedPlaybackDto _$MovieMergedPlaybackDtoFromJson(
  Map<String, dynamic> json,
) => MovieMergedPlaybackDto(
  playUrl: const StringJsonConverter().fromJson(json['play_url']),
);

MoviePlaylistSummaryDto _$MoviePlaylistSummaryDtoFromJson(
  Map<String, dynamic> json,
) => MoviePlaylistSummaryDto(
  id: const IntJsonConverter().fromJson(json['id']),
  name: const StringJsonConverter().fromJson(json['name']),
  kind: json['kind'] == null
      ? 'custom'
      : const StringJsonConverter().fromJson(json['kind']),
  isSystem: const BoolJsonConverter().fromJson(json['is_system']),
);

MovieRankingDto _$MovieRankingDtoFromJson(Map<String, dynamic> json) =>
    MovieRankingDto(
      sourceKey: const StringJsonConverter().fromJson(json['source_key']),
      sourceName: const StringJsonConverter().fromJson(json['source_name']),
      boardKey: const StringJsonConverter().fromJson(json['board_key']),
      boardName: const StringJsonConverter().fromJson(json['board_name']),
      period: const StringJsonConverter().fromJson(json['period']),
      rank: const IntJsonConverter().fromJson(json['rank']),
    );

MovieActorDto _$MovieActorDtoFromJson(Map<String, dynamic> json) =>
    MovieActorDto(
      id: const IntJsonConverter().fromJson(json['id']),
      name: const StringJsonConverter().fromJson(json['name']),
      aliasName: const StringJsonConverter().fromJson(json['alias_name']),
      gender: const IntJsonConverter().fromJson(json['gender']),
      isSubscribed: const BoolJsonConverter().fromJson(json['is_subscribed']),
      profileImage: movieImageFromJson(json['profile_image']),
      apiDisplayName: const NullableStringJsonConverter().fromJson(
        json['display_name'],
      ),
    );

MovieTagDto _$MovieTagDtoFromJson(Map<String, dynamic> json) => MovieTagDto(
  tagId: const IntJsonConverter().fromJson(json['tag_id']),
  name: const StringJsonConverter().fromJson(json['name']),
);

MovieMediaVideoInfoDto _$MovieMediaVideoInfoDtoFromJson(
  Map<String, dynamic> json,
) => MovieMediaVideoInfoDto(
  container: _containerInfoFromJson(json['container']),
  video: _videoStreamInfoFromJson(json['video']),
  audio: _audioStreamInfoFromJson(json['audio']),
  subtitles: _subtitlesFromJson(json['subtitles']),
);

MovieMediaContainerInfoDto _$MovieMediaContainerInfoDtoFromJson(
  Map<String, dynamic> json,
) => MovieMediaContainerInfoDto(
  formatName: const StringJsonConverter().fromJson(json['format_name']),
  durationSeconds: const NullableIntJsonConverter().fromJson(
    json['duration_seconds'],
  ),
  bitRate: const NullableIntJsonConverter().fromJson(json['bit_rate']),
  sizeBytes: const NullableIntJsonConverter().fromJson(json['size_bytes']),
);

MovieMediaVideoStreamInfoDto _$MovieMediaVideoStreamInfoDtoFromJson(
  Map<String, dynamic> json,
) => MovieMediaVideoStreamInfoDto(
  codecName: const StringJsonConverter().fromJson(json['codec_name']),
  codecLongName: const StringJsonConverter().fromJson(json['codec_long_name']),
  profile: const NullableStringJsonConverter().fromJson(json['profile']),
  bitRate: const NullableIntJsonConverter().fromJson(json['bit_rate']),
  width: const NullableIntJsonConverter().fromJson(json['width']),
  height: const NullableIntJsonConverter().fromJson(json['height']),
  frameRate: const NullableDoubleJsonConverter().fromJson(json['frame_rate']),
  pixelFormat: const StringJsonConverter().fromJson(json['pixel_format']),
);

MovieMediaAudioStreamInfoDto _$MovieMediaAudioStreamInfoDtoFromJson(
  Map<String, dynamic> json,
) => MovieMediaAudioStreamInfoDto(
  codecName: const StringJsonConverter().fromJson(json['codec_name']),
  codecLongName: const StringJsonConverter().fromJson(json['codec_long_name']),
  profile: const NullableStringJsonConverter().fromJson(json['profile']),
  bitRate: const NullableIntJsonConverter().fromJson(json['bit_rate']),
  sampleRate: const NullableIntJsonConverter().fromJson(json['sample_rate']),
  channels: const NullableIntJsonConverter().fromJson(json['channels']),
  channelLayout: const StringJsonConverter().fromJson(json['channel_layout']),
);

MovieMediaSubtitleInfoDto _$MovieMediaSubtitleInfoDtoFromJson(
  Map<String, dynamic> json,
) => MovieMediaSubtitleInfoDto(
  codecName: const StringJsonConverter().fromJson(json['codec_name']),
  codecLongName: const StringJsonConverter().fromJson(json['codec_long_name']),
  language: const StringJsonConverter().fromJson(json['language']),
  title: const StringJsonConverter().fromJson(json['title']),
);

MovieMediaProgressDto _$MovieMediaProgressDtoFromJson(
  Map<String, dynamic> json,
) => MovieMediaProgressDto(
  lastPositionSeconds: const IntJsonConverter().fromJson(
    json['last_position_seconds'],
  ),
  lastWatchedAt: const DateTimeJsonConverter().fromJson(
    json['last_watched_at'],
  ),
);

MovieMediaPointDto _$MovieMediaPointDtoFromJson(Map<String, dynamic> json) =>
    MovieMediaPointDto(
      pointId: const IntJsonConverter().fromJson(json['point_id']),
      thumbnailId: const IntJsonConverter().fromJson(json['thumbnail_id']),
      offsetSeconds: const IntJsonConverter().fromJson(json['offset_seconds']),
      image: movieImageFromJson(json['image']),
    );
