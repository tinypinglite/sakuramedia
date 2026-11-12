import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'plugins_provider.g.dart';

/// 已安装插件列表与安装 / 启停 / 删除操作的会话级共享状态。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class Plugins extends _$Plugins
    with AsyncNotifierDisposeGuardMixin<PluginsState> {
  PluginsApi get _api => ref.read(pluginsApiProvider);

  @override
  Future<PluginsState> build() async {
    // 插件 display_name / load_error 由后端按请求语言解析（读时文案），
    // 语言一变这份快照就过期，必须跟着重拉。
    ref.watch(appLanguageControllerProvider);
    invalidateOnSessionChange(ref);
    attachDisposeGuard();
    return _fetchPlugins();
  }

  Future<void> reload() async {
    state = const AsyncLoading<PluginsState>();
    final next = await AsyncValue.guard(_fetchPlugins);
    if (!isDisposed) {
      state = next;
    }
  }

  Future<PluginsState> _fetchPlugins() async {
    final plugins = await _api.list();
    return PluginsState(plugins: plugins);
  }

  /// 上传安装插件并刷新列表。
  ///
  /// 上传失败会抛异常；上传成功但列表刷新失败时保留旧列表并返回 `false`，
  /// 让 UI 区分「没装上」和「装上了但列表没刷新」两种结果。
  Future<bool> install({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final current = state.value;
    if (current == null ||
        current.isInstalling ||
        current.busyPluginIds.isNotEmpty) {
      return false;
    }
    state = AsyncData(current.copyWith(isInstalling: true));
    try {
      await _api.install(fileBytes: fileBytes, fileName: fileName);
    } catch (_) {
      _setInstalling(false);
      rethrow;
    }
    try {
      final next = await _fetchPlugins();
      if (!isDisposed) {
        _applyInstalledPlugins(next.plugins);
      }
      return true;
    } catch (_) {
      _setInstalling(false);
      return false;
    }
  }

  /// 按各插件 manifest 声明的 Release API 查询可用更新。
  ///
  /// 单个 GitHub 请求失败不影响其他插件，返回值用于让页面提示部分失败。
  Future<bool> checkUpdates() async {
    final current = state.value;
    if (current == null ||
        current.isInstalling ||
        current.isCheckingUpdates ||
        current.busyPluginIds.isNotEmpty) {
      return false;
    }
    state = AsyncData(current.copyWith(isCheckingUpdates: true));
    final checkedVersions = <String, String>{
      for (final plugin in current.plugins) plugin.pluginId: plugin.version,
    };
    final results = <String, PluginReleaseUpdate?>{};
    var allChecksSucceeded = true;
    for (final plugin in current.plugins) {
      if (plugin.releaseApiUrl == null) {
        continue;
      }
      try {
        results[plugin.pluginId] = await _api.checkForUpdate(plugin);
      } catch (_) {
        allChecksSucceeded = false;
      }
    }
    if (!isDisposed) {
      _applyUpdateResults(results, checkedVersions);
    }
    return allChecksSucceeded;
  }

  /// 下载 Release zip 并交给后端替换已安装插件；生效时机仍由用户手动重启容器决定。
  Future<void> upgrade(String pluginId) async {
    final current = state.value;
    final update = current?.updates[pluginId];
    if (current == null ||
        update == null ||
        current.isInstalling ||
        current.isCheckingUpdates ||
        current.busyPluginIds.contains(pluginId)) {
      return;
    }
    _setBusy(pluginId, true);
    try {
      final fileBytes = await _api.downloadUpdate(update);
      final version = await _api.upgrade(
        pluginId: pluginId,
        update: update,
        fileBytes: fileBytes,
      );
      _applyUpgrade(pluginId, version);
    } catch (_) {
      _setBusy(pluginId, false);
      rethrow;
    }
  }

  Future<void> setEnabled(String pluginId, bool enabled) async {
    final current = state.value;
    if (current == null ||
        current.isInstalling ||
        current.isCheckingUpdates ||
        current.busyPluginIds.contains(pluginId)) {
      return;
    }
    _setBusy(pluginId, true);
    try {
      final updated = await _api.setEnabled(pluginId, enabled: enabled);
      _replacePlugin(updated);
    } catch (_) {
      _setBusy(pluginId, false);
      rethrow;
    }
  }

  Future<void> remove(String pluginId) async {
    final current = state.value;
    if (current == null ||
        current.isInstalling ||
        current.isCheckingUpdates ||
        current.busyPluginIds.contains(pluginId)) {
      return;
    }
    _setBusy(pluginId, true);
    try {
      await _api.remove(pluginId);
      if (!isDisposed) {
        final updates = Map<String, PluginReleaseUpdate>.of(current.updates)
          ..remove(pluginId);
        state = AsyncData(
          current.copyWith(
            plugins: current.plugins
                .where((plugin) => plugin.pluginId != pluginId)
                .toList(growable: false),
            updates: updates,
          ),
        );
      }
    } catch (_) {
      _setBusy(pluginId, false);
      rethrow;
    }
  }

  void _setBusy(String pluginId, bool busy) {
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

  void _setInstalling(bool installing) {
    if (isDisposed) {
      return;
    }
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(isInstalling: installing));
  }

  /// 把安装后的列表合并进最新状态，避免覆盖检查更新期间得到的更新结果。
  void _applyInstalledPlugins(List<PluginSummaryDto> plugins) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final previousVersions = <String, String>{
      for (final plugin in current.plugins) plugin.pluginId: plugin.version,
    };
    final installedVersions = <String, String>{
      for (final plugin in plugins) plugin.pluginId: plugin.version,
    };
    final updates = Map<String, PluginReleaseUpdate>.of(current.updates)
      ..removeWhere(
        (pluginId, _) =>
            previousVersions[pluginId] != installedVersions[pluginId],
      );
    state = AsyncData(
      current.copyWith(plugins: plugins, updates: updates, isInstalling: false),
    );
  }

  /// 只应用仍对应当前已安装版本的检查结果，避免安装期间回写旧版本更新。
  void _applyUpdateResults(
    Map<String, PluginReleaseUpdate?> results,
    Map<String, String> checkedVersions,
  ) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final installedVersions = <String, String>{
      for (final plugin in current.plugins) plugin.pluginId: plugin.version,
    };
    final updates = Map<String, PluginReleaseUpdate>.of(current.updates);
    for (final entry in results.entries) {
      if (checkedVersions[entry.key] != installedVersions[entry.key]) {
        continue;
      }
      final update = entry.value;
      if (update == null) {
        updates.remove(entry.key);
      } else {
        updates[entry.key] = update;
      }
    }
    state = AsyncData(
      current.copyWith(updates: updates, isCheckingUpdates: false),
    );
  }

  void _replacePlugin(PluginSummaryDto updated) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final busyPluginIds = Set<String>.of(current.busyPluginIds)
      ..remove(updated.pluginId);
    state = AsyncData(
      current.copyWith(
        plugins: <PluginSummaryDto>[
          for (final plugin in current.plugins)
            if (plugin.pluginId == updated.pluginId) updated else plugin,
        ],
        busyPluginIds: busyPluginIds,
      ),
    );
  }

  void _applyUpgrade(String pluginId, String version) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final busyPluginIds = Set<String>.of(current.busyPluginIds)
      ..remove(pluginId);
    final updates = Map<String, PluginReleaseUpdate>.of(current.updates)
      ..remove(pluginId);
    state = AsyncData(
      current.copyWith(
        plugins: <PluginSummaryDto>[
          for (final plugin in current.plugins)
            if (plugin.pluginId == pluginId)
              plugin.copyWith(version: version)
            else
              plugin,
        ],
        busyPluginIds: busyPluginIds,
        updates: updates,
      ),
    );
  }
}
