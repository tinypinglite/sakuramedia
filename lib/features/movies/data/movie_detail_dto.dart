import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class MovieDetailDto {
  const MovieDetailDto({
    required this.javdbId,
    required this.movieNumber,
    required this.title,
    required this.seriesName,
    required this.makerName,
    required this.directorName,
    required this.coverImage,
    required this.releaseDate,
    required this.durationMinutes,
    required this.score,
    required this.watchedCount,
    required this.wantWatchCount,
    required this.commentCount,
    required this.scoreNumber,
    required this.isCollection,
    required this.isSubscribed,
    required this.canPlay,
    required this.summary,
    required this.thinCoverImage,
    required this.plotImages,
    required this.actors,
    required this.tags,
    required this.mediaItems,
    required this.playlists,
  });

  final String javdbId;
  final String movieNumber;
  final String title;
  final String seriesName;
  final String makerName;
  final String directorName;
  final MovieImageDto? coverImage;
  final DateTime? releaseDate;
  final int durationMinutes;
  final double score;
  final int watchedCount;
  final int wantWatchCount;
  final int commentCount;
  final int scoreNumber;
  final bool isCollection;
  final bool isSubscribed;
  final bool canPlay;
  final String summary;
  final MovieImageDto? thinCoverImage;
  final List<MovieImageDto> plotImages;
  final List<MovieActorDto> actors;
  final List<MovieTagDto> tags;
  final List<MovieMediaItemDto> mediaItems;
  final List<MoviePlaylistSummaryDto> playlists;

  factory MovieDetailDto.fromJson(Map<String, dynamic> json) {
    return MovieDetailDto(
      javdbId: json['javdb_id'] as String? ?? '',
      movieNumber: json['movie_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      seriesName: json['series_name'] as String? ?? '',
      makerName: json['maker_name'] as String? ?? '',
      directorName: json['director_name'] as String? ?? '',
      coverImage: _movieImageFromJson(json['cover_image']),
      releaseDate: _dateFromJson(json['release_date']),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      watchedCount: json['watched_count'] as int? ?? 0,
      wantWatchCount: json['want_watch_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      scoreNumber: json['score_number'] as int? ?? 0,
      isCollection: json['is_collection'] as bool? ?? false,
      isSubscribed: json['is_subscribed'] as bool? ?? false,
      canPlay: json['can_play'] as bool? ?? false,
      summary: json['summary'] as String? ?? '',
      thinCoverImage: _movieImageFromJson(json['thin_cover_image']),
      plotImages: _listFromJson(
        json['plot_images'],
        (item) => MovieImageDto.fromJson(item),
      ),
      actors: _listFromJson(
        json['actors'],
        (item) => MovieActorDto.fromJson(item),
      ),
      tags: _listFromJson(json['tags'], (item) => MovieTagDto.fromJson(item)),
      mediaItems: _listFromJson(
        json['media_items'],
        (item) => MovieMediaItemDto.fromJson(item),
      ),
      playlists: _listFromJson(
        json['playlists'],
        (item) => MoviePlaylistSummaryDto.fromJson(item),
      ),
    );
  }
}

class MoviePlaylistSummaryDto {
  const MoviePlaylistSummaryDto({
    required this.id,
    required this.name,
    required this.kind,
    required this.isSystem,
  });

  final int id;
  final String name;
  final String kind;
  final bool isSystem;

  factory MoviePlaylistSummaryDto.fromJson(Map<String, dynamic> json) {
    return MoviePlaylistSummaryDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'custom',
      isSystem: json['is_system'] as bool? ?? false,
    );
  }
}

class MovieActorDto {
  const MovieActorDto({
    required this.id,
    required this.javdbId,
    required this.name,
    required this.aliasName,
    required this.isSubscribed,
    required this.profileImage,
  });

  final int id;
  final String javdbId;
  final String name;
  final String aliasName;
  final bool isSubscribed;
  final MovieImageDto? profileImage;

  factory MovieActorDto.fromJson(Map<String, dynamic> json) {
    return MovieActorDto(
      id: json['id'] as int? ?? 0,
      javdbId: json['javdb_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      aliasName: json['alias_name'] as String? ?? '',
      isSubscribed: json['is_subscribed'] as bool? ?? false,
      profileImage: _movieImageFromJson(json['profile_image']),
    );
  }
}

class MovieTagDto {
  const MovieTagDto({required this.tagId, required this.name});

  final int tagId;
  final String name;

  factory MovieTagDto.fromJson(Map<String, dynamic> json) {
    return MovieTagDto(
      tagId: json['tag_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class MovieMediaItemDto {
  const MovieMediaItemDto({
    required this.mediaId,
    required this.libraryId,
    required this.playUrl,
    required this.path,
    required this.storageMode,
    required this.resolution,
    required this.fileSizeBytes,
    required this.durationSeconds,
    required this.specialTags,
    required this.valid,
    required this.progress,
    required this.points,
  });

  final int mediaId;
  final int? libraryId;
  final String playUrl;
  final String path;
  final String storageMode;
  final String resolution;
  final int fileSizeBytes;
  final int durationSeconds;
  final String specialTags;
  final bool valid;
  final MovieMediaProgressDto? progress;
  final List<MovieMediaPointDto> points;

  bool get hasPlayableUrl => playUrl.trim().isNotEmpty;

  factory MovieMediaItemDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaItemDto(
      mediaId: json['media_id'] as int? ?? 0,
      libraryId: json['library_id'] as int?,
      playUrl: json['play_url'] as String? ?? '',
      path: json['path'] as String? ?? '',
      storageMode: json['storage_mode'] as String? ?? '',
      resolution: json['resolution'] as String? ?? '',
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      specialTags: json['special_tags'] as String? ?? '',
      valid: json['valid'] as bool? ?? false,
      progress: _progressFromJson(json['progress']),
      points: _listFromJson(
        json['points'],
        (item) => MovieMediaPointDto.fromJson(item),
      ),
    );
  }
}

class MovieMediaProgressDto {
  const MovieMediaProgressDto({
    required this.lastPositionSeconds,
    required this.lastWatchedAt,
  });

  final int lastPositionSeconds;
  final DateTime? lastWatchedAt;

  factory MovieMediaProgressDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaProgressDto(
      lastPositionSeconds: json['last_position_seconds'] as int? ?? 0,
      lastWatchedAt: _dateTimeFromJson(json['last_watched_at']),
    );
  }
}

class MovieMediaPointDto {
  const MovieMediaPointDto({
    required this.pointId,
    required this.offsetSeconds,
  });

  final int pointId;
  final int offsetSeconds;

  factory MovieMediaPointDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaPointDto(
      pointId: json['point_id'] as int? ?? 0,
      offsetSeconds: json['offset_seconds'] as int? ?? 0,
    );
  }
}

MovieImageDto? _movieImageFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MovieImageDto.fromJson(value);
  }
  if (value is Map) {
    return MovieImageDto.fromJson(
      value.map((dynamic key, dynamic data) => MapEntry(key.toString(), data)),
    );
  }
  return null;
}

MovieMediaProgressDto? _progressFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MovieMediaProgressDto.fromJson(value);
  }
  if (value is Map) {
    return MovieMediaProgressDto.fromJson(
      value.map((dynamic key, dynamic data) => MapEntry(key.toString(), data)),
    );
  }
  return null;
}

DateTime? _dateFromJson(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

DateTime? _dateTimeFromJson(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

List<T> _listFromJson<T>(
  dynamic value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) {
    return <T>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => fromJson(
          item.map(
            (dynamic key, dynamic data) => MapEntry(key.toString(), data),
          ),
        ),
      )
      .toList(growable: false);
}
