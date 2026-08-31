import 'package:sakuramedia/core/json/json_parse.dart';

/// `GET /system/plugins` 列表项。
class PluginSummaryDto {
  const PluginSummaryDto({
    required this.pluginId,
    required this.displayName,
    required this.version,
    required this.hostApiVersion,
    required this.enabled,
    required this.loadStatus,
    this.loadError,
  });

  final String pluginId;
  final String displayName;
  final String version;
  final int hostApiVersion;
  final bool enabled;
  final String loadStatus;
  final String? loadError;

  factory PluginSummaryDto.fromJson(Map<String, dynamic> json) {
    return PluginSummaryDto(
      pluginId: asStringOrNull(json['plugin_id']) ?? '',
      displayName: asStringOrNull(json['display_name']) ?? '',
      version: asStringOrNull(json['version']) ?? '',
      hostApiVersion: asInt(json['host_api_version']),
      enabled: json['enabled'] == true,
      loadStatus: asStringOrNull(json['load_status']) ?? 'ok',
      loadError: asStringOrNull(json['load_error']),
    );
  }
}

/// 插件私有配置接口的响应（`plugins.settings.<plugin_id>`）。
class PluginSettingsDto {
  const PluginSettingsDto({required this.settings});

  final Map<String, dynamic> settings;

  factory PluginSettingsDto.fromJson(Map<String, dynamic> json) {
    return PluginSettingsDto(settings: asMap(json['settings']));
  }
}
