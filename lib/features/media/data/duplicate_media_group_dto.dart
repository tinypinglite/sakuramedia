import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';

/// `GET /media/duplicates` 返回的一个重复文件组。
///
/// 后端以文件 hash 分组，但当前契约不返回 hash 原值；前端只展示组内媒体，
/// 避免把技术指纹当成普通管理信息。
class DuplicateMediaGroupDto {
  const DuplicateMediaGroupDto({
    required this.kind,
    required this.mediaCount,
    required this.mediaItems,
  });

  final MediaListItemKind kind;
  final int mediaCount;
  final List<MediaListItemDto> mediaItems;

  DuplicateMediaGroupDto copyWith({
    int? mediaCount,
    List<MediaListItemDto>? mediaItems,
  }) {
    return DuplicateMediaGroupDto(
      kind: kind,
      mediaCount: mediaCount ?? this.mediaCount,
      mediaItems: mediaItems ?? this.mediaItems,
    );
  }

  factory DuplicateMediaGroupDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['media_items'];
    final mediaItems = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => MediaListItemDto.fromJson(
                  item.map(
                    (dynamic key, dynamic value) =>
                        MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList(growable: false)
        : const <MediaListItemDto>[];

    return DuplicateMediaGroupDto(
      kind: MediaListItemKindX.fromWire(json['kind']),
      mediaCount: (json['media_count'] as num?)?.toInt() ?? mediaItems.length,
      mediaItems: mediaItems,
    );
  }
}
