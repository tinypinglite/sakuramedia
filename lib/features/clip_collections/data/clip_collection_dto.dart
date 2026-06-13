import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

/// 切片合集资源（后端 `ClipCollectionResource`）。
///
/// 合集是跨影片的有序切片集合，可连续播放：
/// - `coverImage`：取按顺序排在最前的切片封面；空合集或来源缺失时为 `null`。
/// - `clipCount`：合集内切片数量。
class ClipCollectionDto {
  const ClipCollectionDto({
    required this.id,
    required this.name,
    required this.description,
    required this.clipCount,
    required this.coverImage,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String description;
  final int clipCount;
  final MovieImageDto? coverImage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ClipCollectionDto.fromJson(Map<String, dynamic> json) {
    return ClipCollectionDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      clipCount: json['clip_count'] as int? ?? 0,
      coverImage: _movieImageFromJson(json['cover_image']),
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }

  ClipCollectionDto copyWith({String? name, String? description}) {
    return ClipCollectionDto(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      clipCount: clipCount,
      coverImage: coverImage,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// 合集内的切片项（后端 `ClipCollectionClipItemResource`）：切片资源 + 顺序 `position`。
class ClipCollectionClipItemDto {
  const ClipCollectionClipItemDto({required this.clip, required this.position});

  final MediaClipDto clip;
  final int position;

  factory ClipCollectionClipItemDto.fromJson(Map<String, dynamic> json) {
    return ClipCollectionClipItemDto(
      clip: MediaClipDto.fromJson(json),
      position: json['position'] as int? ?? 0,
    );
  }
}

/// 合集编辑载荷：仅提交需要变更的字段。
class UpdateClipCollectionPayload {
  const UpdateClipCollectionPayload({this.name, this.description});

  final String? name;
  final String? description;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    };
  }
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

DateTime? _dateTimeFromJson(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
