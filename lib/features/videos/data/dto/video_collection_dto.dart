import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';
import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';

part 'video_collection_dto.g.dart';

/// 视频合集资源（`VideoCollectionResource`）。成员顺序见 [VideoCollectionItemDto]。
///
/// - `coverImage`：取按顺序排在最前的视频封面；空合集或来源缺失时为 `null`。
@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
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

  @JsonKey(fromJson: videoImageFromJson)
  final MovieImageDto? coverImage;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory VideoCollectionDto.fromJson(Map<String, dynamic> json) =>
      _$VideoCollectionDtoFromJson(json);
}

/// 视频合集成员项（`VideoCollectionItemResource`）：含排序位 [position] 与内嵌视频概要。
///
/// [playUrl]：连播页所需「首个媒体」的签名播放地址，仅在请求带 `include_play_url=true`
/// 时由后端内联（否则为 `null`）。连播页据此直接组装播放列表，免逐集拉详情。
///
/// [firstMediaId]：「首个媒体」（Media.id 升序）的 id，与 [playUrl] 同源但**恒返回**
/// （不依赖 `include_play_url`），成员无媒体时为 `null`。连播页右侧「整部合集」关键帧
/// 面板据此调 `GET /media/{id}/thumbnails` 拉该集关键帧。
///
/// [playProviderKey]：与 [playUrl] 同源的首个媒体 provider；连播页据此为每一集选择
/// 播放请求头（例如 115 必须使用官方 iOS User-Agent 才能拿到高并发直链）。
@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class VideoCollectionItemDto {
  const VideoCollectionItemDto({
    required this.position,
    required this.video,
    this.playUrl,
    this.firstMediaId,
    this.playProviderKey,
  });

  final int position;

  @JsonKey(fromJson: _videoFromJson)
  final VideoItemListItemDto video;

  @JsonKey(fromJson: asStringOrNull)
  final String? playUrl;

  final int? firstMediaId;

  @JsonKey(name: 'play_provider_key', fromJson: asStringOrNull)
  final String? playProviderKey;

  factory VideoCollectionItemDto.fromJson(Map<String, dynamic> json) =>
      _$VideoCollectionItemDtoFromJson(json);
}

VideoItemListItemDto _videoFromJson(Object? value) =>
    VideoItemListItemDto.fromJson(asMap(value));

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
