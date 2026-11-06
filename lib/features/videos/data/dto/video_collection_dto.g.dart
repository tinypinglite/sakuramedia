// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_collection_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideoCollectionDto _$VideoCollectionDtoFromJson(Map<String, dynamic> json) =>
    VideoCollectionDto(
      id: const IntJsonConverter().fromJson(json['id']),
      name: const StringJsonConverter().fromJson(json['name']),
      description: json['description'] == null
          ? ''
          : const StringJsonConverter().fromJson(json['description']),
      itemCount: json['item_count'] == null
          ? 0
          : const IntJsonConverter().fromJson(json['item_count']),
      coverImage: videoImageFromJson(json['cover_image']),
      createdAt: const DateTimeJsonConverter().fromJson(json['created_at']),
      updatedAt: const DateTimeJsonConverter().fromJson(json['updated_at']),
    );

VideoCollectionItemDto _$VideoCollectionItemDtoFromJson(
  Map<String, dynamic> json,
) => VideoCollectionItemDto(
  position: const IntJsonConverter().fromJson(json['position']),
  video: _videoFromJson(json['video']),
  playUrl: asStringOrNull(json['play_url']),
  firstMediaId: const NullableIntJsonConverter().fromJson(
    json['first_media_id'],
  ),
);
