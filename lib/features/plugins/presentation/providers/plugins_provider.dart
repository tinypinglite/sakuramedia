import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
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
    invalidateOnSignOut(ref);
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
    if (current == null || current.isInstalling) {
      return false;
    }
    state = AsyncData(current.copyWith(isInstalling: true));
    try {
      await _api.install(fileBytes: fileBytes, fileName: fileName);
    } catch (_) {
      if (!isDisposed) {
        state = AsyncData(current.copyWith(isInstalling: false));
      }
      rethrow;
    }
    try {
      final next = await _fetchPlugins();
      if (!isDisposed) {
        state = AsyncData(next);
      }
      return true;
    } catch (_) {
      if (!isDisposed) {
        state = AsyncData(current.copyWith(isInstalling: false));
      }
      return false;
    }
  }

  Future<void> setEnabled(String pluginId, bool enabled) async {
    final current = state.value;
    if (current == null ||
        current.isInstalling ||
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
        current.busyPluginIds.contains(pluginId)) {
      return;
    }
    _setBusy(pluginId, true);
    try {
      await _api.remove(pluginId);
      if (!isDisposed) {
        state = AsyncData(
          current.copyWith(
            plugins: current.plugins
                .where((plugin) => plugin.pluginId != pluginId)
                .toList(growable: false),
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
}
