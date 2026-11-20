import 'package:sakuramedia/core/json/json_parse.dart';

/// 播放列表类型：后端按 `kind` 区分系统列表（不可手动增删）与用户列表。
abstract final class PlaylistKind {
  static const String custom = 'custom';

  /// 智能列表：成员由保存的筛选条件实时计算，不能手动增删。
  static const String smart = 'smart';

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
    required this.isSmart,
    this.smartFilter,
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

  /// 智能列表的成员由筛选条件实时计算，不能手动增删。
  final bool isSmart;

  /// 智能列表保存的筛选快照；普通/系统列表为 null。
  final SmartPlaylistFilterDto? smartFilter;
  final int movieCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PlaylistDto.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String? ?? PlaylistKind.custom;
    return PlaylistDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      kind: kind,
      description: json['description'] as String? ?? '',
      isSystem: json['is_system'] as bool? ?? false,
      isMutable: json['is_mutable'] as bool? ?? false,
      isDeletable: json['is_deletable'] as bool? ?? false,
      isSmart: json['is_smart'] as bool? ?? kind == PlaylistKind.smart,
      smartFilter: asObjectOrNull(
        json['smart_filter'],
        SmartPlaylistFilterDto.fromJson,
      ),
      movieCount: json['movie_count'] as int? ?? 0,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }
}

/// 智能列表保存的筛选快照（与后端 `smart_filter` 字段一一对应）。
///
/// 多选维度用列表表达，空列表表示「不限」；兼容早期单值字段。
class SmartPlaylistFilterDto {
  const SmartPlaylistFilterDto({
    this.statuses = const <String>[],
    this.statusMatch = 'or',
    this.watchStatuses = const <String>[],
    this.watchMatch = 'or',
    this.collectionType = 'all',
    this.numberSource = 'all',
    this.sort,
    this.years = const <int>[],
    this.resolutions = const <String>[],
    this.tagIds = const <int>[],
    this.tagMatch = 'or',
    this.mediaTagIds = const <int>[],
    this.mediaTagMatch = 'or',
    this.actorIds = const <int>[],
    this.actorMatch = 'or',
    this.actorAgeMin,
    this.actorAgeMax,
    this.heatMin,
    this.heatMax,
  });

  final List<String> statuses;
  final String statusMatch;
  final List<String> watchStatuses;
  final String watchMatch;
  final String collectionType;
  final String numberSource;
  final String? sort;
  final List<int> years;
  final List<String> resolutions;
  final List<int> tagIds;
  final String tagMatch;
  final List<int> mediaTagIds;
  final String mediaTagMatch;
  final List<int> actorIds;
  final String actorMatch;
  final int? actorAgeMin;
  final int? actorAgeMax;
  final int? heatMin;
  final int? heatMax;

  factory SmartPlaylistFilterDto.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistFilterDto(
      statuses: _liftLegacyString(
        json['statuses'],
        legacyValue: json['status'],
        legacyAllValue: 'all',
      ),
      statusMatch: json['status_match'] as String? ?? 'or',
      watchStatuses: _liftLegacyString(
        json['watch_statuses'],
        legacyValue: json['watch_status'],
        legacyAllValue: 'all',
      ),
      watchMatch: json['watch_match'] as String? ?? 'or',
      collectionType: json['collection_type'] as String? ?? 'all',
      numberSource: json['number_source'] as String? ?? 'all',
      sort: json['sort'] as String?,
      years: _intListFromJson(json['years']),
      resolutions: _liftLegacyString(
        json['resolutions'],
        legacyValue: json['resolution'],
      ),
      tagIds: _intListFromJson(json['tag_ids']),
      tagMatch: json['tag_match'] as String? ?? 'or',
      mediaTagIds: _intListFromJson(json['media_tag_ids']),
      mediaTagMatch: json['media_tag_match'] as String? ?? 'or',
      actorIds: _intListFromJson(json['actor_ids']),
      actorMatch: json['actor_match'] as String? ?? 'or',
      actorAgeMin: asIntOrNull(json['actor_age_min']),
      actorAgeMax: asIntOrNull(json['actor_age_max']),
      heatMin: asIntOrNull(json['heat_min']),
      heatMax: asIntOrNull(json['heat_max']),
    );
  }
}

class UpdatePlaylistPayload {
  const UpdatePlaylistPayload({this.name, this.description, this.filter});

  final String? name;
  final String? description;
  final Map<String, dynamic>? filter;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (filter != null) 'filter': filter,
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

List<int> _intListFromJson(dynamic value) {
  if (value is! List) {
    return const <int>[];
  }
  return value.map(asIntOrNull).whereType<int>().toList(growable: false);
}

List<String> _stringListFromJson(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}

/// 优先读新列表字段；旧快照只有单值时回退成单元素列表。
List<String> _liftLegacyString(
  dynamic value, {
  dynamic legacyValue,
  String? legacyAllValue,
}) {
  final list = _stringListFromJson(value);
  if (list.isNotEmpty) {
    return list;
  }
  if (legacyValue is String &&
      legacyValue.isNotEmpty &&
      legacyValue != legacyAllValue) {
    return <String>[legacyValue];
  }
  return const <String>[];
}
