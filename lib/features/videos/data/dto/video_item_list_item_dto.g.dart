// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_item_list_item_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideoCollectionRef _$VideoCollectionRefFromJson(Map<String, dynamic> json) =>
    VideoCollectionRef(
      id: const IntJsonConverter().fromJson(json['id']),
      name: const StringJsonConverter().fromJson(json['name']),
    );

VideoItemListItemDto _$VideoItemListItemDtoFromJson(
  Map<String, dynamic> json,
) => VideoItemListItemDto(
  id: const IntJsonConverter().fromJson(json['id']),
  title: const StringJsonConverter().fromJson(json['title']),
  summary: json['summary'] == null
      ? ''
      : const StringJsonConverter().fromJson(json['summary']),
  coverImage: videoImageFromJson(json['cover_image']),
  releaseDate: const DateTimeJsonConverter().fromJson(json['release_date']),
  durationSeconds: json['duration_seconds'] == null
      ? 0
      : const IntJsonConverter().fromJson(json['duration_seconds']),
  fileSizeBytes: json['file_size_bytes'] == null
      ? 0
      : const IntJsonConverter().fromJson(json['file_size_bytes']),
  coverWidth: const NullableIntJsonConverter().fromJson(json['cover_width']),
  coverHeight: const NullableIntJsonConverter().fromJson(json['cover_height']),
  mediaCount: const IntJsonConverter().fromJson(json['media_count']),
  canPlay: const BoolJsonConverter().fromJson(json['can_play']),
  collections: json['collections'] == null
      ? const <VideoCollectionRef>[]
      : videoCollectionRefsFromJson(json['collections']),
  createdAt: const DateTimeJsonConverter().fromJson(json['created_at']),
  updatedAt: const DateTimeJsonConverter().fromJson(json['updated_at']),
);
