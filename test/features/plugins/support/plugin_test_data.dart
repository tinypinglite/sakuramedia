import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';

/// 插件列表项的 JSON 夹具，字段与后端 `GET /system/plugins` 对齐。
Map<String, dynamic> pluginSummaryJson({
  bool enabled = true,
  String? releaseApiUrl,
  String version = '1.0.0',
  List<String> testCapabilities = const <String>[],
  String? testMovieNumber,
}) {
  return <String, dynamic>{
    'plugin_id': 'demo_plugin',
    'display_name': '演示插件',
    'version': version,
    'host_api_version': 1,
    'enabled': enabled,
    'load_status': 'ok',
    'load_error': null,
    'release_api_url': releaseApiUrl,
    'test_capabilities': testCapabilities,
    'test_movie_number': testMovieNumber,
  };
}

/// 插件列表项的 DTO 夹具。
PluginSummaryDto pluginSummaryDto({
  String id = 'demo_plugin',
  String version = '1.0.0',
  bool enabled = false,
  String? releaseApiUrl,
  List<PluginTestCapability> testCapabilities = const <PluginTestCapability>[],
  String? testMovieNumber,
}) {
  return PluginSummaryDto(
    pluginId: id,
    displayName: '演示插件',
    version: version,
    hostApiVersion: 1,
    enabled: enabled,
    loadStatus: 'ok',
    releaseApiUrl: releaseApiUrl,
    testCapabilities: testCapabilities,
    testMovieNumber: testMovieNumber,
  );
}
