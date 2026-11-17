import 'package:sakuramedia/features/plugins/data/dto/plugin_market_dto.dart';

/// 市场索引单个插件条目的 JSON 夹具，字段与 sakuramedia-plugin-market 对齐。
Map<String, dynamic> pluginMarketItemJson({
  String pluginId = 'demo_plugin',
  String displayName = '演示插件',
  String description = '演示插件的用途说明',
  Map<String, String>? displayNameI18n,
  Map<String, String>? descriptionI18n,
  String version = '1.1.0',
  bool official = true,
  int hostApiVersion = 10,
  String? homepage,
  bool withHomepage = true,
}) {
  return <String, dynamic>{
    'plugin_id': pluginId,
    'display_name': displayName,
    'description': description,
    'display_name_i18n': ?displayNameI18n,
    'description_i18n': ?descriptionI18n,
    'author': 'SakuraMedia',
    'repo': 'example/$pluginId',
    'homepage': withHomepage
        ? (homepage ?? 'https://github.com/example/$pluginId')
        : null,
    'categories': <String>['other'],
    'official': official,
    'latest': <String, dynamic>{
      'version': version,
      'host_api_version': hostApiVersion,
      'download_url':
          'https://github.com/example/$pluginId/releases/download/'
          'v$version/$pluginId-$version.zip',
      'sha256':
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      'published_at': '2026-10-01T00:00:00Z',
    },
  };
}

/// 市场索引整体 JSON 夹具。
Map<String, dynamic> pluginMarketIndexJson({
  List<Map<String, dynamic>>? plugins,
}) {
  return <String, dynamic>{
    'schema_version': 1,
    'updated_at': '2026-10-06T10:00:00Z',
    'plugins': plugins ?? <Map<String, dynamic>>[pluginMarketItemJson()],
  };
}

/// 市场索引条目的 DTO 夹具。
PluginMarketItemDto pluginMarketItemDto({
  String pluginId = 'demo_plugin',
  String displayName = '演示插件',
  String description = '演示插件的用途说明',
  Map<String, String> displayNameI18n = const <String, String>{},
  Map<String, String> descriptionI18n = const <String, String>{},
  String version = '1.1.0',
  bool official = true,
}) {
  return PluginMarketItemDto(
    pluginId: pluginId,
    displayName: displayName,
    description: description,
    author: 'SakuraMedia',
    repo: 'example/$pluginId',
    homepage: 'https://github.com/example/$pluginId',
    categories: const <String>['other'],
    official: official,
    displayNameI18n: displayNameI18n,
    descriptionI18n: descriptionI18n,
    latest: PluginMarketReleaseDto(
      version: version,
      hostApiVersion: 10,
      downloadUrl:
          'https://github.com/example/$pluginId/releases/download/'
          'v$version/$pluginId-$version.zip',
      sha256:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    ),
  );
}
