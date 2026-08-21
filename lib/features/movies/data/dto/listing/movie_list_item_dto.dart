class MovieImageDto {
  const MovieImageDto({
    required this.id,
    required this.origin,
    required this.small,
    required this.medium,
    required this.large,
  });

  final int id;
  final String origin;
  final String small;
  final String medium;
  final String large;

  factory MovieImageDto.fromJson(Map<String, dynamic> json) {
    return MovieImageDto(
      id: json['id'] as int? ?? 0,
      origin: json['origin'] as String? ?? '',
      small: json['small'] as String? ?? '',
      medium: json['medium'] as String? ?? '',
      large: json['large'] as String? ?? '',
    );
  }

  String get bestAvailableUrl {
    if (large.isNotEmpty) {
      return large;
    }
    if (medium.isNotEmpty) {
      return medium;
    }
    if (small.isNotEmpty) {
      return small;
    }
    return origin;
  }

  String get resolvedUrl {
    final trimmedOrigin = origin.trim();
    if (trimmedOrigin.isNotEmpty) {
      return trimmedOrigin;
    }
    return bestAvailableUrl;
  }
}

class MovieListItemDto {
  const MovieListItemDto({
    this.id = 0,
    required this.javdbId,
    required this.movieNumber,
    required this.title,
    this.seriesId,
    this.seriesName = '',
    required this.coverImage,
    this.thinCoverImage,
    required this.releaseDate,
    required this.durationMinutes,
    required this.heat,
    required this.isSubscribed,
    required this.canPlay,
    this.similarityScore,
  });

  /// 后端返回的影片整数主键，可用于与订阅等域数据关联。
  final int id;

  final String javdbId;
  final String movieNumber;
  final String title;
  final int? seriesId;
  final String seriesName;
  final MovieImageDto? coverImage;
  final MovieImageDto? thinCoverImage;
  final DateTime? releaseDate;
  final int durationMinutes;
  final int heat;
  final bool isSubscribed;
  final bool canPlay;
  final double? similarityScore;

  /// DMM 中文标题字段已随后端下线（存量收拢进 [title]），这里保留 getter 只做 trim。
  String get preferredTitle => title.trim();

  MovieListItemDto copyWith({
    String? javdbId,
    String? movieNumber,
    String? title,
    int? seriesId,
    String? seriesName,
    MovieImageDto? coverImage,
    MovieImageDto? thinCoverImage,
    DateTime? releaseDate,
    int? durationMinutes,
    int? heat,
    bool? isSubscribed,
    bool? canPlay,
    double? similarityScore,
  }) {
    return MovieListItemDto(
      // id 是不可变主键，copyWith 不开放改写、只透传（漏传会被默认 0 抹掉）。
      id: id,
      javdbId: javdbId ?? this.javdbId,
      movieNumber: movieNumber ?? this.movieNumber,
      title: title ?? this.title,
      seriesId: seriesId ?? this.seriesId,
      seriesName: seriesName ?? this.seriesName,
      coverImage: coverImage ?? this.coverImage,
      thinCoverImage: thinCoverImage ?? this.thinCoverImage,
      releaseDate: releaseDate ?? this.releaseDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      heat: heat ?? this.heat,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      canPlay: canPlay ?? this.canPlay,
      similarityScore: similarityScore ?? this.similarityScore,
    );
  }

  factory MovieListItemDto.fromJson(Map<String, dynamic> json) {
    return MovieListItemDto(
      id: _intFromJson(json['id']) ?? 0,
      javdbId: json['javdb_id'] as String? ?? '',
      movieNumber: json['movie_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      seriesId: _intFromJson(json['series_id']),
      seriesName: json['series_name'] as String? ?? '',
      coverImage: _movieImageFromJson(json['cover_image']),
      thinCoverImage: _movieImageFromJson(json['thin_cover_image']),
      releaseDate: _dateFromJson(json['release_date']),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      heat: json['heat'] as int? ?? 0,
      isSubscribed: json['is_subscribed'] as bool? ?? false,
      canPlay: json['can_play'] as bool? ?? false,
      similarityScore: _doubleFromJson(json['similarity_score']),
    );
  }

  static MovieImageDto? _movieImageFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return MovieImageDto.fromJson(value);
    }
    if (value is Map) {
      return MovieImageDto.fromJson(
        value.map(
          (dynamic key, dynamic data) => MapEntry(key.toString(), data),
        ),
      );
    }
    return null;
  }

  static DateTime? _dateFromJson(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static double? _doubleFromJson(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  static int? _intFromJson(dynamic value) {
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
}
