import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';

@immutable
class PluginsState {
  const PluginsState({
    required this.plugins,
    this.busyPluginIds = const <String>{},
    this.updates = const <String, PluginReleaseUpdate>{},
    this.isInstalling = false,
    this.isCheckingUpdates = false,
  });

  final List<PluginSummaryDto> plugins;

  /// 正在执行启停 / 删除的插件 ID，对应行进入忙碌态。
  final Set<String> busyPluginIds;

  /// 已检查到、可直接安装的 Release 更新，以插件 ID 为键。
  final Map<String, PluginReleaseUpdate> updates;

  /// 是否正在上传安装插件包；安装期间禁用其它写操作。
  final bool isInstalling;

  /// 是否正在逐个查询已声明 Release 地址的插件。
  final bool isCheckingUpdates;

  PluginsState copyWith({
    List<PluginSummaryDto>? plugins,
    Set<String>? busyPluginIds,
    Map<String, PluginReleaseUpdate>? updates,
    bool? isInstalling,
    bool? isCheckingUpdates,
  }) {
    return PluginsState(
      plugins: plugins ?? this.plugins,
      busyPluginIds: busyPluginIds ?? this.busyPluginIds,
      updates: updates ?? this.updates,
      isInstalling: isInstalling ?? this.isInstalling,
      isCheckingUpdates: isCheckingUpdates ?? this.isCheckingUpdates,
    );
  }
}
