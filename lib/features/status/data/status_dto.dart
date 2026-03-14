class ActorStatsDto {
  const ActorStatsDto({
    required this.femaleTotal,
    required this.femaleSubscribed,
  });

  final int femaleTotal;
  final int femaleSubscribed;

  factory ActorStatsDto.fromJson(Map<String, dynamic> json) {
    return ActorStatsDto(
      femaleTotal: json['female_total'] as int? ?? 0,
      femaleSubscribed: json['female_subscribed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'female_total': femaleTotal,
      'female_subscribed': femaleSubscribed,
    };
  }
}

class MovieStatsDto {
  const MovieStatsDto({
    required this.total,
    required this.subscribed,
    required this.playable,
  });

  final int total;
  final int subscribed;
  final int playable;

  factory MovieStatsDto.fromJson(Map<String, dynamic> json) {
    return MovieStatsDto(
      total: json['total'] as int? ?? 0,
      subscribed: json['subscribed'] as int? ?? 0,
      playable: json['playable'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total': total,
      'subscribed': subscribed,
      'playable': playable,
    };
  }
}

class MediaFileStatsDto {
  const MediaFileStatsDto({required this.total, required this.totalSizeBytes});

  final int total;
  final int totalSizeBytes;

  factory MediaFileStatsDto.fromJson(Map<String, dynamic> json) {
    return MediaFileStatsDto(
      total: json['total'] as int? ?? 0,
      totalSizeBytes: json['total_size_bytes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total': total,
      'total_size_bytes': totalSizeBytes,
    };
  }
}

class MediaLibraryStatsDto {
  const MediaLibraryStatsDto({required this.total});

  final int total;

  factory MediaLibraryStatsDto.fromJson(Map<String, dynamic> json) {
    return MediaLibraryStatsDto(total: json['total'] as int? ?? 0);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'total': total};
  }
}

class StatusDto {
  const StatusDto({
    required this.actors,
    required this.movies,
    required this.mediaFiles,
    required this.mediaLibraries,
  });

  final ActorStatsDto actors;
  final MovieStatsDto movies;
  final MediaFileStatsDto mediaFiles;
  final MediaLibraryStatsDto mediaLibraries;

  factory StatusDto.fromJson(Map<String, dynamic> json) {
    return StatusDto(
      actors: ActorStatsDto.fromJson(_asJsonMap(json['actors'])),
      movies: MovieStatsDto.fromJson(_asJsonMap(json['movies'])),
      mediaFiles: MediaFileStatsDto.fromJson(_asJsonMap(json['media_files'])),
      mediaLibraries: MediaLibraryStatsDto.fromJson(
        _asJsonMap(json['media_libraries']),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'actors': actors.toJson(),
      'movies': movies.toJson(),
      'media_files': mediaFiles.toJson(),
      'media_libraries': mediaLibraries.toJson(),
    };
  }

  static Map<String, dynamic> _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic data) => MapEntry(key.toString(), data),
      );
    }
    return const <String, dynamic>{};
  }
}
