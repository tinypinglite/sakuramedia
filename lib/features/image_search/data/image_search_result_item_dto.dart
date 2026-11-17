import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

class ImageSearchResultItemDto {
  const ImageSearchResultItemDto({
    required this.thumbnailId,
    required this.mediaId,
    required this.movieId,
    required this.movieNumber,
    required this.offsetSeconds,
    required this.score,
    required this.image,
    this.plotImageId,
  });

  final int thumbnailId;
  final int mediaId;
  final int movieId;
  final String movieNumber;
  final int offsetSeconds;
  final double score;
  final MovieImageDto image;
  final int? plotImageId;

  int get resultImageId => plotImageId ?? thumbnailId;

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

  factory ImageSearchResultItemDto.fromPlotImageJson(
    Map<String, dynamic> json,
  ) {
    return ImageSearchResultItemDto(
      thumbnailId: 0,
      mediaId: 0,
      movieId: json['movie_id'] as int? ?? 0,
      movieNumber: json['movie_number'] as String? ?? '',
      offsetSeconds: 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      image: MovieImageDto.fromJson(_toMap(json['image'])),
      plotImageId: json['plot_image_id'] as int? ?? 0,
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
