import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_market_dto.dart';
import 'package:sakuramedia/features/plugins/data/plugin_market_source.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_market_state.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'plugin_market_provider.g.dart';

/// 插件市场索引与市场安装 / 更新操作的会话级共享状态。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class PluginMarket extends _$PluginMarket
    with AsyncNotifierDisposeGuardMixin<PluginMarketState> {
  PluginsApi get _api => ref.read(pluginsApiProvider);

  @override
  Future<PluginMarketState> build() async {
    invalidateOnSessionChange(ref);
    attachDisposeGuard();
    return PluginMarketState(catalog: await _fetchCatalog());
  }

  Future<PluginMarketCatalogDto> _fetchCatalog() {
    return _api.fetchMarketCatalog(kPluginMarketIndexUrl);
  }

  Future<void> reload() async {
    final previousKeyword = state.value?.keyword ?? '';
    state = const AsyncLoading<PluginMarketState>();
    final next = await AsyncValue.guard(() async {
      final catalog = await _fetchCatalog();
      return PluginMarketState(catalog: catalog, keyword: previousKeyword);
    });
    if (!isDisposed) {
      state = next;
    }
  }

  void setKeyword(String keyword) {
    final current = state.value;
    if (current == null || current.keyword == keyword) {
      return;
    }
    state = AsyncData(current.copyWith(keyword: keyword));
  }

  /// 下载市场插件安装包并交给后端安装，随后刷新已安装插件列表。
  Future<void> install(PluginMarketItemDto plugin) async {
    final release = plugin.latest;
    if (release == null || _isBusy(plugin.pluginId)) {
      return;
    }
    _setBusy(plugin.pluginId, true);
    try {
      final fileBytes = await _api.downloadMarketRelease(release);
      await _api.install(
        fileBytes: fileBytes,
        fileName: _zipFileName(release.downloadUrl),
        sha256: release.sha256,
      );
      await ref.read(pluginsProvider.notifier).reload();
    } finally {
      _setBusy(plugin.pluginId, false);
    }
  }

  /// 下载市场最新版本并交给后端升级，随后刷新已安装插件列表。
  Future<void> upgrade(PluginMarketItemDto plugin) async {
    final release = plugin.latest;
    if (release == null || _isBusy(plugin.pluginId)) {
      return;
    }
    _setBusy(plugin.pluginId, true);
    try {
      final fileBytes = await _api.downloadMarketRelease(release);
      await _api.upgrade(
        pluginId: plugin.pluginId,
        update: PluginReleaseUpdate(
          version: release.version,
          notes: '',
          assetUrl: release.downloadUrl,
          assetFileName: _zipFileName(release.downloadUrl),
          sha256: release.sha256,
        ),
        fileBytes: fileBytes,
      );
      await ref.read(pluginsProvider.notifier).reload();
    } finally {
      _setBusy(plugin.pluginId, false);
    }
  }

  bool _isBusy(String pluginId) {
    return state.value?.busyPluginIds.contains(pluginId) ?? false;
  }

  void _setBusy(String pluginId, bool busy) {
    if (isDisposed) {
      return;
    }
    final current = state.value;
    if (current == null) {
      return;
    }
    final busyPluginIds = Set<String>.of(current.busyPluginIds);
    if (busy) {
      busyPluginIds.add(pluginId);
    } else {
      busyPluginIds.remove(pluginId);
    }
    state = AsyncData(current.copyWith(busyPluginIds: busyPluginIds));
  }
}

String _zipFileName(String downloadUrl) {
  final segments = Uri.tryParse(downloadUrl)?.pathSegments;
  final name = (segments == null || segments.isEmpty) ? null : segments.last;
  if (name != null && name.toLowerCase().endsWith('.zip')) {
    return name;
  }
  return 'plugin.zip';
}
