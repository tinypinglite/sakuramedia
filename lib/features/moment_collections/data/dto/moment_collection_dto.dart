import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

class MomentCollectionDto {
  const MomentCollectionDto({
    required this.id,
    required this.name,
    required this.description,
    required this.pointCount,
    required this.coverImage,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String description;
  final int pointCount;
  final MovieImageDto? coverImage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MomentCollectionDto.fromJson(Map<String, dynamic> json) {
    return MomentCollectionDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pointCount: json['point_count'] as int? ?? 0,
      coverImage: _imageFromJson(json['cover_image']),
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }
}

class MomentCollectionPointDto {
  const MomentCollectionPointDto({
    required this.pointId,
    required this.mediaId,
    required this.movieNumber,
    required this.videoItemId,
    required this.thumbnailId,
    required this.offsetSeconds,
    required this.image,
    required this.position,
  });

  final int pointId;
  final int mediaId;
  final String? movieNumber;
  final int? videoItemId;
  final int thumbnailId;
  final int offsetSeconds;
  final MovieImageDto? image;
  final int position;

  factory MomentCollectionPointDto.fromJson(Map<String, dynamic> json) {
    return MomentCollectionPointDto(
      pointId: json['point_id'] as int? ?? 0,
      mediaId: json['media_id'] as int? ?? 0,
      movieNumber: json['movie_number'] as String?,
      videoItemId: json['video_item_id'] as int?,
      thumbnailId: json['thumbnail_id'] as int? ?? 0,
      offsetSeconds: json['offset_seconds'] as int? ?? 0,
      image: _imageFromJson(json['image']),
      position: json['position'] as int? ?? 0,
    );
  }

  MomentListItem toMomentListItem() => MomentListItem(
    pointId: pointId,
    mediaId: mediaId,
    movieNumber: movieNumber,
    videoItemId: videoItemId,
    thumbnailId: thumbnailId,
    offsetSeconds: offsetSeconds,
    image: image,
  );
}

class MomentCollectionSummaryDto {
  const MomentCollectionSummaryDto({required this.id, required this.name});

  final int id;
  final String name;

  factory MomentCollectionSummaryDto.fromJson(Map<String, dynamic> json) {
    return MomentCollectionSummaryDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class UpdateMomentCollectionPayload {
  const UpdateMomentCollectionPayload({this.name, this.description});

  final String? name;
  final String? description;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (name != null) 'name': name,
    if (description != null) 'description': description,
  };
}

MovieImageDto? _imageFromJson(dynamic value) {
  if (value is Map<String, dynamic>) return MovieImageDto.fromJson(value);
  if (value is Map) {
    return MovieImageDto.fromJson(
      value.map((dynamic key, dynamic data) => MapEntry(key.toString(), data)),
    );
  }
  return null;
}

DateTime? _dateTimeFromJson(dynamic value) {
  final raw = value as String?;
  return raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);
}
