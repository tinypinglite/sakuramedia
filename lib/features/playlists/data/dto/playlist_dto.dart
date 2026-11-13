import 'package:sakuramedia/core/json/json_parse.dart';

/// 播放列表类型：后端按 `kind` 区分系统列表（不可手动增删）与用户列表。
abstract final class PlaylistKind {
  static const String custom = 'custom';

  /// 系统「最近播放」，播放影片时由后端自动触达维护。
  static const String recentlyPlayed = 'recently_played';

  /// 系统「收藏」，成员由用户在影片详情里手动增删。
  static const String favorites = 'favorites';
}

class PlaylistDto {
  const PlaylistDto({
    required this.id,
    required this.name,
    required this.kind,
    required this.description,
    required this.isSystem,
    required this.isMutable,
    required this.isDeletable,
    required this.movieCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String kind;
  final String description;
  final bool isSystem;

  /// 是否可编辑列表信息（改名/描述）；收藏的成员增删按 [kind] 判定。
  final bool isMutable;
  final bool isDeletable;
  final int movieCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PlaylistDto.fromJson(Map<String, dynamic> json) {
    return PlaylistDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'custom',
      description: json['description'] as String? ?? '',
      isSystem: json['is_system'] as bool? ?? false,
      isMutable: json['is_mutable'] as bool? ?? false,
      isDeletable: json['is_deletable'] as bool? ?? false,
      movieCount: json['movie_count'] as int? ?? 0,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }
}

class UpdatePlaylistPayload {
  const UpdatePlaylistPayload({this.name, this.description});

  final String? name;
  final String? description;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    };
  }
}

class PlaylistMovieBatchAddSkippedItemDto {
  const PlaylistMovieBatchAddSkippedItemDto({
    required this.movieNumber,
    required this.reason,
  });

  final String movieNumber;
  final String reason;

  factory PlaylistMovieBatchAddSkippedItemDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlaylistMovieBatchAddSkippedItemDto(
      movieNumber: json['movie_number'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }
}

class PlaylistMovieBatchAddResultDto {
  const PlaylistMovieBatchAddResultDto({
    required this.requestedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.skipped,
  });

  final int requestedCount;
  final int updatedCount;
  final int skippedCount;
  final List<PlaylistMovieBatchAddSkippedItemDto> skipped;

  factory PlaylistMovieBatchAddResultDto.fromJson(Map<String, dynamic> json) {
    return PlaylistMovieBatchAddResultDto(
      requestedCount: asInt(json['requested_count']),
      updatedCount: asInt(json['updated_count']),
      skippedCount: asInt(json['skipped_count']),
      skipped: asObjectList(
        json['skipped'],
        PlaylistMovieBatchAddSkippedItemDto.fromJson,
      ),
    );
  }
}

DateTime? _dateTimeFromJson(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
