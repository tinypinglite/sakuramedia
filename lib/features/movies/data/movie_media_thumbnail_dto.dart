import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class MovieMediaThumbnailDto {
  const MovieMediaThumbnailDto({
    required this.thumbnailId,
    required this.mediaId,
    required this.offsetSeconds,
    required this.image,
  });

  final int thumbnailId;
  final int mediaId;
  final int offsetSeconds;
  final MovieImageDto image;

  factory MovieMediaThumbnailDto.fromJson(Map<String, dynamic> json) {
    return MovieMediaThumbnailDto(
      thumbnailId: json['thumbnail_id'] as int? ?? 0,
      mediaId: json['media_id'] as int? ?? 0,
      offsetSeconds: json['offset_seconds'] as int? ?? 0,
      image: _imageFromJson(json['image']),
    );
  }

  static MovieImageDto _imageFromJson(dynamic value) {
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
    return const MovieImageDto(
      id: 0,
      origin: '',
      small: '',
      medium: '',
      large: '',
    );
  }
}
