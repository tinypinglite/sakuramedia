import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

class MediaPointListItemDto {
  const MediaPointListItemDto({
    required this.pointId,
    required this.mediaId,
    required this.movieNumber,
    this.videoItemId,
    required this.thumbnailId,
    required this.offsetSeconds,
    required this.image,
    required this.createdAt,
  });

  final int pointId;
  final int mediaId;
  // JAV 时刻带番号，视频时刻为空（后端按 kind 区分）。
  final String? movieNumber;
  // 视频（非 JAV）时刻挂的 videos 域条目 id；JAV 时刻为 null。
  final int? videoItemId;
  final int thumbnailId;
  final int offsetSeconds;
  final MovieImageDto? image;
  final DateTime? createdAt;

  bool get isVideo => videoItemId != null && videoItemId! > 0;

  factory MediaPointListItemDto.fromJson(Map<String, dynamic> json) {
    return MediaPointListItemDto(
      pointId: json['point_id'] as int? ?? 0,
      mediaId: json['media_id'] as int? ?? 0,
      movieNumber: json['movie_number'] as String?,
      videoItemId: json['video_item_id'] as int?,
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
