// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_item_detail_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideoItemDetailDto _$VideoItemDetailDtoFromJson(
  Map<String, dynamic> json,
) => VideoItemDetailDto(
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
  mediaItems: json['media_items'] == null
      ? const <MovieMediaItemDto>[]
      : _mediaItemsFromJson(json['media_items']),
);
