import 'package:sakuramedia/core/json/json_parse.dart';

class MetadataSourceDto {
  const MetadataSourceDto({required this.pluginId, required this.displayName});

  final String pluginId;
  final String displayName;

  factory MetadataSourceDto.fromJson(Map<String, dynamic> json) {
    return MetadataSourceDto(
      pluginId: asStringOrNull(json['plugin_id'], trim: true) ?? '',
      displayName: asStringOrNull(json['display_name'], trim: true) ?? '',
    );
  }
}
