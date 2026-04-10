import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class HotReviewListItemDto {
  const HotReviewListItemDto({
    required this.rank,
    required this.reviewId,
    required this.score,
    required this.content,
    required this.createdAt,
    required this.username,
    required this.likeCount,
    required this.watchCount,
    required this.movie,
  });

  final int rank;
  final int reviewId;
  final int score;
  final String content;
  final DateTime? createdAt;
  final String username;
  final int likeCount;
  final int watchCount;
  final MovieListItemDto movie;

  factory HotReviewListItemDto.fromJson(Map<String, dynamic> json) {
    return HotReviewListItemDto(
      rank: json['rank'] as int? ?? 0,
      reviewId: json['review_id'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      createdAt: _dateTimeFromJson(json['created_at']),
      username: json['username'] as String? ?? '',
      likeCount: json['like_count'] as int? ?? 0,
      watchCount: json['watch_count'] as int? ?? 0,
      movie: _movieFromJson(json['movie']),
    );
  }

  static MovieListItemDto _movieFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return MovieListItemDto.fromJson(value);
    }
    if (value is Map) {
      return MovieListItemDto.fromJson(
        value.map(
          (dynamic key, dynamic data) => MapEntry(key.toString(), data),
        ),
      );
    }
    return const MovieListItemDto(
      javdbId: '',
      movieNumber: '',
      title: '',
      coverImage: null,
      releaseDate: null,
      durationMinutes: 0,
      heat: 0,
      isSubscribed: false,
      canPlay: false,
    );
  }
}

DateTime? _dateTimeFromJson(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
