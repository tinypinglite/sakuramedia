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
}

class MovieListItemDto {
  const MovieListItemDto({
    required this.javdbId,
    required this.movieNumber,
    required this.title,
    required this.coverImage,
    required this.releaseDate,
    required this.durationMinutes,
    required this.heat,
    required this.isSubscribed,
    required this.canPlay,
    this.similarityScore,
  });

  final String javdbId;
  final String movieNumber;
  final String title;
  final MovieImageDto? coverImage;
  final DateTime? releaseDate;
  final int durationMinutes;
  final int heat;
  final bool isSubscribed;
  final bool canPlay;
  final double? similarityScore;

  MovieListItemDto copyWith({
    String? javdbId,
    String? movieNumber,
    String? title,
    MovieImageDto? coverImage,
    DateTime? releaseDate,
    int? durationMinutes,
    int? heat,
    bool? isSubscribed,
    bool? canPlay,
    double? similarityScore,
  }) {
    return MovieListItemDto(
      javdbId: javdbId ?? this.javdbId,
      movieNumber: movieNumber ?? this.movieNumber,
      title: title ?? this.title,
      coverImage: coverImage ?? this.coverImage,
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
      javdbId: json['javdb_id'] as String? ?? '',
      movieNumber: json['movie_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      coverImage: _movieImageFromJson(json['cover_image']),
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
}
