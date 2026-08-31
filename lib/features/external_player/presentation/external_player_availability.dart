import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';

/// 外部播放器是否就绪（设置了默认外部播放器且当前平台支持）。
///
/// 详情页用它决定是否展示「合并播放」模式选项；树上没有 `ProviderScope`
/// 的局部上下文（部分 widget 测试）返回 false（降级为不展示），与旧
/// `ProviderNotFoundException` 降级语义一致。桌面端通道不支持，恒为 false。
///
/// 原位于 `data/external_player_availability.dart`；迁 Riverpod 时随
/// `externalPlayerPreferenceProvider` 上移到 presentation（它持 BuildContext，
/// 本就是 UI 侧关注点，data 层不允许引 presentation 的 provider）。
bool isExternalPlayerReady(BuildContext context) {
  try {
    final selection =
        ProviderScope.containerOf(
          context,
          listen: false,
        ).read(externalPlayerPreferenceProvider).value;
    // 偏好还没读完(value 为 null)按未就绪处理,与旧 isLoaded=false 一致。
    return (selection?.hasExternalPlayer ?? false) &&
        const ExternalPlayerChannel().isSupported;
  } on Object {
    return false;
  }
}
