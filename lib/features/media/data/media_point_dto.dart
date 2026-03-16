import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class MediaPointDto {
  const MediaPointDto({
    required this.pointId,
    required this.mediaId,
    required this.thumbnailId,
    required this.offsetSeconds,
    required this.image,
    required this.createdAt,
  });

  final int pointId;
  final int mediaId;
  final int thumbnailId;
  final int offsetSeconds;
  final MovieImageDto? image;
  final DateTime? createdAt;

  factory MediaPointDto.fromJson(Map<String, dynamic> json) {
    return MediaPointDto(
      pointId: json['point_id'] as int? ?? 0,
      mediaId: json['media_id'] as int? ?? 0,
      thumbnailId: json['thumbnail_id'] as int? ?? 0,
      offsetSeconds: json['offset_seconds'] as int? ?? 0,
      image: _movieImageFromJson(json['image']),
      createdAt: _dateTimeFromJson(json['created_at']),
    );
  }

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
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
}
