import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/format/release_version.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_market_dto.dart';

/// 市场插件相对已安装插件的状态。
enum PluginMarketStatus { notInstalled, installed, updateAvailable }

/// 插件市场页状态：索引目录、搜索关键词与逐插件忙碌标记。
@immutable
class PluginMarketState {
  const PluginMarketState({
    required this.catalog,
    this.busyPluginIds = const <String>{},
    this.keyword = '',
  });

  final PluginMarketCatalogDto catalog;

  /// 正在下载安装 / 更新的插件 ID，对应卡片进入忙碌态。
  final Set<String> busyPluginIds;

  final String keyword;

  /// 按关键词过滤后的插件列表；关键词为空时返回全量。
  List<PluginMarketItemDto> get visiblePlugins {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) {
      return catalog.plugins;
    }
    return <PluginMarketItemDto>[
      for (final plugin in catalog.plugins)
        if (_matches(plugin, query)) plugin,
    ];
  }

  bool _matches(PluginMarketItemDto plugin, String query) {
    // 搜索匹配所有语言变体（中文名、英文名、中英文简介），关键词过滤不依赖
    // 当前语言，切换界面语言也不需要重新拉取索引。
    return plugin.pluginId.toLowerCase().contains(query) ||
        plugin.author.toLowerCase().contains(query) ||
        plugin.searchTexts.any(
          (text) => text.toLowerCase().contains(query),
        );
  }

  PluginMarketState copyWith({
    Set<String>? busyPluginIds,
    String? keyword,
  }) {
    return PluginMarketState(
      catalog: catalog,
      busyPluginIds: busyPluginIds ?? this.busyPluginIds,
      keyword: keyword ?? this.keyword,
    );
  }
}

/// 计算市场条目相对已安装插件版本的状态。
///
/// 已安装版本或市场版本无法解析为三段版本号时按「已安装」处理，
/// 不把解析歧义显示成「可更新」。
PluginMarketStatus pluginMarketStatus(
  PluginMarketItemDto item,
  PluginSummaryDto? installed,
) {
  if (installed == null) {
    return PluginMarketStatus.notInstalled;
  }
  final latestVersion = item.latest?.version;
  if (latestVersion == null) {
    return PluginMarketStatus.installed;
  }
  final installedVersion = ReleaseVersion.tryParse(installed.version);
  final marketVersion = ReleaseVersion.tryParse(latestVersion);
  if (installedVersion == null || marketVersion == null) {
    return PluginMarketStatus.installed;
  }
  return marketVersion.compareTo(installedVersion) > 0
      ? PluginMarketStatus.updateAvailable
      : PluginMarketStatus.installed;
}
