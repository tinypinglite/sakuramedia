import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';

/// 插件任务分段标题优先使用插件显示名，缺失时回退 plugin_id。
Map<String, String> activityPluginDisplayNames(
  Iterable<PluginSummaryDto> plugins,
) {
  return <String, String>{
    for (final plugin in plugins)
      if (plugin.displayName.trim().isNotEmpty)
        plugin.pluginId: plugin.displayName.trim(),
  };
}

String activityPluginDisplayName(
  String pluginId,
  Map<String, String> displayNames,
) {
  final name = displayNames[pluginId]?.trim();
  return name == null || name.isEmpty ? pluginId : name;
}
