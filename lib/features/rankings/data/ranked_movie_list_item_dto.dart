import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/subscription_movie_list_item.dart';

class RankedMovieListItemDto
    implements SubscriptionMovieListItem<RankedMovieListItemDto> {
  const RankedMovieListItemDto({
    required this.rank,
    this.maxMediaWidth = 0,
    required this.movieNumber,
    required this.title,
    required this.coverImage,
    this.thinCoverImage,
    required this.releaseDate,
    required this.durationMinutes,
    required this.heat,
    required this.isSubscribed,
    required this.canPlay,
  });

  final int rank;
  final int maxMediaWidth;
  @override
  final String movieNumber;
  final String title;
  final MovieImageDto? coverImage;
  final MovieImageDto? thinCoverImage;
  final DateTime? releaseDate;
  final int durationMinutes;
  final int heat;
  @override
  final bool isSubscribed;
  final bool canPlay;

  RankedMovieListItemDto copyWith({
    int? rank,
    String? movieNumber,
    String? title,
    MovieImageDto? coverImage,
    MovieImageDto? thinCoverImage,
    DateTime? releaseDate,
    int? durationMinutes,
    int? heat,
    bool? isSubscribed,
    bool? canPlay,
  }) {
    return RankedMovieListItemDto(
      rank: rank ?? this.rank,
      maxMediaWidth: maxMediaWidth,
      movieNumber: movieNumber ?? this.movieNumber,
      title: title ?? this.title,
      coverImage: coverImage ?? this.coverImage,
      thinCoverImage: thinCoverImage ?? this.thinCoverImage,
      releaseDate: releaseDate ?? this.releaseDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      heat: heat ?? this.heat,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      canPlay: canPlay ?? this.canPlay,
    );
  }

  @override
  RankedMovieListItemDto copyWithSubscriptionStatus(bool isSubscribed) =>
      copyWith(isSubscribed: isSubscribed);

  MovieListItemDto toMovieListItem() {
    return MovieListItemDto(
      movieNumber: movieNumber,
      title: title,
      coverImage: coverImage,
      thinCoverImage: thinCoverImage,
      releaseDate: releaseDate,
      durationMinutes: durationMinutes,
      heat: heat,
      isSubscribed: isSubscribed,
      canPlay: canPlay,
      maxMediaWidth: maxMediaWidth,
    );
  }

  factory RankedMovieListItemDto.fromJson(Map<String, dynamic> json) {
    return RankedMovieListItemDto(
      rank: json['rank'] as int? ?? 0,
      maxMediaWidth: MovieListItemDto.fromJson(json).maxMediaWidth,
      movieNumber: json['movie_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      coverImage: _movieImageFromJson(json['cover_image']),
      thinCoverImage: _movieImageFromJson(json['thin_cover_image']),
      releaseDate: _dateFromJson(json['release_date']),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      heat: json['heat'] as int? ?? 0,
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
