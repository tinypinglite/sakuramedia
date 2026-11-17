import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_market_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_market_state.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_state.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 插件页加载态占位状态：真实 [PluginsState] + [BoneMock] 文案，
/// 供 `AppSkeletonizer` 渲染与真实插件行同形的静态骨架。
PluginsState pluginsPlaceholderState({int count = 3}) {
  return PluginsState(
    plugins: List<PluginSummaryDto>.generate(
      count,
      (index) => PluginSummaryDto(
        pluginId: 'plugin-$index',
        displayName: BoneMock.words(2),
        version: '1.0.0',
        hostApiVersion: 1,
        enabled: true,
        loadStatus: 'ok',
      ),
      growable: false,
    ),
  );
}

/// 插件市场加载态占位状态：真实 [PluginMarketState] + [BoneMock] 文案，
/// 供 `AppSkeletonizer` 渲染与真实市场行同形的静态骨架。
PluginMarketState pluginMarketPlaceholderState({int count = 3}) {
  return PluginMarketState(
    catalog: PluginMarketCatalogDto(
      schemaVersion: 1,
      plugins: List<PluginMarketItemDto>.generate(
        count,
        (index) => PluginMarketItemDto(
          pluginId: 'plugin-$index',
          displayName: BoneMock.words(2),
          description: BoneMock.words(10),
          author: BoneMock.words(1),
          repo: 'example/plugin-$index',
          official: true,
          latest: PluginMarketReleaseDto(
            version: '1.0.0',
            hostApiVersion: 1,
            downloadUrl: 'https://example.com/plugin-$index.zip',
          ),
        ),
        growable: false,
      ),
    ),
  );
}
