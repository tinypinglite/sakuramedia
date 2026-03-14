import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class ImageSearchResultItemDto {
  const ImageSearchResultItemDto({
    required this.thumbnailId,
    required this.mediaId,
    required this.movieId,
    required this.movieNumber,
    required this.offsetSeconds,
    required this.score,
    required this.image,
  });

  final int thumbnailId;
  final int mediaId;
  final int movieId;
  final String movieNumber;
  final int offsetSeconds;
  final double score;
  final MovieImageDto image;

  factory ImageSearchResultItemDto.fromJson(Map<String, dynamic> json) {
    return ImageSearchResultItemDto(
      thumbnailId: json['thumbnail_id'] as int? ?? 0,
      mediaId: json['media_id'] as int? ?? 0,
      movieId: json['movie_id'] as int? ?? 0,
      movieNumber: json['movie_number'] as String? ?? '',
      offsetSeconds: json['offset_seconds'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      image: MovieImageDto.fromJson(_toMap(json['image'])),
    );
  }

  static Map<String, dynamic> _toMap(dynamic value) {
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
