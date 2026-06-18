import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';

/// 视频合集资源（`VideoCollectionResource`）。成员顺序见 [VideoCollectionItemDto]。
///
/// - `coverImage`：取按顺序排在最前的视频封面；空合集或来源缺失时为 `null`。
class VideoCollectionDto {
  const VideoCollectionDto({
    required this.id,
    required this.name,
    this.description = '',
    this.itemCount = 0,
    this.coverImage,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String description;
  final int itemCount;
  final MovieImageDto? coverImage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory VideoCollectionDto.fromJson(Map<String, dynamic> json) {
    return VideoCollectionDto(
      id: _intFromJson(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      itemCount: _intFromJson(json['item_count']) ?? 0,
      coverImage: _coverImageFromJson(json['cover_image']),
      createdAt: videoDateFromJson(json['created_at']),
      updatedAt: videoDateFromJson(json['updated_at']),
    );
  }
}

MovieImageDto? _coverImageFromJson(dynamic value) {
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

/// 视频合集成员项（`VideoCollectionItemResource`）：含排序位 [position] 与内嵌视频概要。
///
/// [playUrl]：连播页所需「首个媒体」的签名播放地址，仅在请求带 `include_play_url=true`
/// 时由后端内联（否则为 `null`）。连播页据此直接组装播放列表，免逐集拉详情。
class VideoCollectionItemDto {
  const VideoCollectionItemDto({
    required this.itemId,
    required this.position,
    required this.video,
    this.playUrl,
  });

  final int itemId;
  final int position;
  final VideoItemListItemDto video;
  final String? playUrl;

  factory VideoCollectionItemDto.fromJson(Map<String, dynamic> json) {
    final rawVideo = json['video'];
    final videoMap = rawVideo is Map
        ? rawVideo.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          )
        : <String, dynamic>{};
    return VideoCollectionItemDto(
      itemId: _intFromJson(json['item_id']) ?? 0,
      position: _intFromJson(json['position']) ?? 0,
      video: VideoItemListItemDto.fromJson(videoMap),
      playUrl: asStringOrNull(json['play_url']),
    );
  }
}

/// `PATCH /video-collections/{id}` 的局部更新载荷；字段为 `null` 即不下发。
class VideoCollectionUpdatePayload {
  const VideoCollectionUpdatePayload({this.name, this.description});

  final String? name;
  final String? description;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name!.trim(),
      if (description != null) 'description': description,
    };
  }
}

int? _intFromJson(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
