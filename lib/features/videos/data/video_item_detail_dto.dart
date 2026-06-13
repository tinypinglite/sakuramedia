import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/person_dto.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';

/// 非 JAV 视频条目的详情资源（`VideoItemDetailResource`）。
///
/// 在列表项字段之上追加 [tags]、[persons] 与 [mediaItems]。其中 `media_items`
/// 后端复用「影片媒体资源」结构，因此直接复用 [MovieMediaItemDto.fromJson] 解析，
/// 不再另立平行 DTO；标签同样复用 [MovieTagDto]（`tag_id`/`name` 同形）。
class VideoItemDetailDto {
  const VideoItemDetailDto({
    required this.id,
    required this.title,
    this.summary = '',
    this.coverImage,
    this.releaseDate,
    required this.mediaCount,
    required this.canPlay,
    this.createdAt,
    this.updatedAt,
    this.tags = const <MovieTagDto>[],
    this.persons = const <PersonDto>[],
    this.mediaItems = const <MovieMediaItemDto>[],
  });

  final int id;
  final String title;
  final String summary;
  final MovieImageDto? coverImage;
  final DateTime? releaseDate;
  final int mediaCount;
  final bool canPlay;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<MovieTagDto> tags;
  final List<PersonDto> persons;
  final List<MovieMediaItemDto> mediaItems;

  String get preferredTitle {
    final resolved = title.trim();
    if (resolved.isNotEmpty) {
      return resolved;
    }
    return '未命名视频';
  }

  /// 详情转列表项，便于在列表/合集等位置复用已加载的概要信息。
  VideoItemListItemDto toListItem() {
    return VideoItemListItemDto(
      id: id,
      title: title,
      summary: summary,
      coverImage: coverImage,
      releaseDate: releaseDate,
      mediaCount: mediaCount,
      canPlay: canPlay,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory VideoItemDetailDto.fromJson(Map<String, dynamic> json) {
    return VideoItemDetailDto(
      id: _intFromJson(json['id']) ?? 0,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      coverImage: videoImageFromJson(json['cover_image']),
      releaseDate: videoDateFromJson(json['release_date']),
      mediaCount: _intFromJson(json['media_count']) ?? 0,
      canPlay: json['can_play'] as bool? ?? false,
      createdAt: videoDateFromJson(json['created_at']),
      updatedAt: videoDateFromJson(json['updated_at']),
      tags: _listFromJson(json['tags'], MovieTagDto.fromJson),
      persons: _listFromJson(json['persons'], PersonDto.fromJson),
      mediaItems: _listFromJson(json['media_items'], MovieMediaItemDto.fromJson),
    );
  }
}

/// `PATCH /videos/{id}` 的局部更新载荷。
///
/// 字段为 `null` 表示「不传该键、保持原值」；[tagIds]/[personIds] 一旦非 `null`
/// （含空列表）即「整体替换」该关联（对齐后端 `VideoItemUpdateRequest` 语义）。
/// [releaseDate] 仅在非 `null` 时下发，phase 1 不支持经此清空发布时间。
class VideoItemUpdatePayload {
  const VideoItemUpdatePayload({
    this.title,
    this.summary,
    this.releaseDate,
    this.tagIds,
    this.personIds,
  });

  final String? title;
  final String? summary;
  final DateTime? releaseDate;
  final List<int>? tagIds;
  final List<int>? personIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (releaseDate != null)
        'release_date': releaseDate!.toIso8601String(),
      if (tagIds != null) 'tag_ids': tagIds,
      if (personIds != null) 'person_ids': personIds,
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

List<T> _listFromJson<T>(
  dynamic value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) {
    return <T>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => fromJson(
          item.map(
            (dynamic key, dynamic data) => MapEntry(key.toString(), data),
          ),
        ),
      )
      .toList(growable: false);
}
