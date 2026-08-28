import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

class MovieDetailDto {
  const MovieDetailDto({
    this.id = 0,
    required this.javdbId,
    required this.movieNumber,
    required this.title,
    this.seriesId,
    required this.seriesName,
    required this.makerName,
    required this.directorName,
    required this.coverImage,
    required this.releaseDate,
    required this.durationMinutes,
    required this.score,
    required this.heat,
    required this.watchedCount,
    required this.wantWatchCount,
    required this.commentCount,
    required this.scoreNumber,
    required this.isCollection,
    required this.isSubscribed,
    this.isBlacklisted = false,
    required this.canPlay,
    required this.summary,
    required this.thinCoverImage,
    required this.plotImages,
    required this.actors,
    required this.tags,
    required this.mediaItems,
    required this.playlists,
  });

  /// 后端返回的影片整数主键，可用于与订阅等域数据关联。
  final int id;

  final String javdbId;
  final String movieNumber;
  final String title;
  final int? seriesId;
  final String seriesName;
  final String makerName;
  final String directorName;
  final MovieImageDto? coverImage;
  final DateTime? releaseDate;
  final int durationMinutes;
  final double score;
  final int heat;
  final int watchedCount;
  final int wantWatchCount;
  final int commentCount;
  final int scoreNumber;
  final bool isCollection;
  final bool isSubscribed;
  final bool isBlacklisted;
  final bool canPlay;
  final String summary;
  final MovieImageDto? thinCoverImage;
  final List<MovieImageDto> plotImages;
  final List<MovieActorDto> actors;
  final List<MovieTagDto> tags;
  final List<MovieMediaItemDto> mediaItems;
  final List<MoviePlaylistSummaryDto> playlists;

  /// DMM 简介与翻译链路已下线，desc/desc_zh 随 API 移除（存量收拢进 [summary]），
  /// 这里保留 getter 只做 trim。
  String get preferredDescription => summary.trim();

  /// DMM 中文标题已收拢进 [title]，保留 getter 只做 trim。
  String get preferredTitle => title.trim();

  factory MovieDetailDto.fromJson(Map<String, dynamic> json) {
    return MovieDetailDto(
      id: _intFromJson(json['id']) ?? 0,
      javdbId: json['javdb_id'] as String? ?? '',
      movieNumber: json['movie_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      seriesId: _intFromJson(json['series_id']),
      seriesName: json['series_name'] as String? ?? '',
      makerName: json['maker_name'] as String? ?? '',
      directorName: json['director_name'] as String? ?? '',
      coverImage: _movieImageFromJson(json['cover_image']),
      releaseDate: _dateFromJson(json['release_date']),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      heat: json['heat'] as int? ?? 0,
      watchedCount: json['watched_count'] as int? ?? 0,
      wantWatchCount: json['want_watch_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      scoreNumber: json['score_number'] as int? ?? 0,
      isCollection: json['is_collection'] as bool? ?? false,
      isSubscribed: json['is_subscribed'] as bool? ?? false,
      isBlacklisted: json['is_blacklisted'] as bool? ?? false,
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
    required this.gender,
    required this.isSubscribed,
    required this.profileImage,
  });

  static const int femaleGender = 1;

  final int id;
  final String javdbId;
  final String name;
  final String aliasName;
  final int gender;
  final bool isSubscribed;
  final MovieImageDto? profileImage;
  bool get isFemale => gender == femaleGender;

  factory MovieActorDto.fromJson(Map<String, dynamic> json) {
    return MovieActorDto(
      id: json['id'] as int? ?? 0,
      javdbId: json['javdb_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      aliasName: json['alias_name'] as String? ?? '',
      gender: (json['gender'] as num?)?.toInt() ?? 0,
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
    required this.providerKey,
    required this.playUrl,
    required this.resolution,
    required this.fileName,
    required this.fileSizeBytes,
    required this.durationSeconds,
    required this.valid,
    required this.progress,
    required this.points,
    this.videoInfo,
    this.playbackDeliveries = const <MoviePlaybackDelivery>[],
  });

  final int mediaId;
  final int? libraryId;
  final String? providerKey;
  final String playUrl;
  final String fileName;
  final String? resolution;
  final int fileSizeBytes;
  final int durationSeconds;
  final bool valid;
  final MovieMediaProgressDto? progress;
  final List<MovieMediaPointDto> points;
  final MovieMediaVideoInfoDto? videoInfo;
  final List<MoviePlaybackDelivery> playbackDeliveries;

  bool get hasPlayableUrl => playUrl.trim().isNotEmpty;

  bool get supportsRedirectPlayback =>
      playbackDeliveries.contains(MoviePlaybackDelivery.redirect);

  MoviePlaybackDelivery get defaultPlaybackDelivery => supportsRedirectPlayback
      ? MoviePlaybackDelivery.redirect
      : MoviePlaybackDelivery.proxy;

  factory MovieMediaItemDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaItemDto(
      mediaId: _intFromJson(json['media_id'] ?? json['id']) ?? 0,
      libraryId: json['library_id'] as int?,
      providerKey: json['provider_key'] as String?,
      playUrl: json['play_url'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      resolution: json['resolution'] as String?,
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      valid: json['valid'] as bool? ?? true,
      progress: _progressFromJson(json['progress']),
      points: _listFromJson(
        json['points'],
        (item) => MovieMediaPointDto.fromJson(item),
      ),
      videoInfo: _videoInfoFromJson(json['video_info']),
      playbackDeliveries: (json['playback_deliveries'] as List<dynamic>)
          .map((value) => MoviePlaybackDelivery.fromWire(value as String))
          .toList(growable: false),
    );
  }

  /// 可空字段用 sentinel 区分「不改」与「改为 null」；普通字段 `??`。
  MovieMediaItemDto copyWith({
    int? mediaId,
    Object? libraryId = _sentinel,
    Object? providerKey = _sentinel,
    String? playUrl,
    String? fileName,
    Object? resolution = _sentinel,
    int? fileSizeBytes,
    int? durationSeconds,
    bool? valid,
    Object? progress = _sentinel,
    List<MovieMediaPointDto>? points,
    Object? videoInfo = _sentinel,
    List<MoviePlaybackDelivery>? playbackDeliveries,
  }) {
    return MovieMediaItemDto(
      mediaId: mediaId ?? this.mediaId,
      libraryId: identical(libraryId, _sentinel)
          ? this.libraryId
          : libraryId as int?,
      providerKey: identical(providerKey, _sentinel)
          ? this.providerKey
          : providerKey as String?,
      playUrl: playUrl ?? this.playUrl,
      fileName: fileName ?? this.fileName,
      resolution: identical(resolution, _sentinel)
          ? this.resolution
          : resolution as String?,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      valid: valid ?? this.valid,
      progress: identical(progress, _sentinel)
          ? this.progress
          : progress as MovieMediaProgressDto?,
      points: points ?? this.points,
      videoInfo: identical(videoInfo, _sentinel)
          ? this.videoInfo
          : videoInfo as MovieMediaVideoInfoDto?,
      playbackDeliveries: playbackDeliveries ?? this.playbackDeliveries,
    );
  }
}

enum MoviePlaybackDelivery {
  proxy('proxy'),
  redirect('redirect');

  const MoviePlaybackDelivery(this.wireValue);

  final String wireValue;

  static MoviePlaybackDelivery fromWire(String value) => switch (value) {
    'proxy' => MoviePlaybackDelivery.proxy,
    'redirect' => MoviePlaybackDelivery.redirect,
    _ => throw FormatException('Unknown playback delivery: $value'),
  };
}

String withMoviePlaybackDelivery(
  String playUrl,
  MoviePlaybackDelivery delivery,
) {
  if (delivery == MoviePlaybackDelivery.proxy) {
    return playUrl;
  }
  final uri = Uri.parse(playUrl);
  return uri
      .replace(
        queryParameters: <String, String>{
          ...uri.queryParameters,
          'delivery': delivery.wireValue,
        },
      )
      .toString();
}

const Object _sentinel = Object();

class MovieMediaVideoInfoDto {
  const MovieMediaVideoInfoDto({
    required this.container,
    required this.video,
    required this.audio,
    required this.subtitles,
  });

  final MovieMediaContainerInfoDto? container;
  final MovieMediaVideoStreamInfoDto? video;
  final MovieMediaAudioStreamInfoDto? audio;
  final List<MovieMediaSubtitleInfoDto> subtitles;

  factory MovieMediaVideoInfoDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaVideoInfoDto(
      container: _containerInfoFromJson(json['container']),
      video: _videoStreamInfoFromJson(json['video']),
      audio: _audioStreamInfoFromJson(json['audio']),
      subtitles: _listFromJson(
        json['subtitles'],
        (item) => MovieMediaSubtitleInfoDto.fromJson(item),
      ),
    );
  }
}

class MovieMediaContainerInfoDto {
  const MovieMediaContainerInfoDto({
    required this.formatName,
    required this.durationSeconds,
    required this.bitRate,
    required this.sizeBytes,
  });

  final String formatName;
  final int? durationSeconds;
  final int? bitRate;
  final int? sizeBytes;

  factory MovieMediaContainerInfoDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaContainerInfoDto(
      formatName: json['format_name'] as String? ?? '',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      bitRate: (json['bit_rate'] as num?)?.toInt(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
    );
  }
}

class MovieMediaVideoStreamInfoDto {
  const MovieMediaVideoStreamInfoDto({
    required this.codecName,
    required this.codecLongName,
    required this.profile,
    required this.bitRate,
    required this.width,
    required this.height,
    required this.frameRate,
    required this.pixelFormat,
  });

  final String codecName;
  final String codecLongName;
  final String? profile;
  final int? bitRate;
  final int? width;
  final int? height;
  final double? frameRate;
  final String pixelFormat;

  factory MovieMediaVideoStreamInfoDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaVideoStreamInfoDto(
      codecName: json['codec_name'] as String? ?? '',
      codecLongName: json['codec_long_name'] as String? ?? '',
      profile: json['profile'] as String?,
      bitRate: (json['bit_rate'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      frameRate: (json['frame_rate'] as num?)?.toDouble(),
      pixelFormat: json['pixel_format'] as String? ?? '',
    );
  }
}

class MovieMediaAudioStreamInfoDto {
  const MovieMediaAudioStreamInfoDto({
    required this.codecName,
    required this.codecLongName,
    required this.profile,
    required this.bitRate,
    required this.sampleRate,
    required this.channels,
    required this.channelLayout,
  });

  final String codecName;
  final String codecLongName;
  final String? profile;
  final int? bitRate;
  final int? sampleRate;
  final int? channels;
  final String channelLayout;

  factory MovieMediaAudioStreamInfoDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaAudioStreamInfoDto(
      codecName: json['codec_name'] as String? ?? '',
      codecLongName: json['codec_long_name'] as String? ?? '',
      profile: json['profile'] as String?,
      bitRate: (json['bit_rate'] as num?)?.toInt(),
      sampleRate: (json['sample_rate'] as num?)?.toInt(),
      channels: (json['channels'] as num?)?.toInt(),
      channelLayout: json['channel_layout'] as String? ?? '',
    );
  }
}

class MovieMediaSubtitleInfoDto {
  const MovieMediaSubtitleInfoDto({
    required this.codecName,
    required this.codecLongName,
    required this.language,
    required this.title,
  });

  final String codecName;
  final String codecLongName;
  final String language;
  final String title;

  factory MovieMediaSubtitleInfoDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaSubtitleInfoDto(
      codecName: json['codec_name'] as String? ?? '',
      codecLongName: json['codec_long_name'] as String? ?? '',
      language: json['language'] as String? ?? '',
      title: json['title'] as String? ?? '',
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
    required this.thumbnailId,
    required this.offsetSeconds,
    required this.image,
  });

  final int pointId;
  final int thumbnailId;
  final int offsetSeconds;
  final MovieImageDto? image;

  factory MovieMediaPointDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaPointDto(
      pointId: json['point_id'] as int? ?? 0,
      thumbnailId: json['thumbnail_id'] as int? ?? 0,
      offsetSeconds: json['offset_seconds'] as int? ?? 0,
      image: _movieImageFromJson(json['image']),
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

MovieMediaVideoInfoDto? _videoInfoFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MovieMediaVideoInfoDto.fromJson(value);
  }
  if (value is Map) {
    return MovieMediaVideoInfoDto.fromJson(
      value.map((dynamic key, dynamic data) => MapEntry(key.toString(), data)),
    );
  }
  return null;
}

MovieMediaContainerInfoDto? _containerInfoFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MovieMediaContainerInfoDto.fromJson(value);
  }
  if (value is Map) {
    return MovieMediaContainerInfoDto.fromJson(
      value.map((dynamic key, dynamic data) => MapEntry(key.toString(), data)),
    );
  }
  return null;
}

MovieMediaVideoStreamInfoDto? _videoStreamInfoFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MovieMediaVideoStreamInfoDto.fromJson(value);
  }
  if (value is Map) {
    return MovieMediaVideoStreamInfoDto.fromJson(
      value.map((dynamic key, dynamic data) => MapEntry(key.toString(), data)),
    );
  }
  return null;
}

MovieMediaAudioStreamInfoDto? _audioStreamInfoFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MovieMediaAudioStreamInfoDto.fromJson(value);
  }
  if (value is Map) {
    return MovieMediaAudioStreamInfoDto.fromJson(
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

int? _intFromJson(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
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
