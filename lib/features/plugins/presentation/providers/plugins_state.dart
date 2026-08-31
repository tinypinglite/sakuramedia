import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';

@immutable
class PluginsState {
  const PluginsState({
    required this.plugins,
    this.busyPluginIds = const <String>{},
    this.isInstalling = false,
  });

  final List<PluginSummaryDto> plugins;

  /// 正在执行启停 / 删除的插件 ID，对应行进入忙碌态。
  final Set<String> busyPluginIds;

  /// 是否正在上传安装插件包；安装期间禁用其它写操作。
  final bool isInstalling;

  PluginsState copyWith({
    List<PluginSummaryDto>? plugins,
    Set<String>? busyPluginIds,
    bool? isInstalling,
  }) {
    return PluginsState(
      plugins: plugins ?? this.plugins,
      busyPluginIds: busyPluginIds ?? this.busyPluginIds,
      isInstalling: isInstalling ?? this.isInstalling,
    );
  }
}
