import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class RankedMovieListItemDto {
  const RankedMovieListItemDto({
    required this.rank,
    required this.javdbId,
    required this.movieNumber,
    required this.title,
    required this.coverImage,
    required this.releaseDate,
    required this.durationMinutes,
    required this.isSubscribed,
    required this.canPlay,
  });

  final int rank;
  final String javdbId;
  final String movieNumber;
  final String title;
  final MovieImageDto? coverImage;
  final DateTime? releaseDate;
  final int durationMinutes;
  final bool isSubscribed;
  final bool canPlay;

  RankedMovieListItemDto copyWith({
    int? rank,
    String? javdbId,
    String? movieNumber,
    String? title,
    MovieImageDto? coverImage,
    DateTime? releaseDate,
    int? durationMinutes,
    bool? isSubscribed,
    bool? canPlay,
  }) {
    return RankedMovieListItemDto(
      rank: rank ?? this.rank,
      javdbId: javdbId ?? this.javdbId,
      movieNumber: movieNumber ?? this.movieNumber,
      title: title ?? this.title,
      coverImage: coverImage ?? this.coverImage,
      releaseDate: releaseDate ?? this.releaseDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      canPlay: canPlay ?? this.canPlay,
    );
  }

  MovieListItemDto toMovieListItem() {
    return MovieListItemDto(
      javdbId: javdbId,
      movieNumber: movieNumber,
      title: title,
      coverImage: coverImage,
      releaseDate: releaseDate,
      durationMinutes: durationMinutes,
      isSubscribed: isSubscribed,
      canPlay: canPlay,
    );
  }

  factory RankedMovieListItemDto.fromJson(Map<String, dynamic> json) {
    return RankedMovieListItemDto(
      rank: json['rank'] as int? ?? 0,
      javdbId: json['javdb_id'] as String? ?? '',
      movieNumber: json['movie_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      coverImage: _movieImageFromJson(json['cover_image']),
      releaseDate: _dateFromJson(json['release_date']),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      isSubscribed: json['is_subscribed'] as bool? ?? false,
      canPlay: json['can_play'] as bool? ?? false,
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
}
