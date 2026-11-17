import 'package:sakuramedia/core/json/json_parse.dart';

/// `/system/plugins/bindings` 中的互动数字段描述。
class PluginStatsFieldDto {
  const PluginStatsFieldDto({
    required this.key,
    required this.label,
    required this.valueType,
    this.min = 0,
    this.max,
    this.unit,
  });

  final String key;
  final String label;
  final String valueType;
  final num min;
  final num? max;
  final String? unit;

  factory PluginStatsFieldDto.fromJson(Map<String, dynamic> json) {
    return PluginStatsFieldDto(
      key: asStringOrNull(json['key'], trim: true) ?? '',
      label: asStringOrNull(json['label'], trim: true) ?? '',
      valueType: asStringOrNull(json['value_type'], trim: true) ?? 'int',
      min: asDoubleOrNull(json['min']) ?? 0,
      max: asDoubleOrNull(json['max']),
      unit: asStringOrNull(json['unit'], trim: true),
    );
  }
}

class PluginBindingSourceDto {
  const PluginBindingSourceDto({
    required this.pluginId,
    required this.displayName,
  });

  final String pluginId;
  final String displayName;

  factory PluginBindingSourceDto.fromJson(Map<String, dynamic> json) {
    return PluginBindingSourceDto(
      pluginId: asStringOrNull(json['plugin_id'], trim: true) ?? '',
      displayName: asStringOrNull(json['display_name'], trim: true) ?? '',
    );
  }
}

class PluginBindingsDto {
  const PluginBindingsDto({
    this.statsSource,
    this.reviewSource,
    this.statsSourceAvailable = false,
    this.reviewSourceAvailable = false,
    this.statsSourceDisplayName,
    this.reviewSourceDisplayName,
    this.statsFields = const <PluginStatsFieldDto>[],
    this.heatVersion,
    this.availableStatsSources = const <PluginBindingSourceDto>[],
    this.availableReviewSources = const <PluginBindingSourceDto>[],
    this.pendingRestart = const <String>[],
  });

  final String? statsSource;
  final String? reviewSource;
  final bool statsSourceAvailable;
  final bool reviewSourceAvailable;
  final String? statsSourceDisplayName;
  final String? reviewSourceDisplayName;
  final List<PluginStatsFieldDto> statsFields;
  final String? heatVersion;
  final List<PluginBindingSourceDto> availableStatsSources;
  final List<PluginBindingSourceDto> availableReviewSources;
  final List<String> pendingRestart;

  PluginStatsFieldDto? fieldForKey(String key) {
    for (final field in statsFields) {
      if (field.key == key) {
        return field;
      }
    }
    return null;
  }

  factory PluginBindingsDto.fromJson(Map<String, dynamic> json) {
    return PluginBindingsDto(
      statsSource: asStringOrNull(json['stats_source'], trim: true),
      reviewSource: asStringOrNull(json['review_source'], trim: true),
      statsSourceAvailable: json['stats_source_available'] == true,
      reviewSourceAvailable: json['review_source_available'] == true,
      statsSourceDisplayName: asStringOrNull(
        json['stats_source_display_name'],
        trim: true,
      ),
      reviewSourceDisplayName: asStringOrNull(
        json['review_source_display_name'],
        trim: true,
      ),
      statsFields: asObjectList(
        json['stats_fields'],
        PluginStatsFieldDto.fromJson,
      ),
      heatVersion: asStringOrNull(json['heat_version'], trim: true),
      availableStatsSources: asObjectList(
        json['available_stats_sources'],
        PluginBindingSourceDto.fromJson,
      ),
      availableReviewSources: asObjectList(
        json['available_review_sources'],
        PluginBindingSourceDto.fromJson,
      ),
      pendingRestart: asStringList(json['pending_restart']),
    );
  }
}
