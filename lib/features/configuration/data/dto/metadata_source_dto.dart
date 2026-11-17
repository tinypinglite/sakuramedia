import 'package:sakuramedia/core/json/json_parse.dart';

class MetadataSourceDto {
  const MetadataSourceDto({
    required this.pluginId,
    required this.displayName,
    required this.supportsActorMovies,
  });

  final String pluginId;
  final String displayName;

  /// null 表示后端版本还没有下发该能力字段。
  final bool? supportsActorMovies;

  factory MetadataSourceDto.fromJson(Map<String, dynamic> json) {
    return MetadataSourceDto(
      pluginId: asStringOrNull(json['plugin_id'], trim: true) ?? '',
      displayName: asStringOrNull(json['display_name'], trim: true) ?? '',
      supportsActorMovies: json.containsKey('supports_actor_movies')
          ? asBool(json['supports_actor_movies'])
          : null,
    );
  }
}
