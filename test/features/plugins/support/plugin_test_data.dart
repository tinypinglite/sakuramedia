import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';

/// 插件列表项的 JSON 夹具，字段与后端 `GET /system/plugins` 对齐。
Map<String, dynamic> pluginSummaryJson({bool enabled = true}) {
  return <String, dynamic>{
    'plugin_id': 'demo_plugin',
    'display_name': '演示插件',
    'version': '1.0.0',
    'host_api_version': 1,
    'enabled': enabled,
    'load_status': 'ok',
    'load_error': null,
  };
}

/// 插件列表项的 DTO 夹具。
PluginSummaryDto pluginSummaryDto({
  String id = 'demo_plugin',
  bool enabled = false,
}) {
  return PluginSummaryDto(
    pluginId: id,
    displayName: '演示插件',
    version: '1.0.0',
    hostApiVersion: 1,
    enabled: enabled,
    loadStatus: 'ok',
  );
}
