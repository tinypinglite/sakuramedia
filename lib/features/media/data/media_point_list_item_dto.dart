import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class MediaPointListItemDto {
  const MediaPointListItemDto({
    required this.pointId,
    required this.mediaId,
    required this.movieNumber,
    required this.thumbnailId,
    required this.offsetSeconds,
    required this.image,
    required this.createdAt,
  });

  final int pointId;
  final int mediaId;
  final String movieNumber;
  final int thumbnailId;
  final int offsetSeconds;
  final MovieImageDto? image;
  final DateTime? createdAt;

  factory MediaPointListItemDto.fromJson(Map<String, dynamic> json) {
    return MediaPointListItemDto(
      pointId: json['point_id'] as int? ?? 0,
      mediaId: json['media_id'] as int? ?? 0,
      movieNumber: json['movie_number'] as String? ?? '',
      thumbnailId: json['thumbnail_id'] as int? ?? 0,
      offsetSeconds: json['offset_seconds'] as int? ?? 0,
      image: _movieImageFromJson(json['image']),
      createdAt: _dateTimeFromJson(json['created_at']),
    );
  }
}

DateTime? _dateTimeFromJson(dynamic value) {
  final raw = value as String?;
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

MovieImageDto? _movieImageFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MovieImageDto.fromJson(value);
  }
  if (value is Map) {
    return MovieImageDto.fromJson(
      value.map((dynamic key, dynamic data) => MapEntry(key.toString(), data)),
    );
  }
  return null;
}
